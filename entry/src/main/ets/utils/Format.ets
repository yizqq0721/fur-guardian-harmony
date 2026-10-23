function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function todayText(): string {
  const now: Date = new Date();
  return `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`;
}

export function dateText(value?: string | null): string {
  if (!value) {
    return '—';
  }
  const date: Date = new Date(value.replace(' ', 'T'));
  if (isNaN(date.getTime())) {
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function dateTimeText(value?: string | null): string {
  if (!value) {
    return '—';
  }
  const date: Date = new Date(value.replace(' ', 'T'));
  if (isNaN(date.getTime())) {
    return value;
  }
  return `${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function timeShort(value?: string | null): string {
  return value && value.length >= 5 ? value.substring(0, 5) : (value ?? '');
}

/** 生日 → 「N 月龄」/「N 岁 M 个月」，与 Vue utils/format.ts 一致 */
export function ageText(birthday?: string | null): string {
  if (!birthday) {
    return '年龄未知';
  }
  const birth: Date = new Date(birthday.replace(' ', 'T'));
  if (isNaN(birth.getTime())) {
    return '年龄未知';
  }
  const now: Date = new Date();
  let months: number = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
  if (now.getDate() < birth.getDate()) {
    months -= 1;
  }
  if (months < 0) {
    months = 0;
  }
  if (months < 12) {
    return `${months} 月龄`;
  }
  const years: number = Math.floor(months / 12);
  const rest: number = months % 12;
  return rest > 0 ? `${years} 岁 ${rest} 个月` : `${years} 岁`;
}

export function fromNow(value?: string | null): string {
  if (!value) {
    return '—';
  }
  const date: Date = new Date(value.replace(' ', 'T'));
  if (isNaN(date.getTime())) {
    return '—';
  }
  const mins: number = Math.floor((Date.now() - date.getTime()) / 60000);
  if (mins < 1) {
    return '刚刚';
  }
  if (mins < 60) {
    return `${mins} 分钟前`;
  }
  const hours: number = Math.floor(mins / 60);
  if (hours < 24) {
    return `${hours} 小时前`;
  }
  const days: number = Math.floor(hours / 24);
  if (days < 7) {
    return `${days} 天前`;
  }
  return dateText(value);
}

export function addDays(date: Date, days: number): Date {
  const result: Date = new Date(date.getTime());
  result.setDate(result.getDate() + days);
  return result;
}

export function ymd(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** 短日期：5月12日（与前端 M月D日 一致） */
export function monthDayText(value?: string | null): string {
  if (!value) {
    return '—';
  }
  const date: Date = new Date(value.replace(' ', 'T'));
  if (isNaN(date.getTime())) {
    if (value.length >= 10) {
      return `${Number(value.substring(5, 7))}月${Number(value.substring(8, 10))}日`;
    }
    return value;
  }
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

export function hhmm(date: Date): string {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)} m`;
  }
  return `${(meters / 1000).toFixed(1)} km`;
}
