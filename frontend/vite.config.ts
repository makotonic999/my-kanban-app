import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// 開発時は /api を Go API にプロキシして CORS を回避しやすくする。
// 本番は VITE_API_BASE_URL で直接 API のオリジンを指定する。
//
// プロキシ先はコンテナ実行かホスト実行かで変わる:
//  - コンテナ(compose)内: サービス名 "api" で名前解決 → http://api:8080
//  - ホストで直接 npm run dev: http://localhost:8080
// 環境変数 VITE_DEV_PROXY_TARGET で上書きでき、未設定時は localhost にフォールバック。
const proxyTarget = process.env.VITE_DEV_PROXY_TARGET ?? "http://localhost:8080";

export default defineConfig({
  plugins: [react()],
  server: {
    // 0.0.0.0 で待受 → コンテナ外（ホストのブラウザ）から到達可能にする。
    host: true,
    port: 5173,
    // bind mount + Linux コンテナでファイル変更検知が効かない場合の保険。
    // ホットリロードを確実にするためポーリング監視を有効化する。
    watch: {
      usePolling: true,
    },
    proxy: {
      "/api": {
        target: proxyTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
});
