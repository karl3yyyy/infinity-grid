// Credit packs bought with real money through Stripe Checkout.
//
// 1. The game asks POST /api/account/checkout {pack}. The server creates a
//    Stripe Checkout Session for the pack's price, tagged with the account
//    key (a SHA-256 hash of the account code), and answers {url}.
// 2. The game sends the player to that Stripe page. Afterwards Stripe sends
//    them back to the game (/?checkout=success or /?checkout=cancel).
// 3. Stripe calls POST /api/stripe/webhook. Only a correctly signed, paid
//    "checkout.session.completed" (or "...async_payment_succeeded") event adds
//    the pack's credits, once per session. The game never reports a payment.
//
// Configuration (wrangler.toml [vars] and `wrangler secret put`):
//   STRIPE_PRICE_SMALL / _MEDIUM / _LARGE   price ids (price_...) of the packs
//   STRIPE_SECRET_KEY      secret, sk_test_... (test mode) or sk_live_...
//   STRIPE_WEBHOOK_SECRET  secret, whsec_... of the webhook endpoint
// Without them the shop simply offers no packs.

// Credits per pack are decided here; the label must match the Stripe price.
export const PACKS = {
  small: { credits: 500, label: "1,99 €", price: "STRIPE_PRICE_SMALL" },
  medium: { credits: 1400, label: "4,99 €", price: "STRIPE_PRICE_MEDIUM" },
  large: { credits: 3200, label: "9,99 €", price: "STRIPE_PRICE_LARGE" },
};

// Stripe's own libraries reject signatures older than five minutes (replays).
const SIGNATURE_TOLERANCE_SECONDS = 300;
const PAID_EVENTS = ["checkout.session.completed", "checkout.session.async_payment_succeeded"];

export function paymentsEnabled(env) {
  return Boolean(env.STRIPE_SECRET_KEY && env.STRIPE_WEBHOOK_SECRET);
}

// Packs the game may offer: only those with a configured price.
export function offeredPacks(env) {
  if (!paymentsEnabled(env)) {
    return [];
  }
  return Object.entries(PACKS)
    .filter(([, pack]) => env[pack.price])
    .map(([id, pack]) => ({ id, credits: pack.credits, label: pack.label }));
}

// returnPage: the game page (origin and path, no trailing slash) to come back to.
export async function createCheckout(env, accountKey, packId, returnPage) {
  const pack = PACKS[packId];
  if (!paymentsEnabled(env) || !pack || !env[pack.price]) {
    return { status: 503, body: { error: "payments_off" } };
  }
  const form = new URLSearchParams({
    mode: "payment",
    "line_items[0][price]": env[pack.price],
    "line_items[0][quantity]": "1",
    client_reference_id: accountKey,
    "metadata[pack]": packId,
    success_url: returnPage + "/?checkout=success",
    cancel_url: returnPage + "/?checkout=cancel",
  });
  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  }).catch(() => null);
  const session = response ? await response.json().catch(() => ({})) : {};
  if (!response || !response.ok || !session.url) {
    return { status: 502, body: { error: "payment_failed" } };
  }
  return { status: 200, body: { session: session.id, url: session.url } };
}

// Verifies the event and hands paid packs to the account they were bought for.
export async function handleWebhook(request, env) {
  if (!paymentsEnabled(env)) {
    return new Response("Payments are not configured", { status: 503 });
  }
  const raw = await request.text();
  if (!(await validSignature(request.headers.get("Stripe-Signature") || "", raw, env.STRIPE_WEBHOOK_SECRET))) {
    return new Response("Bad signature", { status: 400 });
  }
  const event = JSON.parse(raw);
  if (!PAID_EVENTS.includes(event.type)) {
    return new Response("Ignored", { status: 200 });
  }
  const session = (event.data || {}).object || {};
  const pack = PACKS[(session.metadata || {}).pack];
  // Card payments are "paid" at once; slower methods follow with async_payment_succeeded.
  if (session.payment_status !== "paid" || !pack || !/^[0-9a-f]{64}$/.test(session.client_reference_id || "")) {
    return new Response("Nothing to grant", { status: 200 });
  }
  const account = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(session.client_reference_id));
  const answer = await account.fetch("https://account/grant", {
    method: "POST",
    body: JSON.stringify({ transaction: session.id, credits: pack.credits }),
  });
  // A failure makes Stripe retry the delivery later.
  return new Response(answer.ok ? "OK" : "Retry", { status: answer.ok ? 200 : 500 });
}

// Header "t=<unix time>,v1=<hex hmac>[,v1=...]"; signed text is "<t>.<raw body>".
async function validSignature(header, raw, secret) {
  let timestamp = "";
  const signatures = [];
  for (const part of header.split(",")) {
    const [key, value] = part.split("=");
    if (key === "t") {
      timestamp = value;
    } else if (key === "v1") {
      signatures.push(value);
    }
  }
  if (!timestamp || Math.abs(Date.now() / 1000 - Number(timestamp)) > SIGNATURE_TOLERANCE_SECONDS) {
    return false;
  }
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${timestamp}.${raw}`));
  const expected = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
  return signatures.some((signature) => timingSafeEqual(signature || "", expected));
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
