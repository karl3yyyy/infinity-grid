// Ranked play: Elo rating, a rating-aware queue and the leaderboard.
//
// Only signed-in players (e-mail or Google) play ranked. The game asks
// POST /api/ranked/ticket for a one-minute ticket and opens
// wss://<worker>/play?mode=ranked&ticket=... ; the ticket keeps the account
// code out of the address. The "RankedLobby" Durable Object pairs players of
// similar rating (the allowed gap grows while they wait) and sets up a room
// that referees every move with rules.js and reports the result here.
//
//   GET /api/ranked/leaderboard  -> {players: [{name, avatar, rating, rank, games}]}

import { accountCall, accountKey, json, CORS, normaliseCode } from "./accounts.js";

export const START_RATING = 1000;
export const PLACEMENT_GAMES = 5;
const TICKET_SECONDS = 60;
const LEADERBOARD_SIZE = 50;
// Rating gap allowed when two players meet, and how fast it widens per second waited.
const MATCH_GAP = 100;
const MATCH_GAP_PER_SECOND = 20;

// Must match RankedRules.TIERS in scripts/network/ranked_rules.gd (checked by tests/lan_test.gd).
export const TIERS = [
  ["BRONZE", 0],
  ["SILBER", 1100],
  ["GOLD", 1250],
  ["PLATIN", 1400],
  ["DIAMANT", 1550],
  ["KERN", 1700],
];

export function rankOf(rating, games) {
  if (games < PLACEMENT_GAMES) return "PLATZIERUNG";
  let name = TIERS[0][0];
  for (const [tier, floor] of TIERS) {
    if (rating >= floor) name = tier;
  }
  return name;
}

// New ratings after a game; score is 1 (win), 0.5 (draw) or 0 for player a.
export function elo(a, b, score) {
  const expected = 1 / (1 + 10 ** ((b.rating - a.rating) / 400));
  const factor = (games) => (games < 10 ? 48 : 32);
  const deltaA = Math.round(factor(a.games) * (score - expected));
  const deltaB = Math.round(factor(b.games) * ((1 - score) - (1 - expected)));
  return [deltaA, deltaB];
}

export async function handleRankedApi(request, env, url) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  const action = url.pathname.replace(/^\/api\/ranked\/?/, "");
  const lobby = env.RANKED.get(env.RANKED.idFromName("ranked"));
  if (action === "leaderboard") {
    const answer = await lobby.fetch("https://ranked/leaderboard", { method: "POST" });
    return json(await answer.json());
  }
  if (action === "ticket" && request.method === "POST") {
    const code = normaliseCode((request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, ""));
    if (!code) return json({ error: "no_account" }, 401);
    const account = await accountCall(env, code, "public");
    if (account.status !== 200) return json({ error: "no_account" }, 401);
    if (!account.body.email) return json({ error: "sign_in_first" }, 403);
    if (!account.body.username) return json({ error: "need_username" }, 403);
    const player = { key: await accountKey(code), ...account.body };
    delete player.email;
    const answer = await lobby.fetch("https://ranked/ticket", { method: "POST", body: JSON.stringify(player) });
    return json(await answer.json());
  }
  return json({ error: "not_found" }, 404);
}

export class RankedLobby {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade") === "websocket") {
      return this.join(url.searchParams.get("ticket") || "");
    }
    const op = url.pathname.slice(1);
    const body = await request.json().catch(() => ({}));
    if (op === "ticket") {
      const ticket = crypto.randomUUID().replace(/-/g, "");
      await this.state.storage.put("ticket:" + ticket, { player: body, expires: Date.now() + TICKET_SECONDS * 1000 });
      return json({ ticket });
    }
    if (op === "leaderboard") {
      const board = (await this.state.storage.get("leaderboard")) || [];
      return json({ players: board.map(({ name, avatar, rating, games }) => ({ name, avatar, rating, games, rank: rankOf(rating, games) })) });
    }
    if (op === "result") {
      // Players after a ranked game: keep the best LEADERBOARD_SIZE placed players.
      let board = (await this.state.storage.get("leaderboard")) || [];
      for (const player of body.players || []) {
        board = board.filter((entry) => entry.key !== player.key);
        if (player.games >= PLACEMENT_GAMES) {
          board.push({ key: player.key, name: player.name, avatar: player.avatar, rating: player.rating, games: player.games });
        }
      }
      board.sort((a, b) => b.rating - a.rating);
      await this.state.storage.put("leaderboard", board.slice(0, LEADERBOARD_SIZE));
      return json({ ok: true });
    }
    return json({ error: "not_found" }, 404);
  }

  async join(ticket) {
    const stored = /^[a-f0-9]{32}$/.test(ticket) ? await this.state.storage.get("ticket:" + ticket) : null;
    if (stored) {
      await this.state.storage.delete("ticket:" + ticket);
    }
    const [client, server] = Object.values(new WebSocketPair());
    if (!stored || stored.expires < Date.now()) {
      server.accept();
      server.send(JSON.stringify({ type: "error", reason: "bad_ticket" }));
      return new Response(null, { status: 101, webSocket: client });
    }
    this.state.acceptWebSocket(server, ["waiting"]);
    server.serializeAttachment({ ...stored.player, since: Date.now() });
    server.send(JSON.stringify({ type: "queued", rating: stored.player.rating }));
    await this.pair();
    return new Response(null, { status: 101, webSocket: client });
  }

  // Pairs the longest-waiting players whose ratings are close enough.
  async pair() {
    const now = Date.now();
    const waiting = this.state.getWebSockets("waiting")
      .filter((socket) => socket.readyState === 1 && !(socket.deserializeAttachment() || {}).matched)
      .map((socket) => ({ socket, player: socket.deserializeAttachment() }))
      .sort((a, b) => a.player.since - b.player.since);
    const taken = new Set();
    for (let i = 0; i < waiting.length; i++) {
      for (let j = i + 1; j < waiting.length; j++) {
        if (taken.has(i) || taken.has(j)) continue;
        const a = waiting[i].player;
        const b = waiting[j].player;
        const waited = (now - Math.min(a.since, b.since)) / 1000;
        if (a.key === b.key || Math.abs(a.rating - b.rating) > MATCH_GAP + MATCH_GAP_PER_SECOND * waited) continue;
        taken.add(i);
        taken.add(j);
        await this.start([waiting[i], waiting[j]]);
      }
    }
    if (waiting.length - taken.size > 0) {
      await this.state.storage.setAlarm(Date.now() + 3000);
    }
  }

  async start(pair) {
    if (Math.random() < 0.5) pair.reverse();
    const code = crypto.randomUUID().replace(/-/g, "").slice(0, 12);
    const room = this.env.ROOMS.get(this.env.ROOMS.idFromName(code));
    await room.fetch("https://room/setup", { method: "POST", body: JSON.stringify({ players: pair.map((entry) => entry.player) }) });
    pair.forEach((entry, team) => {
      entry.socket.serializeAttachment({ ...entry.player, matched: true });
      const opponent = pair[1 - team].player;
      entry.socket.send(JSON.stringify({ type: "matched", code, team, opponent: { name: opponent.name, avatar: opponent.avatar, rating: opponent.rating, rank: rankOf(opponent.rating, opponent.games) } }));
    });
  }

  async alarm() {
    // Unused tickets expire.
    for (const [key, value] of await this.state.storage.list({ prefix: "ticket:" })) {
      if (value.expires < Date.now()) await this.state.storage.delete(key);
    }
    await this.pair();
  }

  webSocketMessage() {}

  webSocketClose() {}
}

// Settles a finished ranked room: scores [team 0, team 1] (1, 0.5, 0).
// Returns per team {before, after, delta, rank}.
export async function settle(env, players, scores) {
  const [deltaA, deltaB] = elo(players[0], players[1], scores[0]);
  const deltas = [deltaA, deltaB];
  const results = [];
  const updated = [];
  for (const team of [0, 1]) {
    const player = players[team];
    const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(player.key));
    const answer = await account.fetch("https://account/ranked", { method: "POST", body: JSON.stringify({ delta: deltas[team], score: scores[team] }) });
    const after = (await answer.json()).ranked || { rating: player.rating + deltas[team], games: player.games + 1 };
    results.push({ before: player.rating, after: after.rating, delta: deltas[team], rank: rankOf(after.rating, after.games) });
    updated.push({ key: player.key, name: player.name, avatar: player.avatar, rating: after.rating, games: after.games });
  }
  await env.RANKED.get(env.RANKED.idFromName("ranked")).fetch("https://ranked/result", { method: "POST", body: JSON.stringify({ players: updated }) });
  return results;
}
