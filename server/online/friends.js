// Friends, found by their permanent username: send requests, accept them, see
// who is online and invite friends to a room. Account keys never leave the
// server; the game only sees usernames. Only accounts with a username (signed
// in, see accounts.js "username") take part.
//
// HTTP API (Bearer account code):
//   GET  /api/friends                       -> {username, friends, incoming, outgoing, invites}
//   POST /api/friends/add     {username}    send a request (or accept theirs)
//   POST /api/friends/accept  {username}
//   POST /api/friends/remove  {username}    unfriend, decline or withdraw
//   POST /api/friends/invite  {username, code}  invite a friend to a room
//   POST /api/friends/dismiss {username}    drop an invitation
//   POST /api/friends/invited {username}    came through username's invite link: friends + credits
// A person = {username, name, avatar, rating, rank, online}; invite = person + {code}.

import { accountCall, accountKey, json, CORS, normaliseCode } from "./accounts.js";
import { rankOf } from "./ranked.js";

const MAX_FRIENDS = 100;
const ONLINE_SECONDS = 150;
export const INVITE_SECONDS = 10 * 60;

export async function handleFriendsApi(request, env, url) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  const code = normaliseCode((request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, ""));
  if (!code) return json({ error: "no_account" }, 401);
  const me = await accountKey(code);
  const mine = await social(env, me, { action: "get" });
  if (!mine) return json({ error: "no_account" }, 401);
  if (!mine.username) return json({ error: "need_username" }, 403);
  const action = url.pathname.replace(/^\/api\/friends\/?/, "");
  const body = request.method === "POST" ? await request.json().catch(() => ({})) : {};

  if (action === "") {
    return json(await overview(env, me, mine.username));
  }
  const other = await lookupUsername(env, String(body.username || ""));
  if (!other) return json({ error: "unknown_user" }, 404);
  if (other === me) return json({ error: "self" }, 400);

  if (action === "add") {
    if (mine.friends.includes(other)) return json({ error: "already_friends" }, 409);
    if (mine.friends.length >= MAX_FRIENDS) return json({ error: "too_many" }, 400);
    if (mine.incoming.includes(other)) {
      await befriend(env, me, other);
    } else {
      await social(env, me, { action: "add", list: "outgoing", key: other });
      await social(env, other, { action: "add", list: "incoming", key: me });
    }
  } else if (action === "accept") {
    if (!mine.incoming.includes(other)) return json({ error: "no_request" }, 404);
    await befriend(env, me, other);
  } else if (action === "invited") {
    // The caller came through other's invite link: friends right away (the link
    // was the invitation) and a one-time credit bonus for both.
    const reward = await accountOp(env, me, "invite", { role: "invitee", from: other });
    if (reward && reward.rewarded) {
      await accountOp(env, other, "invite", { role: "inviter" });
      if (!mine.friends.includes(other)) await befriend(env, me, other);
      return json({ ...(await overview(env, me, mine.username)), bonus: reward.credits });
    }
  } else if (action === "remove") {
    await social(env, me, { action: "forget", key: other });
    await social(env, other, { action: "forget", key: me });
  } else if (action === "invite") {
    if (!mine.friends.includes(other)) return json({ error: "not_friends" }, 403);
    const room = String(body.code || "");
    if (!/^\d{4}$/.test(room)) return json({ error: "bad_code" }, 400);
    await social(env, other, { action: "invite", key: me, code: room });
  } else if (action === "dismiss") {
    await social(env, me, { action: "uninvite", key: other });
  } else {
    return json({ error: "not_found" }, 404);
  }
  return json(await overview(env, me, mine.username));
}

// The Account Durable Object's part (op "social"): lists of account keys.
export function socialOp(data, body) {
  for (const list of ["friends", "incoming", "outgoing", "invites"]) {
    data[list] = data[list] || [];
  }
  const now = Date.now();
  data.invites = data.invites.filter((invite) => now - invite.at < INVITE_SECONDS * 1000);
  const key = String(body.key || "");
  const drop = (list) => { data[list] = data[list].filter((entry) => entry !== key); };
  switch (body.action) {
    case "add":
      if (["incoming", "outgoing"].includes(body.list) && !data[body.list].includes(key)) data[body.list].push(key);
      break;
    case "befriend":
      drop("incoming");
      drop("outgoing");
      if (!data.friends.includes(key)) data.friends.push(key);
      break;
    case "forget":
      drop("incoming");
      drop("outgoing");
      drop("friends");
      data.invites = data.invites.filter((invite) => invite.from !== key);
      break;
    case "invite":
      data.invites = data.invites.filter((invite) => invite.from !== key);
      data.invites.push({ from: key, code: String(body.code), at: now });
      break;
    case "uninvite":
      data.invites = data.invites.filter((invite) => invite.from !== key);
      break;
  }
  return { username: data.username || "", friends: data.friends, incoming: data.incoming, outgoing: data.outgoing, invites: data.invites };
}

// What friends may see of an account (op "public").
export function publicView(data) {
  const rating = data.rating || 1000;
  const games = data.games || 0;
  return {
    name: data.username || "Gast", avatar: typeof data.avatar === "string" ? data.avatar : "symbol:code", email: data.email || "",
    username: data.username || "", rating, games, rank: rankOf(rating, games), wins: data.wins || 0, losses: data.losses || 0,
    online: Date.now() - (data.lastSeen || 0) < ONLINE_SECONDS * 1000,
  };
}

async function social(env, key, body) {
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(key));
  const answer = await account.fetch("https://account/social", { method: "POST", body: JSON.stringify(body) });
  return answer.ok ? await answer.json() : null;
}

async function person(env, key) {
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(key));
  const answer = await account.fetch("https://account/public", { method: "POST", body: "{}" });
  if (!answer.ok) return null;
  const view = await answer.json();
  delete view.email;
  return view;
}

async function befriend(env, a, b) {
  await social(env, a, { action: "befriend", key: b });
  await social(env, b, { action: "befriend", key: a });
}

async function overview(env, me, username) {
  const lists = await social(env, me, { action: "get" });
  const people = async (keys) => (await Promise.all(keys.map((key) => person(env, key)))).filter(Boolean);
  const friends = await people(lists.friends);
  friends.sort((a, b) => Number(b.online) - Number(a.online) || a.name.localeCompare(b.name));
  const invites = [];
  for (const invite of lists.invites) {
    const from = await person(env, invite.from);
    if (from) invites.push({ ...from, code: invite.code });
  }
  return { username, friends, incoming: await people(lists.incoming), outgoing: await people(lists.outgoing), invites };
}

// Usernames: 3-16 letters, digits or _, unique regardless of upper/lower case.
export function validUsername(text) {
  return /^[A-Za-z0-9_]{3,16}$/.test(String(text));
}

// Reserves a username for an account in the "Login" store; false if taken.
export async function claimUsername(env, username, key) {
  const claim = env.LOGINS.get(env.LOGINS.idFromName("user:" + username.toLowerCase()));
  const answer = await claim.fetch("https://login/claim", { method: "POST", body: JSON.stringify({ key }) });
  return answer.ok;
}

async function lookupUsername(env, username) {
  if (!validUsername(username.trim())) return null;
  const claim = env.LOGINS.get(env.LOGINS.idFromName("user:" + username.trim().toLowerCase()));
  const answer = await claim.fetch("https://login/lookup", { method: "POST", body: "{}" });
  return answer.ok ? (await answer.json()).key : null;
}

async function accountOp(env, key, op, body) {
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(key));
  const answer = await account.fetch("https://account/" + op, { method: "POST", body: JSON.stringify(body) });
  return answer.ok ? await answer.json() : null;
}
