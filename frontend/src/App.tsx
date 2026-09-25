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
    <div className="min-h-screen bg-slate-100">
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-5xl mx-auto px-4 py-3 flex justify-between items-center">
          <h1 className="font-bold text-slate-800">Kanban Board</h1>
          <button
            onClick={handleLogout}
            className="text-sm text-slate-600 hover:text-slate-900"
          >
            ログアウト
          </button>
        </div>
      </header>
      <main className="max-w-5xl mx-auto p-4">
        <Board onUnauthorized={handleLogout} />
      </main>
    </div>
  );
}
