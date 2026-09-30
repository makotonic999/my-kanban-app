import { useState } from "react";
import { clearToken, getToken } from "./api";
import { Login } from "./components/Login";
import { Board } from "./components/Board";

export function App() {
  const [authed, setAuthed] = useState<boolean>(() => getToken() !== null);

  function handleLogout() {
    clearToken();
    setAuthed(false);
  }

  if (!authed) {
    return <Login onAuthed={() => setAuthed(true)} />;
  }

  return (
    <div className="min-h-screen flex flex-col bg-base-900 bg-grid text-slate-200">
      <header className="border-b border-slate-800 bg-base-800/80 backdrop-blur">
        <div className="max-w-5xl mx-auto px-4 py-3 flex justify-between items-center">
          <h1 className="flex items-center gap-2 font-bold">
            <span className="font-mono text-accent">▚</span>
            <span className="neon-text tracking-wide">KANBAN</span>
            <span className="text-slate-600 font-mono text-xs">/ board</span>
          </h1>
          <button
            onClick={handleLogout}
            className="text-sm text-slate-400 hover:text-accent transition"
          >
            ログアウト
          </button>
        </div>
      </header>

      <main className="flex-1 w-full max-w-5xl mx-auto p-4">
        <Board onUnauthorized={handleLogout} />
      </main>

      {/* キー操作ヒントのフッターバー（常時表示） */}
      <footer className="border-t border-slate-800 bg-base-800/80 backdrop-blur">
        <div className="max-w-5xl mx-auto px-4 py-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500 font-mono">
          <span className="flex items-center gap-1">
            <kbd className="kbd">↑</kbd>
            <kbd className="kbd">↓</kbd>
            <kbd className="kbd">←</kbd>
            <kbd className="kbd">→</kbd>
            <span>選択</span>
          </span>
          <span className="flex items-center gap-1">
            <kbd className="kbd">Shift</kbd>
            <span>+</span>
            <kbd className="kbd">←/→</kbd>
            <span>移動</span>
          </span>
          <span className="flex items-center gap-1">
            <kbd className="kbd">N</kbd>
            <span>新規</span>
          </span>
          <span className="flex items-center gap-1">
            <kbd className="kbd">Delete</kbd>
            <span>削除</span>
          </span>
          <span className="ml-auto flex items-center gap-1 text-slate-400">
            <kbd className="kbd">?</kbd>
            <span>ショートカット一覧</span>
          </span>
        </div>
      </footer>
    </div>
  );
}
