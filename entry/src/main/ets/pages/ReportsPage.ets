import { ReportApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { Pet, ReportConclusion, WeeklyReport } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { addDays, todayText, ymd } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

/** 周度健康报告：移动端卡片列表 + 生成指定周周报 */
@Component
export struct ReportsPage {
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @State private reports: WeeklyReport[] = [];
  @State private loading: boolean = true;
  @State private generateOpen: boolean = false;
  @State private generating: boolean = false;
  @State private weekStart: string = '';

  aboutToAppear(): void {
    this.weekStart = this.mondayOfThisWeek();
    this.load();
  }

  private mondayOfThisWeek(): string {
    const now: Date = new Date();
    const day: number = now.getDay();
    const delta: number = day === 0 ? -6 : 1 - day;
    return ymd(addDays(new Date(now.getFullYear(), now.getMonth(), now.getDate()), delta));
  }

  private currentPet(): Pet | undefined {
    return this.pets.find((pet: Pet) => pet.id === this.currentPetId);
  }

  private async load(): Promise<void> {
    try {
      await PetStore.fetchPets();
    } catch (err) {
      console.warn(`fetch pets failed: ${JSON.stringify(err)}`);
    }
    await this.fetchReports();
  }

  private async fetchReports(): Promise<void> {
    const pet: Pet | undefined = this.currentPet();
    if (pet === undefined) {
      this.reports = [];
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      this.reports = await ReportApi.list(pet.id);
    } catch (err) {
      this.reports = [];
    } finally {
      this.loading = false;
    }
  }

  private parseDay(value: string): Date {
    const parts: string[] = value.substring(0, 10).split('-');
    if (parts.length < 3) {
      return new Date();
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  private weekNo(start?: string): string {
    if (start === undefined || start.length < 10) {
      return '—';
    }
    const date: Date = this.parseDay(start);
    const yearStart: Date = new Date(date.getFullYear(), 0, 1);
    const doy: number = Math.floor((date.getTime() - yearStart.getTime()) / 86400000) + 1;
    return `${Math.ceil(doy / 7)}`;
  }

  private rangeText(start?: string, end?: string): string {
    if (start === undefined || end === undefined) {
      return '—';
    }
    const s: Date = this.parseDay(start);
    const e: Date = this.parseDay(end);
    return `${pad2(s.getMonth() + 1)}-${pad2(s.getDate())} ~ ${pad2(e.getMonth() + 1)}-${pad2(e.getDate())}`;
  }

  private signedPct(pct?: number): string {
    if (pct === undefined || pct === null) {
      return '—';
    }
    const sign: string = pct > 0 ? '+' : pct < 0 ? '−' : '';
    return `${sign}${Math.abs(pct).toFixed(1)}%`;
  }

  private isSignificant(pct?: number): boolean {
    return pct !== undefined && pct !== null && Math.abs(pct) > 3;
  }

  private weightRangeText(report: WeeklyReport): string {
    if (report.weightStartKg === undefined && report.weightEndKg === undefined) {
      return '—';
    }
    const start: string = report.weightStartKg !== undefined ? `${report.weightStartKg}` : '—';
    const end: string = report.weightEndKg !== undefined ? `${report.weightEndKg}` : '—';
    return `${start} → ${end} kg`;
  }

  private dash(value?: number): string {
    return value === undefined || value === null ? '—' : `${value}`;
  }

  private complianceText(value?: number): string {
    return value === undefined || value === null ? '—' : `${(value * 100).toFixed(0)}%`;
  }

  private triggeredCount(report: WeeklyReport): number | null {
    if (report.ruleConclusions === undefined || report.ruleConclusions.length === 0) {
      return null;
    }
    try {
      const conclusion: ReportConclusion = JSON.parse(report.ruleConclusions) as ReportConclusion;
      if (!Array.isArray(conclusion.rules)) {
        return null;
      }
      return conclusion.rules.filter((rule) => rule.triggered).length;
    } catch (err) {
      return null;
    }
  }

  private ruleCountText(report: WeeklyReport): string {
    const count: number | null = this.triggeredCount(report);
    return count === null ? '—' : `${count} 条`;
  }

  private statusLabel(status: string): string {
    if (status === 'generated') {
      return '已生成';
    }
    if (status === 'polished') {
      return '已润色';
    }
    if (status === 'generating') {
      return '生成中';
    }
    return status.length > 0 ? status : '—';
  }

  private statusTone(status: string): string {
    return status === 'generated' || status === 'polished' ? 'ok' : 'default';
  }

  private openReport(report: WeeklyReport): void {
    Nav.push('ReportDetail', report.id);
  }

  private openDatePicker(): void {
    const now: Date = new Date();
    const selected: Date = this.parseDay(this.weekStart);
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: now,
      selected: isNaN(selected.getTime()) ? now : selected,
      onDateAccept: (value: Date) => {
        this.weekStart = ymd(value);
      }
    });
  }

  private async generate(): Promise<void> {
    const pet: Pet | undefined = this.currentPet();
    if (pet === undefined) {
      return;
    }
    const start: Date = this.parseDay(this.weekStart);
    if (start.getDay() !== 1) {
      showToast('请选择周起始日（周一）');
      return;
    }
    if (this.weekStart > todayText()) {
      showToast('不能生成未来周次的周报');
      return;
    }
    this.generating = true;
    try {
      const report: WeeklyReport = await ReportApi.generate(pet.id, this.weekStart);
      showToast('周报已生成');
      this.generateOpen = false;
      await this.fetchReports();
      Nav.push('ReportDetail', report.id);
    } catch (err) {
      console.warn(`generate report failed: ${JSON.stringify(err)}`);
    } finally {
      this.generating = false;
    }
  }

  @Builder
  MetricCell(label: string, value: string, unit: string, sub: string, warn: boolean) {
    Column() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
      Row() {
        Text(value)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(warn ? FG.warning : FG.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (unit.length > 0) {
          Text(unit)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 2, bottom: 2 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 2 })
      .width('100%')
      if (sub.length > 0) {
        Text(sub)
          .fontSize(11)
          .lineHeight(15)
          .fontColor(FG.inkMuted)
          .margin({ top: 2 })
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4 })
  }

  @Builder
  ReportCard(report: WeeklyReport) {
    Column() {
      Row() {
        Column() {
          Text(`第 ${this.weekNo(report.weekStart)} 周`)
            .fontSize(FG.textLead)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
          Text(this.rangeText(report.weekStart, report.weekEnd))
            .fontSize(11)
            .fontColor(FG.inkMuted)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        FgChip({ label: this.statusLabel(report.status), tone: this.statusTone(report.status) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column() {
        Row() {
          this.MetricCell('体重变化', this.signedPct(report.weightChangePct), '', this.weightRangeText(report), this.isSignificant(report.weightChangePct))
          Column()
            .width(1)
            .height(44)
            .backgroundColor(FG.line)
            .margin({ left: 8, right: 8 })
          this.MetricCell('BCS 变化', `${this.dash(report.bcsStart)} → ${this.dash(report.bcsEnd)}`, '/9', '', false)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          this.MetricCell('触发规则数', this.ruleCountText(report), '', '规则引擎判定', false)
          Column()
            .width(1)
            .height(44)
            .backgroundColor(FG.line)
            .margin({ left: 8, right: 8 })
          this.MetricCell('喂养合规度', this.complianceText(report.feedingCompliance), '', '本周打卡完成度', false)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ top: 12 })
      .margin({ top: 12 })
      .border({ width: { top: 1 }, color: FG.line })

      Row() {
        Blank()
        Text('查看详情')
          .fontSize(FG.textLabel)
          .fontColor(FG.accent)
        Icon({ name: 'chevron-right', iconSize: 15, color: FG.accent })
          .margin({ left: 2 })
      }
      .width('100%')
      .padding({ top: 12 })
      .margin({ top: 12 })
      .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 12 })
    .onClick(() => {
      this.openReport(report);
    })
  }

  @Builder
  GenerateSheet() {
    Scroll() {
      Column() {
        Text('生成周报')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ bottom: 16 })

        Text('选择周起始日（周一）')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.5)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ bottom: 6 })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Text(this.weekStart)
              .fontSize(16)
              .fontColor(FG.ink)
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
            Icon({ name: 'calendar-days', iconSize: 16, color: FG.inkMuted })
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
          this.openDatePicker();
        })

        Text('按周汇总本周体重、体况与规则触发情况，生成后可查看详情')
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 8 })

        Row() {
          Column() {
            FgButton({
              label: '取消',
              variant: 'secondary',
              fillWidth: true,
              onTap: () => {
                this.generateOpen = false;
              }
            })
          }
          .layoutWeight(1)
          Column() {
            FgButton({
              label: '生成',
              variant: 'primary',
              fillWidth: true,
              loading: this.generating,
              onTap: () => {
                this.generate();
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
        PageHeader({
          title: '周度健康报告',
          breadcrumb: this.currentPet() !== undefined ? `${(this.currentPet() as Pet).name} · 周报` : '周度健康报告',
          description: '按周汇总体重、体况与规则触发情况，逐周留档可回溯。',
          showActions: true
        }) {
          FgButton({
            label: '生成本周周报',
            variant: 'primary',
            icon: 'plus',
            disabled: this.currentPet() === undefined,
            onTap: () => {
              this.generateOpen = true;
            }
          })
        }

        if (this.pets.length === 0 && !this.loading) {
          EmptyState({ variant: 'pets', description: '请先创建宠物档案，再生成周报' })
        } else if (this.loading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 64 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.reports.length === 0) {
          EmptyState({ variant: 'default', description: '暂无周报，点击上方「生成本周周报」' })
        } else {
          ForEach(this.reports, (report: WeeklyReport) => {
            this.ReportCard(report)
          }, (report: WeeklyReport) => `report-${report.id}`)
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
    .bindSheet($$this.generateOpen, this.GenerateSheet(), {
      height: 360,
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: true
    })
  }
}
