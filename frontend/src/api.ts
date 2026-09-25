import type {
  CreateTaskInput,
  LoginInput,
  RegisterInput,
  Task,
  TaskStatus,
} from "./types";

// 開発時は Vite プロキシ経由で /api、本番は VITE_API_BASE_URL を使う。
const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "/api";

const TOKEN_KEY = "kanban_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

// 認証エラー（401）を型で表現し、UI 側でログアウト処理に使う。
export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
  auth = true,
): Promise<T> {
  const headers = new Headers(options.headers);
  if (options.body) headers.set("Content-Type", "application/json");
  if (auth) {
    const token = getToken();
    if (token) headers.set("Authorization", `Bearer ${token}`);
  }

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new ApiError(res.status, text || res.statusText);
  }

  // 204 No Content はボディなし。
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

// ---- 認証 ----
export async function login(input: LoginInput): Promise<string> {
  const data = await request<{ token: string }>(
    "/login",
    { method: "POST", body: JSON.stringify(input) },
    false,
  );
  setToken(data.token);
  return data.token;
}

export async function register(input: RegisterInput): Promise<void> {
  await request(
    "/users",
    { method: "POST", body: JSON.stringify(input) },
    false,
  );
}

// ---- タスク ----
export function listTasks(): Promise<Task[]> {
  return request<Task[]>("/tasks", { method: "GET" });
}

export function createTask(input: CreateTaskInput): Promise<Task> {
  return request<Task>("/tasks", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function updateTaskStatus(id: number, status: TaskStatus): Promise<Task> {
  return request<Task>(`/tasks/${id}`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
}

export function completeTask(id: number): Promise<Task> {
  return request<Task>(`/tasks/${id}/complete`, { method: "PATCH" });
}

export function deleteTask(id: number): Promise<void> {
  return request<void>(`/tasks/${id}`, { method: "DELETE" });
}
