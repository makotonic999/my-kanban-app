import { useEffect, useState, type FormEvent } from "react";
import {
  ApiError,
  completeTask,
  createTask,
  deleteTask,
  listTasks,
  updateTaskStatus,
} from "../api";
import type { Task, TaskStatus } from "../types";

interface Props {
  onUnauthorized: () => void;
}

const COLUMNS: { key: TaskStatus; label: string; accent: string }[] = [
  { key: "todo", label: "To Do", accent: "border-slate-400" },
  { key: "in_progress", label: "In Progress", accent: "border-amber-400" },
  { key: "done", label: "Done", accent: "border-green-500" },
];

export function Board({ onUnauthorized }: Props) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

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

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    try {
      await createTask({ title: title.trim() });
      setTitle("");
      await refresh();
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

  const byStatus = (status: TaskStatus) =>
    tasks.filter((t) => (t.status || "todo") === status);

  return (
    <div className="space-y-4">
      {error && (
        <p className="text-sm text-red-600 bg-red-50 rounded p-2">{error}</p>
      )}

      <form onSubmit={handleCreate} className="flex gap-2">
        <input
          type="text"
          placeholder="新しいタスクのタイトル"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="flex-1 rounded border border-slate-300 px-3 py-2"
        />
        <button
          type="submit"
          className="rounded bg-blue-600 text-white px-4 py-2 font-medium hover:bg-blue-700"
        >
          追加
        </button>
      </form>

      {loading ? (
        <p className="text-slate-500">読み込み中...</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {COLUMNS.map((col) => (
            <div
              key={col.key}
              className={`bg-white rounded-lg shadow-sm border-t-4 ${col.accent} p-3`}
            >
              <h2 className="font-semibold text-slate-700 mb-3 flex justify-between">
                <span>{col.label}</span>
                <span className="text-slate-400">
                  {byStatus(col.key).length}
                </span>
              </h2>
              <div className="space-y-2">
                {byStatus(col.key).map((task) => (
                  <TaskCard
                    key={task.id}
                    task={task}
                    onMove={moveTo}
                    onDelete={remove}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function TaskCard({
  task,
  onMove,
  onDelete,
}: {
  task: Task;
  onMove: (task: Task, status: TaskStatus) => void;
  onDelete: (task: Task) => void;
}) {
  return (
    <div className="rounded border border-slate-200 p-2 text-sm">
      <div className="flex justify-between items-start gap-2">
        <span className="text-slate-800">{task.title}</span>
        <button
          onClick={() => onDelete(task)}
          className="text-slate-400 hover:text-red-600"
          title="削除"
        >
          ×
        </button>
      </div>
      <div className="mt-2 flex gap-1">
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
      onClick={onClick}
      className="text-xs rounded bg-slate-100 hover:bg-slate-200 px-2 py-1 text-slate-600"
    >
      {label}
    </button>
  );
}
