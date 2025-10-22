// LocalStorage-backed store for demo/MVP
const KEY = "tmb_progress_v1";

function loadAll() {
  if (typeof window === "undefined") return {};
  try { return JSON.parse(localStorage.getItem(KEY) || "{}"); } catch { return {}; }
}
function saveAll(obj) {
  if (typeof window === "undefined") return;
  localStorage.setItem(KEY, JSON.stringify(obj));
}

export function getScout() {
  const all = loadAll();
  return all.scout || { name: "", troop: "", parentEmail: "", city: "", state: "" };
}
export function setScout(data) {
  const all = loadAll();
  all.scout = { ...(all.scout||{}), ...data };
  saveAll(all);
}

export function getBadgeProgress(badgeId) {
  const all = loadAll();
  return (all.badges && all.badges[badgeId]) || { purchased: false, modules: {}, percent: 0 };
}
export function updateModule(badgeId, moduleId, payload) {
  const all = loadAll();
  all.badges = all.badges || {};
  const b = all.badges[badgeId] || { purchased: false, modules: {}, percent: 0 };
  b.modules[moduleId] = { ...(b.modules[moduleId]||{}), ...payload, done: true, updatedAt: new Date().toISOString() };
  // recompute percent: simple proportion of modules marked done
  const done = Object.values(b.modules).filter(m => m.done).length;
  const total = b.total || payload.totalModules || 6; // pass total via first update or set explicitly below
  b.total = total;
  b.percent = Math.min(1, done / total);
  all.badges[badgeId] = b;
  saveAll(all);
  return b;
}
export function markPurchased(badgeId, purchased=true, totalModules=6) {
  const all = loadAll();
  all.badges = all.badges || {};
  const b = all.badges[badgeId] || { modules:{}, percent:0 };
  b.purchased = purchased;
  b.total = totalModules;
  all.badges[badgeId] = b;
  saveAll(all);
}
export async function fetchBadges() {
  const response = await fetch("/api/manifest");
  if (!response.ok) {
    throw new Error("Failed to load badges");
  }
  const { badges } = await response.json();
  return badges;
}
