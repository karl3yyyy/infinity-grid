// "Purge Cycles": ranked seasons of the design bible. A cycle is a fixed
// number of days counted from a start date, so no timer is needed: whoever
// touches an account or the leaderboard after a cycle ended triggers the
// "System Wipe" for it (see accounts.js and ranked.js).

const FIRST_CYCLE_START = Date.UTC(2026, 9, 26);
const CYCLE_DAYS = 182;
const DAY_MS = 24 * 60 * 60 * 1000;
// Credits for the highest rank tier reached in the cycle that just ended.
export const PURGE_CREDITS = [0, 50, 100, 150, 250];

const NAMES = [
  "Cyber-Zero", "Black ICE", "Ghost Protocol", "Null Pointer", "Kernel Panic",
  "Dark Net", "Stack Overflow", "Blue Screen", "Zero Day", "Root Access",
];

export function currentCycle(now = Date.now()) {
  const index = Math.max(0, Math.floor((now - FIRST_CYCLE_START) / (CYCLE_DAYS * DAY_MS)));
  const ends = FIRST_CYCLE_START + (index + 1) * CYCLE_DAYS * DAY_MS;
  return {
    number: index + 1,
    name: NAMES[index % NAMES.length],
    ends,
    daysLeft: Math.max(0, Math.ceil((ends - now) / DAY_MS)),
  };
}
