import { FG } from '../common/Theme';
import { speciesLabel } from '../utils/Constants';

@Component
export struct BcsReference {
  species: string = 'dog';
  @State preview: boolean = false;

  private image(): Resource {
    return this.species === 'cat' ? $r('app.media.bcs_cat') : $r('app.media.bcs_dog');
  }

  build() {
    Column() {
      Row() {
        Text(`${speciesLabel(this.species)} BCS 参考图`)
          .fontSize(FG.textBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
        Blank()
        Text('WSAVA 9 分制 · 点击放大')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Image(this.image())
        .width('100%')
        .aspectRatio(1.42)
        .objectFit(ImageFit.Contain)
        .backgroundColor(FG.paper)
        .borderRadius(4)
        .onClick(() => {
          this.preview = true;
        })
        .bindContentCover($$this.preview, this.previewBuilder(), {
          modalTransition: ModalTransition.DEFAULT
        })

      Text('来源：WSAVA Global Nutrition Committee')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .padding(FG.s3)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 20 })
  }

  @Builder
  previewBuilder() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(this.image())
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
      Row() {
        Text('×')
          .fontSize(28)
          .fontColor(Color.White)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 40, right: 16 })
      .onClick(() => {
        this.preview = false;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#16181A')
  }
}
