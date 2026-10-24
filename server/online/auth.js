// Signing in to a player account with e-mail + password or with Google.
//
// Every player starts as a guest account (accounts.js, opened with a random
// account code the game keeps). A login is a key that leads to an account:
// registering ties the guest account to the e-mail or Google identity, and
// signing in on another device hands that device the account's code.
//
// One "Login" Durable Object per key:
//   "email:<address>"  {code, salt, hash, fails, lockedUntil}
//   "google:<sub>"     {code, email}
//   "pending:<nonce>"  a Google sign-in in progress: {code, created, result}
//
// HTTP API (JSON):
//   POST /api/auth/register {email, password}  Bearer guest code -> {code, account}
//   POST /api/auth/login    {email, password}                    -> {code, account}
//   POST /api/auth/google                       Bearer guest code -> {nonce, url}
//   GET  /api/auth/pending/<nonce>              -> {waiting} or {code, account} (once)
//   GET  /auth/google/start?nonce=..   redirect to Google (opened in its own window)
//   GET  /auth/google/callback         Google returns here; finishes the pending sign-in
//
// Google needs GOOGLE_CLIENT_ID ([vars]) and GOOGLE_CLIENT_SECRET (secret).
// Apple sign-in would plug in the same way once an Apple developer account exists.

import { accountCall, CORS, json, newAccountCode, normaliseCode } from "./accounts.js";

// Workers allow at most 100000 PBKDF2 iterations.
const PBKDF2_ITERATIONS = 100000;
const MAX_FAILS = 8;
const LOCK_SECONDS = 15 * 60;
const PENDING_SECONDS = 10 * 60;

export function googleEnabled(env) {
  return Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);
}

export async function handleAuthApi(request, env, url) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  const action = url.pathname.replace(/^\/api\/auth\/?/, "");
  const body = request.method === "POST" ? await request.json().catch(() => ({})) : {};
  const guest = normaliseCode((request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, ""));

  if (action === "register" || action === "login") {
    const email = normaliseEmail(body.email);
    const password = String(body.password || "");
    if (!email) {
      return json({ error: "bad_email" }, 400);
    }
    if (password.length < 8 || password.length > 128) {
      return json({ error: "bad_password" }, 400);
    }
    const login = await loginCall(env, "email:" + email, action, { password, code: guest });
    if (login.status !== 200) {
      return json(login.body, login.status);
    }
    return finish(env, login.body.code, email);
  }
  if (action === "google") {
    if (!googleEnabled(env)) {
      return json({ error: "google_off" }, 503);
    }
    if (!guest) {
      return json({ error: "no_account" }, 401);
    }
    const nonce = newAccountCode().replace(/-/g, "").toLowerCase() + newAccountCode().replace(/-/g, "").toLowerCase();
    await loginCall(env, "pending:" + nonce, "begin", { code: guest });
    return json({ nonce, url: `${url.origin}/auth/google/start?nonce=${nonce}` });
  }
  if (action.startsWith("pending/")) {
    const nonce = action.slice("pending/".length);
    if (!/^[a-z0-9]{24}$/.test(nonce)) {
      return json({ error: "not_found" }, 404);
    }
    const pending = await loginCall(env, "pending:" + nonce, "collect", {});
    if (pending.status !== 200) {
      return json(pending.body, pending.status);
    }
    if (!pending.body.code) {
      return json({ waiting: true, error: pending.body.error || "" });
    }
    return finish(env, pending.body.code, pending.body.email || "");
  }
  return json({ error: "not_found" }, 404);
}

// Google's pages, opened in the sign-in window.
export async function handleGooglePages(request, env, url) {
  if (!googleEnabled(env)) {
    return page("Google-Anmeldung ist noch nicht eingerichtet.");
  }
  const redirect = url.origin + "/auth/google/callback";
  if (url.pathname === "/auth/google/start") {
    const nonce = url.searchParams.get("nonce") || "";
    if (!/^[a-z0-9]{24}$/.test(nonce)) {
      return page("Ungültige Anmeldung. Versuch es im Spiel nochmal.");
    }
    const target = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    target.search = new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      redirect_uri: redirect,
      response_type: "code",
      scope: "openid email",
      state: nonce,
      prompt: "select_account",
    }).toString();
    return Response.redirect(target.toString(), 302);
  }
  // Callback: swap the code for Google's id token (straight from Google over
  // TLS, so its content can be trusted without checking the signature).
  const nonce = url.searchParams.get("state") || "";
  const grant = url.searchParams.get("code") || "";
  if (!/^[a-z0-9]{24}$/.test(nonce) || !grant) {
    return page("Anmeldung abgebrochen. Du kannst dieses Fenster schließen.");
  }
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: grant,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: redirect,
      grant_type: "authorization_code",
    }),
  }).catch(() => null);
  const tokens = response ? await response.json().catch(() => ({})) : {};
  const claims = decodeJwtPayload(tokens.id_token || "");
  const issuerOk = ["https://accounts.google.com", "accounts.google.com"].includes(claims.iss);
  if (!response || !response.ok || !claims.sub || claims.aud !== env.GOOGLE_CLIENT_ID || !issuerOk) {
    return page("Google-Anmeldung fehlgeschlagen. Versuch es im Spiel nochmal.");
  }
  const email = claims.email_verified ? normaliseEmail(claims.email) : "";
  const done = await loginCall(env, "pending:" + nonce, "google", { sub: claims.sub, email });
  if (done.status !== 200) {
    return page("Diese Anmeldung ist abgelaufen. Versuch es im Spiel nochmal.");
  }
  return page(`Angemeldet${email ? " als " + escapeHtml(email) : ""}. Du kannst dieses Fenster schließen – das Spiel macht weiter.`, true);
}

export class Login {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    const op = new URL(request.url).pathname.slice(1);
    const body = await request.json().catch(() => ({}));
    const storage = this.state.storage;
    const data = await storage.get("login");
    const now = Date.now() / 1000;

    if (op === "register") {
      if (data) {
        return json({ error: "email_taken" }, 409);
      }
      // The guest account on this device becomes this login's account.
      const code = await usableCode(this.env, body.code);
      const salt = crypto.getRandomValues(new Uint8Array(16));
      await storage.put("login", { code, salt: toHex(salt), hash: await passwordHash(body.password, salt), fails: 0, lockedUntil: 0 });
      return json({ code });
    }
    if (op === "login") {
      if (!data) {
        return json({ error: "wrong_login" }, 401);
      }
      if (data.lockedUntil > now) {
        return json({ error: "locked" }, 429);
      }
      const hash = await passwordHash(body.password, fromHex(data.salt));
      if (!timingSafeEqual(hash, data.hash)) {
        data.fails += 1;
        if (data.fails >= MAX_FAILS) {
          data.fails = 0;
          data.lockedUntil = now + LOCK_SECONDS;
        }
        await storage.put("login", data);
        return json({ error: "wrong_login" }, 401);
      }
      data.fails = 0;
      await storage.put("login", data);
      return json({ code: data.code });
    }
    if (op === "begin") {
      await storage.put("login", { code: body.code, created: now });
      await this.state.storage.setAlarm(Date.now() + PENDING_SECONDS * 1000);
      return json({ ok: true });
    }
    if (op === "google") {
      if (!data || data.result || now - data.created > PENDING_SECONDS) {
        return json({ error: "expired" }, 410);
      }
      const identity = await loginCall(this.env, "google:" + body.sub, "identity", { code: data.code, email: body.email });
      data.result = { code: identity.body.code, email: body.email };
      await storage.put("login", data);
      return json({ ok: true });
    }
    if (op === "identity") {
      // First Google sign-in ties the guest account to it; later ones return it.
      if (data) {
        return json({ code: data.code });
      }
      const code = await usableCode(this.env, body.code);
      await storage.put("login", { code, email: body.email });
      return json({ code });
    }
    if (op === "collect") {
      if (!data || now - data.created > PENDING_SECONDS) {
        return json({ error: "expired" }, 410);
      }
      if (!data.result) {
        return json({ waiting: true });
      }
      // Hand the result out once.
      await storage.deleteAll();
      return json(data.result);
    }
    return json({ error: "not_found" }, 404);
  }

  // Pending Google sign-ins clean up after themselves.
  async alarm() {
    const data = await this.state.storage.get("login");
    if (data && data.created && !data.result) {
      await this.state.storage.deleteAll();
    }
  }
}

async function loginCall(env, key, op, body) {
  const login = env.LOGINS.get(env.LOGINS.idFromName(key));
  const answer = await login.fetch("https://login/" + op, { method: "POST", body: JSON.stringify(body) });
  return { status: answer.status, body: await answer.json() };
}

// The device's guest account if it exists, else a fresh one.
async function usableCode(env, code) {
  const guest = normaliseCode(String(code || ""));
  if (guest && (await accountCall(env, guest, "get")).status === 200) {
    return guest;
  }
  const fresh = newAccountCode();
  await accountCall(env, fresh, "create");
  return fresh;
}

// Answers a successful login with the account's code and current state.
async function finish(env, code, email) {
  const linked = await accountCall(env, code, "link", { email });
  return json({ code, account: linked.body.account }, linked.status);
}

function normaliseEmail(text) {
  const email = String(text || "").trim().toLowerCase();
  return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : "";
}

async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(String(password)), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" }, key, 256);
  return toHex(new Uint8Array(bits));
}

function toHex(bytes) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function fromHex(text) {
  return new Uint8Array(text.match(/../g).map((pair) => parseInt(pair, 16)));
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}

function decodeJwtPayload(token) {
  try {
    const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "=".repeat((4 - (part.length % 4)) % 4)));
  } catch {
    return {};
  }
}

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (character) => `&#${character.charCodeAt(0)};`);
}

function page(message, done = false) {
  const html = `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Infinity Grid – Anmeldung</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0a0e09;color:#6ee65a;font:20px/1.5 monospace;text-align:center;padding:16px}</style>
</head><body><p>${message}</p>${done ? "<script>setTimeout(function () { window.close(); }, 2500);</script>" : ""}</body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
}
