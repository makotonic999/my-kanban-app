import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// 開発時は /api を Go API(:8080) にプロキシして CORS を回避しやすくする。
// 本番は VITE_API_BASE_URL で直接 API のオリジンを指定する。
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
});
