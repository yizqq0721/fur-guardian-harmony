import { WeatherApi } from '../api/Api';
import { FG } from '../common/Theme';
import { WeatherToday } from '../models/Types';
import { Icon } from './Icon';

@Component
export struct WeatherWidget {
  @StorageLink('fg_location') @Watch('onLocationChange') location: string = '';
  @State private weather: WeatherToday | null = null;
  @State private loading: boolean = false;
  @State private unavailable: boolean = false;
  @State private panelOpen: boolean = false;
  locating: boolean = false;
  compact: boolean = false;
  onNeedLocate: () => void = () => {
  };
  onOpenReminders: () => void = () => {
  };
  private timer: number = -1;

  aboutToAppear(): void {
    this.loadWeather();
    this.timer = setInterval(() => {
      this.loadWeather();
    }, 30 * 60 * 1000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  onLocationChange(): void {
    this.weather = null;
    this.unavailable = false;
    this.loadWeather();
  }

  private async loadWeather(): Promise<void> {
    if (this.location.length === 0) {
      this.weather = null;
      this.unavailable = false;
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      this.weather = await WeatherApi.today();
      this.unavailable = this.weather === null;
    } catch (err) {
      this.weather = null;
      this.unavailable = true;
    } finally {
      this.loading = false;
    }
  }

  private iconName(): string {
    const weather: WeatherToday | null = this.weather;
    if (weather === null) {
      return 'cloud-sun';
    }
    const text: string = `${weather.text}${weather.textNight ?? ''}`;
    if (text.includes('雷')) {
      return 'cloud-lightning';
    }
    if (text.includes('雪')) {
      return 'snowflake';
    }
    if (text.includes('雨')) {
      return 'cloud-rain';
    }
    if (text.includes('晴')) {
      return 'sun';
    }
    if (text.includes('风') || Number(weather.windScale) >= 5) {
      return 'wind';
    }
    return 'cloud-sun';
  }

  private levelColor(): string {
    const level: string = this.weather?.level ?? 'CAUTION';
    if (level === 'GOOD') {
      return FG.success;
    }
    if (level === 'AVOID') {
      return FG.danger;
    }
    return FG.warning;
  }

  private levelSoft(): string {
    const level: string = this.weather?.level ?? 'CAUTION';
    if (level === 'GOOD') {
      return FG.accentSoft;
    }
    if (level === 'AVOID') {
      return FG.dangerSoft;
    }
    return FG.warningSoft;
  }

  private walkLabel(): string {
    const level: string = this.weather?.level ?? '';
    if (level === 'GOOD') {
      return '适合遛狗';
    }
    if (level === 'AVOID') {
      return '不宜遛狗';
    }
    return '谨慎遛狗';
  }

  private weatherText(): string {
    const weather: WeatherToday | null = this.weather;
    if (weather === null) {
      return '天气';
    }
    if (weather.textNight && weather.textNight !== weather.text) {
      return `${weather.text}转${weather.textNight}`;
    }
    return weather.text;
  }

  @Builder
  panel() {
    Column() {
      Row() {
        Icon({ name: 'map-pin', iconSize: 14, color: FG.inkMuted })
        Text(this.location)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 4 })
          .layoutWeight(1)
        Row() {
          Icon({ name: 'locate-fixed', iconSize: 13, color: FG.accent })
          Text(this.locating ? '定位中' : '重新定位')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .margin({ left: 3 })
        }
        .onClick(() => {
          this.onNeedLocate();
        })
      }
      .width('100%')
      .padding({ bottom: 12 })
      .border({ width: { bottom: 1 }, color: FG.line })

      if (this.weather !== null) {
        Row() {
          Icon({ name: this.iconName(), iconSize: 36, color: this.levelColor() })
          Column() {
            Row() {
              Text(`${this.weather.high}°`)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(FG.ink)
              Text(` / ${this.weather.low}°`)
                .fontSize(FG.textBody)
                .fontColor(FG.inkMuted)
                .margin({ bottom: 4 })
            }
            .alignItems(VerticalAlign.Bottom)
            Text(this.weatherText())
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 12, bottom: 6 })

        Text(`${this.weather.windDirection ?? ''}风 ${this.weather.windScale ?? ''}级` +
          (this.weather.humidity ? ` · 湿度 ${this.weather.humidity}%` : ''))
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .width('100%')

        Row() {
          Text(this.walkLabel())
            .fontSize(FG.textLabel)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.levelColor())
          Text(this.weather.advice)
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(this.levelColor())
            .margin({ left: 8 })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.levelSoft())
        .borderRadius(FG.radius)
        .margin({ top: 12 })

        Row() {
          Text('查看遛弯提醒')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
          Icon({ name: 'arrow-right', iconSize: 13, color: FG.accent })
            .margin({ left: 3 })
        }
        .margin({ top: 12 })
        .onClick(() => {
          this.panelOpen = false;
          this.onOpenReminders();
        })
      } else if (this.loading) {
        Text('正在获取今日天气…')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 12 })
          .width('100%')
      } else {
        Row() {
          Text('暂时取不到天气，请稍后重试。')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
          Text('重试')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .margin({ left: 4 })
            .onClick(() => {
              this.loadWeather();
            })
        }
        .margin({ top: 12 })
        .width('100%')
      }
    }
    .width(300)
    .padding(16)
    .backgroundColor(FG.surface)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.location.length === 0) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          Icon({ name: 'locate-fixed', iconSize: 16, color: FG.inkMuted })
          Text(this.locating ? '定位中' : '定位')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 4 })
        }
      }
      .height(34)
      .padding({ left: 8, right: 8 })
      .borderRadius(17)
      .backgroundColor(FG.surface)
      .border({ width: 1, color: FG.line })
      .enabled(!this.locating)
      .onClick(() => {
        this.onNeedLocate();
      })
    } else {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          if (this.loading) {
            LoadingProgress()
              .width(15)
              .height(15)
              .color(FG.inkMuted)
          } else {
            Icon({ name: this.iconName(), iconSize: 16, color: this.levelColor() })
          }
          if (this.weather !== null) {
            Text(`${this.weather.high}°`)
              .fontSize(FG.textLabel)
              .fontWeight(FontWeight.Bold)
              .fontColor(FG.ink)
              .margin({ left: 4 })
            if (!this.compact) {
              Text(this.weather.text)
                .fontSize(FG.textLabel)
                .fontColor(FG.ink)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ left: 4 })
                .flexShrink(1)
            }
          } else {
            Text('天气')
              .fontSize(FG.textLabel)
              .fontColor(FG.ink)
              .margin({ left: 4 })
          }
        }
      }
      .height(34)
      .constraintSize({ maxWidth: 150 })
      .padding({ left: 8, right: 8 })
      .borderRadius(17)
      .backgroundColor(FG.surface)
      .border({ width: 1, color: FG.line })
      .onClick(() => {
        this.panelOpen = !this.panelOpen;
      })
      .bindPopup(this.panelOpen, {
        builder: this.panel(),
        placement: Placement.Bottom,
        popupColor: FG.surface,
        enableArrow: true,
        radius: FG.radius,
        onStateChange: (event) => {
          if (!event.isVisible) {
            this.panelOpen = false;
          }
        }
      })
    }
  }
}
