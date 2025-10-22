export default function ProgressBar({ value=0 }) {
  const pct = Math.round(value * 100);
  return (
    <div style={{border:"1px solid #ccc", borderRadius:8, padding:2, width:"100%", maxWidth:260}}>
      <div style={{
        height:12, width:`${pct}%`, borderRadius:6, background:"#4caf50",
        transition:"width .3s ease"
      }} />
      <div style={{fontSize:12, marginTop:4}}>{pct}% complete</div>
    </div>
  );
}
