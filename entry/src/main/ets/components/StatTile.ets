import { FG } from '../common/Theme';
import { Icon } from './Icon';

@Component
export struct StatTile {
  label: string = '';
  value: string = '';
  unit: string = '';
  caption: string = '';
  showDelta: boolean = false;
  delta: number = 0;
  deltaUnit: string = '';
  deltaLabel: string = '';
  deltaDirection: string = 'neutral';
  hero: boolean = false;

  private deltaColor(): string {
    if (!this.showDelta || this.delta === 0 || this.deltaDirection === 'neutral') {
      return FG.inkMuted;
    }
    const good: boolean = this.deltaDirection === 'up-is-good' ? this.delta >= 0 : this.delta <= 0;
    return good ? FG.accent : FG.warning;
  }

  private deltaText(): string {
    const sign: string = this.delta > 0 ? '+' : '';
    return `${sign}${Math.abs(this.delta)}${this.deltaUnit}`;
  }

  build() {
    Column() {
      Text(this.label)
        .fontSize(FG.textLabel)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(0.5)
        .fontColor(FG.inkMuted)
        .width('100%')

      Row() {
        Text(this.value)
          .fontSize(this.hero ? FG.textValueHero : FG.textValue)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .letterSpacing(-0.3)
        if (this.unit !== '') {
          Text(this.unit)
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .margin({ left: 4, bottom: 4 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
      .margin({ top: 6 })

      if (this.caption !== '') {
        Text(this.caption)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 6 })
          .width('100%')
      }

      if (this.showDelta) {
        Row() {
          if (this.delta !== 0) {
            Icon({ name: this.delta > 0 ? 'trending-up' : 'trending-down', iconSize: 14, color: this.deltaColor() })
          }
          Text(this.deltaText())
            .fontSize(FG.textLabel)
            .fontColor(this.deltaColor())
            .margin({ left: this.delta !== 0 ? 4 : 0 })
          if (this.deltaLabel !== '') {
            Text(this.deltaLabel)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ left: 4 })
          }
        }
        .margin({ top: 6 })
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
