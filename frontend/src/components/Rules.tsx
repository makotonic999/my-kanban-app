import { useEffect, useRef, useState } from "react";
import { ApiError, getRules, updateRules } from "../api";

interface Props {
  onUnauthorized: () => void;
}

// 空欄のときに薄い字で見せる例ルール（プレースホルダ）。
const EXAMPLE_RULES = `例:
1. In Progress は4つ以上キープしない。
2. タスク名は一目でわかるように。
3. Done はこまめに。完了は小さく刻む。`;

// カンバン上部に置く「ルール」ゾーン。
// 通常は表示モード。「編集」でテキストエリアになり、「保存」で DB に保存する。
export function Rules({ onUnauthorized }: Props) {
  const [rules, setRules] = useState("");
  const [draft, setDraft] = useState("");
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function handleError(err: unknown) {
    if (err instanceof ApiError && err.status === 401) {
      onUnauthorized();
      return;
    }
    setError(err instanceof Error ? err.message : "ルールの処理に失敗しました");
  }

  useEffect(() => {
    (async () => {
      try {
        setRules(await getRules());
      } catch (err) {
        handleError(err);
      } finally {
        setLoading(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function startEdit() {
    setDraft(rules);
    setEditing(true);
    setError(null);
    // フォーカスは描画後に当てる。
    setTimeout(() => textareaRef.current?.focus(), 0);
  }

  function cancelEdit() {
    setEditing(false);
    setDraft("");
    setError(null);
  }

  async function save() {
    setSaving(true);
    setError(null);
    try {
      const saved = await updateRules(draft);
      setRules(saved);
      setEditing(false);
      setDraft("");
    } catch (err) {
      handleError(err);
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="glass rounded-xl border border-slate-700/60 p-3">
      <div className="flex items-center justify-between mb-2">
        <h2 className="flex items-center gap-2 text-sm font-semibold text-slate-200">
          <span className="text-accent">📏</span>
          ルール
        </h2>
        {!editing ? (
          <button
            onClick={startEdit}
            disabled={loading}
            className="text-xs rounded bg-base-800 hover:bg-slate-700 px-3 py-1 text-slate-300 border border-slate-700 transition disabled:opacity-50"
          >
            編集
          </button>
        ) : (
          <div className="flex gap-1.5">
            <button
              onClick={cancelEdit}
              disabled={saving}
              className="text-xs rounded bg-base-800 hover:bg-slate-700 px-3 py-1 text-slate-400 border border-slate-700 transition"
            >
              取消
            </button>
            <button
              onClick={save}
              disabled={saving}
              className="text-xs rounded bg-accent/90 hover:bg-accent px-3 py-1 text-base-900 font-semibold transition disabled:opacity-50"
            >
              {saving ? "保存中..." : "保存"}
            </button>
          </div>
        )}
      </div>

      {error && (
        <p className="text-xs text-red-300 bg-red-950/50 border border-red-800/50 rounded p-2 mb-2">
          {error}
        </p>
      )}

      {editing ? (
        <textarea
          ref={textareaRef}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={EXAMPLE_RULES}
          rows={5}
          className="w-full rounded-lg bg-base-800 border border-slate-700 px-3 py-2 text-sm text-slate-100 placeholder-slate-600 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 transition resize-y font-mono leading-relaxed"
        />
      ) : loading ? (
        <p className="text-xs text-slate-500 font-mono">読み込み中...</p>
      ) : rules.trim() ? (
        // 保存済みルールを改行そのままで表示。
        <pre className="whitespace-pre-wrap text-sm text-slate-200 font-mono leading-relaxed">
          {rules}
        </pre>
      ) : (
        // 未設定のときは例ルールを薄い字で表示（プレースホルダ的）。
        <pre className="whitespace-pre-wrap text-sm text-slate-600 font-mono leading-relaxed">
          {EXAMPLE_RULES}
        </pre>
      )}
    </section>
  );
}
