import { useEffect, useState } from "react";
import BadgeCard from "../components/BadgeCard";
import { getScout, fetchBadges } from "../lib/store";

export default function Dashboard() {
  const scout = getScout();
  const [badges, setBadges] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchBadges()
      .then(setBadges)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <main style={{maxWidth:800, margin:"40px auto", padding:"0 16px"}}>
      <h1>Dashboard</h1>
      <div style={{border:"1px solid #eee", borderRadius:12, padding:12, marginBottom:24}}>
        <strong>{scout.name || "Scout Name"}</strong> • Troop {scout.troop || "—"}<br/>
        {scout.city || "City"}, {scout.state || "State"} • Parent: {scout.parentEmail || "—"}
      </div>
      <h2>Your Merit Badges</h2>
      {error && <div style={{color:"#a00"}}>{error}</div>}
      {!badges && !error && <div>Loading badges…</div>}
      {badges && badges.map((badge) => (
        <BadgeCard key={badge.badgeId} badge={badge} />
      ))}
    </main>
  );
}
