// 表示整形用の小さなヘルパー群。

// 見積もり分を「1h30m」「45m」形式に整形する。
export function formatEstimate(minutes: number | null | undefined): string | null {
  if (minutes == null || minutes <= 0) return null;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0 && m > 0) return `${h}h${m}m`;
  if (h > 0) return `${h}h`;
  return `${m}m`;
}

// 期日を「MM/DD」形式に整形する。無効/未設定は null。
// 期日は「UTC 深夜 0 時」で保存される日付なので、UTC で月日を読む
// （ローカルタイムで読むと環境によって 1 日ずれる）。
export function formatDueDate(due: string | null | undefined): string | null {
  if (!due) return null;
  const d = new Date(due);
  if (Number.isNaN(d.getTime())) return null;
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${mm}/${dd}`;
}

// 期日が今日より前（過ぎている）かどうか。done 判定は呼び出し側で行う。
// 期日は UTC 深夜基準なので、今日も UTC 深夜に正規化して比較する。
export function isOverdue(due: string | null | undefined): boolean {
  if (!due) return false;
  const d = new Date(due);
  if (Number.isNaN(d.getTime())) return false;
  const now = new Date();
  const todayUtc = Date.UTC(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  );
  return d.getTime() < todayUtc;
}


// "20260930" のような YYYYMMDD 8桁文字列を Date に変換する。
// 桁数不足・実在しない日付（13月・2月30日など）は null を返す（厳密判定）。
export function parseYyyymmdd(input: string): Date | null {
  const s = input.trim();
  if (!/^\d{8}$/.test(s)) return null;
  const year = Number(s.slice(0, 4));
  const month = Number(s.slice(4, 6)); // 1-12
  const day = Number(s.slice(6, 8));
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // ローカルタイムの日付として生成し、桁上がり（存在しない日付）を検出する。
  const d = new Date(year, month - 1, day);
  if (
    d.getFullYear() !== year ||
    d.getMonth() !== month - 1 ||
    d.getDate() !== day
  ) {
    return null; // 例: 20260230 → 3月に繰り上がるので不正とみなす
  }
  return d;
}


// date input（value="YYYY-MM-DD"）用に、YYYYMMDD 8桁を "YYYY-MM-DD" へ変換する。
// 不正なら空文字（＝ピッカー未選択）を返す。
export function yyyymmddToInputValue(input: string): string {
  const d = parseYyyymmdd(input);
  if (!d) return "";
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

// date input が返す "YYYY-MM-DD" を YYYYMMDD 8桁へ変換する。空なら空文字。
export function inputValueToYyyymmdd(value: string): string {
  if (!value) return "";
  return value.replace(/-/g, "");
}

// API から返る期日（"2026-09-30T00:00:00Z" のような ISO 文字列）を
// 編集欄用の YYYYMMDD 8桁へ変換する。UTC 深夜基準で保存しているため UTC で読む。
// 無効/未設定は空文字。
export function dueToYyyymmdd(due: string | null | undefined): string {
  if (!due) return "";
  const d = new Date(due);
  if (Number.isNaN(d.getTime())) return "";
  const y = String(d.getUTCFullYear()).padStart(4, "0");
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${y}${m}${dd}`;
}

// YYYYMMDD 8桁を、API 送信用の「UTC 深夜 0 時」RFC3339 文字列へ変換する。
// 期日は時刻を持たない「日付」なので、ローカルタイム→UTC の変換で日付が
// ずれないよう、入力日をそのまま UTC の 0 時として組み立てる。
// 例: "20260930" → "2026-09-30T00:00:00.000Z"
// （Date#toISOString はローカル 0 時を UTC に変換して前日へずらすため使わない）
// 不正な日付は null。
export function yyyymmddToUtcIso(input: string): string | null {
  const d = parseYyyymmdd(input);
  if (!d) return null;
  // parseYyyymmdd はローカルタイムの Date を返すので、年月日を取り出して
  // UTC 深夜として再構築する。
  const utc = new Date(
    Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()),
  );
  return utc.toISOString();
}
