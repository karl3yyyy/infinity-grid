// Player accounts for the cosmetics shop.
//
// There are no passwords or e-mail addresses: an account is opened with a
// random account code ("K7QM-2XRA-9DPE"), which the game keeps and sends as a
// bearer token. Typing the code on another device restores the account.
// The server alone decides credits and ownership; the game only displays them.
//
// HTTP API (JSON, CORS open because the token is not a cookie):
//   POST /api/account                  -> {code, account}   new account
//   GET  /api/account                  -> {account}         (+ daily bonus)
//   POST /api/account/profile {avatar}       (the name is the username, set once)
//   POST /api/account/username {username}  signed-in accounts choose it once, for good
//   POST /api/account/buy {item}       -> 402 not_enough_credits, 409 owned
//   POST /api/account/reward {difficulty} after a won bot match
//   POST /api/account/checkout {pack}  -> Stripe Checkout for a credit pack (payments.js)
// account = {name, avatar, credits, owned: [...], prices: {...}, packs: [...], bonus?: n}

import { createCheckout, offeredPacks } from "./payments.js";
import { claimUsername, publicView, socialOp, validUsername } from "./friends.js";
import { START_RATING } from "./ranked.js";

// Must match CharacterRoster.PRICES (checked by tests/lan_test.gd).
// Items not listed are free for everyone.
export const PRICES = {
  "character:agent": 300,
  "character:mira": 300,
  "character:opa": 300,
  "character:kid": 300,
  "character:monk": 400,
  "character:doc": 400,
  "character:brute": 500,
  "character:baby": 600,
  "echo:agents": 250,
  "echo:cyborgs": 250,
  "board:blood": 250,
  "board:neon": 250,
  "board:void": 300,
  "board:gold": 500,
  "skin:shadow_white": 250,
  "skin:shadow_red": 350,
  "skin:wired_rust": 250,
  "skin:wired_ice": 250,
  "skin:nova_solar": 250,
  "skin:nova_glitch": 250,
  "skin:brute_magma": 250,
  "skin:brute_frost": 250,
  "skin:baby_gold": 350,
  "skin:baby_rowdy": 250,
  "skin:agent_red": 250,
  "skin:agent_white": 350,
  "skin:mira_night": 250,
  "skin:mira_rose": 250,
  "skin:opa_sunday": 250,
  "skin:opa_hacker": 250,
  "skin:punk_toxic": 250,
  "skin:punk_chrome": 350,
  "skin:doc_toxic": 250,
  "skin:doc_black": 250,
  "skin:monk_shadow": 250,
  "skin:monk_jade": 250,
  "skin:kid_pink": 250,
  "skin:kid_street": 250,
};

const START_CREDITS = 300;
const DAILY_BONUS = 25;
// Credits for a won bot match by difficulty (easy, medium, hard).
const BOT_WIN_CREDITS = [10, 20, 40];
// Bot results come from the player's own device, so they are capped.
const BOT_WINS_PER_DAY = 15;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export async function handleAccountApi(request, env, url) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  const action = url.pathname.replace(/^\/api\/account\/?/, "");
  let code;
  let body = {};
  if (request.method === "POST") {
    body = await request.json().catch(() => ({}));
  }
  if (action === "" && request.method === "POST") {
    code = newAccountCode();
    body = { create: true };
  } else {
    code = normaliseCode((request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, ""));
    if (!code) {
      return json({ error: "no_account" }, 401);
    }
  }
  const op = action === "" ? (request.method === "POST" ? "create" : "get") : action;
  if (!["create", "get", "profile", "buy", "reward", "checkout", "username"].includes(op)) {
    return json({ error: "not_found" }, 404);
  }
  // Accounts are stored under a hash of the code, so the payment provider only
  // ever sees the hash (as the checkout reference), never the code itself.
  const key = await accountKey(code);
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(key));
  if (op === "username") {
    const username = String(body.username || "").trim();
    if (!validUsername(username)) return json({ error: "bad_username" }, 400);
    const current = await account.fetch("https://account/public", { method: "POST", body: "{}" });
    if (!current.ok) return json({ error: "no_account" }, 404);
    const state = await current.json();
    if (!state.email) return json({ error: "sign_in_first" }, 403);
    if (state.username) return json({ error: "username_set" }, 409);
    if (!(await claimUsername(env, username, key))) return json({ error: "username_taken" }, 409);
    const set = await account.fetch("https://account/set_username", { method: "POST", body: JSON.stringify({ username }) });
    const result = await set.json();
    if (result.account) result.account.packs = offeredPacks(env);
    return json(result, set.status);
  }
  // Checkout also needs an existing account, so it first asks like "get".
  const answer = await account.fetch("https://account/" + (op === "checkout" ? "get" : op), { method: "POST", body: JSON.stringify(body) });
  const result = await answer.json();
  if (op === "checkout" && answer.ok) {
    const checkout = await createCheckout(env, key, String(body.pack || ""), url.origin, String(body.return_to || ""));
    return json(checkout.body, checkout.status);
  }
  if (op === "create" && answer.ok) {
    result.code = code;
  }
  if (result.account) {
    result.account.packs = offeredPacks(env);
  }
  return json(result, answer.status);
}

export class Account {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    const op = new URL(request.url).pathname.slice(1);
    const body = await request.json().catch(() => ({}));
    const storage = this.state.storage;
    let data = await storage.get("account");
    if (op === "create") {
      if (data) {
        return json({ error: "exists" }, 409);
      }
      data = { name: "Gast", avatar: "symbol:code", credits: START_CREDITS, owned: [], bonusDay: today(), botDay: today(), botWins: 0 };
      await storage.put("account", data);
      return json({ account: view(data) });
    }
    if (!data) {
      return json({ error: "no_account" }, 404);
    }
    if (op === "link") {
      // A login (e-mail or Google) now leads to this account; shown as "signed in as".
      data.email = String(body.email || "").slice(0, 254);
      await storage.put("account", data);
      return json({ account: view(data) });
    }
    if (op === "set_username") {
      if (data.username) {
        return json({ error: "username_set" }, 409);
      }
      data.username = String(body.username);
      data.name = data.username;
      await storage.put("account", data);
      return json({ account: view(data) });
    }
    if (op === "public") {
      return json(publicView(data));
    }
    if (op === "social") {
      const lists = socialOp(data, body);
      await storage.put("account", data);
      return json(lists);
    }
    if (op === "ranked") {
      // A settled ranked game (ranked.js); score 1, 0.5 or 0.
      data.rating = (data.rating || START_RATING) + Math.round(Number(body.delta) || 0);
      data.games = (data.games || 0) + 1;
      const score = Number(body.score);
      if (score === 1) data.wins = (data.wins || 0) + 1;
      else if (score === 0) data.losses = (data.losses || 0) + 1;
      else data.draws = (data.draws || 0) + 1;
      await storage.put("account", data);
      return json({ ranked: { rating: data.rating, games: data.games } });
    }
    if (op === "grant") {
      // Paid credit pack (from the verified Stripe webhook); once per checkout session.
      data.payments = data.payments || [];
      if (!data.payments.includes(body.transaction)) {
        data.payments.push(body.transaction);
        data.credits += Math.max(0, Math.floor(Number(body.credits) || 0));
        await storage.put("account", data);
      }
      return json({ ok: true });
    }
    // Friends see a player as online while the game keeps asking.
    data.lastSeen = Date.now();
    let bonus = 0;
    if (data.bonusDay !== today()) {
      data.bonusDay = today();
      data.credits += DAILY_BONUS;
      bonus = DAILY_BONUS;
    }
    let status = 200;
    let error = "";
    if (op === "profile") {
      // Names are not editable: a guest is "Gast", a signed-in player their username.
      // Profile picture id from the game's avatar gallery ("symbol:code", "character:nova").
      const avatar = String(body.avatar || "");
      data.avatar = /^[a-z]+:[a-z_]{1,24}$/.test(avatar) ? avatar : "symbol:code";
    } else if (op === "buy") {
      const item = String(body.item || "");
      const price = PRICES[item];
      if (price === undefined) {
        [status, error] = [400, "not_for_sale"];
      } else if (needsCharacter(item, data.owned)) {
        [status, error] = [403, "needs_character"];
      } else if (data.owned.includes(item)) {
        [status, error] = [409, "owned"];
      } else if (data.credits < price) {
        [status, error] = [402, "not_enough_credits"];
      } else {
        data.credits -= price;
        data.owned.push(item);
      }
    } else if (op === "reward") {
      if (data.botDay !== today()) {
        data.botDay = today();
        data.botWins = 0;
      }
      const difficulty = Math.max(0, Math.min(2, Math.floor(Number(body.difficulty) || 0)));
      if (data.botWins < BOT_WINS_PER_DAY) {
        data.botWins += 1;
        data.credits += BOT_WIN_CREDITS[difficulty];
      } else {
        error = "daily_limit";
      }
    }
    await storage.put("account", data);
    const result = { account: view(data) };
    if (bonus > 0) {
      result.account.bonus = bonus;
    }
    if (error) {
      result.error = error;
    }
    return json(result, status);
  }
}

function view(data) {
  const ranked = publicView(data);
  return {
    name: ranked.name, avatar: ranked.avatar, email: data.email || "", credits: data.credits, owned: data.owned, prices: PRICES,
    username: ranked.username, rating: ranked.rating, games: ranked.games, rank: ranked.rank, wins: ranked.wins, losses: ranked.losses,
  };
}

// For the login routes (auth.js): ask an account Durable Object by code.
// op "create" opens a new account under that code.
export async function accountCall(env, code, op, body = {}) {
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(await accountKey(code)));
  const answer = await account.fetch("https://account/" + op, { method: "POST", body: JSON.stringify(body) });
  const result = await answer.json();
  if (result.account) {
    result.account.packs = offeredPacks(env);
  }
  return { status: answer.status, body: result };
}

export { newAccountCode, normaliseCode, json, CORS };

function newAccountCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const letters = Array.from(bytes, (byte) => CODE_ALPHABET[byte % CODE_ALPHABET.length]).join("");
  return `${letters.slice(0, 4)}-${letters.slice(4, 8)}-${letters.slice(8)}`;
}

// Accepts lowercase and missing dashes; returns "" for anything else.
function normaliseCode(text) {
  const letters = text.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (letters.length !== 12 || [...letters].some((letter) => !CODE_ALPHABET.includes(letter))) {
    return "";
  }
  return `${letters.slice(0, 4)}-${letters.slice(4, 8)}-${letters.slice(8)}`;
}

export async function accountKey(code) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(code));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", ...CORS } });
}

// Skins ("skin:<character>_<name>") can only be bought for an owned character.
function needsCharacter(item, owned) {
  if (!item.startsWith("skin:")) {
    return false;
  }
  const character = "character:" + item.slice(5).split("_")[0];
  return PRICES[character] !== undefined && !owned.includes(character);
}
