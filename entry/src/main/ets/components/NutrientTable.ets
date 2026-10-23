import { FG } from '../common/Theme';
import { NutrientValidation } from '../models/Types';
import { Icon } from './Icon';

@Component
export struct NutrientTable {
  rows: NutrientValidation[] = [];

  private requiredText(r: NutrientValidation): string {
    if (r.requiredMin != null && r.requiredMax != null) {
      return `≥${r.requiredMin} 且 ≤${r.requiredMax}${r.unit}`;
    }
    if (r.requiredMin != null) {
      return `≥ ${r.requiredMin}${r.unit}`;
    }
    if (r.requiredMax != null) {
      return `≤ ${r.requiredMax}${r.unit}`;
    }
    return '无要求';
  }

  build() {
    Column() {
      Row() {
        Text('营养素')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .layoutWeight(1)
        Text('标注值')
          .fontSize(11)
          .fontColor(FG.inkMuted)
          .width(72)
          .textAlign(TextAlign.End)
        Text('国标要求')
          .fontSize(11)
          .fontColor(FG.inkMuted)
          .width(92)
          .textAlign(TextAlign.End)
        Text('判定')
          .fontSize(11)
          .fontColor(FG.inkMuted)
          .width(64)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
      .border({ width: { bottom: 1 }, color: FG.line })

      ForEach(this.rows, (r: NutrientValidation) => {
        Row() {
          Text(r.nutrient)
            .fontSize(13)
            .fontColor(FG.ink)
            .layoutWeight(1)
          Text(`${r.actualValue}${r.unit}`)
            .fontSize(13)
            .fontColor(FG.ink)
            .width(72)
            .textAlign(TextAlign.End)
          Text(this.requiredText(r))
            .fontSize(13)
            .fontColor(FG.inkMuted)
            .width(92)
            .textAlign(TextAlign.End)
          Row() {
            Icon({
              name: r.passed ? 'circle-check' : 'circle-x',
              iconSize: 11,
              color: r.passed ? FG.accent : FG.danger
            })
            Text(r.passed ? '达标' : '不达标')
              .fontSize(11)
              .fontColor(r.passed ? FG.accent : FG.danger)
              .margin({ left: 2 })
          }
          .height(20)
          .padding({ left: 5, right: 5 })
          .borderRadius(6)
          .backgroundColor(r.passed ? FG.accentSoft : FG.dangerSoft)
          .width(60)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .border({ width: { bottom: 1 }, color: FG.line })
      }, (r: NutrientValidation) => `${r.nutrient}-${r.actualValue}`)
    }
    .width('100%')
  }
}
