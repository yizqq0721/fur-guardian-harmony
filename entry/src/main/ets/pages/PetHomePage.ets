import { PetApi, ReminderApi } from '../api/Api';
import { FG } from '../common/Theme';
import { BcsScale } from '../components/BcsScale';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { Icon } from '../components/Icon';
import { PetAvatarView } from '../components/PetAvatarView';
import { StatTile } from '../components/StatTile';
import { TipCard } from '../components/TipCard';
import { WeightChart } from '../components/WeightChart';
import { Pet, Reminder, WeightLog } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { bcsGroup } from '../utils/Constants';
import { ageText, todayText } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { isReminderDueOn } from '../utils/Reminder';

@Component
export struct PetHomePage {
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @State private pet: Pet | null = null;
  @State private reminders: Reminder[] = [];
  @State private checkedIds: number[] = [];
  @State private weightLogs: WeightLog[] = [];
  @State private loading: boolean = true;
  @State private weightSheet: boolean = false;
  @State private savingWeight: boolean = false;
  @State private weightText: string = '';
  @State private weightBcs: number = 5;
  @State private weightDate: string = todayText();
  private petId: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    let id: number = this.currentPetId;
    if (id <= 0) {
      const current: Pet | undefined = PetStore.currentPet();
      id = current !== undefined ? current.id : 0;
    }
    if (id <= 0) {
      this.loading = false;
      return;
    }
    this.petId = id;
    this.loading = true;
    const today: string = todayText();
    try {
      this.pet = await PetApi.detail(id);
      this.weightBcs = this.pet.bcs ?? 5;
    } catch (err) {
      console.error(`load pet failed: ${JSON.stringify(err)}`);
      this.pet = null;
      this.loading = false;
      return;
    }
    try {
      this.reminders = await ReminderApi.list(id, true);
    } catch (err) {
      this.reminders = [];
    }
    try {
      this.weightLogs = await PetApi.weightHistory(id);
    } catch (err) {
      this.weightLogs = [];
    }
    try {
      const logs = await ReminderApi.logs(id, today, today, true);
      this.checkedIds = logs.map((log) => log.reminderId);
    } catch (err) {
      this.checkedIds = [];
    }
    const latest: WeightLog | undefined = this.latestWeight();
    if (latest !== undefined) {
      this.weightText = `${latest.weightKg}`;
      this.weightBcs = latest.bcs ?? this.weightBcs;
    }
    this.loading = false;
  }

  private latestWeight(): WeightLog | undefined {
    return this.weightLogs.length > 0 ? this.weightLogs[this.weightLogs.length - 1] : undefined;
  }

  private todayReminders(): Reminder[] {
    const today: string = todayText();
    return this.reminders
      .filter((reminder: Reminder) => isReminderDueOn(reminder, today))
      .slice(0, 6);
  }

  private petMeta(): string {
    const pet: Pet | null = this.pet;
    if (pet === null) {
      return '';
    }
    const neutered: boolean = pet.neutered === true || pet.neutered === 1;
    const bits: string[] = [pet.breed !== undefined && pet.breed.length > 0 ? pet.breed : '品种未填写', ageText(pet.birthday)];
    bits.push(neutered ? '已绝育' : '未绝育');
    const latest: WeightLog | undefined = this.latestWeight();
    if (latest !== undefined) {
      bits.push(`${latest.weightKg} kg`);
    }
    return bits.join(' · ');
  }

  private timeText(reminder: Reminder): string {
    if (reminder.remindTime !== undefined && reminder.remindTime.length >= 5) {
      return reminder.remindTime.substring(0, 5);
    }
    if (reminder.relativeMin !== undefined && reminder.relativeMin !== null) {
      return `饭后 ${reminder.relativeMin} 分钟`;
    }
    return '全天';
  }

  private isChecked(id: number): boolean {
    return this.checkedIds.includes(id);
  }

  private async checkin(reminder: Reminder): Promise<void> {
    if (this.isChecked(reminder.id)) {
      return;
    }
    try {
      await ReminderApi.checkin(reminder.id, { doneDate: todayText() });
      this.checkedIds = this.checkedIds.concat([reminder.id]);
      showToast(`已完成「${reminder.title}」`);
    } catch (err) {
      console.error(`checkin failed: ${JSON.stringify(err)}`);
    }
  }

  private openBirthdayPicker(): void {
    const now: Date = new Date();
    const selected: Date = new Date(this.weightDate.replace(' ', 'T'));
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: now,
      selected: isNaN(selected.getTime()) ? now : selected,
      onDateAccept: (value: Date) => {
        this.weightDate = `${value.getFullYear()}-${value.getMonth() + 1 < 10 ? '0' : ''}${value.getMonth() + 1}` +
          `-${value.getDate() < 10 ? '0' : ''}${value.getDate()}`;
      }
    });
  }

  private async saveWeight(): Promise<void> {
    if (this.weightText.trim().length === 0) {
      showToast('请填写体重');
      return;
    }
    let weight: number = Number(this.weightText.trim());
    if (isNaN(weight) || weight < 0.5 || weight > 80) {
      showToast('体重需在 0.5-80 kg 之间');
      return;
    }
    weight = Math.round(weight * 10) / 10;
    this.savingWeight = true;
    try {
      await PetApi.addWeight(this.petId, {
        weightKg: weight,
        bcs: this.weightBcs,
        recordedAt: this.weightDate
      });
      this.weightLogs = await PetApi.weightHistory(this.petId);
      this.weightSheet = false;
      showToast('体重已记录');
    } catch (err) {
      console.error(`save weight failed: ${JSON.stringify(err)}`);
    } finally {
      this.savingWeight = false;
    }
  }

  private goProfile(): void {
    Nav.push('PetProfile');
  }

  private goNutrition(): void {
    Nav.push('Nutrition', this.petId);
  }

  private goReminders(): void {
    Nav.push('Reminders');
  }

  @Builder
  SectionTitle(title: string, iconName: string) {
    Row() {
      Icon({ name: iconName, iconSize: 20, color: FG.ink })
      Text(title)
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.2)
        .margin({ left: 8 })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  BcsBadge(bcs?: number) {
    Row() {
      Text(bcs !== undefined && bcs > 0 ? `BCS ${bcs} / 9 · ${bcsGroup(bcs).label}` : 'BCS 未评估')
        .fontSize(FG.textLabel)
        .fontColor(bcs !== undefined && bcs > 0
          ? (bcs === 4 || bcs === 5 ? FG.accent : FG.warning)
          : FG.inkMuted)
    }
    .height(22)
    .padding({ left: 8, right: 8 })
    .borderRadius(6)
    .backgroundColor(bcs !== undefined && bcs > 0
      ? (bcs === 4 || bcs === 5 ? FG.accentSoft : FG.warningSoft)
      : FG.paper)
    .border({
      width: 1,
      color: bcs !== undefined && bcs > 0 ? 'transparent' : FG.line
    })
  }

  @Builder
  TaskRow(reminder: Reminder) {
    Row() {
      Stack() {
        Row()
          .width(18)
          .height(18)
          .borderRadius(2)
          .border({ width: 1, color: this.isChecked(reminder.id) ? FG.accent : FG.line })
          .backgroundColor(this.isChecked(reminder.id) ? FG.accent : Color.Transparent)
        if (this.isChecked(reminder.id)) {
          Icon({ name: 'check', iconSize: 12, color: FG.surface, weight: 2.6 })
        }
      }
      .width(44)
      .height(44)
      .onClick(() => {
        this.checkin(reminder);
      })

      Text(reminder.title)
        .fontSize(FG.textBody)
        .fontColor(this.isChecked(reminder.id) ? FG.inkMuted : FG.ink)
        .decoration({
          type: this.isChecked(reminder.id) ? TextDecorationType.LineThrough : TextDecorationType.None,
          color: FG.inkMuted
        })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        if (reminder.remindTime !== undefined && reminder.remindTime.length >= 5) {
          Icon({ name: 'clock', iconSize: 12, color: FG.inkMuted })
            .margin({ right: 4 })
        }
        Text(this.timeText(reminder))
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
      }
      .height(22)
      .padding({ left: 8, right: 8 })
      .backgroundColor(FG.paper)
      .border({ width: 1, color: FG.line })
      .borderRadius(6)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ top: 4, bottom: 4 })
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  WeightSheet() {
    Scroll() {
      Column() {
        Text('记录体重')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ bottom: 16 })

        Text('体重 (kg)')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.5)
          .width('100%')
          .margin({ bottom: 6 })
        Row() {
          TextInput({ text: this.weightText, placeholder: '例如：5.1' })
            .type(InputType.NUMBER_DECIMAL)
            .width(140)
            .height(44)
            .fontSize(16)
            .fontColor(FG.ink)
            .placeholderColor('#A3A6AC')
            .backgroundColor(FG.surface)
            .borderRadius(FG.radius)
            .border({ width: 1, color: FG.line })
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.weightText = value;
            })
          Text('kg')
            .fontSize(FG.textLead)
            .fontColor(FG.inkMuted)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ bottom: 16 })

        Text('体况评分 BCS')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.5)
          .width('100%')
          .margin({ bottom: 8 })
        BcsScale({
          value: this.weightBcs,
          onChange: (value: number) => {
            this.weightBcs = value;
          }
        })
        .margin({ bottom: 16 })

        Text('记录日期')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.5)
          .width('100%')
          .margin({ bottom: 6 })
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Text(this.weightDate)
              .fontSize(16)
              .fontColor(FG.ink)
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
            Icon({ name: 'calendar-days', iconSize: 16, color: FG.inkMuted })
          }
          .width('100%')
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor(FG.surface)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
        .onClick(() => {
          this.openBirthdayPicker();
        })

        Row() {
          Blank()
          FgButton({
            label: '取消',
            variant: 'secondary',
            onTap: () => {
              this.weightSheet = false;
            }
          })
          FgButton({
            label: '保存',
            variant: 'primary',
            loading: this.savingWeight,
            onTap: () => {
              this.saveWeight();
            }
          })
            .margin({ left: 12 })
        }
        .width('100%')
        .margin({ top: 24 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 12, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  @Builder
  HeaderSection(pet: Pet) {
    Column() {
      Row() {
        Icon({ name: 'arrow-left', iconSize: 16, color: FG.inkMuted })
        Text('返回我的宠物')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 8 })
      }
      .height(32)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        Nav.pop();
      })
      .margin({ bottom: 12 })

      Row() {
        PetAvatarView({
          avatar: pet.avatar ?? '',
          name: pet.name,
          avatarSize: 48,
          corner: 24,
          textSize: FG.textH3
        })
        Column() {
          Text(pet.name)
            .fontFamily(FG.serif)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.petMeta())
            .fontSize(13)
            .lineHeight(20)
            .fontColor(FG.inkMuted)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        this.BcsBadge(pet.bcs)
        Blank()
      }
      .width('100%')
      .margin({ top: 12 })

      Row() {
        Column() {
          FgButton({
            label: '编辑档案',
            variant: 'secondary',
            onTap: () => {
              this.goProfile();
            }
          })
            .width('100%')
        }
        .layoutWeight(1)

        Column() {
          FgButton({
            label: '营养方案',
            variant: 'primary',
            onTap: () => {
              this.goNutrition();
            }
          })
            .width('100%')
        }
        .layoutWeight(1)
        .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 16 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .margin({ bottom: 24 })
  }

  build() {
    Scroll() {
      Column() {
        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 80 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.pet !== null) {
          this.HeaderSection(this.pet as Pet)

          Column() {
            this.SectionTitle('今日任务', 'list-checks')

            if (this.todayReminders().length === 0) {
              Column() {
                EmptyState({ variant: 'default', description: '今天没有待办提醒' })
                FgButton({
                  label: '去设置提醒',
                  variant: 'secondary',
                  onTap: () => {
                    this.goReminders();
                  }
                })
                  .margin({ top: 12 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            } else {
              Column() {
                ForEach(this.todayReminders(), (reminder: Reminder) => {
                  this.TaskRow(reminder)
                }, (reminder: Reminder) => `${reminder.id}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(FG.s4)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)

          Column() {
            this.SectionTitle('体重趋势', 'scale')

            StatTile({
              label: '当前体重',
              value: this.latestWeight() !== undefined ? `${this.latestWeight()?.weightKg}` : '—',
              unit: 'kg',
              caption: this.latestWeight() !== undefined
                ? `记录于 ${this.latestWeight()?.recordedAt}`
                : '尚无体重记录'
            })

            FgButton({
              label: '记录体重',
              variant: 'primary',
              icon: 'plus',
              onTap: () => {
                this.weightSheet = true;
              }
            })
              .width('100%')
              .margin({ top: 12 })

            Column()
              .width('100%')
              .height(1)
              .backgroundColor(FG.line)
              .margin({ top: 16, bottom: 16 })

            if (this.weightLogs.length > 1) {
              WeightChart({ logs: this.weightLogs, chartHeight: 220 })
            } else {
              Text('再记录几次体重即可看到趋势曲线')
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(FG.s4)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)
          .margin({ top: 12 })

          Column() {
            this.SectionTitle('今日 Tip', 'lightbulb')
            TipCard({ petId: this.petId })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(FG.s4)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)
          .margin({ top: 12 })
        } else {
          Column() {
            Text('未找到宠物档案')
              .fontSize(FG.textLead)
              .fontColor(FG.inkMuted)
            FgButton({
              label: '返回我的宠物',
              variant: 'secondary',
              onTap: () => {
                Nav.pop();
              }
            })
              .margin({ top: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 80 })
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
    .bindSheet($$this.weightSheet, this.WeightSheet(), {
      height: 580,
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: true
    })
  }
}
