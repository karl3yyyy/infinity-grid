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
//   POST /api/account/profile {name, avatar}
//   POST /api/account/buy {item}       -> 402 not_enough_credits, 409 owned
//   POST /api/account/reward {difficulty} after a won bot match
// account = {name, avatar, credits, owned: [...], prices: {...}, bonus?: n}

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
  if (!["create", "get", "profile", "buy", "reward"].includes(op)) {
    return json({ error: "not_found" }, 404);
  }
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(code));
  const answer = await account.fetch("https://account/" + op, { method: "POST", body: JSON.stringify(body) });
  const result = await answer.json();
  if (op === "create" && answer.ok) {
    result.code = code;
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
      data = { name: "Spieler", avatar: 0, credits: START_CREDITS, owned: [], bonusDay: today(), botDay: today(), botWins: 0 };
      await storage.put("account", data);
      return json({ account: view(data) });
    }
    if (!data) {
      return json({ error: "no_account" }, 404);
    }
    let bonus = 0;
    if (data.bonusDay !== today()) {
      data.bonusDay = today();
      data.credits += DAILY_BONUS;
      bonus = DAILY_BONUS;
    }
    let status = 200;
    let error = "";
    if (op === "profile") {
      const name = String(body.name || "").trim().slice(0, 20);
      data.name = name || "Spieler";
      data.avatar = Math.max(0, Math.min(4, Math.floor(Number(body.avatar) || 0)));
    } else if (op === "buy") {
      const item = String(body.item || "");
      const price = PRICES[item];
      if (price === undefined) {
        [status, error] = [400, "not_for_sale"];
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
  return { name: data.name, avatar: data.avatar, credits: data.credits, owned: data.owned, prices: PRICES };
}

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

function today() {
  return new Date().toISOString().slice(0, 10);
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", ...CORS } });
}
