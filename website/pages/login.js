import { useState } from "react";
import { setScout, getScout } from "../lib/store";
import { useRouter } from "next/router";

export default function Login() {
  const router = useRouter();
  const seed = getScout();
  const [form, setForm] = useState(seed);
  const onSubmit = (e) => {
    e.preventDefault();
    setScout(form);
    router.push("/dashboard");
  };
  return (
    <main style={{maxWidth:600, margin:"40px auto", padding:"0 16px"}}>
      <h1>Scout Login</h1>
      <form onSubmit={onSubmit} style={{display:"grid", gap:12}}>
        <input placeholder="Name" value={form.name} onChange={e=>setForm({...form, name:e.target.value})}/>
        <input placeholder="Troop #" value={form.troop} onChange={e=>setForm({...form, troop:e.target.value})}/>
        <input placeholder="Parent Email" value={form.parentEmail} onChange={e=>setForm({...form, parentEmail:e.target.value})}/>
        <div style={{display:"flex", gap:8}}>
          <input placeholder="City" value={form.city} onChange={e=>setForm({...form, city:e.target.value})}/>
          <input placeholder="State" value={form.state} onChange={e=>setForm({...form, state:e.target.value})}/>
        </div>
        <button type="submit">Save & Go to Dashboard</button>
      </form>
    </main>
  );
}
