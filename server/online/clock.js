// Chess clock for ranked rooms: every player has a time bank, the bank of the
// player to move runs, each finished move adds an increment (Fischer). Only
// the server keeps time; clients count down for display and resync with
// every "clock" message.

export const CLOCK_BASE_MS = 5 * 60 * 1000;
export const CLOCK_INCREMENT_MS = 3 * 1000;

// Starts once the Node Ping has decided who moves first. `baseMs` is only
// shortened by tests (RANKED_CLOCK_MS in server/online/.dev.vars).
export function startClock(starter, now, baseMs = CLOCK_BASE_MS) {
  return { left: [baseMs, baseMs], toMove: starter, turnStart: now };
}

// Server time at which the player to move runs out.
export function clockDeadline(clock) {
  return clock.turnStart + clock.left[clock.toMove];
}

// Charges the mover for this turn. Returns false when the time was already
// gone (the move then does not count and the mover loses on time).
export function chargeMove(clock, seat, now) {
  if (clock.toMove !== seat) return false;
  const left = clock.left[seat] - (now - clock.turnStart);
  if (left <= 0) {
    clock.left[seat] = 0;
    return false;
  }
  clock.left[seat] = left + CLOCK_INCREMENT_MS;
  clock.toMove = 1 - seat;
  clock.turnStart = now;
  return true;
}

// What the clients get: both banks as of now, the running one already reduced.
export function clockView(clock, now) {
  const left = clock.left.slice();
  left[clock.toMove] = Math.max(0, left[clock.toMove] - (now - clock.turnStart));
  return { type: "clock", left, to_move: clock.toMove };
}
