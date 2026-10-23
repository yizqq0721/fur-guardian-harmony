import { TipApi } from '../api/Api';
import { FG } from '../common/Theme';
import { Tip } from '../models/Types';
import { showToast } from '../utils/Http';
import { SseFrame, sseRequest } from '../utils/Sse';
import { DisclaimerBar } from './DisclaimerBar';
import { EmptyState } from './EmptyState';
import { Icon } from './Icon';
import { SourceChip } from './SourceChip';

@Component
export struct TipCard {
  @Prop @Watch('onPetChange') petId: number = 0;
  @State private tip: Tip | null = null;
  @State private loading: boolean = false;
  @State private regenerating: boolean = false;
  @State private feedbackBusy: boolean = false;
  @State private feedback: number = -1;
  @State private bump: string = '';
  private bumpTimer: number = -1;

  aboutToAppear(): void {
    this.fetchTip();
  }

  aboutToDisappear(): void {
    if (this.bumpTimer >= 0) {
      clearTimeout(this.bumpTimer);
    }
  }

  onPetChange(): void {
    this.tip = null;
    this.fetchTip();
  }

  private async fetchTip(): Promise<void> {
    if (this.petId <= 0) {
      return;
    }
    this.loading = true;
    try {
      this.tip = await TipApi.today(this.petId);
      this.feedback = this.tip?.feedback ?? -1;
    } catch (err) {
      this.tip = null;
    } finally {
      this.loading = false;
    }
  }

  private async regenerate(): Promise<void> {
    if (this.loading || this.regenerating) {
      return;
    }
    this.regenerating = true;
    let streamError: string = '';
    try {
      await sseRequest(TipApi.streamPath(this.petId, false, true), (frame: SseFrame) => {
        if (frame.event === 'error') {
          streamError = frame.data;
        }
      });
      if (streamError.length > 0) {
        showToast(streamError);
      }
      await this.fetchTip();
    } catch (err) {
      showToast('生成失败，请稍后重试');
    } finally {
      this.regenerating = false;
    }
  }

  private async sendFeedback(value: number): Promise<void> {
    const tip: Tip | null = this.tip;
    if (tip === null || this.feedbackBusy) {
      return;
    }
    const previous: number = this.feedback;
    this.feedback = value;
    this.feedbackBusy = true;
    this.bump = value === 1 ? 'like' : 'dislike';
    if (this.bumpTimer >= 0) {
      clearTimeout(this.bumpTimer);
    }
    this.bumpTimer = setTimeout(() => {
      this.bump = '';
      this.bumpTimer = -1;
    }, 420);

    try {
      await TipApi.feedback(tip.id, value === 1 ? 'like' : 'dislike');
    } catch (err) {
      this.feedback = previous;
    } finally {
      this.feedbackBusy = false;
    }
  }

  @Builder
  skeleton() {
    Column() {
      Row().width('92%').height(12).borderRadius(4).backgroundColor(FG.line)
      Row().width('78%').height(12).borderRadius(4).backgroundColor(FG.line).margin({ top: 8 })
      Row().width('56%').height(12).borderRadius(4).backgroundColor(FG.line).margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  feedbackButton(label: string, icon: string, active: boolean, bump: boolean, value: number) {
    Row() {
      Icon({
        name: icon,
        iconSize: 20,
        color: active ? FG.accent : FG.ink,
        weight: 1.5
      })
        .scale({ x: bump ? 1.28 : 1, y: bump ? 1.28 : 1 })
        .animation({ duration: 180, curve: Curve.EaseOut })
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(active ? FG.accent : FG.ink)
        .margin({ left: 4 })
    }
    .height(44)
    .padding({ left: 8, right: 8 })
    .borderRadius(6)
    .onClick(() => {
      if (value === 0) {
        this.regenerate();
      } else {
        this.sendFeedback(value);
      }
    })
  }

  build() {
    Column() {
      if (this.loading || this.regenerating) {
        Row() {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(FG.accent)
          Text('正在结合知识库生成新的 Tip…')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ bottom: 12 })
        this.skeleton()
      } else if (this.tip !== null) {
        Text(this.tip.content)
          .fontSize(FG.textBody)
          .lineHeight(24)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ bottom: 12 })

        Row() {
          if (this.tip.sourceName) {
            SourceChip({ label: `来源 · ${this.tip.sourceName}` })
          }
          Blank()
          Row() {
            this.feedbackButton('换一条', 'refresh-cw', false, false, 0)
            this.feedbackButton('有用', 'thumbs-up', this.feedback === 1, this.bump === 'like', 1)
            this.feedbackButton('没帮助', 'thumbs-down', this.feedback === 0, this.bump === 'dislike', 0)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        EmptyState({ description: '暂无今日 Tip' })
      }

      DisclaimerBar()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
