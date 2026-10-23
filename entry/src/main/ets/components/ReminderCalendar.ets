import { FG } from '../common/Theme';
import { Reminder } from '../models/Types';
import { isDatedReminder } from '../utils/Reminder';
import { Icon } from './Icon';

class CalCell {
  key: string = '';
  day: number = 1;
  inMonth: boolean = true;
  isToday: boolean = false;
  isPast: boolean = false;
  events: Reminder[] = [];
}

const WEEKDAYS: string[] = ['一', '二', '三', '四', '五', '六', '日'];
const VISIBLE_EVENTS: number = 2;
const CELL_W: number = 82;
const CELL_H: number = 92;
const CELL_GAP: number = 6;
const INNER_W: number = (CELL_W + CELL_GAP) * 7;

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function ymd(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** 护理日历：疫苗、驱虫等按日期提醒的事项，按周一开始的月网格展示 */
@Component
export struct ReminderCalendar {
  @Prop reminders: Reminder[] = [];
  @State private anchorYear: number = new Date().getFullYear();
  @State private anchorMonth: number = new Date().getMonth();

  private monthLabel(): string {
    return `${this.anchorYear}年${this.anchorMonth + 1}月`;
  }

  private isCurrentMonth(): boolean {
    const now: Date = new Date();
    return now.getFullYear() === this.anchorYear && now.getMonth() === this.anchorMonth;
  }

  private monthEvents(): Reminder[] {
    return this.reminders.filter((reminder: Reminder) => {
      if (!isDatedReminder(reminder) || reminder.remindDate === undefined || reminder.remindDate === null) {
        return false;
      }
      const date: Date = new Date(reminder.remindDate.substring(0, 10).replace(' ', 'T'));
      if (isNaN(date.getTime())) {
        return false;
      }
      return date.getFullYear() === this.anchorYear && date.getMonth() === this.anchorMonth;
    });
  }

  private eventsOn(key: string): Reminder[] {
    const list: Reminder[] = this.monthEvents().filter((reminder: Reminder) => {
      return reminder.remindDate !== undefined && reminder.remindDate !== null &&
        reminder.remindDate.substring(0, 10) === key;
    });
    return list.sort((a: Reminder, b: Reminder) => {
      const at: string = a.remindTime !== undefined && a.remindTime !== null && a.remindTime.length > 0 ? a.remindTime : '99:99';
      const bt: string = b.remindTime !== undefined && b.remindTime !== null && b.remindTime.length > 0 ? b.remindTime : '99:99';
      return at.localeCompare(bt);
    });
  }

  private cells(): CalCell[] {
    const monthStart: Date = new Date(this.anchorYear, this.anchorMonth, 1);
    const leading: number = (monthStart.getDay() + 6) % 7;
    const daysInMonth: number = new Date(this.anchorYear, this.anchorMonth + 1, 0).getDate();
    const total: number = Math.ceil((leading + daysInMonth) / 7) * 7;
    const gridStart: Date = new Date(this.anchorYear, this.anchorMonth, 1 - leading);
    const now: Date = new Date();
    const today: string = ymd(now);
    const result: CalCell[] = [];

    for (let i = 0; i < total; i++) {
      const date: Date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i);
      const key: string = ymd(date);
      const cell: CalCell = new CalCell();
      cell.key = key;
      cell.day = date.getDate();
      cell.inMonth = date.getFullYear() === this.anchorYear && date.getMonth() === this.anchorMonth;
      cell.isToday = key === today;
      cell.isPast = key < today;
      cell.events = cell.inMonth ? this.eventsOn(key) : [];
      result.push(cell);
    }
    return result;
  }

  private rowCount(): number {
    return Math.ceil(this.cells().length / 7);
  }

  private shiftMonth(delta: number): void {
    let year: number = this.anchorYear;
    let month: number = this.anchorMonth + delta;
    if (month < 0) {
      month = 11;
      year -= 1;
    } else if (month > 11) {
      month = 0;
      year += 1;
    }
    this.anchorYear = year;
    this.anchorMonth = month;
  }

  private goCurrentMonth(): void {
    const now: Date = new Date();
    this.anchorYear = now.getFullYear();
    this.anchorMonth = now.getMonth();
  }

  private iconFor(type: string): string {
    if (type === 'VACCINE') {
      return 'syringe';
    }
    if (type === 'DEWORM') {
      return 'pill';
    }
    return 'bell';
  }

  private cellBg(cell: CalCell): string {
    if (!cell.inMonth) {
      return '#00000000';
    }
    if (cell.events.length > 0) {
      return cell.isPast ? FG.paper : FG.accentSoft;
    }
    return FG.surface;
  }

  private cellBorder(cell: CalCell): string {
    if (!cell.inMonth) {
      return '#00000000';
    }
    if (cell.events.length > 0) {
      return cell.isPast ? FG.lineStrong : FG.accent;
    }
    return FG.line;
  }

  private dayColor(cell: CalCell): string {
    if (!cell.inMonth) {
      return FG.lineStrong;
    }
    if (cell.isToday) {
      return FG.surface;
    }
    return FG.inkMuted;
  }

  @Builder
  NavButton(icon: string, delta: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Icon({ name: icon, iconSize: 18, color: FG.inkMuted })
    }
    .width(36)
    .height(36)
    .padding(0)
    .borderRadius(FG.radius)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .onClick(() => {
      this.shiftMonth(delta);
    })
  }

  @Builder
  EventChip(reminder: Reminder, muted: boolean) {
    Row() {
      Icon({
        name: this.iconFor(reminder.reminderType),
        iconSize: 11,
        color: muted ? FG.inkMuted : FG.accent
      })
        .margin({ right: 3 })
      Text(reminder.title)
        .fontSize(10)
        .fontColor(muted ? FG.inkMuted : FG.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(17)
    .padding({ left: 4, right: 3 })
    .backgroundColor(FG.surface)
    .borderRadius(2)
    .border({ width: { left: 2 }, color: muted ? FG.lineStrong : FG.accent })
  }

  @Builder
  Cell(cell: CalCell) {
    Column() {
      Row() {
        Text(`${cell.day}`)
          .fontSize(FG.textLabel)
          .fontColor(this.dayColor(cell))
          .fontWeight(cell.isToday ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(cell.isToday ? FG.accent : '#00000000')
        Blank()
      }
      .width('100%')

      if (cell.events.length > 0) {
        Column() {
          ForEach(cell.events.slice(0, VISIBLE_EVENTS), (reminder: Reminder) => {
            this.EventChip(reminder, cell.isPast)
          }, (reminder: Reminder) => `cal-${reminder.id}`)
        }
        .width('100%')
        .margin({ top: 2 })

        if (cell.events.length > VISIBLE_EVENTS) {
          Text(`+${cell.events.length - VISIBLE_EVENTS} 项`)
            .fontSize(10)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ top: 2, left: 4 })
        }
      }
    }
    .width(CELL_W)
    .height(CELL_H)
    .padding({ left: 6, right: 6, top: 6, bottom: 6 })
    .borderRadius(FG.radius)
    .backgroundColor(this.cellBg(cell))
    .border({ width: 1, color: this.cellBorder(cell) })
    .alignItems(HorizontalAlign.Start)
    .margin({ right: CELL_GAP, bottom: CELL_GAP })
  }

  build() {
    Column() {
      Column() {
        Text('护理日历')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
        Text('疫苗、驱虫等按日期提醒的事项')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        this.NavButton('chevron-left', -1)
        Text(this.monthLabel())
          .fontFamily(FG.serif)
          .fontSize(FG.textLead)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        this.NavButton('chevron-right', 1)
        if (!this.isCurrentMonth()) {
          Text('回到本月')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .height(36)
            .padding({ left: 10, right: 10 })
            .borderRadius(FG.radius)
            .border({ width: 1, color: FG.line })
            .margin({ left: 8 })
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.goCurrentMonth();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12, bottom: 12 })

      Scroll() {
        Column() {
          Row() {
            ForEach(WEEKDAYS, (label: string) => {
              Text(`周${label}`)
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
            }, (label: string) => `wd-${label}`)
          }
          .width('100%')
          .height(24)
          .margin({ bottom: 6 })

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.cells(), (cell: CalCell) => {
              this.Cell(cell)
            }, (cell: CalCell) => cell.key)
          }
          .width('100%')
        }
        .width(INNER_W)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(this.rowCount() * (CELL_H + CELL_GAP) + 30)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      if (this.monthEvents().length === 0) {
        Text('本月没有按日期安排的提醒，疫苗、驱虫可在「新建提醒」里选择计划日期。')
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }
}
