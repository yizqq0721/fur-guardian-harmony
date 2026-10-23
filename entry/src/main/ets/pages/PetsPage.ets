import { FoodApi, NutritionApi, PetApi, ReminderApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { PetAvatarView } from '../components/PetAvatarView';
import { Food, NutritionPlan, Pet, Reminder, WeightLog } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { repeatRuleLabel } from '../utils/Constants';
import { ageText, fromNow, monthDayText, todayText } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { isReminderDueOn } from '../utils/Reminder';

class PetWeightInfo {
  petId: number;
  kg: number;
  at: string;

  constructor(petId: number, kg: number, at: string) {
    this.petId = petId;
    this.kg = kg;
    this.at = at;
  }
}

class PetPlanInfo {
  petId: number;
  status: string;
  plan: NutritionPlan | null;
  foodName: string;

  constructor(petId: number, status: string, plan: NutritionPlan | null, foodName: string) {
    this.petId = petId;
    this.status = status;
    this.plan = plan;
    this.foodName = foodName;
  }
}

class PetReminderGroup {
  petId: number;
  list: Reminder[];

  constructor(petId: number, list: Reminder[]) {
    this.petId = petId;
    this.list = list;
  }
}

class PetDoneGroup {
  petId: number;
  ids: number[];

  constructor(petId: number, ids: number[]) {
    this.petId = petId;
    this.ids = ids;
  }
}

const REM_LIMIT: number = 3;
const WARN_LIMIT: number = 1;

@Component
export struct PetsPage {
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') @Watch('onCurrentPetChange') currentPetId: number = 0;
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private activeIndex: number = 0;
  @State private weights: PetWeightInfo[] = [];
  @State private plans: PetPlanInfo[] = [];
  @State private reminderGroups: PetReminderGroup[] = [];
  @State private doneGroups: PetDoneGroup[] = [];
  @State private checkingIds: number[] = [];
  @State private openWarnings: number[] = [];
  @State private openReminders: number[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private onCurrentPetChange(): void {
    const at: number = this.pets.findIndex((pet: Pet) => pet.id === this.currentPetId);
    if (at > -1 && at !== this.activeIndex) {
      this.activeIndex = at;
    }
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const list: Pet[] = await PetStore.fetchPets(true);
      const at: number = list.findIndex((pet: Pet) => pet.id === this.currentPetId);
      this.activeIndex = at > -1 ? at : 0;
      this.loadWeights(list);
      this.loadReminders(list);
      this.loadTodayDone(list);
      this.loadPlans(list);
    } catch (err) {
      console.error(`load pets failed: ${JSON.stringify(err)}`);
      this.error = '宠物列表加载失败，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private async loadWeights(list: Pet[]): Promise<void> {
    await Promise.all(list.map(async (pet: Pet) => {
      try {
        const logs: WeightLog[] = await PetApi.weightHistory(pet.id);
        const last: WeightLog | undefined = logs.length > 0 ? logs[logs.length - 1] : undefined;
        if (last !== undefined) {
          this.setWeight(new PetWeightInfo(pet.id, last.weightKg, last.recordedAt));
        } else {
          this.setWeight(new PetWeightInfo(pet.id, 0, ''));
        }
      } catch (err) {
        this.setWeight(new PetWeightInfo(pet.id, 0, ''));
      }
    }));
  }

  private async loadReminders(list: Pet[]): Promise<void> {
    await Promise.all(list.map(async (pet: Pet) => {
      try {
        const rows: Reminder[] = await ReminderApi.list(pet.id, true);
        this.setReminders(pet.id, rows);
      } catch (err) {
        this.setReminders(pet.id, []);
      }
    }));
  }

  private async loadTodayDone(list: Pet[]): Promise<void> {
    const today: string = todayText();
    await Promise.all(list.map(async (pet: Pet) => {
      try {
        const logs = await ReminderApi.logs(pet.id, today, today, true);
        this.setDone(pet.id, logs.map((log) => log.reminderId));
      } catch (err) {
        this.setDone(pet.id, []);
      }
    }));
  }

  private async loadPlans(list: Pet[]): Promise<void> {
    list.forEach((pet: Pet) => {
      this.setPlan(new PetPlanInfo(pet.id, 'loading', null, ''));
    });
    if (list.length === 0) {
      return;
    }
    let foods: Food[] = [];
    try {
      const page = await FoodApi.list({ page: 1, size: 100 });
      foods = page.records;
    } catch (err) {
      list.forEach((pet: Pet) => {
        this.setPlan(new PetPlanInfo(pet.id, 'empty', null, ''));
      });
      return;
    }
    await Promise.all(list.map(async (pet: Pet) => {
      const food: Food | undefined = this.pickStaple(foods, pet);
      if (food === undefined) {
        this.setPlan(new PetPlanInfo(pet.id, 'empty', null, ''));
        return;
      }
      try {
        const plan: NutritionPlan = await NutritionApi.calculate(pet.id, food.id);
        this.setPlan(new PetPlanInfo(pet.id, 'ready', plan, food.name));
      } catch (err) {
        this.setPlan(new PetPlanInfo(pet.id, 'empty', null, ''));
      }
    }));
  }

  private pickStaple(foods: Food[], pet: Pet): Food | undefined {
    const scope: string = pet.species === 'cat' ? 'CAT' : 'DOG';
    const matched: Food[] = foods.filter((food: Food) =>
      !food.speciesScope || food.speciesScope === 'BOTH' || food.speciesScope === scope);
    const complete: Food[] = matched.filter((food: Food) =>
      !food.productType || food.productType === 'COMPLETE' || food.productType === 'COMPLEMENTARY');
    const dry: Food | undefined = complete.find((food: Food) => food.foodType === 'DRY');
    if (dry !== undefined) {
      return dry;
    }
    if (complete.length > 0) {
      return complete[0];
    }
    return matched.length > 0 ? matched[0] : undefined;
  }

  private setWeight(info: PetWeightInfo): void {
    const next: PetWeightInfo[] = this.weights.filter((item: PetWeightInfo) => item.petId !== info.petId);
    next.push(info);
    this.weights = next;
  }

  private setPlan(info: PetPlanInfo): void {
    const next: PetPlanInfo[] = this.plans.filter((item: PetPlanInfo) => item.petId !== info.petId);
    next.push(info);
    this.plans = next;
  }

  private setReminders(petId: number, list: Reminder[]): void {
    const next: PetReminderGroup[] = this.reminderGroups.filter((item: PetReminderGroup) => item.petId !== petId);
    next.push(new PetReminderGroup(petId, list));
    this.reminderGroups = next;
  }

  private setDone(petId: number, ids: number[]): void {
    const next: PetDoneGroup[] = this.doneGroups.filter((item: PetDoneGroup) => item.petId !== petId);
    next.push(new PetDoneGroup(petId, ids));
    this.doneGroups = next;
  }

  private activePet(): Pet | undefined {
    if (this.pets.length === 0) {
      return undefined;
    }
    const at: number = Math.min(Math.max(this.activeIndex, 0), this.pets.length - 1);
    return this.pets[at];
  }

  private setActive(index: number): void {
    if (this.pets.length === 0) {
      return;
    }
    const clamped: number = Math.min(Math.max(index, 0), this.pets.length - 1);
    this.activeIndex = clamped;
    const pet: Pet = this.pets[clamped];
    if (pet.id !== this.currentPetId) {
      PetStore.setCurrentPet(pet.id);
    }
  }

  private caption(): string {
    if (this.pets.length === 0) {
      return '还没有宠物档案';
    }
    const stamps: string[] = [];
    this.pets.forEach((pet: Pet) => {
      const stamp: string = pet.updatedAt !== undefined && pet.updatedAt.length > 0
        ? pet.updatedAt
        : (pet.createdAt ?? '');
      if (stamp.length > 0) {
        stamps.push(stamp);
      }
    });
    stamps.sort();
    const latest: string = stamps.length > 0 ? stamps[stamps.length - 1] : '';
    return `共 ${this.pets.length} 只 · 最近更新 ${monthDayText(latest)}`;
  }

  private weightOf(id: number): PetWeightInfo | undefined {
    return this.weights.find((item: PetWeightInfo) => item.petId === id);
  }

  private planOf(id: number): PetPlanInfo | undefined {
    return this.plans.find((item: PetPlanInfo) => item.petId === id);
  }

  private remindersOf(id: number): Reminder[] {
    const group: PetReminderGroup | undefined = this.reminderGroups.find((item: PetReminderGroup) => item.petId === id);
    return group !== undefined ? group.list : [];
  }

  private doneIdsOf(id: number): number[] {
    const group: PetDoneGroup | undefined = this.doneGroups.find((item: PetDoneGroup) => item.petId === id);
    return group !== undefined ? group.ids : [];
  }

  private isDone(petId: number, reminderId: number): boolean {
    return this.doneIdsOf(petId).includes(reminderId);
  }

  private dueReminders(id: number): Reminder[] {
    const today: string = todayText();
    return this.remindersOf(id)
      .filter((reminder: Reminder) => isReminderDueOn(reminder, today))
      .sort((a: Reminder, b: Reminder) => (a.remindTime ?? '99:99').localeCompare(b.remindTime ?? '99:99'));
  }

  private shownReminders(id: number): Reminder[] {
    const all: Reminder[] = this.dueReminders(id);
    return this.openReminders.includes(id) ? all : all.slice(0, REM_LIMIT);
  }

  private hiddenReminders(id: number): number {
    return Math.max(0, this.dueReminders(id).length - REM_LIMIT);
  }

  private shownWarnings(id: number): string[] {
    const all: string[] = this.planOf(id)?.plan?.warnings ?? [];
    return this.openWarnings.includes(id) ? all : all.slice(0, WARN_LIMIT);
  }

  private hiddenWarnings(id: number): number {
    const all: string[] = this.planOf(id)?.plan?.warnings ?? [];
    return Math.max(0, all.length - WARN_LIMIT);
  }

  private toggleWarnings(id: number): void {
    this.openWarnings = this.openWarnings.includes(id)
      ? this.openWarnings.filter((item: number) => item !== id)
      : this.openWarnings.concat([id]);
  }

  private toggleReminders(id: number): void {
    this.openReminders = this.openReminders.includes(id)
      ? this.openReminders.filter((item: number) => item !== id)
      : this.openReminders.concat([id]);
  }

  private timeOf(reminder: Reminder): string {
    if (reminder.remindTime !== undefined && reminder.remindTime.length >= 5) {
      return reminder.remindTime.substring(0, 5);
    }
    return reminder.relativeMin !== undefined && reminder.relativeMin !== null ? '餐后' : '—';
  }

  private repeatLabel(reminder: Reminder): string {
    const label: string = repeatRuleLabel(reminder.repeatRule);
    return label.length > 0 ? label : '每天';
  }

  private metaText(pet: Pet): string {
    const neutered: boolean = pet.neutered === true || pet.neutered === 1;
    const bits: string[] = [pet.breed !== undefined && pet.breed.length > 0 ? pet.breed : '品种未填写', ageText(pet.birthday)];
    if (neutered) {
      bits.push('已绝育');
    }
    return bits.join(' · ');
  }

  private bcsColor(bcs?: number): string {
    if (bcs === undefined || bcs <= 0) {
      return FG.inkMuted;
    }
    return bcs === 4 || bcs === 5 ? FG.accent : FG.warning;
  }

  private lastRecordText(pet: Pet): string {
    const weight: PetWeightInfo | undefined = this.weightOf(pet.id);
    const stamp: string = weight !== undefined && weight.at.length > 0
      ? weight.at
      : (pet.updatedAt ?? pet.createdAt ?? '');
    const rel: string = fromNow(stamp);
    const isYmd: boolean = rel.length === 10 && rel.charAt(4) === '-' && rel.charAt(7) === '-';
    return isYmd ? monthDayText(stamp) : rel;
  }

  private round(value?: number): string {
    return value === undefined || value === null ? '—' : `${Math.round(value)}`;
  }

  private weightValue(id: number): string {
    const info: PetWeightInfo | undefined = this.weightOf(id);
    return info !== undefined && info.kg > 0 ? `${info.kg}` : '—';
  }

  private async checkIn(petId: number, reminder: Reminder): Promise<void> {
    if (this.isDone(petId, reminder.id) || this.checkingIds.includes(reminder.id)) {
      return;
    }
    this.checkingIds = this.checkingIds.concat([reminder.id]);
    try {
      await ReminderApi.checkin(reminder.id, { doneDate: todayText() });
      this.setDone(petId, this.doneIdsOf(petId).concat([reminder.id]));
      showToast(`已完成「${reminder.title}」`);
    } catch (err) {
      console.error(`checkin failed: ${JSON.stringify(err)}`);
    } finally {
      this.checkingIds = this.checkingIds.filter((id: number) => id !== reminder.id);
    }
  }

  private goPet(id: number): void {
    PetStore.setCurrentPet(id);
    Nav.push('PetHome');
  }

  private goNutrition(id: number): void {
    PetStore.setCurrentPet(id);
    Nav.push('Nutrition', id);
  }

  private goReminders(id: number): void {
    PetStore.setCurrentPet(id);
    Nav.push('Reminders');
  }

  @Builder
  StatCell(label: string, value: string, unit: string, valueColor: string) {
    Column() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
      Row() {
        Text(value)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(valueColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (unit !== '') {
          Text(unit)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 2, bottom: 1 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PanelButton(label: string, iconName: string, onTap: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        Icon({ name: iconName, iconSize: 14, color: FG.accent })
        Text(label)
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.accent)
          .margin({ left: 4 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .height(28)
    .padding({ left: 10, right: 10 })
    .backgroundColor(FG.accentSoft)
    .borderRadius(6)
    .onClick(onTap)
  }

  @Builder
  NutritionPanel(pet: Pet) {
    Column() {
      Row() {
        Text('营养方案')
          .fontFamily(FG.serif)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
        Blank()
        this.PanelButton('查看方案', 'utensils-crossed', () => {
          this.goNutrition(pet.id);
        })
      }
      .width('100%')

      if (this.planOf(pet.id)?.status === 'ready') {
        Row() {
          Icon({ name: 'utensils-crossed', iconSize: 14, color: FG.inkMuted })
          Text(this.planOf(pet.id)?.foodName ?? '')
            .fontSize(13)
            .fontColor(FG.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
          if (this.planOf(pet.id)?.plan?.energyEstimated === true) {
            Text('能量估算')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .height(20)
              .padding({ left: 6, right: 6 })
              .border({ width: 1, color: FG.line })
              .borderRadius(6)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12, bottom: 12 })

        Row() {
          Column() {
            this.StatCell('每日喂量', this.round(this.planOf(pet.id)?.plan?.mainFoodGrams), 'g', FG.ink)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            this.StatCell('分餐', this.round(this.planOf(pet.id)?.plan?.gramsPerMeal),
              `g × ${this.planOf(pet.id)?.plan?.mealsPerDay ?? '—'} 餐`, FG.ink)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
        }
        .width('100%')

        Row() {
          Column() {
            this.StatCell('目标能量', this.round(this.planOf(pet.id)?.plan?.merKcal), 'kcal', FG.ink)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            this.StatCell('零食上限', this.round(this.planOf(pet.id)?.plan?.snackBudgetGrams), 'g', FG.ink)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
        }
        .width('100%')
        .margin({ top: 12 })

        if (this.hiddenWarnings(pet.id) > 0 || this.openWarnings.includes(pet.id)) {
          Column({ space: 4 }) {
            ForEach(this.shownWarnings(pet.id), (warning: string, index: number) => {
              Row() {
                Icon({ name: 'triangle-alert', iconSize: 14, color: FG.warning })
                Text(warning)
                  .fontSize(FG.textLabel)
                  .lineHeight(19)
                  .fontColor(FG.warning)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                  .margin({ left: 8 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (warning: string, index: number) => `${pet.id}-${index}-${warning}`)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 12 })
        }

        if (this.hiddenWarnings(pet.id) > 0) {
          Text(this.openWarnings.includes(pet.id) ? '收起' : `展开其余 ${this.hiddenWarnings(pet.id)} 条`)
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .height(32)
            .onClick(() => {
              this.toggleWarnings(pet.id);
            })
        }
      } else if (this.planOf(pet.id)?.status === 'loading') {
        Text('方案计算中…')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(FG.inkMuted)
          .margin({ top: 12 })
      } else {
        Text('食品库里没有可匹配这只宠物的全价主食，先到营养方案页选粮。')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(FG.inkMuted)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReminderRow(petId: number, reminder: Reminder) {
    Row() {
      Text(this.timeOf(reminder))
        .fontFamily(FG.mono)
        .fontSize(13)
        .fontColor(FG.accent)
        .width(42)

      Text(reminder.title)
        .fontSize(13)
        .fontColor(this.isDone(petId, reminder.id) ? FG.inkMuted : FG.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text(this.repeatLabel(reminder))
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .margin({ left: 8 })

      Stack() {
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .border({
            width: 1,
            color: this.isDone(petId, reminder.id) ? FG.accent : FG.line
          })
          .backgroundColor(this.isDone(petId, reminder.id) ? FG.accent : Color.Transparent)
        if (this.isDone(petId, reminder.id)) {
          Icon({ name: 'check', iconSize: 14, color: FG.surface, weight: 2.4 })
        }
      }
      .width(44)
      .height(44)
      .margin({ left: 4 })
      .onClick(() => {
        this.checkIn(petId, reminder);
      })
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  RemindersPanel(pet: Pet) {
    Column() {
      Row() {
        Text('每日提醒')
          .fontFamily(FG.serif)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
        Blank()
        this.PanelButton('提醒管理', 'bell', () => {
          this.goReminders(pet.id);
        })
      }
      .width('100%')

      if (this.dueReminders(pet.id).length > 0) {
        Column() {
          ForEach(this.shownReminders(pet.id), (reminder: Reminder) => {
            this.ReminderRow(pet.id, reminder)
          }, (reminder: Reminder) => `${reminder.id}`)
        }
        .width('100%')
        .margin({ top: 4 })
      } else {
        Text('今天没有需要执行的提醒。')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(FG.inkMuted)
          .margin({ top: 12 })
      }

      if (this.hiddenReminders(pet.id) > 0) {
        Text(this.openReminders.includes(pet.id) ? '收起' : `展开其余 ${this.hiddenReminders(pet.id)} 项`)
          .fontSize(FG.textLabel)
          .fontColor(FG.accent)
          .height(32)
          .margin({ top: 4 })
          .onClick(() => {
            this.toggleReminders(pet.id);
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PetCard(pet: Pet) {
    Column() {
      Row() {
        PetAvatarView({
          avatar: pet.avatar ?? '',
          name: pet.name,
          avatarSize: 96,
          corner: FG.radius,
          textSize: 32
        })

        Column() {
          Row() {
            Text(pet.name)
              .fontFamily(FG.serif)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(FG.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                Text('进入主页')
                  .fontSize(FG.textLabel)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(FG.surface)
                Icon({ name: 'arrow-right', iconSize: 14, color: FG.surface })
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
            }
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor(FG.accent)
            .borderRadius(FG.radius)
            .margin({ left: 8 })
            .onClick(() => {
              this.goPet(pet.id);
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.metaText(pet))
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 8 })

          Row() {
            Column() {
              this.StatCell('体重', this.weightValue(pet.id),
                this.weightOf(pet.id) !== undefined && this.weightOf(pet.id)?.kg !== 0 ? 'kg' : '', FG.ink)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.StatCell('体况 BCS', pet.bcs !== undefined && pet.bcs > 0 ? `${pet.bcs}` : '—',
                pet.bcs !== undefined && pet.bcs > 0 ? '/ 9' : '', this.bcsColor(pet.bcs))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 12 })
          }
          .width('100%')
          .margin({ top: 8 })
          .padding({ top: 8 })
          .border({ width: { top: 1 }, color: FG.line })

          Column() {
            this.StatCell('最近更新', this.lastRecordText(pet), '', FG.ink)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column() {
        this.NutritionPanel(pet)

        Column()
          .width('100%')
          .height(1)
          .backgroundColor(FG.line)
          .margin({ top: 16, bottom: 16 })

        this.RemindersPanel(pet)
      }
      .width('100%')
      .margin({ top: 16 })
      .padding({ top: 16 })
      .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  SkeletonCard() {
    Column() {
      Row() {
        Column()
          .width(96)
          .height(96)
          .backgroundColor(FG.paper)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)

        Column() {
          Column()
            .width('42%')
            .height(16)
            .backgroundColor(FG.paper)
            .borderRadius(4)
          Column()
            .width('64%')
            .height(16)
            .backgroundColor(FG.paper)
            .borderRadius(4)
            .margin({ top: 10 })
          Column()
            .width('100%')
            .height(40)
            .backgroundColor(FG.paper)
            .borderRadius(4)
            .margin({ top: 16 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column()
        .width('100%')
        .height(90)
        .backgroundColor(FG.paper)
        .borderRadius(4)
        .margin({ top: 16 })

      Column()
        .width('100%')
        .height(90)
        .backgroundColor(FG.paper)
        .borderRadius(4)
        .margin({ top: 16 })
    }
    .width('100%')
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  ErrorCallout() {
    Column() {
      Text(this.error)
        .fontSize(FG.textBody)
        .lineHeight(24)
        .fontColor(FG.ink)
        .width('100%')

      Row() {
        Icon({ name: 'rotate-ccw', iconSize: 16, color: FG.ink })
        Text('重试')
          .fontSize(FG.textBody)
          .fontColor(FG.ink)
          .margin({ left: 6 })
      }
      .height(44)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.load();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, top: 12, bottom: 12 })
    .border({ width: { left: 2 }, color: FG.danger })
  }

  @Builder
  Pager() {
    Row() {
      if (this.pets.length > 5) {
        Text(`${this.activeIndex + 1} / ${this.pets.length}`)
          .fontFamily(FG.mono)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
      } else {
        ForEach(this.pets, (pet: Pet, index: number) => {
          Stack() {
            Column()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(index === this.activeIndex ? FG.accent : Color.Transparent)
              .border({ width: 1, color: index === this.activeIndex ? FG.accent : FG.line })
          }
          .width(28)
          .height(28)
          .onClick(() => {
            this.setActive(index);
          })
        }, (pet: Pet) => `dot-${pet.id}`)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 16 })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '我的宠物',
          breadcrumb: '宠物档案',
          description: this.caption(),
          showActions: true
        }) {
          FgButton({
            label: '添加宠物',
            variant: 'primary',
            icon: 'plus',
            onTap: () => {
              Nav.push('Onboarding');
            }
          })
        }

        if (this.loading) {
          this.SkeletonCard()
        } else if (this.error.length > 0) {
          this.ErrorCallout()
        } else if (this.pets.length === 0) {
          Column() {
            EmptyState({ variant: 'pets', description: '还没有宠物档案' })
            FgButton({
              label: '添加第一只宠物',
              variant: 'primary',
              onTap: () => {
                Nav.push('Onboarding');
              }
            })
              .margin({ top: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 32 })
        } else {
          if (this.activePet() !== undefined) {
            this.PetCard(this.activePet() as Pet)
          }
          this.Pager()
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
