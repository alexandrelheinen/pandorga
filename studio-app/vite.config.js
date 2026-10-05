import { defineConfig } from "vite";
import path from "node:path";

export default defineConfig({
  root: ".",
  base: "/studio/",
  publicDir: false,
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
});
