import { Reminder, ReminderType } from '../models/Types';

const DATED_TYPES: string[] = ['VACCINE', 'DEWORM'];

/** 疫苗、驱虫是「某一天去做」的事件，按用户指定日期提醒一次 */
export function isDatedType(type: ReminderType): boolean {
  return DATED_TYPES.includes(type);
}

export function isDatedReminder(reminder: Reminder): boolean {
  return reminder.repeatRule === 'ONCE' && reminder.remindDate !== undefined && reminder.remindDate.length > 0;
}

function anchorDate(value?: string): Date | null {
  if (!value) {
    return null;
  }
  const date: Date = new Date(value.replace(' ', 'T'));
  return isNaN(date.getTime()) ? null : date;
}

/** 与 Vue utils/reminder.ts 的 isReminderDueOn 保持一致 */
export function isReminderDueOn(reminder: Reminder, date: string): boolean {
  const rule: string = (reminder.repeatRule ?? '').trim().toUpperCase();
  const target: Date = new Date(date.replace(' ', 'T'));
  if (isNaN(target.getTime())) {
    return true;
  }
  const targetDay: string = date.substring(0, 10);

  if (rule === 'ONCE') {
    return !reminder.remindDate || reminder.remindDate.substring(0, 10) === targetDay;
  }
  if (rule === 'WEEKLY') {
    const days: number[] = (reminder.repeatDays ?? '')
      .split(',')
      .map((part: string) => Number(part.trim()))
      .filter((day: number) => Number.isInteger(day) && day >= 1 && day <= 7);
    if (days.length === 0) {
      return true;
    }
    const weekday: number = target.getDay() === 0 ? 7 : target.getDay();
    return days.includes(weekday);
  }
  if (rule === 'MONTHLY' || rule === 'YEARLY') {
    const anchor: Date | null = anchorDate(reminder.remindDate !== undefined ? reminder.remindDate : reminder.createdAt);
    if (anchor === null) {
      return true;
    }
    if (rule === 'YEARLY' && anchor.getMonth() !== target.getMonth()) {
      return false;
    }
    const daysInMonth: number = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
    return target.getDate() === Math.min(anchor.getDate(), daysInMonth);
  }
  return true;
}
