// Limited-time shop: one item per day and a few per week, the same for everyone.
// The rotation follows from the date alone, so nothing has to be stored; the
// account server only sells what is in the rotation (see accounts.js, op "buy").

const DAY_MS = 24 * 60 * 60 * 1000;
const WEEK_MS = 7 * DAY_MS;
// 1970-01-01 was a Thursday; weeks start on Monday 00:00 UTC (the first one 4 days in).
const WEEK_ANCHOR_MS = 4 * DAY_MS;
export const WEEKLY_COUNT = 5;

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Dearer items are rarer: they come up less often.
function weight(price) {
  if (price >= 500) return 1;
  if (price >= 350) return 2;
  return 4;
}

function pick(random, pool, prices, count) {
  const left = [...pool];
  const chosen = [];
  while (chosen.length < count && left.length > 0) {
    const total = left.reduce((sum, item) => sum + weight(prices[item]), 0);
    let roll = random() * total;
    let index = 0;
    for (; index < left.length - 1; index += 1) {
      roll -= weight(prices[left[index]]);
      if (roll < 0) break;
    }
    chosen.push(left.splice(index, 1)[0]);
  }
  return chosen;
}

// {daily: [item], daily_ends: ms, weekly: [items], weekly_ends: ms}
export function rotation(prices, now = Date.now()) {
  const items = Object.keys(prices).sort();
  const day = Math.floor(now / DAY_MS);
  const week = Math.floor((now - WEEK_ANCHOR_MS) / WEEK_MS);
  const weekly = pick(seededRandom(week * 7919 + 17), items, prices, WEEKLY_COUNT);
  const daily = pick(seededRandom(day * 104729 + 31), items.filter((item) => !weekly.includes(item)), prices, 1);
  return {
    daily,
    daily_ends: (day + 1) * DAY_MS,
    weekly,
    weekly_ends: (week + 1) * WEEK_MS + WEEK_ANCHOR_MS,
  };
}

export function inRotation(prices, item, now = Date.now()) {
  const current = rotation(prices, now);
  return current.daily.includes(item) || current.weekly.includes(item);
}
