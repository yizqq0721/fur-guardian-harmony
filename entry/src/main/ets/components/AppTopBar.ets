import { FG } from '../common/Theme';
import { Icon } from './Icon';
import { PetSwitcher } from './PetSwitcher';
import { WeatherWidget } from './WeatherWidget';

@Component
export struct AppTopBar {
  onMenuClick: () => void = () => {
  };

  build() {
    Stack() {
      Image($r('app.media.topbar_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Row() {
        Row() {
          Image($r('app.media.ic_paw'))
            .width(20)
            .height(20)
          Text('FurGuardian')
            .fontFamily(FG.serif)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.2)
            .fontColor(FG.ink)
            .margin({ left: 8 })
        }
        .onClick(() => {
          AppStorage.setOrCreate('fg_activeTab', 0);
        })

        Blank()

        WeatherWidget({
          compact: true,
          onOpenReminders: () => {
            AppStorage.setOrCreate('fg_activeTab', 2);
          }
        })
          .margin({ right: 8 })

        PetSwitcher({
          plain: true,
          onChange: (id: number) => {
            AppStorage.setOrCreate('fg_activeTab', 0);
          }
        })
          .margin({ right: 8 })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Icon({ name: 'menu', iconSize: 22, color: FG.ink })
        }
        .width(44)
        .height(44)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
        .backgroundColor(FG.surface)
        .onClick(() => {
          this.onMenuClick();
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .linearGradient({
        angle: 90,
        colors: [['rgba(253,251,246,0.78)', 0.0], ['rgba(250,248,242,0.68)', 1.0]]
      })
    }
    .width('100%')
    .height(FG.topbarH)
    .border({ width: { bottom: 1 }, color: FG.line })
  }
}
