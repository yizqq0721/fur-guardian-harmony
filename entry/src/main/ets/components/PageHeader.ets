import { FG } from '../common/Theme';
import { Icon } from './Icon';

@Component
export struct PageHeader {
  title: string = '';
  description: string = '';
  breadcrumb: string = '';
  backLabel: string = '';
  showActions: boolean = false;
  onBack: () => void = () => {
  };
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder
  emptyActions() {
  }

  build() {
    Column() {
      if (this.backLabel !== '') {
        Row() {
          Icon({ name: 'arrow-left', iconSize: 16, color: FG.inkMuted })
          Text(`返回${this.backLabel}`)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 6 })
        }
        .height(32)
        .onClick(() => {
          this.onBack();
        })
        .margin({ bottom: 10 })
      }

      if (this.breadcrumb !== '') {
        Text(this.breadcrumb)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.6)
          .margin({ bottom: 6 })
      }

      Text(this.title)
        .fontFamily(FG.serif)
        .fontSize(FG.textH1)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.4)
        .width('100%')

      if (this.description !== '') {
        Text(this.description)
          .fontSize(13)
          .lineHeight(21)
          .fontColor(FG.inkMuted)
          .margin({ top: 8 })
          .width('100%')
      }

      if (this.showActions) {
        Row() {
          this.actions()
        }
        .width('100%')
        .margin({ top: 12 })
        .flexShrink(0)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ bottom: 16 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .margin({ bottom: 20 })
  }
}
