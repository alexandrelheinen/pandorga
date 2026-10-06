import { defineConfig, loadEnv } from "vite";
import path from "node:path";
import fs from "node:fs";

/** Decode Frontend API host from a Clerk publishable key (`pk_test_` / `pk_live_`). */
function frontendApiHostFromKey(key) {
  const raw = String(key || "").replace(/^pk_(test|live)_/, "");
  if (!raw) return "";
  try {
    const pad = "=".repeat((4 - (raw.length % 4)) % 4);
    const b64 = (raw + pad).replace(/-/g, "+").replace(/_/g, "/");
    return Buffer.from(b64, "base64").toString("utf8").replace(/\$$/, "").trim();
  } catch {
    return "";
  }
}

function rejectExampleClerkHost(mode) {
  return {
    name: "reject-example-clerk-host",
    configResolved() {
      const env = loadEnv(mode, process.cwd(), "");
      const key = env.VITE_CLERK_PUBLISHABLE_KEY || process.env.VITE_CLERK_PUBLISHABLE_KEY || "";
      const host = frontendApiHostFromKey(key);
      if (!key) {
        throw new Error(
          "Studio production build requires VITE_CLERK_PUBLISHABLE_KEY (see studio-app/.env.local).",
        );
      }
      if (!host || host === "clerk.example.com" || host.endsWith(".example.com")) {
        throw new Error(
          `Refusing to bake placeholder Clerk host "${host || "(empty)"}" into studio/. ` +
            "Set VITE_CLERK_PUBLISHABLE_KEY to the real instance publishable key.",
        );
      }
    },
    writeBundle(_options, bundle) {
      for (const [fileName, chunk] of Object.entries(bundle)) {
        if (!fileName.endsWith(".js") || typeof chunk.code !== "string") continue;
        if (
          chunk.code.includes("clerk.example.com") ||
          chunk.code.includes("pk_test_Y2xlcmsuZXhhbXBsZS5jb20k")
        ) {
          throw new Error(
            `Studio bundle ${fileName} embeds clerk.example.com — rebuild with the real VITE_CLERK_PUBLISHABLE_KEY.`,
          );
        }
      }
    },
    closeBundle() {
      // emptyOutDir is false so schema.yml survives; drop stale hashed assets.
      const studioDir = path.resolve(__dirname, "../studio");
      const htmlPath = path.join(studioDir, "index.html");
      if (!fs.existsSync(htmlPath)) return;
      const html = fs.readFileSync(htmlPath, "utf8");
      const keep = new Set(
        [...html.matchAll(/\/studio\/assets\/([^"']+)/g)].map((m) => m[1]),
      );
      const assetsDir = path.join(studioDir, "assets");
      if (!fs.existsSync(assetsDir)) return;
      for (const name of fs.readdirSync(assetsDir)) {
        if (!/^index-.*\.(js|css)$/.test(name)) continue;
        if (keep.has(name)) continue;
        fs.unlinkSync(path.join(assetsDir, name));
      }
    },
  };
}

export default defineConfig(({ mode }) => ({
  root: ".",
  base: "/studio/",
  publicDir: false,
  plugins: [rejectExampleClerkHost(mode)],
  build: {
    outDir: path.resolve(__dirname, "../studio"),
    emptyOutDir: false,
    assetsDir: "assets",
    rollupOptions: {
      input: path.resolve(__dirname, "index.html"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/api/studio": {
        target: process.env.STUDIO_API_PROXY || "http://127.0.0.1:8788",
        changeOrigin: true,
      },
    },
  },
}));
