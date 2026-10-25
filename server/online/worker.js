// Infinity Grid online server (Cloudflare Worker).
// - Serves the web build (static assets; index.wasm is joined from parts).
// - One Durable Object per room relays moves and keeps the match history, so a
//   player whose connection drops can come back within RECONNECT_SECONDS.
// - One "lobby" Durable Object pairs players who want a quick match.
//
// Protocol (wss://<worker>/play?...), shared with the PC host for the basics:
//   mode=create                      -> {"type":"room","code":"4821"}
//   mode=join&code=4821              -> both: {"type":"start","team","cards","code","token"}
//   mode=quick                       -> {"type":"queued"}, later {"type":"matched","code","team"}
//   mode=match&code=<12>&team=0|1    -> both: start (the lobby sends players here)
//   mode=resume&code=..&token=..     -> {"type":"resume","team","cards","code","token","moves":[...]}
// Client messages: {"type":"move"|"pass", "seq": n, ...}, {"type":"look", ...}, {"type":"leave"}, raw "ping".
// Node Ping before every match ("start" carries ping:true): both send
// {"type":"node_ping", spot:[x,y]}; the server rolls the signal and answers
// {"type":"ping_result", picks, signal, winner} (winner -1 = collision, ping
// again); the winner sends {"type":"choose", starter} and both get
// {"type":"starter", team}. Moves are accepted only after that.
// Server events: opponent_away {seconds}, opponent_back, opponent_left, error {reason}.
// Every client runs the rules itself; the server only checks turn order.
// Player accounts for the cosmetics shop live in accounts.js (/api/account);
// credit packs paid through Stripe Checkout in payments.js (/api/stripe/webhook);
// signing in with e-mail or Google in auth.js (/api/auth, /auth/google);
// friends in friends.js (/api/friends); ranked queue, rating and leaderboard in
// ranked.js (/api/ranked, /play?mode=ranked). Ranked rooms referee every move
// with rules.js and settle the result themselves.

import { handleAccountApi } from "./accounts.js";
import { donePage, handleWebhook } from "./payments.js";
import { handleAuthApi, handleGooglePages } from "./auth.js";
import { handleFriendsApi } from "./friends.js";
import { handleRankedApi, settle } from "./ranked.js";
import { newGame, pingDistance, play, setStarter } from "./rules.js";
import { chargeMove, clockDeadline, clockView, startClock } from "./clock.js";
export { Login } from "./auth.js";
export { RankedLobby } from "./ranked.js";
export { Account } from "./accounts.js";

// Must match MovementCard.create_deck() (checked by tests/lan_test.gd).
const CARD_NAMES = [
  "Crane", "Wave", "Comet", "Shell", "Vortex", "Nova", "Tide", "Orbit", "Rift", "Halo",
  "Ember", "Drift", "Zephyr", "Eclipse", "Prism", "Pulse", "Echo", "Serpent", "Viper",
];

// Static assets are limited to 25 MiB per file, so the engine's index.wasm and
// the game data index.pck are uploaded in parts (tools/publish_online.ps1) and
// joined here.
const SPLIT_FILES = {
  "/index.wasm": {
    type: "application/wasm",
    parts: ["/index.wasm.part0", "/index.wasm.part1"],
  },
  "/index.pck": {
    type: "application/octet-stream",
    parts: ["/index.pck.part0", "/index.pck.part1"],
  },
};

// Must match EmoteWheel.CATALOGUE in scripts/ui/emote_wheel.gd.
const EMOTE_IDS = [
  "dance", "spin", "hop", "shadowbox", "chill", "glitch",
  "twerk", "smoke", "laugh", "cheer",
  "gg", "glhf", "e404", "lag", "nice", "heat",
  "haha", "what", "heart", "skull", "fire", "eyes",
];

const RECONNECT_SECONDS = 60;
// A quick match is cancelled when both players have not arrived by then.
const MATCH_JOIN_SECONDS = 15;
// Rooms nobody uses any more are deleted after this long.
const ROOM_IDLE_SECONDS = 6 * 60 * 60;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (Object.hasOwn(SPLIT_FILES, url.pathname)) {
      return serveSplitFile(request, env, SPLIT_FILES[url.pathname]);
    }
    if (url.pathname === "/api/stripe/webhook" && request.method === "POST") {
      return handleWebhook(request, env);
    }
    if (url.pathname.startsWith("/api/auth/")) {
      return handleAuthApi(request, env, url);
    }
    if (url.pathname === "/auth/google/start" || url.pathname === "/auth/google/callback") {
      return handleGooglePages(request, env, url);
    }
    if (url.pathname === "/checkout/done") {
      return donePage(url);
    }
    if (url.pathname.startsWith("/api/account")) {
      return handleAccountApi(request, env, url);
    }
    if (url.pathname.startsWith("/api/friends")) {
      return handleFriendsApi(request, env, url);
    }
    if (url.pathname.startsWith("/api/ranked")) {
      return handleRankedApi(request, env, url);
    }
    if (url.pathname !== "/play") {
      return new Response("Not found", { status: 404 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected a WebSocket", { status: 426 });
    }
    const mode = url.searchParams.get("mode");
    let code = url.searchParams.get("code") || "";
    if (mode === "quick") {
      return env.LOBBY.get(env.LOBBY.idFromName("lobby")).fetch(request);
    }
    if (mode === "ranked") {
      return env.RANKED.get(env.RANKED.idFromName("ranked")).fetch(request);
    }
    if (mode === "create") {
      code = String(Math.floor(Math.random() * 10000)).padStart(4, "0");
    } else if (mode === "join" && !/^\d{4}$/.test(code)) {
      return rejectSocket("not_found");
    } else if (mode === "match" && !/^[a-z0-9]{12}$/.test(code)) {
      return rejectSocket("bad_request");
    } else if (mode === "resume" && !/^(\d{4}|[a-z0-9]{12})$/.test(code)) {
      return rejectSocket("not_found");
    } else if (!["create", "join", "match", "resume"].includes(mode)) {
      return rejectSocket("bad_request");
    }
    const room = env.ROOMS.get(env.ROOMS.idFromName(code));
    const forwarded = new URL(request.url);
    forwarded.searchParams.set("code", code);
    return room.fetch(new Request(forwarded, request));
  },
};

export class Room {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    // Answered by the runtime without waking the object.
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async load() {
    return (await this.state.storage.get("room")) || null;
  }

  async save(room) {
    room.touched = Date.now();
    await this.state.storage.put("room", room);
  }

  // A room has one alarm but up to two deadlines: the room's own (join,
  // reconnect or idle; `baseAt`) and a ranked clock running out. The alarm is
  // set to the earlier one; alarm() tells them apart. `baseAt` is stored
  // without touching the room so idle rooms still expire.
  async arm(room, baseAt) {
    if (baseAt !== undefined) {
      room.baseAt = baseAt;
      await this.state.storage.put("room", room);
    }
    const clock = this.runningClock(room);
    const at = Math.min(room.baseAt || Infinity, clock ? clockDeadline(clock) : Infinity);
    if (at !== Infinity) await this.state.storage.setAlarm(at);
  }

  runningClock(room) {
    const ranked = room.ranked;
    return ranked && ranked.clock && !ranked.settled && room.phase === "playing" ? ranked.clock : null;
  }

  // Both players get the clock as the server sees it right now.
  sendClock(room) {
    const clock = this.runningClock(room);
    if (!clock) return;
    const view = clockView(clock, Date.now());
    for (const seat of [0, 1]) {
      const socket = this.socketFor(seat);
      if (socket) send(socket, view);
    }
  }

  // The open connection of a seat; a socket that is closing does not count.
  socketFor(seat, except = null) {
    return this.state.getWebSockets(String(seat)).find((socket) => socket !== except && socket.readyState === 1) || null;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/setup") {
      // A ranked pairing from ranked.js: both seats are known, the server referees.
      const body = await request.json();
      const cards = drawCards(5);
      const room = { code: "", phase: "matching", cards, tokens: [null, null], moves: [], ranked: { players: body.players, game: newGame(cards) } };
      await this.save(room);
      await this.arm(room, Date.now() + MATCH_JOIN_SECONDS * 1000);
      return new Response("ok");
    }
    const mode = url.searchParams.get("mode");
    const code = url.searchParams.get("code");
    let room = await this.load();
    if (room && room.phase === "ended") {
      await this.state.storage.deleteAll();
      room = null;
    }

    if (mode === "create") {
      if (room) {
        return rejectSocket("code_taken");
      }
      room = { code, phase: "waiting", cards: drawCards(5), tokens: [newToken(), null], moves: [] };
      await this.save(room);
      await this.arm(room, Date.now() + ROOM_IDLE_SECONDS * 1000);
      return this.accept(0, { type: "room", code });
    }

    if (mode === "join") {
      if (!room || room.phase !== "waiting" || !room.tokens[0]) {
        return rejectSocket(room && room.phase === "playing" ? "full" : "not_found");
      }
      room.tokens[1] = newToken();
      room.phase = "playing";
      await this.save(room);
      const response = this.accept(1, null);
      this.sendStart(room);
      return response;
    }

    if (mode === "match") {
      const team = Number(url.searchParams.get("team"));
      if (team !== 0 && team !== 1) {
        return rejectSocket("bad_request");
      }
      if (!room) {
        room = { code, phase: "matching", cards: drawCards(5), tokens: [null, null], moves: [] };
        await this.arm(room, Date.now() + MATCH_JOIN_SECONDS * 1000);
      }
      room.code = code;
      if (room.phase !== "matching" || room.tokens[team]) {
        return rejectSocket("full");
      }
      room.tokens[team] = newToken();
      const ready = room.tokens[0] && room.tokens[1];
      if (ready) {
        room.phase = "playing";
        await this.arm(room, Date.now() + ROOM_IDLE_SECONDS * 1000);
      }
      await this.save(room);
      const response = this.accept(team, ready ? null : { type: "queued" });
      if (ready) {
        this.sendStart(room);
      }
      return response;
    }

    if (mode === "resume") {
      const token = url.searchParams.get("token");
      const seat = room ? room.tokens.indexOf(token) : -1;
      if (!room || room.phase !== "playing" || seat < 0 || !token) {
        return rejectSocket("not_found");
      }
      await this.save(room);
      // Accept the new connection before closing the old one so the close
      // handler sees the seat as still taken.
      const old = this.socketFor(seat);
      const response = this.accept(seat, {
        type: "resume", team: seat, cards: room.cards, code: room.code, token, moves: room.moves,
        starter: room.starter === undefined ? -1 : room.starter, ping: room.ping || null,
        opponent_look: (room.looks || [null, null])[1 - seat],
        clock: this.runningClock(room) ? clockView(room.ranked.clock, Date.now()) : null,
      });
      if (old) {
        old.close(1000, "replaced");
      }
      const other = this.socketFor(1 - seat);
      if (other) {
        send(other, { type: "opponent_back" });
        await this.arm(room, Date.now() + ROOM_IDLE_SECONDS * 1000);
      }
      return response;
    }
    return rejectSocket("bad_request");
  }

  accept(seat, firstMessage) {
    const [client, server] = Object.values(new WebSocketPair());
    this.state.acceptWebSocket(server, [String(seat)]);
    if (firstMessage) {
      send(server, firstMessage);
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  sendStart(room) {
    for (const seat of [0, 1]) {
      const socket = this.socketFor(seat);
      if (socket) {
        send(socket, { type: "start", team: seat, cards: room.cards, code: room.code, token: room.tokens[seat], ping: true });
      }
    }
  }

  // Node Ping: both picks in, roll the signal; equal distance means another round.
  async nodePing(room, seat, message) {
    if (room.starter !== undefined) return;
    const spot = message.spot || [];
    const x = Number(spot[0]), y = Number(spot[1]);
    if (!(x >= 0 && x <= 1 && y >= 0 && y <= 1)) return;
    room.ping = room.ping || { picks: [null, null], winner: -1 };
    if (room.ping.winner >= 0) return;
    room.ping.picks[seat] = [x, y];
    if (room.ping.picks.some((pick) => !pick)) {
      await this.save(room);
      return;
    }
    const signal = [Math.random(), Math.random()];
    const [a, b] = room.ping.picks.map((pick) => pingDistance(pick, signal));
    const winner = a === b ? -1 : (a < b ? 0 : 1);
    const result = { type: "ping_result", picks: room.ping.picks, signal, winner };
    room.ping = winner < 0 ? { picks: [null, null], winner: -1 } : { picks: room.ping.picks, winner };
    await this.save(room);
    for (const s of [0, 1]) {
      const socket = this.socketFor(s);
      if (socket) send(socket, result);
    }
  }

  async chooseStarter(room, seat, message) {
    if (room.starter !== undefined || !room.ping || room.ping.winner !== seat) return;
    const starter = Number(message.starter) === 1 ? 1 : 0;
    room.starter = starter;
    if (room.ranked) {
      setStarter(room.ranked.game, starter);
      room.ranked.clock = startClock(starter, Date.now(), Number(this.env.RANKED_CLOCK_MS) || undefined);
    }
    await this.save(room);
    await this.arm(room);
    for (const s of [0, 1]) {
      const socket = this.socketFor(s);
      if (socket) send(socket, { type: "starter", team: starter });
    }
    this.sendClock(room);
  }

  // The player to move has no time left: a normal ranked loss.
  async timeOut(room) {
    const loser = room.ranked.clock.toMove;
    room.ranked.clock.left[loser] = 0;
    await this.finishRanked(room, loser === 0 ? [0, 1] : [1, 0], "time");
  }

  async webSocketMessage(socket, text) {
    let message;
    try {
      message = JSON.parse(text);
    } catch {
      return;
    }
    const seat = Number(this.state.getTags(socket)[0]);
    const room = await this.load();
    if (!room || room.phase !== "playing") {
      return;
    }
    if (message.type === "leave") {
      await this.end(room, seat);
      return;
    }
    if (message.type === "look") {
      // Cosmetic choice (character and its skin, echoes, board skin); kept for resumes.
      const look = { type: "look" };
      for (const key of ["character", "skin", "echo", "board"]) {
        look[key] = String(message[key] || "").slice(0, 32);
      }
      room.looks = room.looks || [null, null];
      room.looks[seat] = look;
      await this.save(room);
      const other = this.socketFor(1 - seat);
      if (other) {
        send(other, look);
      }
      return;
    }
    if (message.type === "emote") {
      // Relayed, not stored; only known emotes, at most one per seat every 2 s.
      const now = Date.now();
      this.lastEmote = this.lastEmote || [0, 0];
      if (EMOTE_IDS.includes(message.id) && now - this.lastEmote[seat] > 2000) {
        this.lastEmote[seat] = now;
        const other = this.socketFor(1 - seat);
        if (other) send(other, { type: "emote", id: message.id });
      }
      return;
    }
    if (message.type === "node_ping") {
      await this.nodePing(room, seat, message);
      return;
    }
    if (message.type === "choose") {
      await this.chooseStarter(room, seat, message);
      return;
    }
    if (message.type !== "move" && message.type !== "pass" || room.starter === undefined) {
      return;
    }
    // The starter moves first and every turn is exactly one move or pass, so
    // the sequence number decides whose turn it is. Repeats after a reconnect are dropped.
    const seq = Number(message.seq);
    const toMove = seq % 2 === 0 ? room.starter : 1 - room.starter;
    if (seq !== room.moves.length || toMove !== seat) {
      return;
    }
    let outcome = null;
    if (room.ranked) {
      const clock = this.runningClock(room);
      if (clock && clock.left[seat] - (Date.now() - clock.turnStart) <= 0) {
        // Arrived after the flag fell (the alarm may not have fired yet).
        await this.timeOut(room);
        return;
      }
      outcome = play(room.ranked.game, seat, message);
      if (!outcome.ok) {
        send(socket, { type: "error", reason: "invalid_move" });
        return;
      }
    }
    const clock = this.runningClock(room);
    if (clock) chargeMove(clock, seat, Date.now());
    room.moves.push(message);
    await this.save(room);
    const other = this.socketFor(1 - seat);
    if (other) {
      send(other, message);
    }
    if (clock && outcome.winner === undefined && !outcome.draw) {
      await this.arm(room);
      this.sendClock(room);
    }
    if (outcome && outcome.winner !== undefined) {
      await this.finishRanked(room, outcome.winner === 0 ? [1, 0] : [0, 1]);
    } else if (outcome && outcome.draw) {
      await this.finishRanked(room, [0.5, 0.5]);
    }
  }

  // Rates a ranked game once and tells both players their new rating.
  async finishRanked(room, scores, reason = "") {
    if (!room.ranked || room.ranked.settled) {
      return;
    }
    room.ranked.settled = true;
    room.phase = "ended";
    await this.save(room);
    const results = await settle(this.env, room.ranked.players, scores);
    for (const seat of [0, 1]) {
      const socket = this.socketFor(seat);
      if (socket) {
        send(socket, { type: "ranked_result", score: scores[seat], reason, ...results[seat] });
      }
    }
  }

  async webSocketClose(socket) {
    const seat = Number(this.state.getTags(socket)[0]);
    const room = await this.load();
    if (!room || this.socketFor(seat, socket)) {
      // A newer connection of this player already replaced the closed one.
      return;
    }
    if (room.phase === "waiting" || room.phase === "matching") {
      await this.state.storage.deleteAll();
      for (const other of this.state.getWebSockets()) {
        send(other, { type: "error", reason: "match_failed" });
      }
      return;
    }
    if (room.phase === "playing") {
      const other = this.socketFor(1 - seat, socket);
      if (!other) {
        await this.state.storage.deleteAll();
        return;
      }
      send(other, { type: "opponent_away", seconds: RECONNECT_SECONDS });
      await this.arm(room, Date.now() + RECONNECT_SECONDS * 1000);
    }
  }

  async webSocketError(socket) {
    await this.webSocketClose(socket);
  }

  async alarm() {
    const room = await this.load();
    if (!room) {
      return;
    }
    if (room.phase === "matching") {
      for (const socket of this.state.getWebSockets()) {
        send(socket, { type: "error", reason: "match_failed" });
      }
      await this.state.storage.deleteAll();
      return;
    }
    const clock = this.runningClock(room);
    if (clock && Date.now() >= clockDeadline(clock)) {
      // The clock fell; this also holds while the player to move is away.
      await this.timeOut(room);
      await this.arm(room);
      return;
    }
    if (room.baseAt && Date.now() < room.baseAt) {
      // Woken for the clock, but no time ran out and the room's own deadline is later.
      await this.arm(room);
      return;
    }
    const missing = [0, 1].filter((seat) => !this.socketFor(seat));
    if (room.phase === "playing" && missing.length === 1) {
      await this.end(room, missing[0]);
      return;
    }
    if (missing.length === 2 || Date.now() - room.touched > ROOM_IDLE_SECONDS * 1000) {
      await this.state.storage.deleteAll();
      return;
    }
    await this.arm(room, Date.now() + ROOM_IDLE_SECONDS * 1000);
  }

  // The player in seat `leaver` is gone for good; the other one is told so.
  async end(room, leaver) {
    if (room.ranked && !room.ranked.settled) {
      // Leaving a ranked game (or not coming back in time) loses it. The
      // result goes out first: the game hangs up when the opponent has left.
      await this.finishRanked(room, leaver === 0 ? [0, 1] : [1, 0]);
    } else {
      room.phase = "ended";
      await this.save(room);
    }
    const other = this.socketFor(1 - leaver);
    if (other) {
      send(other, { type: "opponent_left" });
    }
  }
}

// Pairs quick-match players. Waiting sockets are tagged "waiting"; once two
// are there, both are sent to a fresh room and leave the lobby.
export class Lobby {
  constructor(state) {
    this.state = state;
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch() {
    const [client, server] = Object.values(new WebSocketPair());
    // Tags cannot change, so a matched socket is marked through its attachment.
    const waiting = this.state.getWebSockets("waiting")
      .filter((socket) => socket.readyState === 1 && !(socket.deserializeAttachment() || {}).matched);
    if (waiting.length > 0) {
      const code = newToken().slice(0, 12);
      const partner = waiting[0];
      partner.serializeAttachment({ matched: true });
      send(partner, { type: "matched", code, team: 0 });
      this.state.acceptWebSocket(server, ["matched"]);
      send(server, { type: "matched", code, team: 1 });
      // Both clients now connect to the room and close these sockets themselves.
    } else {
      this.state.acceptWebSocket(server, ["waiting"]);
      send(server, { type: "queued" });
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage() {}

  webSocketClose() {}
}

async function serveSplitFile(request, env, file) {
  const parts = await Promise.all(
    file.parts.map((path) => env.ASSETS.fetch(new Request(new URL(path, request.url))))
  );
  if (parts.some((part) => !part.ok)) {
    return new Response("Game file missing", { status: 500 });
  }
  const length = parts.reduce((sum, part) => sum + Number(part.headers.get("Content-Length") || 0), 0);
  const { readable, writable } = new TransformStream();
  (async () => {
    for (const part of parts) {
      await part.body.pipeTo(writable, { preventClose: true });
    }
    await writable.close();
  })();
  const headers = { "Content-Type": file.type, "Cache-Control": "public, max-age=3600" };
  if (length > 0) {
    headers["Content-Length"] = String(length);
  }
  return new Response(readable, { headers });
}

function drawCards(count) {
  const deck = [...CARD_NAMES];
  for (let index = deck.length - 1; index > 0; index--) {
    const other = Math.floor(Math.random() * (index + 1));
    [deck[index], deck[other]] = [deck[other], deck[index]];
  }
  return deck.slice(0, count);
}

// Lowercase letters and digits; also used for quick-match room codes.
function newToken() {
  const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}

// The client closes the socket after reading the reason; closing right away
// can drop the message before the handshake has settled on the client.
function rejectSocket(reason) {
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  send(server, { type: "error", reason });
  return new Response(null, { status: 101, webSocket: client });
}

function send(socket, message) {
  try {
    socket.send(JSON.stringify(message));
  } catch {
    // The socket is already closing; nothing to tell it.
  }
}
