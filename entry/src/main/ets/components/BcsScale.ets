import { FG } from '../common/Theme';
import { BcsGroup, bcsGroup } from '../utils/Constants';

function silhouette(n: number): string {
  const belly: number = 4 + (n - 1) * 1.35;
  const waist: number = 13 - (n - 1) * 1.1;
  const body: number = 29 + n * 0.2;
  return `M3 15 C3 6 9 3 17 3 C25 3 ${body} 6 ${body} 15 ` +
    `M${waist} 15 C${waist} ${15 + belly} ${29 - belly * 0.4} ${15 + belly} ${29 - belly * 0.4} 15`;
}

@Component
export struct BcsScale {
  @Prop value: number = 5;
  onChange: (value: number) => void = () => {
  };
  private scores: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  private group(): BcsGroup {
    return bcsGroup(this.value);
  }

  private descColor(): string {
    if (this.value >= 8) {
      return FG.danger;
    }
    if (this.value === 4 || this.value === 5) {
      return FG.accent;
    }
    return FG.warning;
  }

  build() {
    Column() {
      Row() {
        ForEach(this.scores, (n: number, index: number) => {
          Column() {
            Shape() {
              Path()
                .commands(silhouette(n))
                .stroke(this.value === n ? FG.accent : FG.inkMuted)
                .strokeWidth(1.5)
                .strokeLineJoin(LineJoinStyle.Round)
                .fill(Color.Transparent)
            }
            .width(26)
            .height(16)
            .viewPort({ x: 0, y: 0, width: 34, height: 20 })

            Text(`${n}`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.value === n ? FG.accent : FG.inkMuted)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.value === n ? FG.accentSoft : FG.surface)
          .border({
            width: { right: index < 8 ? 1 : 0 },
            color: FG.line
          })
          .onClick(() => {
            this.onChange(n);
          })
        }, (n: number) => `${n}`)
      }
      .width('100%')
      .border({ width: 1, color: FG.line })
      .borderRadius(FG.radius)
      .clip(true)

      Row() {
        Text('偏瘦')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
        Blank()
        Text('理想')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
        Blank()
        Text('偏胖')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
      }
      .width('100%')
      .margin({ top: 8 })

      Text(`${this.value} 分 · ${this.group().label} —— ${this.group().desc}`)
        .fontSize(FG.textBody)
        .lineHeight(21)
        .fontColor(this.descColor())
        .margin({ top: 12 })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
