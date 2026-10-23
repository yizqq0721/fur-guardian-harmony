import { PetApi } from '../api/Api';
import { FG } from '../common/Theme';
import { BcsReference } from '../components/BcsReference';
import { BcsScale } from '../components/BcsScale';
import { FgButton } from '../components/FgButton';
import { FgInput } from '../components/FgInput';
import { FgSelect } from '../components/FgSelect';
import { Icon } from '../components/Icon';
import { PetAvatarPicker } from '../components/PetAvatarPicker';
import { ActivityLevel, PetForm, Physiology, SelectOption, Sex, Species } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { ACTIVITY_OPTIONS, PHYSIOLOGY_OPTIONS } from '../utils/Constants';
import { todayText, ymd } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { avatarBelongsToSpecies, isRemoteAvatar } from '../utils/PetAvatar';

interface SpeciesOption {
  value: Species;
  label: string;
  icon: string;
}

interface SegmentOption {
  value: string;
  label: string;
}

const SPECIES_OPTIONS: SpeciesOption[] = [
  { value: 'dog', label: '犬', icon: 'dog' },
  { value: 'cat', label: '猫', icon: 'cat' }
];

const SEX_OPTIONS: SegmentOption[] = [
  { value: 'male', label: '男孩' },
  { value: 'female', label: '女孩' }
];

const NEUTERED_OPTIONS: SegmentOption[] = [
  { value: 'true', label: '已绝育' },
  { value: 'false', label: '未绝育' }
];

const STEP_LABELS: string[] = ['基本信息', '身体数据', '体况评分与体重', '创建完成'];

@Component
export struct OnboardingPage {
  @State private step: number = 0;
  @State private name: string = '';
  @State private species: Species = 'dog';
  @State private breed: string = '';
  @State private avatar: string = '';
  @State private sex: Sex = 'male';
  @State private neutered: boolean = true;
  @State private birthday: string = '';
  @State private activityLevel: ActivityLevel = 'LOW';
  @State private physiology: Physiology = 'NORMAL';
  @State private bcs: number = 5;
  @State private weightText: string = '';
  @State private submitting: boolean = false;
  @State private createdPetId: number = 0;

  private canGoNext(): boolean {
    if (this.step === 0) {
      return this.name.trim().length > 0;
    }
    return true;
  }

  private canReproduce(): boolean {
    return this.sex === 'female' && !this.neutered;
  }

  private physiologyOptions(): SelectOption[] {
    if (this.canReproduce()) {
      return PHYSIOLOGY_OPTIONS;
    }
    return PHYSIOLOGY_OPTIONS.filter((option: SelectOption) => option.value === 'NORMAL');
  }

  private normalizePhysiology(): void {
    if (!this.canReproduce()) {
      this.physiology = 'NORMAL';
    }
  }

  private selectSpecies(value: Species): void {
    if (this.species === value) {
      return;
    }
    this.species = value;
    if (this.avatar.length > 0 && !isRemoteAvatar(this.avatar) && !avatarBelongsToSpecies(this.avatar, value)) {
      this.avatar = '';
    }
  }

  private openBirthday(): void {
    const now: Date = new Date();
    const selected: Date = this.birthday.length > 0
      ? new Date(this.birthday.replace(' ', 'T'))
      : new Date(now.getFullYear() - 3, 0, 1);
    DatePickerDialog.show({
      start: new Date(2000, 0, 1),
      end: now,
      selected: selected,
      onDateAccept: (value: Date) => {
        this.birthday = ymd(value);
      }
    });
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.name.trim().length === 0) {
      showToast('请填写宠物名字');
      return;
    }
    let weight: number = 0;
    if (this.weightText.trim().length > 0) {
      weight = Number(this.weightText.trim());
      if (isNaN(weight) || weight < 0.5 || weight > 80) {
        showToast('体重需在 0.5-80 kg 之间');
        return;
      }
      weight = Math.round(weight * 10) / 10;
    }

    this.submitting = true;
    try {
      const form: PetForm = {
        name: this.name.trim(),
        species: this.species,
        breed: this.breed.length > 0 ? this.breed : undefined,
        avatar: this.avatar.length > 0 ? this.avatar : undefined,
        sex: this.sex,
        neutered: this.neutered,
        birthday: this.birthday.length > 0 ? this.birthday : undefined,
        activityLevel: this.activityLevel,
        physiology: this.physiology,
        bcs: this.bcs
      };
      const id: number = await PetApi.create(form);
      this.createdPetId = id;
      if (weight > 0) {
        await PetApi.addWeight(id, {
          weightKg: weight,
          bcs: this.bcs,
          recordedAt: todayText()
        });
      }
      await PetStore.fetchPets(true);
      PetStore.setCurrentPet(id);
      this.step = 3;
    } catch (err) {
      console.error(`create pet failed: ${JSON.stringify(err)}`);
      showToast('创建失败，请稍后重试');
    } finally {
      this.submitting = false;
    }
  }

  private skip(): void {
    Nav.pop();
  }

  private finishToTab(tab: number): void {
    AppStorage.setOrCreate('fg_activeTab', tab);
    Nav.clear();
  }

  @Builder
  FieldLabel(label: string, required: boolean) {
    Row() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontWeight(FontWeight.Medium)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.4)
      if (required) {
        Text('*')
          .fontSize(FG.textLabel)
          .fontColor(FG.danger)
          .margin({ left: 2 })
      }
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  @Builder
  SpeciesButton(option: SpeciesOption) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        Icon({
          name: option.icon,
          iconSize: 24,
          color: this.species === option.value ? FG.accent : FG.ink
        })
        Text(option.label)
          .fontSize(FG.textLead)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.species === option.value ? FG.accent : FG.ink)
          .margin({ left: 12 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .backgroundColor(this.species === option.value ? FG.accentSoft : FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: this.species === option.value ? FG.accent : FG.line })
    .onClick(() => {
      this.selectSpecies(option.value);
    })
  }

  @Builder
  SegmentButton(label: string, active: boolean, onSelect: () => void) {
    Text(label)
      .fontSize(FG.textBody)
      .fontWeight(FontWeight.Medium)
      .fontColor(active ? FG.accent : FG.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(44)
      .backgroundColor(active ? FG.accentSoft : FG.surface)
      .borderRadius(FG.radius)
      .border({ width: 1, color: active ? FG.accent : FG.line })
      .onClick(() => {
        onSelect();
      })
  }

  @Builder
  Header() {
    Column() {
      Text('创建你的第一个宠物档案')
        .fontSize(FG.textLabel)
        .letterSpacing(0.5)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ bottom: 8 })

      Text(`${this.step + 1} / 4`)
        .fontFamily(FG.mono)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')

      Row() {
        Column()
          .width(`${(this.step + 1) * 25}%`)
          .height('100%')
          .backgroundColor(FG.accent)
      }
      .width('100%')
      .height(2)
      .backgroundColor(FG.line)
      .margin({ top: 8 })

      Text(STEP_LABELS[this.step])
        .fontFamily(FG.serif)
        .fontSize(FG.textH2)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .margin({ top: 16, bottom: 8 })

      if (this.step < 3) {
        Text('只需 4 步，完成后即可生成个体化营养方案。所有信息之后都可以修改。')
          .fontSize(FG.textBody)
          .lineHeight(24)
          .fontColor(FG.inkMuted)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 16 })
    .border({ width: { bottom: 1 }, color: FG.line })
  }

  @Builder
  StepBasic() {
    Column() {
      this.FieldLabel('它叫什么名字？', true)
      FgInput({
        value: this.name,
        placeholder: '例如：豆豆',
        maxLength: 20,
        onChange: (value: string) => {
          this.name = value;
        }
      })
        .margin({ bottom: 16 })

      this.FieldLabel('物种', true)
      Column({ space: 12 }) {
        ForEach(SPECIES_OPTIONS, (option: SpeciesOption) => {
          this.SpeciesButton(option)
        }, (option: SpeciesOption) => option.value)
      }
      .width('100%')
      .margin({ bottom: 16 })

      this.FieldLabel('头像（选填）', false)
      PetAvatarPicker({
        value: this.avatar,
        species: this.species,
        onChange: (value: string) => {
          this.avatar = value;
        }
      })
        .margin({ bottom: 16 })

      this.FieldLabel('品种', false)
      FgInput({
        value: this.breed,
        placeholder: '例如：玩具贵宾 / 英短（选填）',
        maxLength: 50,
        onChange: (value: string) => {
          this.breed = value;
        }
      })
        .margin({ bottom: 16 })

      this.FieldLabel('性别', true)
      Row({ space: 8 }) {
        ForEach(SEX_OPTIONS, (option: SegmentOption) => {
          this.SegmentButton(option.label, this.sex === option.value, () => {
            this.sex = option.value as Sex;
            this.normalizePhysiology();
          })
        }, (option: SegmentOption) => option.value)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 24 })
  }

  @Builder
  StepBody() {
    Column() {
      this.FieldLabel('出生日期', false)
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          Text(this.birthday.length > 0 ? this.birthday : '不记得准确日期可估计')
            .fontSize(16)
            .fontColor(this.birthday.length > 0 ? FG.ink : '#A3A6AC')
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
      .margin({ bottom: 16 })
      .onClick(() => {
        this.openBirthday();
      })

      this.FieldLabel('是否绝育', false)
      Row({ space: 8 }) {
        ForEach(NEUTERED_OPTIONS, (option: SegmentOption) => {
          this.SegmentButton(option.label, this.neutered === (option.value === 'true'), () => {
            this.neutered = option.value === 'true';
            this.normalizePhysiology();
          })
        }, (option: SegmentOption) => option.value)
      }
      .width('100%')
      .margin({ bottom: 16 })

      this.FieldLabel('活动量', false)
      FgSelect({
        value: this.activityLevel,
        options: ACTIVITY_OPTIONS,
        onChange: (value: string) => {
          this.activityLevel = value as ActivityLevel;
        }
      })
        .margin({ bottom: 16 })

      this.FieldLabel('生理状态', false)
      FgSelect({
        value: this.physiology,
        options: this.physiologyOptions(),
        onChange: (value: string) => {
          this.physiology = value as Physiology;
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 24 })
  }

  @Builder
  StepBcs() {
    Column() {
      Text('体况评分 BCS（9 分制）：俯视和侧视观察宠物的腰线与肋骨触感，选择最接近的一档。4-5 分为理想体态。')
        .fontSize(FG.textBody)
        .lineHeight(24)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ bottom: 16 })

      BcsScale({
        value: this.bcs,
        onChange: (value: number) => {
          this.bcs = value;
        }
      })

      BcsReference({ species: this.species })
        .margin({ bottom: 24 })

      this.FieldLabel('当前体重 (kg)', false)
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

      Text('选填，用于生成首条体重记录')
        .fontSize(FG.textLabel)
        .lineHeight(18)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 24 })
  }

  @Builder
  StepDone() {
    Column() {
      Icon({ name: 'circle-check', iconSize: 24, color: FG.accent })
      Text(`${this.name} 的档案已创建`)
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .margin({ top: 16, bottom: 8 })
      Text('接下来去录入主粮，就能生成每日喂食方案了。')
        .fontSize(FG.textBody)
        .lineHeight(24)
        .fontColor(FG.inkMuted)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 24 })
  }

  @Builder
  Footer() {
    Row() {
      Row() {
        if (this.step > 0 && this.step < 3) {
          Text('上一步')
            .fontSize(FG.textBody)
            .fontColor(FG.accent)
            .height(44)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.step -= 1;
            })
        }
      }

      Blank()

      Row({ space: 12 }) {
        if (this.step < 3) {
          Text('跳过引导')
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .height(44)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              this.skip();
            })
        }

        if (this.step < 2) {
          FgButton({
            label: '继续',
            variant: 'primary',
            disabled: !this.canGoNext(),
            onTap: () => {
              if (this.canGoNext()) {
                this.step += 1;
              }
            }
          })
        } else if (this.step === 2) {
          FgButton({
            label: '创建档案',
            variant: 'primary',
            loading: this.submitting,
            onTap: () => {
              this.submit();
            }
          })
        } else {
          FgButton({
            label: '去录入主粮',
            variant: 'primary',
            onTap: () => {
              this.finishToTab(1);
            }
          })
          FgButton({
            label: '先看看主页',
            variant: 'secondary',
            onTap: () => {
              this.finishToTab(0);
            }
          })
        }
      }
    }
    .width('100%')
    .margin({ top: 24 })
    .padding({ top: 16 })
    .border({ width: { top: 1 }, color: FG.line })
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          this.Header()

          if (this.step === 0) {
            this.StepBasic()
          } else if (this.step === 1) {
            this.StepBody()
          } else if (this.step === 2) {
            this.StepBcs()
          } else {
            this.StepDone()
          }

          this.Footer()
        }
        .width('100%')
        .constraintSize({ maxWidth: 560 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16, top: 24, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
