import Link from "next/link";
import ProgressBar from "./ProgressBar";
import { getBadgeProgress } from "../lib/store";

export default function BadgeCard({ badge }) {
  const progress = getBadgeProgress(badge.badgeId);
  return (
    <div style={{border:"1px solid #ddd", borderRadius:12, padding:16, marginBottom:12}}>
      <h3 style={{margin:"0 0 8px"}}>{badge.title}</h3>
      <div style={{display:"flex", gap:16, alignItems:"center"}}>
        <ProgressBar value={progress.percent || 0}/>
        <Link href={`/badges/${badge.badgeId}`}>Open</Link>
      </div>
      {!progress.purchased && <div style={{fontSize:12, color:"#666", marginTop:8}}>${badge.priceUSD || 20} per badge</div>}
    </div>
  );
}
