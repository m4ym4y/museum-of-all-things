import Link from "next/link";

export default function Home() {
  return (
    <main style={{maxWidth:720, margin:"40px auto", padding:"0 16px"}}>
      <h1>Thunderbird Merit Badges</h1>
      <p>
        Earn badges online at your own pace with instant AI guidance and
        real Scoutmaster oversight. Your progress saves automatically and
        prints to a blue-card summary at completion.
      </p>
      <p><Link href="/login">Log in</Link> · <Link href="/dashboard">Dashboard</Link></p>
      <p><Link href="/badges/reading">Try the Reading badge →</Link></p>
    </main>
  );
}
