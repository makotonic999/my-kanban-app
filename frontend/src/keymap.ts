// キーボードショートカットの割り当てを 1 箇所に集約する。
// 将来「ユーザーがキーバインドを切り替えられる」機能を足す際、
// ここを設定値として差し替えられるように分離しておく。

export interface Shortcut {
  /** ヘルプ表示用のキー表記（例: "Shift + →"） */
  keys: string[];
  /** 動作の説明 */
  description: string;
}

// ヘルプモーダル/フッターに表示するショートカット一覧（表示用の定義）。
// 実際のキーハンドリングは useBoardKeyboard 側で行う。ここは「案内の真実の源」。
export const SHORTCUTS: Shortcut[] = [
  { keys: ["↑", "↓"], description: "同じ列で選択を上下に移動" },
  { keys: ["←", "→"], description: "隣の列へ選択を移動" },
  { keys: ["Shift", "←/→"], description: "選択中のタスクを隣の列へ移動" },
  { keys: ["N"], description: "新しいタスクを追加（入力にフォーカス）" },
  { keys: ["Delete"], description: "選択中のタスクを削除" },
  { keys: ["Esc"], description: "選択を解除 / モーダルを閉じる" },
  { keys: ["?"], description: "このショートカット一覧を表示" },
];
