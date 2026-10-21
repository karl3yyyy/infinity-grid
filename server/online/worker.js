// Infinity Grid online relay (Cloudflare Worker + one Durable Object per room).
// Same protocol as the PC host in scripts/network/lan_host_server.gd:
//   wss://<worker>/play?mode=create            -> {"type":"room","code":"4821"}
//   wss://<worker>/play?mode=join&code=4821    -> both get {"type":"start","team":0|1,"cards":[...]}
// Afterwards "move"/"pass" messages are relayed to the opponent unchanged.
// Every client runs the rules itself; the server never checks moves.

// Must match MovementCard.create_deck() (checked by tests/lan_test.gd).
const CARD_NAMES = [
  "Crane", "Wave", "Comet", "Shell", "Vortex", "Nova", "Tide", "Orbit", "Rift", "Halo",
  "Ember", "Drift", "Zephyr", "Eclipse", "Prism", "Pulse", "Echo", "Serpent", "Viper",
];

// Static assets are limited to 25 MiB per file, so the engine's index.wasm is
// uploaded in parts (tools/publish_online.ps1) and joined here.
const WASM_PARTS = ["/index.wasm.part0", "/index.wasm.part1"];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/index.wasm") {
      return serveSplitWasm(request, env);
    }
    if (url.pathname !== "/play") {
      return new Response("Not found", { status: 404 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected a WebSocket", { status: 426 });
    }
    const mode = url.searchParams.get("mode");
    let code = url.searchParams.get("code") || "";
    if (mode === "create") {
      code = String(Math.floor(Math.random() * 10000)).padStart(4, "0");
    } else if (mode !== "join" || !/^\d{4}$/.test(code)) {
      return rejectSocket(mode === "join" ? "not_found" : "bad_request");
    }
    const room = env.ROOMS.get(env.ROOMS.idFromName(code));
    const forwarded = new URL(request.url);
    forwarded.searchParams.set("code", code);
    return room.fetch(new Request(forwarded, request));
  },
};

export class Room {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const mode = url.searchParams.get("mode");
    const code = url.searchParams.get("code");
    const players = this.state.getWebSockets();
    if (mode === "create" && players.length > 0) {
      return rejectSocket("code_taken");
    }
    if (mode === "join" && players.length === 0) {
      return rejectSocket("not_found");
    }
    if (mode === "join" && players.length > 1) {
      return rejectSocket("full");
    }
    const [client, server] = Object.values(new WebSocketPair());
    const team = players.length;
    this.state.acceptWebSocket(server, [String(team)]);
    if (mode === "create") {
      send(server, { type: "room", code });
    } else {
      const cards = drawCards(5);
      for (const socket of this.state.getWebSockets()) {
        send(socket, { type: "start", team: Number(this.state.getTags(socket)[0]), cards });
      }
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(socket, text) {
    let message;
    try {
      message = JSON.parse(text);
    } catch {
      return;
    }
    if (message.type !== "move" && message.type !== "pass") {
      return;
    }
    for (const other of this.state.getWebSockets()) {
      if (other !== socket) {
        send(other, message);
      }
    }
  }

  webSocketClose(socket) {
    // The match is over for everyone in the room. The remaining client closes
    // its socket after reading this (closing it here could drop the message);
    // the room is free again once both sockets are gone.
    for (const other of this.state.getWebSockets()) {
      if (other !== socket) {
        send(other, { type: "opponent_left" });
      }
    }
  }

  webSocketError(socket) {
    this.webSocketClose(socket);
  }
}

async function serveSplitWasm(request, env) {
  const parts = await Promise.all(
    WASM_PARTS.map((path) => env.ASSETS.fetch(new Request(new URL(path, request.url))))
  );
  if (parts.some((part) => !part.ok)) {
    return new Response("Engine file missing", { status: 500 });
  }
  const length = parts.reduce((sum, part) => sum + Number(part.headers.get("Content-Length") || 0), 0);
  const { readable, writable } = new TransformStream();
  (async () => {
    for (const part of parts) {
      await part.body.pipeTo(writable, { preventClose: true });
    }
    await writable.close();
  })();
  const headers = { "Content-Type": "application/wasm", "Cache-Control": "public, max-age=3600" };
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
