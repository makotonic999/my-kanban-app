// Go API のモデルに対応する型。

export type TaskStatus = "todo" | "in_progress" | "done";

export interface Task {
  id: number;
  user_id: number;
  title: string;
  description: string | null;
  status: TaskStatus | string;
  due_date: string | null;
  estimated_minutes: number | null;
  actual_minutes: number | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateTaskInput {
  title: string;
  description?: string | null;
  estimated_minutes?: number | null;
  due_date?: string | null;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface RegisterInput {
  email: string;
  password: string;
  display_name?: string;
}
