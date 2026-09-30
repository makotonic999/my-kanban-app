/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // アプリ共通のダーク背景・面の色
        base: {
          900: "#0b1120", // 最背面（body）
          800: "#0f172a", // パネル背面
          700: "#111a2e", // カード
        },
        // ネオン系アクセント（シアン〜エメラルド）
        accent: {
          DEFAULT: "#22d3ee", // cyan-400
          soft: "#67e8f9", // cyan-300
        },
      },
      fontFamily: {
        mono: [
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "Consolas",
          "monospace",
        ],
      },
      keyframes: {
        "fade-in": {
          "0%": { opacity: "0", transform: "translateY(4px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        "fade-in": "fade-in 0.15s ease-out",
      },
    },
  },
  plugins: [],
};
