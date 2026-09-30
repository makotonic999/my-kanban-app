import { SHORTCUTS } from "../keymap";

interface Props {
  onClose: () => void;
}

// キーボードショートカット一覧を表示するモーダル。`?` キーで開く。
export function ShortcutsHelp({ onClose }: Props) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-fade-in"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="キーボードショートカット一覧"
    >
      <div
        className="w-full max-w-md glass rounded-2xl border border-slate-700/70 shadow-2xl p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold neon-text">
            キーボードショートカット
          </h2>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-accent transition text-xl leading-none"
            aria-label="閉じる"
          >
            ×
          </button>
        </div>

        <ul className="space-y-2.5">
          {SHORTCUTS.map((s) => (
            <li
              key={s.description}
              className="flex items-center justify-between gap-4"
            >
              <span className="text-sm text-slate-300">{s.description}</span>
              <span className="flex items-center gap-1 shrink-0">
                {s.keys.map((k, i) => (
                  <span key={i} className="flex items-center gap-1">
                    {i > 0 && (
                      <span className="text-slate-600 text-xs">+</span>
                    )}
                    <kbd className="kbd">{k}</kbd>
                  </span>
                ))}
              </span>
            </li>
          ))}
        </ul>

        <p className="mt-5 text-xs text-slate-500 text-center font-mono">
          <kbd className="kbd">Esc</kbd> または画面外クリックで閉じる
        </p>
      </div>
    </div>
  );
}
