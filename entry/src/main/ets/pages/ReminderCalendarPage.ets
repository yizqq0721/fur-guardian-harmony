import { ReminderApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { PageHeader } from '../components/PageHeader';
import { ReminderCalendar } from '../components/ReminderCalendar';
import { Pet, Reminder } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { Nav } from '../utils/Nav';

@Component
export struct ReminderCalendarPage {
  initialPetId: number = 0;
  @StorageLink('fg_pets') pets: Pet[] = [];
  @State private reminders: Reminder[] = [];
  @State private loading: boolean = true;
  @State private loadError: boolean = false;
  @State private filterPetId: number = 0;

  aboutToAppear(): void {
    if (this.initialPetId > 0) {
      this.filterPetId = this.initialPetId;
    }
    this.load();
  }

  private async load(): Promise<void> {
    try {
      await PetStore.fetchPets();
    } catch (err) {
      console.warn(`fetch pets failed: ${JSON.stringify(err)}`);
    }
    await this.fetchReminders();
  }

  private async fetchReminders(): Promise<void> {
    this.loading = true;
    this.loadError = false;
    try {
      this.reminders = await ReminderApi.list(this.filterPetId > 0 ? this.filterPetId : undefined);
    } catch (err) {
      this.reminders = [];
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  private selectPet(id: number): void {
    if (this.filterPetId === id) {
      return;
    }
    this.filterPetId = id;
    this.fetchReminders();
  }

  @Builder
  FilterChip(label: string, value: number) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontColor(this.filterPetId === value ? FG.accent : FG.inkMuted)
      .fontWeight(this.filterPetId === value ? FontWeight.Medium : FontWeight.Normal)
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(17)
      .backgroundColor(this.filterPetId === value ? FG.accentSoft : FG.surface)
      .border({ width: 1, color: this.filterPetId === value ? FG.accent : FG.line })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectPet(value);
      })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '待办日历',
          breadcrumb: '提醒管理 · 日历',
          description: '按月查看疫苗、驱虫这类按日期提醒的事项，提前安排好护理。',
          backLabel: '提醒管理',
          onBack: () => {
            Nav.pop();
          }
        })

        if (this.pets.length === 0 && !this.loading) {
          Column() {
            EmptyState({ variant: 'pets', description: '请先创建宠物档案，再安排护理日历' })
            FgButton({
              label: '去创建',
              variant: 'primary',
              onTap: () => {
                Nav.push('Onboarding');
              }
            })
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        } else {
          Column() {
            Text('查看宠物')
              .fontSize(FG.textLabel)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(0.5)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ bottom: 8 })

            Flex({ wrap: FlexWrap.Wrap }) {
              this.FilterChip('全部', 0)
              ForEach(this.pets, (pet: Pet) => {
                this.FilterChip(pet.name, pet.id)
              }, (pet: Pet) => `cal-pet-${pet.id}`)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 8 })
          .margin({ bottom: 12 })
          .border({ width: { bottom: 1 }, color: FG.line })

          if (this.loadError) {
            Row() {
              Text('日历加载失败，请检查网络后重试。')
                .fontSize(FG.textBody)
                .fontColor(FG.danger)
                .layoutWeight(1)
              Text('重新加载')
                .fontSize(FG.textBody)
                .fontColor(FG.danger)
                .decoration({ type: TextDecorationType.Underline })
                .onClick(() => {
                  this.fetchReminders();
                })
            }
            .width('100%')
            .padding({ left: 12, top: 12, bottom: 12 })
            .border({ width: { left: 2 }, color: FG.danger })
          } else if (this.loading) {
            Column() {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(FG.accent)
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .alignItems(HorizontalAlign.Center)
          } else {
            ReminderCalendar({ reminders: this.reminders })
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
