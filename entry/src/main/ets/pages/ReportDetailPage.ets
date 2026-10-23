import { ReportApi } from '../api/Api';
import { FG } from '../common/Theme';
import { DisclaimerBar } from '../components/DisclaimerBar';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { Icon } from '../components/Icon';
import { MarkdownView } from '../components/MarkdownView';
import { SeverityDot } from '../components/SeverityDot';
import { WeightChart } from '../components/WeightChart';
import { Pet, ReportConclusion, ReportRule, WeeklyReport, WeightLog } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { dateText } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

/** 周报详情：AI 小结 + 关键指标 + 体重曲线 + 规则结论 */
@Component
export struct ReportDetailPage {
  reportId: number = 0;
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @State private loading: boolean = true;
  @State private polishing: boolean = false;
  @State private report: WeeklyReport | null = null;
  @State private conclusion: ReportConclusion | null = null;
  @State private summary: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      await PetStore.fetchPets();
    } catch (err) {
      console.warn(`fetch pets failed: ${JSON.stringify(err)}`);
    }
    if (this.reportId <= 0) {
      this.loading = false;
      return;
    }
    try {
      const report: WeeklyReport = await ReportApi.detail(this.reportId);
      this.report = report;
      try {
        const conclusion: ReportConclusion = await ReportApi.conclusions(this.reportId);
        this.conclusion = conclusion;
      } catch (err) {
        if (report.ruleConclusions !== undefined && report.ruleConclusions.length > 0) {
          try {
            this.conclusion = JSON.parse(report.ruleConclusions) as ReportConclusion;
          } catch (parseErr) {
            this.conclusion = null;
          }
        }
      }
      this.summary = report.llmSummary !== undefined && report.llmSummary !== null ? report.llmSummary : '';
      if (this.summary.length === 0) {
        this.generateSummary(false);
      }
    } catch (err) {
      console.warn(`load report failed: ${JSON.stringify(err)}`);
      this.report = null;
    } finally {
      this.loading = false;
    }
  }

  private async generateSummary(force: boolean): Promise<void> {
    this.polishing = true;
    try {
      const updated: WeeklyReport = await ReportApi.polish(this.reportId, force);
      if (updated !== null && updated !== undefined && updated.llmSummary !== undefined && updated.llmSummary !== null &&
        updated.llmSummary.length > 0) {
        this.summary = updated.llmSummary;
      } else {
        const content: string = await ReportApi.summary(this.reportId);
        this.summary = content !== null && content !== undefined ? content : '';
      }
      if (force) {
        showToast('AI 小结已重新生成');
      }
    } catch (err) {
      if (force) {
        showToast('重新生成失败，请稍后重试');
      }
    } finally {
      this.polishing = false;
    }
  }

  private petName(): string {
    if (this.report !== null) {
      const found: Pet | undefined = this.pets.find((pet: Pet) => pet.id === (this.report as WeeklyReport).petId);
      if (found !== undefined) {
        return found.name;
      }
      return `宠物 #${(this.report as WeeklyReport).petId}`;
    }
    const current: Pet | undefined = this.pets.find((pet: Pet) => pet.id === this.currentPetId);
    return current !== undefined ? current.name : '宠物';
  }

  private petBreed(): string {
    if (this.report !== null) {
      const found: Pet | undefined = this.pets.find((pet: Pet) => pet.id === (this.report as WeeklyReport).petId);
      if (found !== undefined && found.breed !== undefined) {
        return found.breed;
      }
    }
    return '';
  }

  private parseDay(value: string): Date {
    const parts: string[] = value.substring(0, 10).split('-');
    if (parts.length < 3) {
      return new Date();
    }
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  private weekNo(): string {
    if (this.report === null) {
      return '—';
    }
    const date: Date = this.parseDay((this.report as WeeklyReport).weekStart);
    const yearStart: Date = new Date(date.getFullYear(), 0, 1);
    const doy: number = Math.floor((date.getTime() - yearStart.getTime()) / 86400000) + 1;
    return `${Math.ceil(doy / 7)}`;
  }

  private monthDayDate(value?: string): string {
    if (value === undefined || value.length < 10) {
      return '—';
    }
    const date: Date = this.parseDay(value);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private kickerRange(): string {
    if (this.report === null) {
      return '';
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    return `${this.monthDayDate(report.weekStart)} – ${this.monthDayDate(report.weekEnd)}`;
  }

  private metaLine(): string {
    if (this.report === null) {
      return '';
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    const bits: string[] = [];
    if (this.petBreed().length > 0) {
      bits.push(this.petBreed());
    }
    bits.push(`周期 ${dateText(report.weekStart)} 至 ${dateText(report.weekEnd)}`);
    if (report.createdAt !== undefined) {
      bits.push(`生成于 ${dateText(report.createdAt)}`);
    }
    return bits.join(' · ');
  }

  private weightValue(): string {
    if (this.report === null) {
      return '—';
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    const start: string = report.weightStartKg !== undefined ? `${report.weightStartKg}` : '—';
    const end: string = report.weightEndKg !== undefined ? `${report.weightEndKg}` : '—';
    return `${start} → ${end}`;
  }

  private weightCaption(): string {
    if (this.report === null) {
      return '本周体重';
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    if (report.weightStartKg === undefined || report.weightEndKg === undefined) {
      return '本周体重';
    }
    const diff: number = report.weightEndKg - report.weightStartKg;
    const sign: string = diff > 0 ? '+' : diff < 0 ? '−' : '';
    return `较上周 ${sign}${Math.abs(diff).toFixed(1)} kg`;
  }

  private bcsValue(): string {
    if (this.report === null) {
      return '—';
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    const start: string = report.bcsStart !== undefined ? `${report.bcsStart}` : '—';
    const end: string = report.bcsEnd !== undefined ? `${report.bcsEnd}` : '—';
    return `${start} → ${end}`;
  }

  private complianceValue(): string {
    if (this.report === null) {
      return '—';
    }
    const value: number | undefined = (this.report as WeeklyReport).feedingCompliance;
    return value === undefined || value === null ? '—' : `${(value * 100).toFixed(0)}`;
  }

  private snackValue(): string {
    if (this.report === null) {
      return '0';
    }
    const value: number | undefined = (this.report as WeeklyReport).snackOverLimit;
    return value !== undefined && value !== null ? `${value}` : '0';
  }

  private snackCaption(): string {
    if (this.report === null) {
      return '本周超额度次数';
    }
    const value: number | undefined = (this.report as WeeklyReport).snackOverLimit;
    return value !== undefined && value !== null && value > 0 ? '本周超额度次数' : '本周未超零食额度';
  }

  private weightLogs(): WeightLog[] {
    if (this.report === null) {
      return [];
    }
    const report: WeeklyReport = this.report as WeeklyReport;
    if (report.weightStartKg === undefined || report.weightEndKg === undefined) {
      return [];
    }
    const first: WeightLog = {
      id: 1,
      petId: report.petId,
      weightKg: report.weightStartKg,
      recordedAt: report.weekStart
    };
    const second: WeightLog = {
      id: 2,
      petId: report.petId,
      weightKg: report.weightEndKg,
      recordedAt: report.weekEnd
    };
    return [first, second];
  }

  private rules(): ReportRule[] {
    return this.conclusion !== null ? ((this.conclusion as ReportConclusion).rules ?? []) : [];
  }

  private triggeredRules(): ReportRule[] {
    return this.rules().filter((rule: ReportRule) => rule.triggered);
  }

  private otherRules(): ReportRule[] {
    return this.rules().filter((rule: ReportRule) => !rule.triggered);
  }

  private hasDanger(): boolean {
    return this.triggeredRules().some((rule: ReportRule) => rule.severity === 'danger');
  }

  private hasWarn(): boolean {
    return this.triggeredRules().some((rule: ReportRule) => rule.severity === 'warn');
  }

  private aggregateColor(): string {
    if (this.hasDanger()) {
      return FG.danger;
    }
    if (this.hasWarn()) {
      return FG.warning;
    }
    return FG.line;
  }

  @Builder
  SectionTitle(label: string, icon: string) {
    Row() {
      Icon({ name: icon, iconSize: 18, color: FG.ink })
        .margin({ right: 6 })
      Text(label)
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 10 })
  }

  @Builder
  ReportMetric(label: string, value: string, unit: string, caption: string) {
    Column() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
      Row() {
        Text(value)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
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
      .width('100%')
      .margin({ top: 4 })
      if (caption.length > 0) {
        Text(caption)
          .fontSize(11)
          .lineHeight(15)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 3 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RuleItem(rule: ReportRule, muted: boolean) {
    Row() {
      Column() {
        SeverityDot({ level: muted ? 'info' : rule.severity })
      }
      .padding({ top: 5 })

      Column() {
        Text(rule.ruleName)
          .fontSize(FG.textBody)
          .fontWeight(muted ? FontWeight.Normal : FontWeight.Bold)
          .fontColor(muted ? FG.inkMuted : FG.ink)
          .width('100%')
        if (!muted && rule.suggestion.length > 0) {
          Text(rule.suggestion)
            .fontSize(FG.textBody)
            .lineHeight(23)
            .fontColor('#3A3E44')
            .width('100%')
            .margin({ top: 4 })
        }
        if (rule.detail.length > 0) {
          Text(rule.detail)
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  Letter() {
    Column() {
      Column() {
        Row() {
          Icon({ name: 'arrow-left', iconSize: 16, color: FG.inkMuted })
          Text('返回周报列表')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 6 })
        }
        .height(32)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          Nav.pop();
        })
        .margin({ bottom: 14 })

        Text(`第 ${this.weekNo()} 周 · ${this.kickerRange()}`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.4)
          .width('100%')

        Text(`${this.petName()}的本周小结`)
          .fontFamily(FG.serif)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .letterSpacing(-0.4)
          .lineHeight(34)
          .width('100%')
          .margin({ top: 8 })

        Text(this.metaLine())
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 8 })

        Column() {
          FgButton({
            label: '重新生成',
            variant: 'primary',
            icon: 'refresh-cw',
            fillWidth: true,
            loading: this.polishing,
            onTap: () => {
              this.generateSummary(true);
            }
          })
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 20 })
      .border({ width: { bottom: 1 }, color: FG.line })

      Column() {
        Text('AI 本周小结')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ bottom: 10 })

        if (this.polishing && this.summary.length === 0) {
          Row() {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(FG.accent)
            Text('AI 正在根据本周数据生成小结…')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .margin({ left: 8 })
          }
          .width('100%')
        } else if (this.summary.length > 0) {
          MarkdownView({ content: this.summary })
        } else {
          Text('暂时没能生成 AI 小结，可点击上方「重新生成」再试；规则结论不受影响。')
            .fontSize(FG.textBody)
            .lineHeight(23)
            .fontColor(FG.inkMuted)
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 20, bottom: 20 })
      .border({ width: { bottom: 1 }, color: FG.line })

      Column() {
        Row() {
          this.ReportMetric('体重', this.weightValue(), 'kg', this.weightCaption())
          Column()
            .width(1)
            .height(52)
            .backgroundColor(FG.line)
            .margin({ left: 8, right: 8 })
          this.ReportMetric('BCS', this.bcsValue(), '/9', '体况评分')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column()
          .width('100%')
          .height(1)
          .backgroundColor(FG.line)
          .margin({ top: 12, bottom: 12 })

        Row() {
          this.ReportMetric('打卡率', this.complianceValue(), '%', '喂养合规度')
          Column()
            .width(1)
            .height(52)
            .backgroundColor(FG.line)
            .margin({ left: 8, right: 8 })
          this.ReportMetric('零食超标', this.snackValue(), '次', this.snackCaption())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(FG.s4)
      .backgroundColor(FG.surface)
      .border({ width: 1, color: FG.line })
      .borderRadius(FG.radius)
      .margin({ top: 20 })

      Column() {
        this.SectionTitle('本周体重', 'activity')
        Column() {
          if (this.weightLogs().length > 1) {
            WeightChart({ logs: this.weightLogs(), chartHeight: 220 })
          } else {
            Text('本周仅有单点体重记录，暂不绘制曲线。')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .width('100%')
          }
        }
        .width('100%')
        .padding(FG.s4)
        .backgroundColor(FG.surface)
        .border({ width: 1, color: FG.line })
        .borderRadius(FG.radius)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24 })

      Column() {
        this.SectionTitle('触发的规则', 'list-checks')

        if (this.conclusion === null) {
          EmptyState({ variant: 'default', description: '暂无规则结论' })
        } else {
          Text(`共 ${this.rules().length} 项判定，${this.triggeredRules().length} 项触发`)
            .fontSize(FG.textLabel)
            .fontColor(this.triggeredRules().length > 0 ? FG.warning : FG.inkMuted)
            .width('100%')
            .margin({ bottom: 4 })

          ForEach(this.triggeredRules(), (rule: ReportRule) => {
            this.RuleItem(rule, false)
          }, (rule: ReportRule) => `rule-${rule.ruleId}`)

          if (this.otherRules().length > 0) {
            Text('未触发的规则')
              .fontSize(FG.textLabel)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(1)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ top: 16, bottom: 2 })

            ForEach(this.otherRules(), (rule: ReportRule) => {
              this.RuleItem(rule, true)
            }, (rule: ReportRule) => `rule-off-${rule.ruleId}`)
          }

          if (this.conclusion !== null && (this.conclusion as ReportConclusion).summary.length > 0) {
            Text((this.conclusion as ReportConclusion).summary)
              .fontSize(FG.textBody)
              .lineHeight(25)
              .fontColor(FG.ink)
              .width('100%')
              .padding({ left: 12, top: 10, bottom: 10 })
              .border({ width: { left: 2 }, color: this.aggregateColor() })
              .margin({ top: 16 })
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24 })

      Text('以上结论由规则引擎生成，AI 仅负责措辞。')
        .fontSize(FG.textLabel)
        .lineHeight(19)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 24 })

      DisclaimerBar()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column() {
        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 80 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.report !== null) {
          this.Letter()
        } else {
          Column() {
            EmptyState({ variant: 'warning', description: '周报加载失败，请返回重试' })
            FgButton({
              label: '返回周报列表',
              variant: 'secondary',
              onTap: () => {
                Nav.pop();
              }
            })
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 48 })
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
  }
}
