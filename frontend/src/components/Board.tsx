import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  ApiError,
  completeTask,
  createTask,
  deleteTask,
  listTasks,
  updateTask,
  updateTaskStatus,
} from "../api";
import type { Task, TaskStatus } from "../types";
import {
  formatDueDate,
  isOverdue,
  inputValueToYyyymmdd,
  parseYyyymmdd,
  yyyymmddToInputValue,
} from "../format";
import { ShortcutsHelp } from "./ShortcutsHelp";
import { Rules } from "./Rules";

interface Props {
  onUnauthorized: () => void;
}

const COLUMNS: {
  key: TaskStatus;
  label: string;
  ring: string;
  dot: string;
}[] = [
  { key: "todo", label: "To Do", ring: "before:bg-slate-500", dot: "bg-slate-400" },
  {
    key: "in_progress",
    label: "In Progress",
    ring: "before:bg-amber-400",
    dot: "bg-amber-400",
  },
  { key: "done", label: "Done", ring: "before:bg-emerald-400", dot: "bg-emerald-400" },
];

const STATUS_ORDER: TaskStatus[] = ["todo", "in_progress", "done"];

export function Board({ onUnauthorized }: Props) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [due, setDue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [helpOpen, setHelpOpen] = useState(false);

  // キーボード選択カーソル: { col: 列index, row: カード index }
  const [cursor, setCursor] = useState<{ col: number; row: number } | null>(
    null,
  );

  // インライン編集の状態。editingId が非 null のカードが編集モード。
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [editDue, setEditDue] = useState(""); // YYYYMMDD 形式

  const titleInputRef = useRef<HTMLInputElement>(null);
  const dueInputRef = useRef<HTMLInputElement>(null);
  const datePickerRef = useRef<HTMLInputElement>(null);

  function handleError(err: unknown) {
    if (err instanceof ApiError && err.status === 401) {
      onUnauthorized();
      return;
    }
    setError(err instanceof Error ? err.message : "不明なエラー");
  }

  async function refresh() {
    try {
      setTasks(await listTasks());
    } catch (err) {
      handleError(err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 各列のタスクを「期日の近い順」に並べる。
  // 期日なしは末尾へ。同じ期日（や期日なし同士）は id 昇順で安定させる。
  const byStatus = (status: TaskStatus) =>
    tasks
      .filter((t) => (t.status || "todo") === status)
      .slice()
      .sort((a, b) => {
        const da = a.due_date ? new Date(a.due_date).getTime() : Infinity;
        const db = b.due_date ? new Date(b.due_date).getTime() : Infinity;
        if (da !== db) return da - db;
        return a.id - b.id;
      });

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;

    // 期日: "20260930" 形式。空欄は期日なし。不正な値はエラーにして中断。
    let dueIso: string | null = null;
    if (due.trim()) {
      const parsed = parseYyyymmdd(due);
      if (!parsed) {
        setError(
          "期日は YYYYMMDD 形式で入力してください（例: 20260930）。存在しない日付は登録できません。",
        );
        dueInputRef.current?.focus();
        return;
      }
      dueIso = parsed.toISOString();
    }

    try {
      await createTask({
        title: title.trim(),
        due_date: dueIso,
      });
      setTitle("");
      setDue("");
      setError(null);
      await refresh();
      // 続けて入力しやすいようタイトルへフォーカスを戻す。
      titleInputRef.current?.focus();
    } catch (err) {
      handleError(err);
    }
  }

  async function moveTo(task: Task, status: TaskStatus) {
    try {
      if (status === "done") {
        await completeTask(task.id);
      } else {
        await updateTaskStatus(task.id, status);
      }
      await refresh();
    } catch (err) {
      handleError(err);
    }
  }

  async function remove(task: Task) {
    try {
      await deleteTask(task.id);
      await refresh();
    } catch (err) {
      handleError(err);
    }
  }

  // 選択中カードのインライン編集を開始する（F2）。
  function startEdit(task: Task) {
    setEditingId(task.id);
    setEditTitle(task.title);
    setEditDue(task.due_date ? yyyymmddToInputValue(task.due_date).replace(/-/g, "") : "");
    setError(null);
  }

  function cancelEdit() {
    setEditingId(null);
    setEditTitle("");
    setEditDue("");
  }

  // 編集内容を保存する。変更があったフィールドだけ送る。
  async function saveEdit(task: Task) {
    const newTitle = editTitle.trim();
    if (!newTitle) {
      setError("タイトルは空にできません。");
      return;
    }

    // 期日: 空欄は「期日なし」。入力ありは YYYYMMDD を検証。
    let newDueIso: string | null = null;
    if (editDue.trim()) {
      const parsed = parseYyyymmdd(editDue);
      if (!parsed) {
        setError(
          "期日は YYYYMMDD 形式で入力してください（例: 20260930）。存在しない日付は登録できません。",
        );
        return;
      }
      newDueIso = parsed.toISOString();
    }

    const patch: { title?: string; due_date?: string | null } = {};
    if (newTitle !== task.title) patch.title = newTitle;
    const oldDueYmd = task.due_date
      ? yyyymmddToInputValue(task.due_date).replace(/-/g, "")
      : "";
    if (editDue.trim() !== oldDueYmd) patch.due_date = newDueIso;

    // 変更がなければ API を叩かずに閉じる。
    if (patch.title === undefined && patch.due_date === undefined) {
      cancelEdit();
      return;
    }

    try {
      await updateTask(task.id, patch);
      cancelEdit();
      await refresh();
    } catch (err) {
      handleError(err);
    }
  }

  // 現在カーソルが指しているタスクを取り出す。
  function taskAtCursor(): Task | null {
    if (!cursor) return null;
    const status = STATUS_ORDER[cursor.col];
    const col = byStatus(status);
    return col[cursor.row] ?? null;
  }

  // --- キーボード操作 ---
  // 割り当ては keymap.ts の案内と対応。実ハンドリングはここに集約。
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null;
      const typing =
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.isContentEditable);

      // ヘルプを開く「?」は入力中でなければ常時有効。
      if (e.key === "?" && !typing) {
        e.preventDefault();
        setHelpOpen((v) => !v);
        return;
      }

      // F2: 選択中カードのインライン編集を開始（編集中・入力中でなければ）。
      if (e.key === "F2" && !typing && editingId === null) {
        const task = taskAtCursor();
        if (task) {
          e.preventDefault();
          startEdit(task);
        }
        return;
      }

      // 編集中はカード内の入力欄が処理するので、グローバルの操作は行わない
      // （Enter/Esc/矢印/Tab はカード側の onKeyDown が担当）。
      if (editingId !== null) return;

      if (e.key === "Escape") {
        if (helpOpen) {
          setHelpOpen(false);
        } else if (typing && target) {
          (target as HTMLInputElement).blur();
        } else {
          setCursor(null);
        }
        return;
      }

      // 新規タスク: N（入力中は無効）
      if ((e.key === "n" || e.key === "N") && !typing) {
        e.preventDefault();
        titleInputRef.current?.focus();
        return;
      }

      // 入力欄で ↓ を押したら、入力から抜けてボードのタスク選択へ移る。
      // （連続入力しつつ、いつでも下キーでタスク操作へ移れるようにする）
      if (e.key === "ArrowDown" && typing && target && !helpOpen) {
        const cols = STATUS_ORDER.map((s) => byStatus(s));
        const firstCol = cols.findIndex((c) => c.length > 0);
        if (firstCol !== -1) {
          e.preventDefault();
          (target as HTMLInputElement).blur();
          setCursor({ col: firstCol, row: 0 });
        }
        return;
      }

      // 入力中・ヘルプ表示中はナビゲーションを無効化。
      if (typing || helpOpen) return;

      const cols = STATUS_ORDER.map((s) => byStatus(s));

      // まだ選択がない状態で矢印を押したら、最初の非空列の先頭を選ぶ。
      function ensureCursor(): { col: number; row: number } | null {
        if (cursor) return cursor;
        const firstCol = cols.findIndex((c) => c.length > 0);
        if (firstCol === -1) return null;
        return { col: firstCol, row: 0 };
      }

      switch (e.key) {
        case "ArrowUp": {
          e.preventDefault();
          const c = ensureCursor();
          if (!c) return;
          // 一番上のタスクで さらに ↑ を押したら、入力欄（タイトル）へ戻る。
          if (c.row === 0) {
            setCursor(null);
            titleInputRef.current?.focus();
            return;
          }
          setCursor({ col: c.col, row: Math.max(0, c.row - 1) });
          break;
        }
        case "ArrowDown": {
          e.preventDefault();
          const c = ensureCursor();
          if (!c) return;
          const len = cols[c.col].length;
          setCursor({ col: c.col, row: Math.min(len - 1, c.row + 1) });
          break;
        }
        case "ArrowLeft":
        case "ArrowRight": {
          e.preventDefault();
          const c = ensureCursor();
          if (!c) return;
          const dir = e.key === "ArrowRight" ? 1 : -1;

          // Shift 併用: 選択中タスクを隣の列へ「移動」する。
          if (e.shiftKey) {
            const task = cols[c.col][c.row];
            if (!task) return;
            const targetCol = c.col + dir;
            if (targetCol < 0 || targetCol >= STATUS_ORDER.length) return;
            void moveTo(task, STATUS_ORDER[targetCol]);
            // 移動先の列の末尾あたりに選択を移す（refresh 後に補正される）。
            setCursor({ col: targetCol, row: cols[targetCol].length });
            return;
          }

          // Shift なし: 選択カーソルを隣の列へ移すだけ。
          let targetCol = c.col + dir;
          while (
            targetCol >= 0 &&
            targetCol < STATUS_ORDER.length &&
            cols[targetCol].length === 0
          ) {
            targetCol += dir;
          }
          if (targetCol < 0 || targetCol >= STATUS_ORDER.length) return;
          const row = Math.min(c.row, cols[targetCol].length - 1);
          setCursor({ col: targetCol, row: Math.max(0, row) });
          break;
        }
        case "Delete":
        case "Backspace": {
          const task = taskAtCursor();
          if (!task) return;
          e.preventDefault();
          if (window.confirm(`「${task.title}」を削除しますか？`)) {
            void remove(task);
          }
          break;
        }
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
    // tasks/cursor/helpOpen/editingId に依存（最新の状態で判定するため）
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tasks, cursor, helpOpen, editingId]);

  // タスク更新でカーソルが範囲外になったら補正する。
  useEffect(() => {
    if (!cursor) return;
    const len = byStatus(STATUS_ORDER[cursor.col]).length;
    if (len === 0) {
      setCursor(null);
    } else if (cursor.row > len - 1) {
      setCursor({ col: cursor.col, row: len - 1 });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tasks]);

  return (
    <div className="space-y-5">
      {error && (
        <p className="text-sm text-red-300 bg-red-950/50 border border-red-800/50 rounded-lg p-2.5">
          {error}
        </p>
      )}

      {/* ルールゾーン（タスク追加フォームの上） */}
      <Rules onUnauthorized={onUnauthorized} />

      {/* 作成フォーム: タイトル + 期日（Enter で作成） */}
      <form
        onSubmit={handleCreate}
        className="glass rounded-xl border border-slate-700/60 p-3 flex flex-col sm:flex-row gap-2"
      >
        <input
          ref={titleInputRef}
          type="text"
          placeholder="新しいタスクのタイトル（N でフォーカス）"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              dueInputRef.current?.focus();
            }
          }}
          className="flex-1 rounded-lg bg-base-800 border border-slate-700 px-3 py-2 text-slate-100 placeholder-slate-500 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 transition"
        />
        <div className="flex gap-2">
          <label className="flex items-center gap-1 rounded-lg bg-base-800 border border-slate-700 px-2 focus-within:border-accent transition">
            <span className="text-xs text-slate-500 shrink-0">期日</span>
            <input
              ref={dueInputRef}
              type="text"
              inputMode="numeric"
              maxLength={8}
              placeholder="例: 20260930 (2026/09/30)"
              value={due}
              // 数字以外は弾き、最大8桁に制限する。
              onChange={(e) =>
                setDue(e.target.value.replace(/\D/g, "").slice(0, 8))
              }
              className="w-52 bg-transparent text-slate-200 text-sm py-2 focus:outline-none placeholder-slate-500 font-mono"
            />
            {/* カレンダーからも選べるようにする（テキストと相互連動） */}
            <button
              type="button"
              title="カレンダーから選ぶ"
              aria-label="カレンダーから期日を選ぶ"
              onClick={() => {
                const el = datePickerRef.current;
                if (!el) return;
                // 現在のテキスト値をピッカーの初期値に反映してから開く。
                el.value = yyyymmddToInputValue(due);
                if (typeof el.showPicker === "function") el.showPicker();
                else el.click();
              }}
              className="text-slate-500 hover:text-accent transition text-sm leading-none px-1"
            >
              📅
            </button>
            {/* 見えない date input。選択結果をテキスト欄(YYYYMMDD)へ反映する。 */}
            <input
              ref={datePickerRef}
              type="date"
              tabIndex={-1}
              aria-hidden="true"
              onChange={(e) => setDue(inputValueToYyyymmdd(e.target.value))}
              className="sr-only absolute h-0 w-0 opacity-0"
            />
          </label>
        </div>
        <button
          type="submit"
          className="rounded-lg bg-accent/90 hover:bg-accent text-base-900 px-5 py-2 font-semibold shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 transition"
        >
          追加
        </button>
      </form>

      {loading ? (
        <p className="text-slate-500 font-mono text-sm">読み込み中...</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {COLUMNS.map((col, colIndex) => {
            const items = byStatus(col.key);
            return (
              <div
                key={col.key}
                className="glass rounded-xl border border-slate-700/60 p-3 min-h-[8rem]"
              >
                <h2 className="flex items-center justify-between mb-3 px-1">
                  <span className="flex items-center gap-2 font-semibold text-slate-200">
                    <span className={`h-2 w-2 rounded-full ${col.dot}`} />
                    {col.label}
                  </span>
                  <span className="font-mono text-xs text-slate-500 bg-base-800 rounded-full px-2 py-0.5">
                    {items.length}
                  </span>
                </h2>
                <div className="space-y-2">
                  {items.map((task, rowIndex) => (
                    <TaskCard
                      key={task.id}
                      task={task}
                      selected={
                        cursor?.col === colIndex && cursor?.row === rowIndex
                      }
                      editing={editingId === task.id}
                      editTitle={editTitle}
                      editDue={editDue}
                      onEditTitleChange={setEditTitle}
                      onEditDueChange={setEditDue}
                      onSave={() => saveEdit(task)}
                      onCancel={cancelEdit}
                      onMove={moveTo}
                      onDelete={remove}
                      onSelect={() =>
                        setCursor({ col: colIndex, row: rowIndex })
                      }
                      onStartEdit={() => startEdit(task)}
                    />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {helpOpen && <ShortcutsHelp onClose={() => setHelpOpen(false)} />}
    </div>
  );
}

function TaskCard({
  task,
  selected,
  editing,
  editTitle,
  editDue,
  onEditTitleChange,
  onEditDueChange,
  onSave,
  onCancel,
  onMove,
  onDelete,
  onSelect,
  onStartEdit,
}: {
  task: Task;
  selected: boolean;
  editing: boolean;
  editTitle: string;
  editDue: string;
  onEditTitleChange: (v: string) => void;
  onEditDueChange: (v: string) => void;
  onSave: () => void;
  onCancel: () => void;
  onMove: (task: Task, status: TaskStatus) => void;
  onDelete: (task: Task) => void;
  onSelect: () => void;
  onStartEdit: () => void;
}) {
  const dueLabel = formatDueDate(task.due_date);
  const overdue = task.status !== "done" && isOverdue(task.due_date);

  const editTitleRef = useRef<HTMLInputElement>(null);
  const editDueRef = useRef<HTMLInputElement>(null);

  // 編集モードに入ったらタイトル入力へフォーカス＆全選択（エクセル的な F2）。
  useEffect(() => {
    if (editing) {
      const el = editTitleRef.current;
      if (el) {
        el.focus();
        el.select();
      }
    }
  }, [editing]);

  // --- 編集モードの表示 ---
  if (editing) {
    return (
      <div className="rounded-lg border neon-ring border-accent/70 bg-base-700 p-2.5 text-sm space-y-2">
        {/* タイトル編集 */}
        <input
          ref={editTitleRef}
          type="text"
          value={editTitle}
          onChange={(e) => onEditTitleChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              onSave();
            } else if (e.key === "Escape") {
              e.preventDefault();
              onCancel();
            } else if (e.key === "ArrowDown" || e.key === "Tab") {
              // ↓ / Tab で期日編集へ移る。
              e.preventDefault();
              editDueRef.current?.focus();
              editDueRef.current?.select();
            }
          }}
          className="w-full rounded bg-base-800 border border-slate-600 px-2 py-1 text-slate-100 focus:border-accent focus:outline-none focus:ring-1 focus:ring-accent/40"
        />
        {/* 期日編集（YYYYMMDD） */}
        <div className="flex items-center gap-1">
          <span className="text-[0.65rem] text-slate-500 shrink-0">期日</span>
          <input
            ref={editDueRef}
            type="text"
            inputMode="numeric"
            maxLength={8}
            placeholder="例: 20260930（空で期日なし）"
            value={editDue}
            onChange={(e) =>
              onEditDueChange(e.target.value.replace(/\D/g, "").slice(0, 8))
            }
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                onSave();
              } else if (e.key === "Escape") {
                e.preventDefault();
                onCancel();
              } else if (e.key === "ArrowUp") {
                // ↑ でタイトルへ戻る。
                e.preventDefault();
                editTitleRef.current?.focus();
                editTitleRef.current?.select();
              } else if (e.key === "Tab") {
                // Tab はタイトルへ循環。
                e.preventDefault();
                editTitleRef.current?.focus();
                editTitleRef.current?.select();
              }
            }}
            className="flex-1 rounded bg-base-800 border border-slate-600 px-2 py-1 text-slate-100 font-mono text-xs focus:border-accent focus:outline-none focus:ring-1 focus:ring-accent/40"
          />
        </div>
        <div className="flex items-center justify-between">
          <span className="text-[0.6rem] text-slate-500 font-mono">
            Enter 保存 / Esc 取消 / ↓Tab 期日
          </span>
          <div className="flex gap-1">
            <button
              onClick={onCancel}
              className="text-[0.65rem] rounded bg-base-800 hover:bg-slate-700 px-2 py-1 text-slate-400 border border-slate-700"
            >
              取消
            </button>
            <button
              onClick={onSave}
              className="text-[0.65rem] rounded bg-accent/90 hover:bg-accent px-2 py-1 text-base-900 font-semibold"
            >
              保存
            </button>
          </div>
        </div>
      </div>
    );
  }

  // --- 通常表示 ---
  return (
    <div
      onClick={onSelect}
      onDoubleClick={onStartEdit}
      className={`group rounded-lg border p-2.5 text-sm cursor-pointer transition ${
        selected
          ? "neon-ring border-accent/70 bg-base-700"
          : "border-slate-700/70 bg-base-700/60 hover:border-slate-600"
      }`}
    >
      <div className="flex justify-between items-start gap-2">
        <span className="text-slate-100 leading-snug">{task.title}</span>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onDelete(task);
          }}
          className="text-slate-600 hover:text-red-400 transition shrink-0 leading-none"
          title="削除"
        >
          ×
        </button>
      </div>

      {dueLabel && (
        <div className="mt-2 flex flex-wrap items-center gap-1.5">
          <span
            className={`inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[0.65rem] font-mono ${
              overdue
                ? "bg-red-950/60 text-red-300 border border-red-800/50"
                : "bg-base-800 text-slate-400 border border-slate-700"
            }`}
            title="期日"
          >
            📅 {dueLabel}
          </span>
        </div>
      )}

      <div className="mt-2 flex gap-1 opacity-0 group-hover:opacity-100 transition">
        {task.status !== "todo" && (
          <MoveButton label="← To Do" onClick={() => onMove(task, "todo")} />
        )}
        {task.status !== "in_progress" && (
          <MoveButton
            label="In Progress"
            onClick={() => onMove(task, "in_progress")}
          />
        )}
        {task.status !== "done" && (
          <MoveButton label="Done →" onClick={() => onMove(task, "done")} />
        )}
      </div>
    </div>
  );
}

function MoveButton({
  label,
  onClick,
}: {
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      className="text-[0.65rem] rounded bg-base-800 hover:bg-slate-700 px-2 py-1 text-slate-400 hover:text-slate-200 border border-slate-700 transition"
    >
      {label}
    </button>
  );
}
