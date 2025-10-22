import fs from "fs";
import path from "path";

export default function handler(req, res) {
  try {
    const dataDir = path.join(process.cwd(), "data");
    const files = fs.readdirSync(dataDir).filter((file) => file.endsWith(".json"));

    const badges = files.map((file) => {
      const raw = fs.readFileSync(path.join(dataDir, file), "utf-8");
      const json = JSON.parse(raw);
      return {
        badgeId: json.badgeId || file.replace(/\.json$/, ""),
        title: json.title || json.badgeId || file.replace(/\.json$/, ""),
        priceUSD: json.priceUSD ?? 20,
      };
    });

    badges.sort((a, b) => a.title.localeCompare(b.title));
    res.status(200).json({ badges });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to load manifest." });
  }
}
