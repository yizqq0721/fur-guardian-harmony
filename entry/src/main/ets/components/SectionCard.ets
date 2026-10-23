import { FG } from '../common/Theme';

/** 白底 + 1px 发丝边框的卡片；标题可选，内容通过尾随闭包传入 */
@Component
export struct SectionCard {
  title: string = '';
  padding: number = FG.s4;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title !== '') {
        Text(this.title)
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .letterSpacing(-0.2)
          .margin({ bottom: 12 })
          .width('100%')
      }
      this.content()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(this.padding)
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
  }
}
