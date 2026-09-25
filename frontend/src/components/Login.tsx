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
    <div className="min-h-screen flex items-center justify-center bg-slate-100 p-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm bg-white rounded-xl shadow p-6 space-y-4"
      >
        <h1 className="text-xl font-bold text-slate-800">
          {mode === "login" ? "ログイン" : "アカウント作成"}
        </h1>

        {error && (
          <p className="text-sm text-red-600 bg-red-50 rounded p-2">{error}</p>
        )}

        {mode === "register" && (
          <label className="block">
            <span className="text-sm text-slate-600">表示名（任意）</span>
            <input
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="mt-1 w-full rounded border border-slate-300 px-3 py-2"
            />
          </label>
        )}

        <label className="block">
          <span className="text-sm text-slate-600">メールアドレス</span>
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded border border-slate-300 px-3 py-2"
          />
        </label>

        <label className="block">
          <span className="text-sm text-slate-600">パスワード</span>
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded border border-slate-300 px-3 py-2"
          />
        </label>

        <button
          type="submit"
          disabled={busy}
          className="w-full rounded bg-blue-600 text-white py-2 font-medium hover:bg-blue-700 disabled:opacity-50"
        >
          {busy ? "処理中..." : mode === "login" ? "ログイン" : "登録してログイン"}
        </button>

        <button
          type="button"
          onClick={() => {
            setMode(mode === "login" ? "register" : "login");
            setError(null);
          }}
          className="w-full text-sm text-blue-600 hover:underline"
        >
          {mode === "login"
            ? "アカウントを作成する"
            : "既存アカウントでログイン"}
        </button>
      </form>
    </div>
  );
}
