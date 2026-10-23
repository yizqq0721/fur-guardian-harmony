import { FG } from '../common/Theme';
import { Icon } from './Icon';

export interface TimelineStep {
  label: string;
  formula?: string;
  result?: string;
  why?: string;
  whyTitle?: string;
}

@Component
export struct StepTimeline {
  steps: TimelineStep[] = [];
  @State expanded: number = -1;

  @Builder
  stepItem(step: TimelineStep, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (index < this.steps.length - 1) {
        Column()
          .width(1)
          .height('100%')
          .backgroundColor(FG.line)
          .position({ x: 11, y: index === 0 ? 24 : 0 })
      }

      Row() {
        Column() {
          Text(`${index + 1 < 10 ? '0' : ''}${index + 1}`)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
        }
        .width(24)
        .height(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(FG.surface)
        .borderRadius(12)
        .border({ width: 1, color: FG.line })
        .zIndex(1)

        Column() {
          Row() {
            Column() {
              Text(step.label)
                .fontSize(FG.textBody)
                .fontColor(FG.ink)
                .width('100%')
              if (step.formula) {
                Text(step.formula)
                  .fontSize(12)
                  .fontColor(FG.inkMuted)
                  .margin({ top: 2 })
                  .width('100%')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (step.result) {
              Text(step.result)
                .fontSize(FG.textLead)
                .fontWeight(FontWeight.Bold)
                .fontColor(FG.ink)
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          if (step.why) {
            Row() {
              Text(this.expanded === index ? (step.whyTitle ?? '为什么这样算？') : (step.whyTitle ?? '为什么这样算？'))
                .fontSize(FG.textLabel)
                .fontColor(FG.accent)
              Icon({
                name: this.expanded === index ? 'chevron-up' : 'chevron-down',
                iconSize: 12,
                color: FG.accent
              })
                .margin({ left: 2 })
            }
            .margin({ top: 6 })
            .onClick(() => {
              this.expanded = this.expanded === index ? -1 : index;
            })

            if (this.expanded === index) {
              Text(step.why)
                .fontSize(FG.textLabel)
                .lineHeight(20)
                .fontColor(FG.inkMuted)
                .margin({ top: 6 })
                .width('100%')
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 10, bottom: 10 })
    }
    .width('100%')
  }

  build() {
    Column() {
      ForEach(this.steps, (step: TimelineStep, index: number) => {
        this.stepItem(step, index)
      }, (step: TimelineStep, index: number) => `${index}-${step.label}`)
    }
    .width('100%')
  }
}
