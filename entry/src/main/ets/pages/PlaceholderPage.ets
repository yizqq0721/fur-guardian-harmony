import { FG } from '../common/Theme';
import { Nav } from '../utils/Nav';

@Component
export struct PlaceholderPage {
  title: string = '';
  description: string = '';
  showBack: boolean = false;

  build() {
    Scroll() {
      Column() {
        if (this.showBack) {
          Row() {
            Text('←')
              .fontSize(16)
              .fontColor(FG.inkMuted)
            Text('返回')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ left: 4 })
          }
          .height(36)
          .margin({ bottom: 8 })
          .onClick(() => {
            Nav.pop();
          })
        }

        Text(this.title)
          .fontFamily(FG.serif)
          .fontSize(FG.textH2)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)

        Text(this.description)
          .fontSize(13)
          .lineHeight(22)
          .fontColor(FG.inkMuted)
          .margin({ top: 8, bottom: 24 })

        Column() {
          Text('页面迁移中')
            .fontFamily(FG.serif)
            .fontSize(FG.textH3)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.ink)
          Text('该页面将在后续阶段按原 Vue 界面逐页还原。')
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(FG.s4)
        .backgroundColor(FG.surface)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 20, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .backgroundColor(Color.Transparent)
  }
}
