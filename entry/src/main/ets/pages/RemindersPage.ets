import { FeedingApi, FoodApi, ReminderApi, WeatherApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { FgInput } from '../components/FgInput';
import { FgSelect } from '../components/FgSelect';
import { Icon } from '../components/Icon';
import { StatTile } from '../components/StatTile';
import {
  Food,
  Pet,
  Reminder,
  ReminderForm,
  ReminderLog,
  ReminderType,
  RepeatRule,
  SelectOption,
  WeatherToday,
  PageResult
} from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { reminderTypeLabel, REMINDER_TYPE_OPTIONS, repeatRuleLabel, REPEAT_RULE_OPTIONS } from '../utils/Constants';
import { addDays, monthDayText, todayText, ymd } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { isDatedReminder, isDatedType, isReminderDueOn } from '../utils/Reminder';

class TimelineGroup {
  key: string = '';
  label: string = '';
  rows: Reminder[] = [];

  constructor(key: string, label: string, rows: Reminder[]) {
    this.key = key;
    this.label = label;
    this.rows = rows;
  }
}

class WeekBar {
  date: string = '';
  weekday: string = '';
  count: number = 0;

  constructor(date: string, weekday: string, count: number) {
    this.date = date;
    this.weekday = weekday;
    this.count = count;
  }
}

const WEEKDAY_CN: string[] = ['日', '一', '二', '三', '四', '五', '六'];
const WEEKDAY_NUM: string[] = ['一', '二', '三', '四', '五', '六', '日'];

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

/** 提醒管理：每日时间轴、打卡、本周完成率与提醒编辑 */
@Component
export struct RemindersPage {
  initialPetId: number = 0;
  showBack: boolean = false;
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @StorageLink('fg_location') @Watch('onLocationChange') location: string = '';
  @State private reminders: Reminder[] = [];
  @State private logs: ReminderLog[] = [];
  @State private optimistic: number[] = [];
  @State private loading: boolean = true;
  @State private loadError: boolean = false;
  @State private filterPetId: number = 0;
  @State private onlyToday: boolean = false;
  @State private viewDate: string = todayText();
  @State private weather: WeatherToday | null = null;
  @State private weatherLoading: boolean = false;
  @State private weatherUnavailable: boolean = false;
  @State private drawerVisible: boolean = false;
  @State private editingId: number = 0;
  @State private saving: boolean = false;
  @State private formPetId: number = 0;
  @State private formTitle: string = '';
  @State private formType: ReminderType = 'FEED';
  @State private formRemindTime: string = '08:00';
  @State private formRelativeMin: number = 30;
  @State private formRemindDate: string = todayText();
  @State private formRepeatRule: RepeatRule = 'DAILY';
  @State private timeMode: string = 'fixed';
  @State private weekdayChecks: string[] = [];
  @State private feedOpen: boolean = false;
  @State private feedRow: Reminder | null = null;
  @State private feedFoods: Food[] = [];
  @State private feedFoodId: number = 0;
  @State private feedGrams: number = 60;
  @State private feedFoodLoading: boolean = false;
  @State private feedSaving: boolean = false;

  aboutToAppear(): void {
    if (this.initialPetId > 0) {
      this.filterPetId = this.initialPetId;
    }
    this.load();
  }

  private async load(): Promise<void> {
    try {
      await PetStore.fetchPets();
    } catch (err) {
      console.warn(`fetch pets failed: ${JSON.stringify(err)}`);
    }
    const current: Pet | undefined = PetStore.currentPet();
    this.formPetId = this.filterPetId > 0 ? this.filterPetId : (current !== undefined ? current.id : 0);
    await this.fetchReminders();
    await this.fetchLogs();
    this.maybeLoadWeather(false);
  }

  private onLocationChange(): void {
    this.weather = null;
    this.weatherUnavailable = false;
    this.maybeLoadWeather(false);
  }

  private parseDay(value: string): Date {
    const text: string = value.substring(0, 10);
    const parts: string[] = text.split('-');
    if (parts.length < 3) {
      return new Date();
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  private weekdayOf(date: string): string {
    const day: number = this.parseDay(date).getDay();
    return WEEKDAY_CN[day];
  }

  private isTodayView(): boolean {
    return this.viewDate === todayText();
  }

  private viewLabel(): string {
    const date: Date = this.parseDay(this.viewDate);
    return `${date.getMonth() + 1}月${date.getDate()}日 周${this.weekdayOf(this.viewDate)}`;
  }

  private canPrev(): boolean {
    const windowStart: string = ymd(addDays(new Date(), -6));
    return this.viewDate > windowStart;
  }

  private canNext(): boolean {
    return !this.isTodayView();
  }

  private shiftDate(delta: number): void {
    const target: Date = addDays(this.parseDay(this.viewDate), delta);
    const targetText: string = ymd(target);
    const windowStart: string = ymd(addDays(new Date(), -6));
    if (targetText < windowStart || targetText > todayText()) {
      return;
    }
    this.viewDate = targetText;
    this.maybeLoadWeather(false);
  }

  private async fetchReminders(): Promise<void> {
    this.loading = true;
    this.loadError = false;
    try {
      this.reminders = await ReminderApi.list(this.filterPetId > 0 ? this.filterPetId : undefined);
    } catch (err) {
      this.reminders = [];
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  private async fetchLogs(): Promise<void> {
    const petIds: number[] = this.filterPetId > 0 ? [this.filterPetId] : this.pets.map((pet: Pet) => pet.id);
    if (petIds.length === 0) {
      this.logs = [];
      return;
    }
    const startDate: string = ymd(addDays(new Date(), -6));
    const endDate: string = todayText();
    let all: ReminderLog[] = [];
    for (let i = 0; i < petIds.length; i++) {
      try {
        const rows: ReminderLog[] = await ReminderApi.logs(petIds[i], startDate, endDate, true);
        all = all.concat(rows);
      } catch (err) {
        console.warn(`fetch reminder logs failed: ${JSON.stringify(err)}`);
      }
    }
    this.logs = all;
  }

  private selectPet(id: number): void {
    if (this.filterPetId === id) {
      return;
    }
    this.filterPetId = id;
    this.fetchReminders();
    this.fetchLogs();
    this.maybeLoadWeather(false);
  }

  private petName(id: number): string {
    const found: Pet | undefined = this.pets.find((pet: Pet) => pet.id === id);
    return found !== undefined ? found.name : `#${id}`;
  }

  private scopeLabel(): string {
    if (this.filterPetId > 0) {
      return `${this.petName(this.filterPetId)} · 提醒`;
    }
    return `全部宠物 · ${this.pets.length} 只`;
  }

  private dueOn(date: string): Reminder[] {
    return this.reminders.filter((reminder: Reminder) => isReminderDueOn(reminder, date));
  }

  private doneIdsFor(date: string): number[] {
    const ids: number[] = [];
    this.logs.forEach((log: ReminderLog) => {
      if (log.doneDate !== undefined && log.doneDate.substring(0, 10) === date && !ids.includes(log.reminderId)) {
        ids.push(log.reminderId);
      }
    });
    if (date === todayText()) {
      this.optimistic.forEach((id: number) => {
        if (!ids.includes(id)) {
          ids.push(id);
        }
      });
    }
    return ids;
  }

  private isDone(id: number): boolean {
    return this.doneIdsFor(this.viewDate).includes(id);
  }

  private filteredRows(): Reminder[] {
    const due: Reminder[] = this.dueOn(this.viewDate);
    if (!this.onlyToday) {
      return due;
    }
    const doneToday: number[] = this.doneIdsFor(todayText());
    return due.filter((reminder: Reminder) => !doneToday.includes(reminder.id));
  }

  private timelineGroups(): TimelineGroup[] {
    const list: Reminder[] = this.filteredRows();
    const timed: Reminder[] = list
      .filter((reminder: Reminder) => reminder.remindTime !== undefined && reminder.remindTime.length > 0)
      .sort((a: Reminder, b: Reminder) => (a.remindTime as string).localeCompare(b.remindTime as string));
    const relative: Reminder[] = list.filter((reminder: Reminder) => {
      return (reminder.remindTime === undefined || reminder.remindTime.length === 0) &&
        reminder.relativeMin !== undefined && reminder.relativeMin !== null;
    });
    const unset: Reminder[] = list.filter((reminder: Reminder) => {
      return (reminder.remindTime === undefined || reminder.remindTime.length === 0) &&
        (reminder.relativeMin === undefined || reminder.relativeMin === null);
    });
    const groups: TimelineGroup[] = [];
    if (timed.length > 0) {
      groups.push(new TimelineGroup('timed', '定时提醒', timed));
    }
    if (relative.length > 0) {
      groups.push(new TimelineGroup('relative', '餐后提醒', relative));
    }
    if (unset.length > 0) {
      groups.push(new TimelineGroup('unset', '未设置时间', unset));
    }
    return groups;
  }

  private shownRows(): Reminder[] {
    const rows: Reminder[] = [];
    this.timelineGroups().forEach((group: TimelineGroup) => {
      group.rows.forEach((reminder: Reminder) => {
        rows.push(reminder);
      });
    });
    return rows;
  }

  private shownTotal(): number {
    return this.shownRows().length;
  }

  private shownDone(): number {
    return this.shownRows().filter((reminder: Reminder) => this.isDone(reminder.id)).length;
  }

  private dueToday(): Reminder[] {
    return this.dueOn(todayText());
  }

  private doneToday(): number {
    const ids: number[] = this.doneIdsFor(todayText());
    return this.dueToday().filter((reminder: Reminder) => ids.includes(reminder.id)).length;
  }

  private todayRate(): string {
    const total: number = this.dueToday().length;
    if (total === 0) {
      return '0';
    }
    return `${Math.round((this.doneToday() / total) * 100)}`;
  }

  private upcomingEvents(): Reminder[] {
    const today: string = todayText();
    return this.reminders
      .filter((reminder: Reminder) => {
        return isDatedReminder(reminder) && reminder.remindDate !== undefined &&
          reminder.remindDate.substring(0, 10) > today;
      })
      .sort((a: Reminder, b: Reminder) => (a.remindDate as string).localeCompare(b.remindDate as string))
      .slice(0, 5);
  }

  private daysUntil(date?: string): string {
    if (date === undefined) {
      return '';
    }
    const target: Date = this.parseDay(date);
    const now: Date = this.parseDay(todayText());
    const days: number = Math.round((target.getTime() - now.getTime()) / 86400000);
    return days === 1 ? '明天' : `${days} 天后`;
  }

  private uniqueDoneCount(date: string): number {
    const ids: number[] = [];
    this.logs.forEach((log: ReminderLog) => {
      if (log.doneDate !== undefined && log.doneDate.substring(0, 10) === date && !ids.includes(log.reminderId)) {
        ids.push(log.reminderId);
      }
    });
    if (date === todayText()) {
      this.optimistic.forEach((id: number) => {
        if (!ids.includes(id)) {
          ids.push(id);
        }
      });
    }
    return ids.length;
  }

  private weekDays(): WeekBar[] {
    const result: WeekBar[] = [];
    for (let i = 0; i < 7; i++) {
      const date: string = ymd(addDays(new Date(), i - 6));
      result.push(new WeekBar(date, this.weekdayOf(date), this.uniqueDoneCount(date)));
    }
    return result;
  }

  private weekTotal(): number {
    let total: number = 0;
    this.weekDays().forEach((day: WeekBar) => {
      total += day.count;
    });
    return total;
  }

  private activeDays(): number {
    return this.weekDays().filter((day: WeekBar) => day.count > 0).length;
  }

  private weekMax(): number {
    let max: number = 1;
    this.weekDays().forEach((day: WeekBar) => {
      if (day.count > max) {
        max = day.count;
      }
    });
    return max;
  }

  private streak(): number {
    let count: number = 0;
    for (let i = 0; i < 7; i++) {
      const date: string = ymd(addDays(new Date(), -i));
      if (this.uniqueDoneCount(date) > 0) {
        count += 1;
      } else if (i > 0) {
        break;
      }
    }
    return count;
  }

  private barHeight(count: number): number {
    if (count === 0) {
      return 2;
    }
    return Math.max(8, Math.round((count / this.weekMax()) * 48));
  }

  private rowTime(row: Reminder): string {
    if (row.remindTime !== undefined && row.remindTime.length > 0) {
      return row.remindTime.substring(0, 5);
    }
    return row.relativeMin !== undefined && row.relativeMin !== null ? '餐后' : '—';
  }

  private typeLabel(row: Reminder): string {
    const label: string = reminderTypeLabel(row.reminderType);
    return label.length > 0 ? label : row.reminderType;
  }

  private repeatLabel(row: Reminder): string {
    const label: string = repeatRuleLabel(row.repeatRule);
    return label.length > 0 ? label : '每天';
  }

  private repeatDaysText(days: string): string {
    const labels: string[] = days.split(',').map((part: string) => {
      const index: number = Number(part.trim()) - 1;
      return index >= 0 && index < 7 ? WEEKDAY_NUM[index] : part.trim();
    });
    return labels.join('、');
  }

  private iconFor(type: ReminderType): string {
    if (type === 'FEED') {
      return 'utensils-crossed';
    }
    if (type === 'WALK') {
      return 'footprints';
    }
    if (type === 'WATER') {
      return 'droplet';
    }
    if (type === 'GROOMING') {
      return 'brush';
    }
    if (type === 'DEWORM') {
      return 'pill';
    }
    if (type === 'VACCINE') {
      return 'syringe';
    }
    if (type === 'BATH') {
      return 'bath';
    }
    return 'bell';
  }

  private knowledgePrompt(type: ReminderType): string {
    if (type === 'VACCINE') {
      return '犬猫疫苗接种前后需要注意什么？';
    }
    if (type === 'DEWORM') {
      return '犬猫应该多久驱虫一次？驱虫前后要注意什么？';
    }
    return '';
  }

  private hasRowLinks(row: Reminder): boolean {
    if (row.reminderType === 'WALK') {
      return true;
    }
    if (this.knowledgePrompt(row.reminderType).length > 0) {
      return true;
    }
    return row.reminderType === 'FEED' && this.isTodayView() && !this.isDone(row.id);
  }

  private weatherIconName(data: WeatherToday): string {
    const text: string = `${data.text}${data.textNight ?? ''}`;
    if (text.includes('雷')) {
      return 'cloud-lightning';
    }
    if (text.includes('雪')) {
      return 'snowflake';
    }
    if (text.includes('雨')) {
      return 'cloud-rain';
    }
    if (text.includes('晴')) {
      return 'sun';
    }
    if (text.includes('风') || Number(data.windScale) >= 5) {
      return 'wind';
    }
    return 'cloud-sun';
  }

  private weatherColor(): string {
    const level: string = this.weather !== null ? this.weather.level : 'CAUTION';
    if (level === 'GOOD') {
      return FG.success;
    }
    if (level === 'AVOID') {
      return FG.danger;
    }
    return FG.warning;
  }

  private weatherSoft(): string {
    const level: string = this.weather !== null ? this.weather.level : 'CAUTION';
    if (level === 'GOOD') {
      return FG.accentSoft;
    }
    if (level === 'AVOID') {
      return FG.dangerSoft;
    }
    return FG.warningSoft;
  }

  private weatherActionText(): string {
    return this.weatherUnavailable ? '重新获取天气' : '查看今日天气';
  }

  private weatherEmptyText(): string {
    if (this.location.length === 0) {
      return '还没获取当前位置，获取后就能查看当日遛弯天气。';
    }
    if (this.weatherUnavailable) {
      return '按当前位置暂时取不到天气，请稍后重试或重新定位。';
    }
    return '正在等待今日天气。';
  }

  private weatherLine(data: WeatherToday): string {
    let text: string = `${data.location} · ${data.text}`;
    if (data.textNight !== undefined && data.textNight.length > 0 && data.textNight !== data.text) {
      text += `转${data.textNight}`;
    }
    text += `  ${data.low}~${data.high}°C`;
    return text;
  }

  private async maybeLoadWeather(interactive: boolean): Promise<void> {
    if (!this.isTodayView() || this.weather !== null || this.weatherLoading) {
      return;
    }
    const hasWalk: boolean = this.reminders.some((reminder: Reminder) => {
      return reminder.reminderType === 'WALK' && isReminderDueOn(reminder, this.viewDate);
    });
    if (!hasWalk && !interactive) {
      return;
    }
    if (this.location.length === 0) {
      return;
    }
    this.weatherLoading = true;
    try {
      const data: WeatherToday | null = await WeatherApi.today();
      this.weather = data;
      this.weatherUnavailable = data === null;
    } catch (err) {
      this.weather = null;
      this.weatherUnavailable = true;
    } finally {
      this.weatherLoading = false;
    }
  }

  private goCalendar(): void {
    Nav.push('ReminderCalendar', this.filterPetId);
  }

  private goNearby(row: Reminder): void {
    Nav.push('Nearby', row.id);
  }

  private askKnowledge(row: Reminder): void {
    const prompt: string = this.knowledgePrompt(row.reminderType);
    if (prompt.length > 0) {
      Nav.push('Knowledge', prompt);
    }
  }

  private onToggle(row: Reminder): void {
    if (!this.isTodayView() || this.isDone(row.id)) {
      return;
    }
    if (row.reminderType === 'FEED') {
      this.openFeed(row);
      return;
    }
    this.checkin(row);
  }

  private async checkin(row: Reminder): Promise<void> {
    try {
      await ReminderApi.checkin(row.id, { doneDate: todayText() });
      if (!this.optimistic.includes(row.id)) {
        this.optimistic = this.optimistic.concat([row.id]);
      }
      showToast(`已完成「${row.title}」`);
      await this.fetchLogs();
    } catch (err) {
      console.warn(`checkin failed: ${JSON.stringify(err)}`);
    }
  }

  private openCreate(): void {
    this.editingId = 0;
    this.timeMode = 'fixed';
    this.weekdayChecks = [];
    const current: Pet | undefined = PetStore.currentPet();
    this.formPetId = this.filterPetId > 0 ? this.filterPetId : (current !== undefined ? current.id : 0);
    this.formTitle = '';
    this.formType = 'FEED';
    this.formRemindTime = '08:00';
    this.formRelativeMin = 30;
    this.formRemindDate = todayText();
    this.formRepeatRule = 'DAILY';
    this.drawerVisible = true;
  }

  private openEdit(row: Reminder): void {
    this.editingId = row.id;
    this.timeMode = row.relativeMin !== undefined && row.relativeMin !== null ? 'relative' : 'fixed';
    this.weekdayChecks = row.repeatDays !== undefined && row.repeatDays.length > 0 ? row.repeatDays.split(',') : [];
    this.formPetId = row.petId;
    this.formTitle = row.title;
    this.formType = row.reminderType;
    this.formRemindTime = row.remindTime !== undefined && row.remindTime.length >= 5 ? row.remindTime.substring(0, 5) : '08:00';
    this.formRelativeMin = row.relativeMin !== undefined && row.relativeMin !== null ? row.relativeMin : 30;
    this.formRemindDate = row.remindDate !== undefined && row.remindDate.length >= 10 ? row.remindDate.substring(0, 10) : todayText();
    this.formRepeatRule = row.repeatRule ?? 'DAILY';
    this.drawerVisible = true;
    if (row.reminderType === 'WALK') {
      this.maybeLoadWeather(false);
    }
  }

  private formIsEvent(): boolean {
    return isDatedType(this.formType);
  }

  private formIsDated(): boolean {
    return this.formIsEvent() || this.formRepeatRule === 'ONCE';
  }

  private onTypeChange(value: string): void {
    this.formType = value as ReminderType;
    if (this.formIsEvent()) {
      this.formRepeatRule = 'ONCE';
      this.timeMode = 'fixed';
    } else if (this.formRepeatRule === 'ONCE') {
      this.formRepeatRule = 'DAILY';
    }
    if (this.formType === 'WALK') {
      this.maybeLoadWeather(true);
    }
  }

  private petOptions(): SelectOption[] {
    return this.pets.map((pet: Pet) => {
      const option: SelectOption = { value: `${pet.id}`, label: pet.name };
      return option;
    });
  }

  private toggleWeekday(day: number): void {
    const key: string = `${day}`;
    if (this.weekdayChecks.includes(key)) {
      this.weekdayChecks = this.weekdayChecks.filter((item: string) => item !== key);
    } else {
      this.weekdayChecks = this.weekdayChecks.concat([key]);
    }
  }

  private isWeekdayChecked(day: number): boolean {
    return this.weekdayChecks.includes(`${day}`);
  }

  private openTimePicker(): void {
    const parts: string[] = this.formRemindTime.split(':');
    const selected: Date = new Date();
    selected.setHours(parts.length > 1 ? Number(parts[0]) : 8, parts.length > 1 ? Number(parts[1]) : 0, 0, 0);
    TimePickerDialog.show({
      selected: selected,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        this.formRemindTime = `${pad2(value.hour)}:${pad2(value.minute)}`;
      }
    });
  }

  private openDatePicker(): void {
    const now: Date = new Date();
    const start: Date = this.editingId > 0 ? new Date(2000, 0, 1) : new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const selected: Date = this.parseDay(this.formRemindDate);
    DatePickerDialog.show({
      start: start,
      end: new Date(2100, 11, 31),
      selected: isNaN(selected.getTime()) ? now : selected,
      onDateAccept: (value: Date) => {
        this.formRemindDate = ymd(value);
      }
    });
  }

  private async save(): Promise<void> {
    const title: string = this.formTitle.trim();
    if (title.length === 0) {
      showToast('请填写提醒标题');
      return;
    }
    if (this.formPetId <= 0) {
      showToast('请选择关联宠物');
      return;
    }
    if (this.formIsDated() && this.formRemindDate.length < 10) {
      showToast('请选择提醒日期');
      return;
    }
    this.saving = true;
    try {
      const form: ReminderForm = {
        petId: this.formPetId,
        title: title,
        reminderType: this.formType,
        repeatRule: this.formIsEvent() ? 'ONCE' : this.formRepeatRule
      };
      if (this.timeMode === 'fixed' || this.formIsEvent()) {
        form.remindTime = this.formRemindTime;
      }
      if (!this.formIsEvent() && this.timeMode === 'relative') {
        form.relativeMin = this.formRelativeMin;
      }
      if (this.formIsDated()) {
        form.remindDate = this.formRemindDate;
      }
      if (!this.formIsEvent() && this.formRepeatRule === 'WEEKLY' && this.weekdayChecks.length > 0) {
        form.repeatDays = this.weekdayChecks.join(',');
      }
      if (this.editingId > 0) {
        await ReminderApi.update(this.editingId, form);
      } else {
        await ReminderApi.create(form);
      }
      showToast('已保存');
      this.drawerVisible = false;
      await this.fetchReminders();
      await this.fetchLogs();
    } catch (err) {
      console.warn(`save reminder failed: ${JSON.stringify(err)}`);
    } finally {
      this.saving = false;
    }
  }

  private confirmRemove(row: Reminder): void {
    AlertDialog.show({
      title: '删除确认',
      message: `确定删除提醒「${row.title}」吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: FG.danger,
        action: () => {
          this.remove(row);
        }
      }
    });
  }

  private async remove(row: Reminder): Promise<void> {
    try {
      await ReminderApi.remove(row.id);
      showToast('已删除');
      await this.fetchReminders();
      await this.fetchLogs();
    } catch (err) {
      console.warn(`remove reminder failed: ${JSON.stringify(err)}`);
    }
  }

  private openFeed(row: Reminder): void {
    if (!this.isTodayView() || this.isDone(row.id)) {
      return;
    }
    this.feedRow = row;
    this.feedFoodId = 0;
    this.feedGrams = 60;
    this.feedOpen = true;
    this.feedFoods = [];
    this.loadFeedFoods();
  }

  private async loadFeedFoods(): Promise<void> {
    this.feedFoodLoading = true;
    try {
      const page: PageResult<Food> = await FoodApi.list({ page: 1, size: 100 });
      this.feedFoods = page.records;
    } catch (err) {
      this.feedFoods = [];
    } finally {
      this.feedFoodLoading = false;
    }
  }

  private feedPetScope(): string {
    if (this.feedRow === null) {
      return '';
    }
    const pet: Pet | undefined = this.pets.find((item: Pet) => item.id === (this.feedRow as Reminder).petId);
    if (pet === undefined) {
      return '';
    }
    return pet.species === 'cat' ? 'CAT' : 'DOG';
  }

  private feedPetLabel(): string {
    const scope: string = this.feedPetScope();
    if (scope === 'CAT') {
      return '猫咪';
    }
    if (scope === 'DOG') {
      return '狗狗';
    }
    return '宠物';
  }

  private feedFoodOptions(): Food[] {
    const scope: string = this.feedPetScope();
    if (scope.length === 0) {
      return this.feedFoods;
    }
    return this.feedFoods.filter((food: Food) => {
      return food.speciesScope === undefined || food.speciesScope === 'BOTH' || food.speciesScope === scope;
    });
  }

  private feedSelectOptions(): SelectOption[] {
    return this.feedFoodOptions().map((food: Food) => {
      const label: string = food.brand !== undefined && food.brand.length > 0 ? `${food.name} · ${food.brand}` : food.name;
      const option: SelectOption = { value: `${food.id}`, label: label };
      return option;
    });
  }

  private feedSelectedFood(): Food | null {
    const found: Food | undefined = this.feedFoodOptions().find((food: Food) => food.id === this.feedFoodId);
    return found !== undefined ? found : null;
  }

  private feedKcalText(): string {
    const food: Food | null = this.feedSelectedFood();
    if (food === null || food.labeledMeKcal === undefined || food.labeledMeKcal === null) {
      return '';
    }
    const kcal: number = Math.round((food.labeledMeKcal * this.feedGrams) / 100) / 10;
    return `按标注值约 ${kcal} kcal`;
  }

  private async saveFeedAndCheckin(): Promise<void> {
    const row: Reminder | null = this.feedRow;
    const food: Food | null = this.feedSelectedFood();
    if (row === null || food === null) {
      return;
    }
    this.feedSaving = true;
    try {
      await FeedingApi.create({
        petId: row.petId,
        foodId: food.id,
        grams: this.feedGrams,
        fedDate: todayText()
      });
    } catch (err) {
      this.feedSaving = false;
      return;
    }
    try {
      await ReminderApi.checkin(row.id, {
        doneDate: todayText(),
        note: `${food.name} ${this.feedGrams}g`.substring(0, 255)
      });
      if (!this.optimistic.includes(row.id)) {
        this.optimistic = this.optimistic.concat([row.id]);
      }
      showToast(`已记录 ${food.name} ${this.feedGrams}g，并完成「${row.title}」打卡`);
      this.feedOpen = false;
      await this.fetchLogs();
    } catch (err) {
      showToast('喂食已记录，但打卡没有完成，请直接点这一行的圆圈补打卡');
    } finally {
      this.feedSaving = false;
    }
  }

  private async checkinOnly(): Promise<void> {
    const row: Reminder | null = this.feedRow;
    if (row === null) {
      return;
    }
    this.feedSaving = true;
    try {
      await this.checkin(row);
      this.feedOpen = false;
    } finally {
      this.feedSaving = false;
    }
  }

  private rowMenu(row: Reminder): MenuElement[] {
    return [
      {
        value: '编辑',
        action: () => {
          this.openEdit(row);
        }
      },
      {
        value: '删除',
        action: () => {
          this.confirmRemove(row);
        }
      }
    ];
  }

  @Builder
  SquareButton(icon: string, disabled: boolean, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: !disabled }) {
      Icon({ name: icon, iconSize: 18, color: disabled ? FG.lineStrong : FG.inkMuted })
    }
    .width(36)
    .height(36)
    .padding(0)
    .borderRadius(FG.radius)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .enabled(!disabled)
    .onClick(() => {
      action();
    })
  }

  @Builder
  FilterChip(label: string, value: number) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontColor(this.filterPetId === value ? FG.accent : FG.inkMuted)
      .fontWeight(this.filterPetId === value ? FontWeight.Medium : FontWeight.Normal)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(17)
      .backgroundColor(this.filterPetId === value ? FG.accentSoft : FG.surface)
      .border({ width: 1, color: this.filterPetId === value ? FG.accent : FG.line })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectPet(value);
      })
  }

  @Builder
  Header() {
    Column() {
      if (this.showBack) {
        Row() {
          Icon({ name: 'arrow-left', iconSize: 16, color: FG.inkMuted })
          Text('返回')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 6 })
        }
        .height(32)
        .onClick(() => {
          Nav.pop();
        })
        .margin({ bottom: 10 })
      }

      Text(this.scopeLabel())
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.6)
        .width('100%')
        .margin({ bottom: 6 })

      Text('提醒管理')
        .fontFamily(FG.serif)
        .fontSize(FG.textH1)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.4)
        .width('100%')

      Text('把喂食、遛弯、护理排进一天的时间轴，完成一项就打一次卡。')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 8 })

      Row() {
        this.SquareButton('chevron-left', !this.canPrev(), () => {
          this.shiftDate(-1);
        })

        Row() {
          Text(this.viewLabel())
            .fontFamily(FG.serif)
            .fontSize(FG.textLead)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
          Text(this.isTodayView() ? '今天' : '回顾')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 6 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        this.SquareButton('chevron-right', !this.canNext(), () => {
          this.shiftDate(1);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })

      Row() {
        Row() {
          Icon({ name: 'flame', iconSize: 18, color: FG.warning })
          Text('连续')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 4 })
          Text(`${this.streak()}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
            .margin({ left: 4 })
          Text('天')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 2 })
        }
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ top: 8, bottom: 10 })

      Row() {
        Column() {
          FgButton({
            label: '查看待办日历',
            variant: 'secondary',
            icon: 'calendar-days',
            fillWidth: true,
            onTap: () => {
              this.goCalendar();
            }
          })
        }
        .layoutWeight(1)

        Column() {
          FgButton({
            label: '新建提醒',
            variant: 'primary',
            icon: 'plus',
            fillWidth: true,
            disabled: this.pets.length === 0,
            onTap: () => {
              this.openCreate();
            }
          })
        }
        .layoutWeight(1)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 16 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .margin({ bottom: 18 })
  }

  @Builder
  Toolbar() {
    Column() {
      Text('查看宠物')
        .fontSize(FG.textLabel)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(0.5)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.FilterChip('全部', 0)
        ForEach(this.pets, (pet: Pet) => {
          this.FilterChip(pet.name, pet.id)
        }, (pet: Pet) => `rem-pet-${pet.id}`)
      }
      .width('100%')

      Row() {
        Row() {
          if (this.onlyToday) {
            Icon({ name: 'check', iconSize: 13, color: FG.accent })
              .margin({ right: 4 })
          }
          Text('只看今日待办')
            .fontSize(FG.textLabel)
            .fontColor(this.onlyToday ? FG.accent : FG.inkMuted)
        }
        .height(32)
        .padding({ left: 10, right: 10 })
        .borderRadius(16)
        .backgroundColor(this.onlyToday ? FG.accentSoft : FG.surface)
        .border({ width: 1, color: this.onlyToday ? FG.accent : FG.line })
        .onClick(() => {
          this.onlyToday = !this.onlyToday;
        })
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 12 })
    .margin({ bottom: 14 })
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  TimelineRow(row: Reminder) {
    Row() {
      Column() {
        Text(this.rowTime(row))
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Bold)
          .fontColor(row.remindTime !== undefined ? FG.ink : FG.inkMuted)
          .width('100%')
          .textAlign(TextAlign.End)
      }
      .width(48)
      .padding({ right: 8, top: 3 })
      .alignItems(HorizontalAlign.End)

      Column() {
        Circle()
          .width(7)
          .height(7)
          .fill(this.isDone(row.id) ? FG.lineStrong : FG.accent)
      }
      .width(14)
      .padding({ top: 7 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Button({ type: ButtonType.Normal, stateEffect: !this.isDone(row.id) }) {
          if (this.isDone(row.id)) {
            Icon({ name: 'check', iconSize: 13, color: FG.surface })
          }
        }
        .width(22)
        .height(22)
        .padding(0)
        .borderRadius(11)
        .backgroundColor(this.isDone(row.id) ? FG.accent : Color.Transparent)
        .border({ width: 1, color: this.isDone(row.id) ? FG.accent : FG.lineStrong })
        .enabled(this.isTodayView() && !this.isDone(row.id))
        .onClick(() => {
          this.onToggle(row);
        })
      }
      .width(30)
      .padding({ top: 1 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Row() {
          Icon({
            name: this.iconFor(row.reminderType),
            iconSize: 18,
            color: this.isDone(row.id) ? FG.inkMuted : FG.accent
          })
            .margin({ right: 6 })
          Text(row.title)
            .fontSize(FG.textLead)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDone(row.id) ? FG.inkMuted : FG.ink)
            .decoration({
              type: this.isDone(row.id) ? TextDecorationType.LineThrough : TextDecorationType.None
            })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          Row() {
            Text(`${this.typeLabel(row)} · ${this.petName(row.petId)}`)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
          }
          .margin({ right: 6, top: 4 })

          if (isDatedReminder(row)) {
            Row() {
              FgChip({ label: `计划 ${monthDayText(row.remindDate)}`, tone: 'default' })
            }
            .margin({ right: 6, top: 4 })
          } else {
            Row() {
              FgChip({
                label: `${this.repeatLabel(row)}${row.repeatDays !== undefined && row.repeatDays.length > 0 ? `（${this.repeatDaysText(row.repeatDays)}）` : ''}`,
                tone: 'default'
              })
            }
            .margin({ right: 6, top: 4 })
          }

          if (row.relativeMin !== undefined && row.relativeMin !== null) {
            Row() {
              FgChip({ label: `饭后 ${row.relativeMin} 分钟`, tone: 'default' })
            }
            .margin({ right: 6, top: 4 })
          }
        }
        .width('100%')

        if (this.hasRowLinks(row)) {
          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            if (row.reminderType === 'FEED' && this.isTodayView() && !this.isDone(row.id)) {
              Row() {
                Icon({ name: 'utensils-crossed', iconSize: 13, color: FG.accent })
                Text('记录喂食')
                  .fontSize(FG.textLabel)
                  .fontColor(FG.accent)
                  .margin({ left: 3 })
              }
              .margin({ right: 12, top: 6 })
              .onClick(() => {
                this.openFeed(row);
              })
            }

            if (row.reminderType === 'WALK') {
              Row() {
                Icon({ name: 'map-pin', iconSize: 13, color: FG.accent })
                Text('找遛弯点')
                  .fontSize(FG.textLabel)
                  .fontColor(FG.accent)
                  .margin({ left: 3 })
              }
              .margin({ right: 12, top: 6 })
              .onClick(() => {
                this.goNearby(row);
              })

              if (this.isTodayView() && this.weather !== null) {
                Row() {
                  Icon({
                    name: this.weatherIconName(this.weather as WeatherToday),
                    iconSize: 13,
                    color: this.weatherColor()
                  })
                  Text(`${(this.weather as WeatherToday).low}~${(this.weather as WeatherToday).high}°C`)
                    .fontSize(FG.textLabel)
                    .fontColor(this.weatherColor())
                    .margin({ left: 3 })
                  Text((this.weather as WeatherToday).text)
                    .fontSize(FG.textLabel)
                    .fontColor(this.weatherColor())
                    .margin({ left: 4 })
                  Text((this.weather as WeatherToday).advice)
                    .fontSize(FG.textLabel)
                    .fontColor(this.weatherColor())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ left: 4 })
                    .constraintSize({ maxWidth: 150 })
                }
                .height(24)
                .padding({ left: 7, right: 7 })
                .borderRadius(6)
                .backgroundColor(this.weatherSoft())
                .margin({ right: 8, top: 6 })
                .alignItems(VerticalAlign.Center)
              } else if (this.isTodayView() && this.weatherLoading) {
                Text('正在获取今日天气…')
                  .fontSize(FG.textLabel)
                  .fontColor(FG.inkMuted)
                  .margin({ right: 8, top: 6 })
              } else if (this.isTodayView() && this.location.length > 0) {
                Row() {
                  Icon({ name: 'cloud-sun', iconSize: 13, color: FG.accent })
                  Text(this.weatherActionText())
                    .fontSize(FG.textLabel)
                    .fontColor(FG.accent)
                    .margin({ left: 3 })
                }
                .margin({ right: 12, top: 6 })
                .onClick(() => {
                  this.maybeLoadWeather(true);
                })
              } else if (this.isTodayView()) {
                Row() {
                  Icon({ name: 'map-pin', iconSize: 13, color: FG.accent })
                  Text('获取当前位置')
                    .fontSize(FG.textLabel)
                    .fontColor(FG.accent)
                    .margin({ left: 3 })
                }
                .margin({ right: 12, top: 6 })
                .onClick(() => {
                  Nav.push('UserProfile');
                })
              }
            }

            if (this.knowledgePrompt(row.reminderType).length > 0) {
              Row() {
                Icon({ name: 'arrow-up-right', iconSize: 13, color: FG.accent })
                Text('问一问')
                  .fontSize(FG.textLabel)
                  .fontColor(FG.accent)
                  .margin({ left: 3 })
              }
              .margin({ right: 12, top: 6 })
              .onClick(() => {
                this.askKnowledge(row);
              })
            }
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Icon({ name: 'more-horizontal', iconSize: 18, color: FG.inkMuted })
        }
        .width(32)
        .height(32)
        .padding(0)
        .borderRadius(16)
        .backgroundColor(Color.Transparent)
        .bindMenu(this.rowMenu(row))
      }
      .width(32)
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  MainCard() {
    Column() {
      Column() {
        Text('当日时间轴')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
        Text(`共 ${this.shownTotal()} 项 · 已完成 ${this.shownDone()} 项`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 12 })

      if (this.loadError) {
        Row() {
          Text('提醒列表加载失败，请检查网络后重试。')
            .fontSize(FG.textBody)
            .fontColor(FG.danger)
            .layoutWeight(1)
          Text('重新加载')
            .fontSize(FG.textBody)
            .fontColor(FG.danger)
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              this.fetchReminders();
              this.fetchLogs();
            })
        }
        .width('100%')
        .padding({ left: 12, top: 12, bottom: 12 })
        .border({ width: { left: 2 }, color: FG.danger })
      } else if (this.loading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(FG.accent)
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      } else {
        if (!this.isTodayView()) {
          Text(`正在回顾 ${this.viewLabel()} 的完成情况，打卡仅在今天有效。`)
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(FG.inkMuted)
            .width('100%')
            .padding({ left: 12, top: 10, bottom: 10 })
            .border({ width: { left: 2 }, color: FG.warning })
            .margin({ bottom: 8 })
        }

        if (this.shownTotal() === 0) {
          EmptyState({
            variant: 'default',
            description: this.reminders.length === 0
              ? '还没有提醒，点击「新建提醒」安排第一项'
              : this.onlyToday
                ? '今日待办已全部完成'
                : '这一天没有到期的提醒'
          })
        } else {
          ForEach(this.timelineGroups(), (group: TimelineGroup) => {
            Column() {
              Text(group.label)
                .fontSize(FG.textLabel)
                .fontWeight(FontWeight.Medium)
                .letterSpacing(1)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ bottom: 2 })

              ForEach(group.rows, (row: Reminder) => {
                this.TimelineRow(row)
              }, (row: Reminder) => `tl-${row.id}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 10 })
          }, (group: TimelineGroup) => `group-${group.key}`)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  UpcomingCard() {
    Column() {
      Text('接下来的日程')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .width('100%')
      Text('疫苗、驱虫按设定日期提醒一次')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .margin({ top: 4, bottom: 8 })
        .width('100%')

      ForEach(this.upcomingEvents(), (row: Reminder) => {
        Row() {
          Column() {
            Text(monthDayText(row.remindDate))
              .fontSize(FG.textBody)
              .fontWeight(FontWeight.Bold)
              .fontColor(FG.ink)
            Text(`周${this.weekdayOf(row.remindDate !== undefined ? row.remindDate.substring(0, 10) : '')}`)
              .fontSize(11)
              .fontColor(FG.inkMuted)
              .margin({ top: 2 })
          }
          .width(62)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text(row.title)
              .fontSize(FG.textBody)
              .fontWeight(FontWeight.Medium)
              .fontColor(FG.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(`${this.typeLabel(row)} · ${this.petName(row.petId)}${row.remindTime !== undefined ? ` · ${row.remindTime.substring(0, 5)}` : ''}`)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 3 })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          FgChip({ label: this.daysUntil(row.remindDate), tone: 'default' })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .border({ width: { bottom: 1 }, color: FG.line })
      }, (row: Reminder) => `up-${row.id}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 12 })
  }

  @Builder
  WeekBars() {
    Row() {
      ForEach(this.weekDays(), (day: WeekBar) => {
        Column() {
          Text(day.count > 0 ? `${day.count}` : '—')
            .fontSize(10)
            .fontColor(FG.inkMuted)
            .height(14)
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width(12)
              .height(48)
              .backgroundColor(day.date === this.viewDate ? FG.accentSoft : FG.paper)
              .borderRadius(2)
            Column()
              .width(12)
              .height(this.barHeight(day.count))
              .backgroundColor(day.count > 0 ? FG.accent : FG.line)
              .borderRadius(2)
          }
          .height(48)
          .width(12)
          Text(day.weekday)
            .fontSize(11)
            .fontColor(day.date === this.viewDate ? FG.accent : FG.inkMuted)
            .fontWeight(day.date === this.viewDate ? FontWeight.Bold : FontWeight.Normal)
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, (day: WeekBar) => `bar-${day.date}`)
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  StatsCard() {
    Column() {
      Text('本周完成率')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .width('100%')
        .margin({ bottom: 12 })

      StatTile({
        label: '今日完成',
        value: this.todayRate(),
        unit: '%',
        caption: `已打卡 ${this.doneToday()} 项 / 共 ${this.dueToday().length} 项`
      })

      Column()
        .width('100%')
        .height(1)
        .backgroundColor(FG.line)
        .margin({ top: 14, bottom: 14 })

      this.WeekBars()

      Text('柱高按当日已完成的提醒条目数，单位：项')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  OverviewCard() {
    Column() {
      Text('打卡概览')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .width('100%')
        .margin({ bottom: 6 })

      this.KvRow('近 7 天累计', `${this.weekTotal()} 项`)
      this.KvRow('有打卡的天数', `${this.activeDays()} 天`)
      this.KvRow('连续打卡', `${this.streak()} 天`)
      this.KvRow('提醒条目', `${this.reminders.length} 项`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 12 })
  }

  @Builder
  KvRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
      Blank()
      Text(value)
        .fontSize(FG.textBody)
        .fontWeight(FontWeight.Medium)
        .fontColor(FG.ink)
    }
    .width('100%')
    .height(40)
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(0.5)
      .fontColor(FG.inkMuted)
      .width('100%')
      .margin({ bottom: 6 })
  }

  @Builder
  PickerField(value: string, icon: string, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        Text(value)
          .fontSize(16)
          .fontColor(FG.ink)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Icon({ name: icon, iconSize: 16, color: FG.inkMuted })
      }
      .width('100%')
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .onClick(() => {
      action();
    })
  }

  @Builder
  WeekdayToggle(day: number) {
    Text(WEEKDAY_NUM[day - 1])
      .fontSize(FG.textLabel)
      .fontColor(this.isWeekdayChecked(day) ? FG.accent : FG.inkMuted)
      .fontWeight(this.isWeekdayChecked(day) ? FontWeight.Bold : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .width(38)
      .height(34)
      .borderRadius(FG.radius)
      .backgroundColor(this.isWeekdayChecked(day) ? FG.accentSoft : FG.surface)
      .border({ width: 1, color: this.isWeekdayChecked(day) ? FG.accent : FG.line })
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.toggleWeekday(day);
      })
  }

  @Builder
  WeatherPanel() {
    Column() {
      Row() {
        Icon({
          name: this.weather !== null ? this.weatherIconName(this.weather as WeatherToday) : 'cloud-sun',
          iconSize: 18,
          color: this.weather !== null ? this.weatherColor() : FG.inkMuted
        })
        Text('今日遛弯天气')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
          .margin({ left: 6 })
      }
      .width('100%')

      if (this.weather !== null) {
        Text(this.weatherLine(this.weather as WeatherToday))
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ top: 8 })
        Text(`${(this.weather as WeatherToday).windDirection ?? ''}风${(this.weather as WeatherToday).windScale ?? ''}级` +
          ((this.weather as WeatherToday).humidity ? ` · 湿度 ${(this.weather as WeatherToday).humidity}%` : ''))
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 4 })
        Text((this.weather as WeatherToday).advice)
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(this.weatherColor())
          .width('100%')
          .margin({ top: 6 })
        Text(`按当前位置「${this.location}」查询`)
          .fontSize(11)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 6 })
      } else if (this.weatherLoading) {
        Text('正在获取今日天气…')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 8 })
      } else {
        Text(this.weatherEmptyText())
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 8 })
        if (this.location.length === 0) {
          Text('去获取位置')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .margin({ top: 6 })
            .onClick(() => {
              Nav.push('UserProfile');
            })
        } else {
          Text('重新获取天气')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .margin({ top: 6 })
            .onClick(() => {
              this.maybeLoadWeather(true);
            })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(FG.radius)
    .backgroundColor(FG.paper)
    .border({ width: 1, color: FG.line })
    .margin({ bottom: 16 })
  }

  @Builder
  FormSheet() {
    Scroll() {
      Column() {
        Text(this.editingId > 0 ? '编辑提醒' : '新建提醒')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ bottom: 16 })

        FgInput({
          label: '提醒标题',
          value: this.formTitle,
          placeholder: '例如：早餐 / 晚间遛弯',
          maxLength: 30,
          onChange: (value: string) => {
            this.formTitle = value;
          }
        })
          .margin({ bottom: 14 })

        FgSelect({
          label: '类型',
          value: this.formType,
          options: REMINDER_TYPE_OPTIONS,
          onChange: (value: string) => {
            this.onTypeChange(value);
          }
        })
          .margin({ bottom: 14 })

        FgSelect({
          label: '关联宠物',
          value: this.formPetId > 0 ? `${this.formPetId}` : '',
          placeholder: '请选择宠物',
          options: this.petOptions(),
          onChange: (value: string) => {
            this.formPetId = Number(value);
          }
        })
          .margin({ bottom: 14 })

        if (!this.formIsEvent()) {
          this.FieldLabel('提醒方式')
          Row() {
            Text('固定时间')
              .fontSize(FG.textLabel)
              .fontColor(this.timeMode === 'fixed' ? FG.surface : FG.inkMuted)
              .textAlign(TextAlign.Center)
              .height(36)
              .layoutWeight(1)
              .borderRadius(6)
              .backgroundColor(this.timeMode === 'fixed' ? FG.accent : Color.Transparent)
              .onClick(() => {
                this.timeMode = 'fixed';
              })
            Text('相对时间（饭后）')
              .fontSize(FG.textLabel)
              .fontColor(this.timeMode === 'relative' ? FG.surface : FG.inkMuted)
              .textAlign(TextAlign.Center)
              .height(36)
              .layoutWeight(1)
              .borderRadius(6)
              .backgroundColor(this.timeMode === 'relative' ? FG.accent : Color.Transparent)
              .onClick(() => {
                this.timeMode = 'relative';
              })
          }
          .width('100%')
          .padding(2)
          .borderRadius(FG.radius)
          .backgroundColor(FG.paper)
          .border({ width: 1, color: FG.line })
          .margin({ bottom: 14 })
        }

        if (this.formIsEvent() || this.timeMode === 'fixed') {
          this.FieldLabel('提醒时间')
          this.PickerField(this.formRemindTime, 'clock', () => {
            this.openTimePicker();
          })
          Column()
            .width('100%')
            .height(14)
        }

        if (!this.formIsEvent() && this.timeMode === 'relative') {
          this.FieldLabel('饭后多少分钟')
          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text('−')
                .fontSize(18)
                .fontColor(FG.ink)
            }
            .width(40)
            .height(40)
            .padding(0)
            .borderRadius(FG.radius)
            .backgroundColor(FG.surface)
            .border({ width: 1, color: FG.line })
            .onClick(() => {
              this.formRelativeMin = Math.max(5, this.formRelativeMin - 5);
            })
            Text(`${this.formRelativeMin} 分钟`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(FG.ink)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text('+')
                .fontSize(18)
                .fontColor(FG.ink)
            }
            .width(40)
            .height(40)
            .padding(0)
            .borderRadius(FG.radius)
            .backgroundColor(FG.surface)
            .border({ width: 1, color: FG.line })
            .onClick(() => {
              this.formRelativeMin = Math.min(240, this.formRelativeMin + 5);
            })
          }
          .width('100%')
          .margin({ bottom: 6 })
          Text('如「饭后 30 分钟」遛狗，防胃扭转')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ bottom: 14 })
        }

        if (!this.formIsEvent()) {
          FgSelect({
            label: '重复规则',
            value: this.formRepeatRule,
            options: REPEAT_RULE_OPTIONS,
            onChange: (value: string) => {
              this.formRepeatRule = value as RepeatRule;
            }
          })
            .margin({ bottom: 14 })
        }

        if (!this.formIsEvent() && this.formRepeatRule === 'WEEKLY') {
          this.FieldLabel('重复日')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach([1, 2, 3, 4, 5, 6, 7], (day: number) => {
              this.WeekdayToggle(day)
            }, (day: number) => `weekday-${day}`)
          }
          .width('100%')
          .margin({ bottom: 8 })
        }

        if (this.formIsDated()) {
          this.FieldLabel('计划日期')
          this.PickerField(this.formRemindDate, 'calendar-days', () => {
            this.openDatePicker();
          })
          Text(this.formIsEvent()
            ? '疫苗、驱虫这类事件按日期提醒一次，不会周期重复'
            : '仅一次的提醒只在这一天出现')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ top: 6, bottom: 14 })
        }

        if (this.formType === 'WALK') {
          this.WeatherPanel()
        }

        Row() {
          Column() {
            FgButton({
              label: '取消',
              variant: 'secondary',
              fillWidth: true,
              onTap: () => {
                this.drawerVisible = false;
              }
            })
          }
          .layoutWeight(1)

          Column() {
            FgButton({
              label: '保存',
              variant: 'primary',
              fillWidth: true,
              loading: this.saving,
              onTap: () => {
                this.save();
              }
            })
          }
          .layoutWeight(1)
          .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 12, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  @Builder
  FeedSheet() {
    Scroll() {
      Column() {
        Text('记录这次喂食')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ bottom: 6 })

        Row() {
          Icon({ name: 'utensils-crossed', iconSize: 15, color: FG.inkMuted })
          Text(`${this.feedRow !== null ? (this.feedRow as Reminder).title : ''} · ${this.feedRow !== null ? this.petName((this.feedRow as Reminder).petId) : ''}`)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 5 })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ bottom: 14 })

        FgSelect({
          label: '从食品库选择',
          value: this.feedFoodId > 0 ? `${this.feedFoodId}` : '',
          placeholder: '搜索或选择食品',
          options: this.feedSelectOptions(),
          onChange: (value: string) => {
            this.feedFoodId = Number(value);
          }
        })

        if (!this.feedFoodLoading && this.feedFoodOptions().length === 0) {
          Row() {
            Text(`食品库还没有适合${this.feedPetLabel()}的食品。`)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
            Text('先去录入')
              .fontSize(FG.textLabel)
              .fontColor(FG.accent)
              .margin({ left: 4 })
              .onClick(() => {
                this.feedOpen = false;
                Nav.push('FoodForm');
              })
          }
          .width('100%')
          .margin({ top: 8 })
        }

        Column() {
          this.FieldLabel('实际吃了多少克')
          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text('−')
                .fontSize(18)
                .fontColor(FG.ink)
            }
            .width(40)
            .height(40)
            .padding(0)
            .borderRadius(FG.radius)
            .backgroundColor(FG.surface)
            .border({ width: 1, color: FG.line })
            .onClick(() => {
              this.feedGrams = Math.max(1, this.feedGrams - 5);
            })
            Text(`${this.feedGrams} g`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(FG.ink)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text('+')
                .fontSize(18)
                .fontColor(FG.ink)
            }
            .width(40)
            .height(40)
            .padding(0)
            .borderRadius(FG.radius)
            .backgroundColor(FG.surface)
            .border({ width: 1, color: FG.line })
            .onClick(() => {
              this.feedGrams = Math.min(2000, this.feedGrams + 5);
            })
          }
          .width('100%')

          if (this.feedKcalText().length > 0) {
            Text(this.feedKcalText())
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ top: 6 })
          }
        }
        .width('100%')
        .margin({ top: 14 })

        Row() {
          Column() {
            FgButton({
              label: '取消',
              variant: 'secondary',
              fillWidth: true,
              onTap: () => {
                this.feedOpen = false;
              }
            })
          }
          .layoutWeight(1)

          Column() {
            FgButton({
              label: '仅打卡',
              variant: 'secondary',
              fillWidth: true,
              loading: this.feedSaving,
              onTap: () => {
                this.checkinOnly();
              }
            })
          }
          .layoutWeight(1)
          .margin({ left: 8 })

          Column() {
            FgButton({
              label: '保存并打卡',
              variant: 'primary',
              fillWidth: true,
              loading: this.feedSaving,
              disabled: this.feedSelectedFood() === null,
              onTap: () => {
                this.saveFeedAndCheckin();
              }
            })
          }
          .layoutWeight(1)
          .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 12, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  build() {
    Scroll() {
      Column() {
        this.Header()

        if (this.pets.length === 0 && !this.loading) {
          Column() {
            EmptyState({ variant: 'pets', description: '请先创建宠物档案，再安排每日提醒' })
            FgButton({
              label: '去创建',
              variant: 'primary',
              onTap: () => {
                Nav.push('Onboarding');
              }
            })
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        } else {
          this.Toolbar()
          Column() {
            this.MainCard()
          }
          .width('100%')
          .bindSheet($$this.feedOpen, this.FeedSheet(), {
            height: 520,
            dragBar: true,
            backgroundColor: FG.surface,
            showClose: true
          })

          if (this.upcomingEvents().length > 0) {
            this.UpcomingCard()
          }

          this.StatsCard()
          this.OverviewCard()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .bindSheet($$this.drawerVisible, this.FormSheet(), {
      height: 720,
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: true
    })
  }
}
