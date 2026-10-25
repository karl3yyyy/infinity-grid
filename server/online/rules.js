// The game rules on the server, used to referee ranked matches.
// Mirrors scripts/battle/movement_card.gd and GridBattleManager; the card
// offsets are checked against the game by tests/lan_test.gd.
//
// Win: capture the enemy master, or move any piece onto its starting square.
// Board: 5x5, x wraps around, y does not. Team 0 starts on row 4 and moves
// towards row 0, team 1 starts on row 0. Offsets are x = right, y = forward
// from the owning player's view.

// Must match MovementCard.create_deck() (checked by tests/lan_test.gd).
export const CARD_OFFSETS = {
  Crane: [[-1, -1], [1, -1], [0, 1]],
  Wave: [[-2, 0], [1, -1], [1, 1]],
  Comet: [[0, -2], [1, 0], [0, 1]],
  Shell: [[-1, 0], [1, 0], [0, 1]],
  Vortex: [[-1, -1], [1, -1], [0, 2]],
  Nova: [[0, 2], [0, -1]],
  Tide: [[0, 1], [-2, 0], [2, 0]],
  Orbit: [[-1, 1], [1, 1], [-1, -1], [1, -1]],
  Rift: [[-2, 1], [2, 1], [-1, -1], [1, -1]],
  Halo: [[-1, 1], [1, 1], [-1, 0], [1, 0]],
  Ember: [[-1, 1], [1, 1], [0, -1]],
  Drift: [[-2, 0], [-1, 1], [1, -1]],
  Zephyr: [[2, 0], [1, 1], [-1, -1]],
  Eclipse: [[-1, 1], [-1, 0], [1, 0], [1, -1]],
  Prism: [[1, 1], [1, 0], [-1, 0], [-1, -1]],
  Pulse: [[0, 1], [-1, 0], [0, -1]],
  Echo: [[0, 1], [1, 0], [0, -1]],
  Serpent: [[-1, 1], [-1, -1], [1, 0]],
  Viper: [[1, 1], [1, -1], [-1, 0]],
  Lance: [[0, 2], [-1, 0], [1, 0]],
  Spark: [[-1, 1], [1, 1]],
  Anchor: [[0, 1], [0, -2]],
  Glide: [[-2, 0], [2, 0], [0, -1]],
  Knight: [[-1, 2], [1, 2], [0, -1]],
  Mirage: [[-2, 1], [2, -1], [0, 1]],
  Bastion: [[-1, 0], [1, 0], [0, 1], [0, -1]],
  Gale: [[2, 1], [-2, -1], [0, 1]],
  Spire: [[0, 1], [0, 2], [0, -1]],
  Phantom: [[-2, -1], [2, -1], [-1, 1], [1, 1]],
  Flare: [[-1, 1], [0, 1], [1, 1]],
  Chaos: [[-2, 2], [2, 2], [-2, -2], [2, -2]],
  Pinwheel: [[-1, 2], [2, 1], [1, -2], [-2, -1]],
  Quasar: [[-1, -1], [1, -1], [-1, 1], [1, 1], [0, 2], [0, -2]],
  Jester: [[-2, 2], [2, 2], [0, -2]],
  Hydra: [[-2, 1], [2, 1], [0, 2], [0, -1]],
  Nebula: [[-1, 1], [0, 1], [1, 1], [-1, 0], [1, 0], [0, -1]],
};

const SIZE = 5;
const DRAW_REPETITIONS = 3;

// cards: the five dealt names; 0-1 go to team 0, 2-3 to team 1, 4 is the pass card.
export function newGame(cards) {
  const pieces = {};
  for (let x = 0; x < SIZE; x++) {
    pieces[`${x},4`] = { team: 0, master: x === 2 };
    pieces[`${x},0`] = { team: 1, master: x === 2 };
  }
  const game = { pieces, hands: [[cards[0], cards[1]], [cards[2], cards[3]]], pass: cards[4], turn: 0, seen: {} };
  record(game);
  return game;
}

export function destinations(card, x, y, team) {
  const result = [];
  for (const [dx, dy] of CARD_OFFSETS[card] || []) {
    const tx = (((x + (team === 1 ? -dx : dx)) % SIZE) + SIZE) % SIZE;
    const ty = y + (team === 1 ? dy : -dy);
    if (ty >= 0 && ty < SIZE && !result.some(([rx, ry]) => rx === tx && ry === ty)) {
      result.push([tx, ty]);
    }
  }
  return result;
}

export function hasLegalMove(game, team) {
  for (const [key, piece] of Object.entries(game.pieces)) {
    if (piece.team !== team) continue;
    const [x, y] = key.split(",").map(Number);
    for (const card of game.hands[team]) {
      for (const [tx, ty] of destinations(card, x, y, team)) {
        const target = game.pieces[`${tx},${ty}`];
        if (!target || target.team !== team) return true;
      }
    }
  }
  return false;
}

// The Node Ping decided who moves first.
export function setStarter(game, team) {
  game.turn = team;
  game.seen = {};
  record(game);
}

// Node Ping: squared distance between two spots on the free square (0..1).
export function pingDistance(a, b) {
  return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2;
}

// Applies a client message ({type:"move", slot, from:[x,y], to:[x,y]} or
// {type:"pass", slot}) for `team`. Returns {ok:false} for an illegal turn,
// else {ok:true, winner?:0|1, draw?:true}.
export function play(game, team, message) {
  if (game.turn !== team) return { ok: false };
  const slot = Number(message.slot);
  if (slot !== 0 && slot !== 1) return { ok: false };
  const card = game.hands[team][slot];
  let winner = null;
  if (message.type === "pass") {
    // Passing is only allowed without any legal move.
    if (hasLegalMove(game, team)) return { ok: false };
  } else if (message.type === "move") {
    const from = message.from || [];
    const to = message.to || [];
    const piece = game.pieces[`${from[0]},${from[1]}`];
    if (!piece || piece.team !== team) return { ok: false };
    const legal = destinations(card, Number(from[0]), Number(from[1]), team).some(([x, y]) => x === Number(to[0]) && y === Number(to[1]));
    const toKey = `${Number(to[0])},${Number(to[1])}`;
    const target = game.pieces[toKey];
    if (!legal || (target && target.team === team)) return { ok: false };
    if (target && target.master) winner = team;
    // Any piece on the enemy master's starting square wins.
    if (toKey === (team === 0 ? "2,0" : "2,4")) winner = team;
    delete game.pieces[`${from[0]},${from[1]}`];
    game.pieces[toKey] = piece;
  } else {
    return { ok: false };
  }
  // The used card goes to the pass space; the waiting card joins the hand.
  game.hands[team][slot] = game.pass;
  game.pass = card;
  if (winner !== null) return { ok: true, winner };
  game.turn = 1 - team;
  if (record(game) >= DRAW_REPETITIONS) return { ok: true, draw: true };
  return { ok: true };
}

// Same position = same pieces, hands (in any order), pass card and side to move.
function record(game) {
  const parts = Object.entries(game.pieces).map(([key, piece]) => `${piece.team}${piece.master ? "M" : "S"}${key}`).sort();
  for (const hand of game.hands) parts.push([...hand].sort().join("|"));
  parts.push(game.pass, String(game.turn));
  const key = parts.join(";");
  game.seen[key] = (game.seen[key] || 0) + 1;
  return game.seen[key];
}
