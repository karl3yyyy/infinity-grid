// Rooms for two to four players (Finite Grid and its chaos variants). Like the
// two-player room this is a relay: every client runs the rules itself, the
// server only keeps the seats, deals the same cards and seed to everybody,
// numbers the turns and replays them to a player who comes back.
//
// Protocol (wss://<worker>/play?...):
//   mode=group_create&max=2..4&tiles=0|1&effects=0|1&name=..&avatar=..
//                                -> {"type":"group","code":"48213","seat":0,"token","host":true,...}
//   mode=group_join&code=48213&name=..&avatar=..
//   mode=group_resume&code=..&token=..
//   mode=group_watch&code=..&key=.. -> read-only watch_start snapshot and turns
// Server messages: group (you are in), lobby {players, max, settings}, group_start,
// move|pass|effect (relayed, with "seat" and "seq"), emote, match_ended, seat_away, seat_back,
// seat_left (a bot takes over), host {seat}, error {reason}.
// Client messages: start (host), move|pass|effect, emote, leave, raw "ping".
// A turn names the seat it is for. A player may only send for their own seat; the
// host also sends the turns of bots and of players who left.

import { CARD_NAMES, drawCards, newToken, rejectSocket, send } from "./worker.js";

const MAX_PLAYERS = 4;
// Cards that reach further than two squares in total; Finite Grid leaves them out
// (see FfaDeck.MAX_REACH, checked by tests/ffa_test.gd).
const TOO_STRONG = ["Rift"];
// Humans take the seats opposite each other first (see FfaRules: 0 bottom, 1 left, 2 top, 3 right).
const SEAT_ORDER = [0, 2, 1, 3];
const AWAY_SECONDS = 120;
const IDLE_SECONDS = 30 * 60;
const TURN_TYPES = ["move", "pass", "effect"];
const EMOTE_GAP_MS = 2000;

export function newGroupCode() {
  return String(10000 + Math.floor(Math.random() * 90000));
}

export class GroupRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
    this.lastEmote = {};
  }

  async load() {
    return (await this.state.storage.get("room")) || null;
  }

  async save(room) {
    room.touched = Date.now();
    await this.state.storage.put("room", room);
  }

  socketFor(seat, except = null) {
    return this.state.getWebSockets(String(seat)).find((socket) => socket !== except && socket.readyState === 1) || null;
  }

  broadcast(room, message, exceptSeat = -1) {
    for (const player of room.players) {
      if (player.seat !== exceptSeat && !player.left) {
        const socket = this.socketFor(player.seat);
        if (socket) send(socket, message);
      }
    }
    for (const socket of this.state.getWebSockets("watcher")) {
      if (socket.readyState === 1) send(socket, message);
    }
  }

  accept(seat, firstMessage) {
    const [client, server] = Object.values(new WebSocketPair());
    this.state.acceptWebSocket(server, [String(seat)]);
    if (firstMessage) send(server, firstMessage);
    return new Response(null, { status: 101, webSocket: client });
  }

  acceptWatcher(firstMessage) {
    const [client, server] = Object.values(new WebSocketPair());
    this.state.acceptWebSocket(server, ["watcher"]);
    send(server, firstMessage);
    return new Response(null, { status: 101, webSocket: client });
  }

  lobbyView(room) {
    return {
      type: "lobby",
      max: room.max,
      settings: room.settings,
      players: room.players.map((player) => ({ seat: player.seat, name: player.name, avatar: player.avatar })),
    };
  }

  // Seat of the host: the player who created the room, or the next one still here.
  hostSeat(room) {
    const host = room.players.find((player) => !player.left);
    return host ? host.seat : -1;
  }

  intro(room, player, type) {
    return {
      type, code: room.code, seat: player.seat, token: player.token, host: this.hostSeat(room) === player.seat,
      max: room.max, settings: room.settings, phase: room.phase,
      watch_key: room.watch_key,
    };
  }

  startMessage(room, player) {
    const names = ["", "", "", ""];
    const avatars = ["", "", "", ""];
    for (const other of room.players) {
      names[other.seat] = other.name;
      avatars[other.seat] = other.avatar;
    }
    return {
      ...this.intro(room, player, "group_start"),
      humans: room.players.filter((other) => !other.left).map((other) => other.seat),
      names, avatars, cards: room.cards, seed: room.seed,
    };
  }

  async fetch(request) {
    const url = new URL(request.url);
    const mode = url.searchParams.get("mode");
    const code = url.searchParams.get("code");
    const name = cleanText(url.searchParams.get("name"), 16) || "Gast";
    const avatar = cleanText(url.searchParams.get("avatar"), 40);
    let room = await this.load();
    if (room && room.phase === "ended") {
      await this.state.storage.deleteAll();
      room = null;
    }

    if (mode === "group_create") {
      if (room) return rejectSocket("code_taken");
      const max = Math.min(MAX_PLAYERS, Math.max(2, Number(url.searchParams.get("max")) || MAX_PLAYERS));
      const player = { seat: SEAT_ORDER[0], token: newToken(), name, avatar };
      room = {
        code, phase: "lobby", max, players: [player], moves: [], away: {}, finished: [],
        watch_key: newToken(),
        settings: { tiles: url.searchParams.get("tiles") === "1", effects: url.searchParams.get("effects") === "1" },
      };
      await this.save(room);
      await this.arm(room, IDLE_SECONDS * 1000);
      return this.accept(player.seat, this.intro(room, player, "group"));
    }

    if (mode === "group_join") {
      if (!room) return rejectSocket("not_found");
      if (room.phase !== "lobby") return rejectSocket("started");
      if (room.players.length >= room.max) return rejectSocket("full");
      const player = { seat: SEAT_ORDER[room.players.length], token: newToken(), name, avatar };
      room.players.push(player);
      await this.save(room);
      const response = this.accept(player.seat, this.intro(room, player, "group"));
      this.broadcast(room, this.lobbyView(room));
      return response;
    }

    if (mode === "group_watch") {
      const key = url.searchParams.get("key");
      if (!room || room.phase !== "playing" || room.starter === undefined || !key || key !== room.watch_key) {
        return rejectSocket("not_found");
      }
      const info = this.startMessage(room, { seat: -1, token: "" });
      info.type = "watch_start";
      info.moves = room.moves;
      info.starter = room.starter;
      return this.acceptWatcher(info);
    }

    if (mode === "group_resume") {
      const token = url.searchParams.get("token");
      const player = room && token ? room.players.find((other) => other.token === token && !other.left) : null;
      if (!player) return rejectSocket("not_found");
      const old = this.socketFor(player.seat);
      delete room.away[player.seat];
      await this.save(room);
      const response = this.accept(player.seat, {
        ...this.startMessage(room, player), type: "group_resume", moves: room.moves, starter: room.starter === undefined ? -1 : room.starter,
      });
      if (old) old.close(1000, "replaced");
      this.broadcast(room, { type: "seat_back", seat: player.seat }, player.seat);
      return response;
    }
    return rejectSocket("bad_request");
  }

  async webSocketMessage(socket, text) {
    let message;
    try {
      message = JSON.parse(text);
    } catch {
      return;
    }
    const tag = this.state.getTags(socket)[0];
    if (tag === "watcher") return;
    const seat = Number(tag);
    const room = await this.load();
    if (!room) return;
    if (message.type === "finish") {
      if (room.phase === "playing" && room.players.some((player) => player.seat === seat && !player.left)) {
        room.finished = room.finished || [];
        if (!room.finished.includes(seat)) room.finished.push(seat);
        const activeSeats = room.players.filter((player) => !player.left).map((player) => player.seat);
        if (!activeSeats.every((activeSeat) => room.finished.includes(activeSeat))) {
          await this.save(room);
          return;
        }
        room.phase = "ended";
        await this.save(room);
        this.broadcast(room, { type: "match_ended" });
      }
      return;
    }
    if (room.phase === "ended") return;
    if (message.type === "leave") {
      await this.drop(room, seat, true);
    } else if (message.type === "start") {
      await this.startMatch(room, seat);
    } else if (message.type === "node_ping") {
      await this.nodePing(room, seat, message);
    } else if (message.type === "choose") {
      await this.chooseStarter(room, seat, message);
    } else if (message.type === "emote") {
      this.relayEmote(room, seat, message);
    } else if (TURN_TYPES.includes(message.type)) {
      await this.relayTurn(room, seat, message);
    }
  }

  async startMatch(room, seat) {
    if (room.phase !== "lobby" || seat !== this.hostSeat(room) || room.players.length < 2) return;
    room.phase = "playing";
    room.seed = crypto.getRandomValues(new Uint32Array(1))[0];
    room.cards = drawCards(9, CARD_NAMES.filter((name) => !TOO_STRONG.includes(name)), false);
    room.ping = { picks: {}, winner: -1 };
    delete room.starter;
    await this.save(room);
    await this.arm(room, IDLE_SECONDS * 1000);
    for (const player of room.players) {
      const socket = this.socketFor(player.seat);
      if (socket) send(socket, this.startMessage(room, player));
    }
  }

  // Node Ping: every human has picked a spot, bots get a random one; the closest
  // seat wins (an exact tie in front means another round).
  async nodePing(room, seat, message) {
    if (room.phase !== "playing" || room.starter !== undefined || room.ping.winner >= 0) return;
    const spot = message.spot || [];
    const x = Number(spot[0]), y = Number(spot[1]);
    if (!(x >= 0 && x <= 1 && y >= 0 && y <= 1)) return;
    room.ping.picks[seat] = [x, y];
    await this.save(room);
    await this.rollPing(room);
  }

  humanSeats(room) {
    return room.players.filter((player) => !player.left).map((player) => player.seat);
  }

  async rollPing(room) {
    const humans = this.humanSeats(room);
    if (room.starter !== undefined || room.ping.winner >= 0 || humans.length === 0) return;
    if (humans.some((seat) => !room.ping.picks[seat])) return;
    const picks = [0, 1, 2, 3].map((seat) => room.ping.picks[seat] || [Math.random(), Math.random()]);
    const signal = [Math.random(), Math.random()];
    const distances = picks.map((pick) => (pick[0] - signal[0]) ** 2 + (pick[1] - signal[1]) ** 2);
    const best = Math.min(...distances);
    const closest = distances.map((value, seat) => (value === best ? seat : -1)).filter((seat) => seat >= 0);
    const winner = closest.length === 1 ? closest[0] : -1;
    room.ping = { picks: {}, winner };
    await this.save(room);
    this.broadcast(room, { type: "ping_result", picks, signal, winner });
    // A bot (or a player who left) that wins simply starts.
    if (winner >= 0 && !humans.includes(winner)) await this.setStarter(room, winner);
  }

  async chooseStarter(room, seat, message) {
    if (room.starter !== undefined || room.ping.winner !== seat) return;
    const starter = Number(message.starter);
    // Start, or move last: then the next seat starts.
    if (starter !== seat && starter !== (seat + 1) % MAX_PLAYERS) return;
    await this.setStarter(room, starter);
  }

  async setStarter(room, starter) {
    room.starter = starter;
    await this.save(room);
    this.broadcast(room, { type: "starter", seat: starter });
  }

  // Numbered like the two-player room: repeats after a reconnect are dropped.
  async relayTurn(room, seat, message) {
    // Nobody moves before the Node Ping has named the first player.
    if (room.phase !== "playing" || room.starter === undefined) return;
    const target = Number(message.seat);
    if (!(target >= 0 && target < MAX_PLAYERS) || Number(message.seq) !== room.moves.length) return;
    const owner = room.players.find((player) => player.seat === target && !player.left);
    const allowed = owner ? target === seat : seat === this.hostSeat(room);
    if (!allowed) return;
    const turn = { type: message.type, seq: room.moves.length, seat: target };
    for (const key of ["from", "to", "slot"]) {
      if (message[key] !== undefined) turn[key] = message[key];
    }
    room.moves.push(turn);
    await this.save(room);
    this.broadcast(room, turn, seat);
  }

  relayEmote(room, seat, message) {
    const now = Date.now();
    if (now - (this.lastEmote[seat] || 0) < EMOTE_GAP_MS) return;
    this.lastEmote[seat] = now;
    this.broadcast(room, { type: "emote", seat, id: cleanText(message.id, 16) }, seat);
  }

  // A player is gone: in the lobby their seat frees up, in a match a bot takes over.
  async drop(room, seat, voluntary) {
    const index = room.players.findIndex((player) => player.seat === seat);
    if (index < 0) return;
    const wasHost = this.hostSeat(room) === seat;
    if (room.phase === "lobby") {
      if (wasHost) {
        this.broadcast(room, { type: "error", reason: "host_left" }, seat);
        await this.state.storage.deleteAll();
        return;
      }
      room.players.splice(index, 1);
      // Keep the seats in joining order.
      room.players.forEach((player, order) => { player.seat = SEAT_ORDER[order]; });
      await this.save(room);
      this.broadcast(room, this.lobbyView(room));
      return;
    }
    room.players[index].left = true;
    delete room.away[seat];
    await this.save(room);
    const socket = this.socketFor(seat);
    if (socket && voluntary) socket.close(1000, "left");
    const remaining = room.players.filter((player) => !player.left);
    if (remaining.length === 0) {
      await this.state.storage.deleteAll();
      return;
    }
    this.broadcast(room, { type: "seat_left", seat });
    if (room.phase === "playing" && room.starter === undefined) {
      // The ping must not wait for somebody who is gone.
      if (room.ping.winner === seat) await this.setStarter(room, seat);
      else await this.rollPing(room);
    }
    if (wasHost) this.broadcast(room, { type: "host", seat: this.hostSeat(room) });
  }

  async webSocketClose(socket) {
    if (this.state.getTags(socket)[0] === "watcher") return;
    const seat = Number(this.state.getTags(socket)[0]);
    const room = await this.load();
    if (!room || room.phase === "ended" || this.socketFor(seat, socket)) return;
    const player = room.players.find((other) => other.seat === seat);
    if (!player || player.left) return;
    if (room.phase === "lobby") {
      await this.drop(room, seat, false);
      return;
    }
    room.away[seat] = Date.now() + AWAY_SECONDS * 1000;
    await this.save(room);
    this.broadcast(room, { type: "seat_away", seat, seconds: AWAY_SECONDS }, seat);
    await this.arm(room);
  }

  async webSocketError(socket) {
    await this.webSocketClose(socket);
  }

  // One alarm: the earliest of the away deadlines and the idle deadline.
  async arm(room, idleMs) {
    if (idleMs !== undefined) room.idleAt = Date.now() + idleMs;
    const times = Object.values(room.away || {});
    times.push(room.idleAt || Infinity);
    await this.state.storage.put("room", room);
    await this.state.storage.setAlarm(Math.min(...times));
  }

  async alarm() {
    const room = await this.load();
    if (!room) return;
    const now = Date.now();
    for (const [seat, due] of Object.entries(room.away || {})) {
      if (due <= now && !this.socketFor(Number(seat))) {
        await this.drop(room, Number(seat), false);
        const again = await this.load();
        if (!again) return;
        Object.assign(room, again);
      }
    }
    const here = room.players.filter((player) => !player.left && this.socketFor(player.seat));
    if (here.length === 0 && now >= (room.idleAt || 0)) {
      await this.state.storage.deleteAll();
      return;
    }
    await this.arm(room, here.length > 0 ? IDLE_SECONDS * 1000 : undefined);
  }
}

function cleanText(value, length) {
  return String(value || "").replace(/[^\p{L}\p{N}_:\- ]/gu, "").slice(0, length);
}
