import { WeatherApi } from '../api/Api';
import { FG } from '../common/Theme';
import { Pet, WeatherToday } from '../models/Types';
import { PetStore } from '../stores/PetStore';

@Component
export struct AppTopBar {
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @State weather: WeatherToday | null = null;
  onMenuClick: () => void = () => {
  };

  aboutToAppear(): void {
    this.loadWeather();
  }

  private async loadWeather(): Promise<void> {
    try {
      this.weather = await WeatherApi.today();
    } catch (err) {
      console.warn(`weather load failed: ${JSON.stringify(err)}`);
    }
  }

  private currentPetName(): string {
    const current: Pet | undefined = this.pets.find((pet: Pet) => pet.id === this.currentPetId);
    if (current !== undefined) {
      return current.name;
    }
    return this.pets.length > 0 ? this.pets[0].name : '宠物';
  }

  private petMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    this.pets.forEach((pet: Pet) => {
      items.push({
        value: pet.name,
        action: () => {
          PetStore.setCurrentPet(pet.id);
        }
      });
    });
    if (items.length === 0) {
      items.push({ value: '暂无宠物', action: () => {
      }, enabled: false });
    }
    return items;
  }

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
            .fontColor(FG.ink)
            .margin({ left: 4 })
        }
        .onClick(() => {
          AppStorage.setOrCreate('fg_activeTab', 0);
        })

        Blank()

        if (this.weather !== null) {
          Row() {
            Text(this.weather.text)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
            Text(`${this.weather.high}°`)
              .fontSize(FG.textLabel)
              .fontColor(FG.ink)
              .margin({ left: 4 })
          }
          .height(32)
          .padding({ left: 8, right: 8 })
          .borderRadius(FG.radius)
          .border({ width: 1, color: FG.line })
          .backgroundColor(FG.surface)
          .margin({ right: 8 })
        }

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Text(this.currentPetName())
              .fontSize(FG.textBody)
              .fontColor(FG.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('⌄')
              .fontSize(14)
              .fontColor(FG.inkMuted)
              .margin({ left: 2 })
          }
        }
        .height(36)
        .constraintSize({ maxWidth: 96 })
        .padding({ left: 8, right: 8 })
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
        .backgroundColor(FG.surface)
        .margin({ right: 8 })
        .bindMenu(this.petMenu())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text('☰')
            .fontSize(22)
            .fontColor(FG.ink)
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
      .backgroundColor('rgba(253,251,246,0.72)')
    }
    .width('100%')
    .height(FG.topbarH)
    .border({ width: { bottom: 1 }, color: FG.line })
  }
}
