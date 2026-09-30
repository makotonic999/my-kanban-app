import { useState, type FormEvent } from "react";
import { ApiError, login, register } from "../api";

interface Props {
  onAuthed: () => void;
}

export function Login({ onAuthed }: Props) {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      if (mode === "register") {
        await register({ email, password, display_name: displayName });
      }
      await login({ email, password });
      onAuthed();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setError("メールアドレスまたはパスワードが正しくありません。");
      } else if (err instanceof ApiError) {
        setError(`エラー (${err.status}): ${err.message}`);
      } else {
        setError("通信に失敗しました。API が起動しているか確認してください。");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-base-900 bg-grid p-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm glass rounded-2xl border border-slate-700/70 shadow-2xl shadow-cyan-500/5 p-7 space-y-5 animate-fade-in"
      >
        <div className="space-y-1">
          <p className="font-mono text-xs tracking-widest text-accent/70">
            KANBAN&nbsp;//&nbsp;{mode === "login" ? "SIGN IN" : "SIGN UP"}
          </p>
          <h1 className="text-2xl font-bold neon-text">
            {mode === "login" ? "ログイン" : "アカウント作成"}
          </h1>
        </div>

        {error && (
          <p className="text-sm text-red-300 bg-red-950/50 border border-red-800/50 rounded-lg p-2.5">
            {error}
          </p>
        )}

        {mode === "register" && (
          <label className="block">
            <span className="text-xs font-medium text-slate-400">
              表示名（任意）
            </span>
            <input
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="mt-1 w-full rounded-lg bg-base-800 border border-slate-700 px-3 py-2 text-slate-100 placeholder-slate-500 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 transition"
            />
          </label>
        )}

        <label className="block">
          <span className="text-xs font-medium text-slate-400">
            メールアドレス
          </span>
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded-lg bg-base-800 border border-slate-700 px-3 py-2 text-slate-100 placeholder-slate-500 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 transition"
          />
        </label>

        <label className="block">
          <span className="text-xs font-medium text-slate-400">パスワード</span>
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded-lg bg-base-800 border border-slate-700 px-3 py-2 text-slate-100 placeholder-slate-500 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 transition"
          />
        </label>

        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-lg bg-accent/90 hover:bg-accent text-base-900 py-2.5 font-semibold tracking-wide shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 disabled:opacity-50 disabled:cursor-not-allowed transition"
        >
          {busy ? "処理中..." : mode === "login" ? "ログイン" : "登録してログイン"}
        </button>

        <button
          type="button"
          onClick={() => {
            setMode(mode === "login" ? "register" : "login");
            setError(null);
          }}
          className="w-full text-sm text-slate-400 hover:text-accent transition"
        >
          {mode === "login"
            ? "アカウントを作成する"
            : "既存アカウントでログイン"}
        </button>
      </form>
    </div>
  );
}
