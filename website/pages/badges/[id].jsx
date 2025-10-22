import { useRouter } from "next/router";
import { useEffect, useState } from "react";
import ProgressBar from "../../components/ProgressBar";
import { getBadgeProgress, updateModule, markPurchased } from "../../lib/store";

export default function BadgePage() {
  const router = useRouter();
  const { id } = router.query;
  const [badge, setBadge] = useState(null);
  const [progress, setProgress] = useState(getBadgeProgress(id));

  useEffect(() => {
    if (!id) return;
    import(`../../data/${id}.json`).then(mod => {
      setBadge(mod);
      // ensure total modules known for percent calc
      markPurchased(id, getBadgeProgress(id).purchased || false, mod.modules.length);
      setProgress(getBadgeProgress(id));
    }).catch(() => setBadge(null));
  }, [id]);

  if (!id) return null;
  if (badge === null) return <main style={{padding:24}}>Badge not found.</main>;
  const purchased = getBadgeProgress(id).purchased;

  const completeModule = (m) => {
    const updated = updateModule(id, m.id, { totalModules: badge.modules.length });
    setProgress(updated);
  };

  const handlePurchase = () => {
    // placeholder; integrate Stripe later
    markPurchased(id, true, badge.modules.length);
    setProgress(getBadgeProgress(id));
    alert("Purchased for demo purposes. (Integrate Stripe here.)");
  };

  return (
    <main style={{maxWidth:820, margin:"40px auto", padding:"0 16px"}}>
      <h1>{badge.title}</h1>
      <p>{badge.summary}</p>
      {badge.officialUrl && (
        <p>
          <a href={badge.officialUrl} target="_blank" rel="noreferrer">
            View Official Requirements ↗
          </a>
        </p>
      )}
      {Array.isArray(badge.resources) && badge.resources.length > 0 && (
        <div style={{border:"1px solid #eee", borderRadius:12, padding:12, margin:"12px 0"}}>
          <strong>Explore More</strong>
          <ul style={{marginTop:8}}>
            {badge.resources.map((resource, index) => (
              <li key={index}>
                <a href={resource.url} target="_blank" rel="noreferrer">{resource.title}</a>
                {resource.description ? (
                  <>
                    {" "}— <span style={{color:"#555"}}>{resource.description}</span>
                  </>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      )}
      <div style={{margin:"12px 0"}}><ProgressBar value={progress.percent || 0}/></div>

      {!purchased && (
        <div style={{border:"1px dashed #aaa", padding:12, borderRadius:10, marginBottom:16}}>
          <strong>Price:</strong> ${badge.priceUSD || 20}{" "}
          <button onClick={handlePurchase} style={{marginLeft:8}}>Purchase Access</button>
          <div style={{fontSize:12, color:"#666"}}>Discounts available for urban troops.</div>
        </div>
      )}

      {badge.modules.map((m, idx) => {
        const done = progress.modules?.[m.id]?.done;
        return (
          <div key={m.id} style={{border:"1px solid #eee", borderRadius:12, padding:16, marginBottom:12, opacity: purchased ? 1 : 0.5}}>
            <h3 style={{marginTop:0}}>{idx+1}. {m.title}</h3>
            <p style={{marginTop:4}}>
              <em>Estimated:</em> {m.minutes} min • <em>Type:</em> {m.type}
            </p>
            {m.instructions && <p>{m.instructions}</p>}
            {m.prompt && <p><strong>Prompt:</strong> {m.prompt}</p>}

            {/* Minimal inputs to capture work (extend per type later) */}
            {purchased ? (
              <>
                <textarea placeholder="Paste notes / reflection / links here…" rows={4} style={{width:"100%", marginTop:8}}/>
                <div style={{display:"flex", gap:8, marginTop:8}}>
                  <button onClick={() => completeModule(m)} disabled={!!done}>
                    {done ? "Completed ✓" : "Mark Complete"}
                  </button>
                </div>
              </>
            ) : (
              <div style={{fontSize:12, color:"#a00"}}>Purchase required to submit work.</div>
            )}
          </div>
        );
      })}
    </main>
  );
}
