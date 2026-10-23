import { PetApi } from '../api/Api';
import { FG } from '../common/Theme';
import { BcsReference } from '../components/BcsReference';
import { BcsScale } from '../components/BcsScale';
import { FgButton } from '../components/FgButton';
import { FgInput } from '../components/FgInput';
import { FgSelect } from '../components/FgSelect';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { PetAvatarPicker } from '../components/PetAvatarPicker';
import { ActivityLevel, Pet, PetForm, Physiology, SelectOption, Sex, Species } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { ACTIVITY_OPTIONS, PHYSIOLOGY_OPTIONS } from '../utils/Constants';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { avatarBelongsToSpecies, isRemoteAvatar } from '../utils/PetAvatar';

@Component
export struct PetProfilePage {
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @State private name: string = '';
  @State private species: Species = 'dog';
  @State private breed: string = '';
  @State private avatar: string = '';
  @State private sex: Sex = 'male';
  @State private neutered: boolean = false;
  @State private birthday: string = '';
  @State private activityLevel: ActivityLevel = 'LOW';
  @State private physiology: Physiology = 'NORMAL';
  @State private bcs: number = 5;
  @State private loading: boolean = true;
  @State private saving: boolean = false;
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
      showToast('未选择宠物');
      Nav.pop();
      return;
    }
    this.petId = id;
    this.loading = true;
    try {
      const pet: Pet = await PetApi.detail(id);
      this.name = pet.name;
      this.species = pet.species;
      this.breed = pet.breed ?? '';
      this.avatar = pet.avatar ?? '';
      this.sex = pet.sex;
      this.neutered = pet.neutered === true || pet.neutered === 1;
      this.birthday = pet.birthday ?? '';
      this.activityLevel = pet.activityLevel ?? 'LOW';
      this.physiology = pet.physiology ?? 'NORMAL';
      this.bcs = pet.bcs ?? 5;
      this.normalizePhysiology();
    } catch (err) {
      console.error(`load pet profile failed: ${JSON.stringify(err)}`);
      showToast('宠物档案加载失败');
    } finally {
      this.loading = false;
    }
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
    const selected: Date = this.birthday.length > 0 ? new Date(this.birthday.replace(' ', 'T')) : new Date(now.getFullYear() - 3, 0, 1);
    DatePickerDialog.show({
      start: new Date(2000, 0, 1),
      end: now,
      selected: isNaN(selected.getTime()) ? now : selected,
      onDateAccept: (value: Date) => {
        this.birthday = `${value.getFullYear()}-${value.getMonth() + 1 < 10 ? '0' : ''}${value.getMonth() + 1}` +
          `-${value.getDate() < 10 ? '0' : ''}${value.getDate()}`;
      }
    });
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.name.trim().length === 0) {
      showToast('请填写昵称');
      return;
    }
    this.saving = true;
    try {
      const form: PetForm = {
        name: this.name.trim(),
        species: this.species,
        breed: this.breed.length > 0 ? this.breed : undefined,
        avatar: this.avatar,
        sex: this.sex,
        neutered: this.neutered,
        birthday: this.birthday.length > 0 ? this.birthday : undefined,
        activityLevel: this.activityLevel,
        physiology: this.physiology,
        bcs: this.bcs
      };
      await PetApi.update(this.petId, form);
      await PetStore.fetchPets(true);
      showToast('已保存');
    } catch (err) {
      console.error(`save pet failed: ${JSON.stringify(err)}`);
    } finally {
      this.saving = false;
    }
  }

  private confirmRemove(): void {
    AlertDialog.show({
      title: '删除确认',
      message: `确定删除「${this.name}」的档案吗？相关的体重记录和提醒将一并删除，此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: FG.danger,
        action: () => {
          this.removePet();
        }
      }
    });
  }

  private async removePet(): Promise<void> {
    try {
      await PetApi.remove(this.petId);
      await PetStore.fetchPets(true);
      showToast('已删除');
      AppStorage.setOrCreate('fg_activeTab', 0);
      Nav.clear();
    } catch (err) {
      console.error(`remove pet failed: ${JSON.stringify(err)}`);
    }
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
  SegmentButton(label: string, iconName: string, active: boolean, onSelect: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        if (iconName !== '') {
          Icon({ name: iconName, iconSize: 20, color: active ? FG.accent : FG.inkMuted })
            .margin({ right: 8 })
        }
        Text(label)
          .fontSize(FG.textBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(active ? FG.accent : FG.ink)
      }
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(44)
    .backgroundColor(active ? FG.accentSoft : FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: active ? FG.accent : FG.line })
    .onClick(onSelect)
  }

  @Builder
  BlockTitle(title: string) {
    Text(title)
      .fontFamily(FG.serif)
      .fontSize(FG.textH3)
      .fontWeight(FontWeight.Bold)
      .fontColor(FG.ink)
      .letterSpacing(-0.2)
      .width('100%')
      .margin({ bottom: 12 })
  }

  @Builder
  DeleteButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text('删除档案')
        .fontSize(FG.textBody)
        .fontColor(FG.danger)
    }
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .onClick(() => {
      this.confirmRemove();
    })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '宠物档案',
          breadcrumb: this.name.length > 0 ? `${this.name} · 档案` : '宠物档案',
          backLabel: '宠物主页',
          description: '这里的每一项都会进入 MER 与营养达标计算，改完记得保存。',
          onBack: () => {
            Nav.pop();
          }
        })

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
        } else {
          Column() {
            Column() {
              this.BlockTitle('基本信息')

              FgInput({
                label: '昵称',
                value: this.name,
                maxLength: 20,
                onChange: (value: string) => {
                  this.name = value;
                }
              })
                .margin({ bottom: 12 })

              FgInput({
                label: '品种',
                value: this.breed,
                maxLength: 50,
                onChange: (value: string) => {
                  this.breed = value;
                }
              })
                .margin({ bottom: 12 })

              this.FieldLabel('物种', true)
              Row({ space: 8 }) {
                this.SegmentButton('犬', 'dog', this.species === 'dog', () => {
                  this.selectSpecies('dog');
                })
                this.SegmentButton('猫', 'cat', this.species === 'cat', () => {
                  this.selectSpecies('cat');
                })
              }
              .width('100%')
              .margin({ bottom: 12 })

              this.FieldLabel('性别', true)
              Row({ space: 8 }) {
                this.SegmentButton('公', '', this.sex === 'male', () => {
                  this.sex = 'male';
                  this.normalizePhysiology();
                })
                this.SegmentButton('母', '', this.sex === 'female', () => {
                  this.sex = 'female';
                  this.normalizePhysiology();
                })
              }
              .width('100%')
              .margin({ bottom: 12 })

              this.FieldLabel('头像', false)
              PetAvatarPicker({
                value: this.avatar,
                species: this.species,
                onChange: (value: string) => {
                  this.avatar = value;
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ bottom: 12 })
            .margin({ bottom: 20 })
            .border({ width: { bottom: 1 }, color: FG.line })

            Column() {
              this.BlockTitle('生理与活动')

              this.FieldLabel('出生日期', false)
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  Text(this.birthday.length > 0 ? this.birthday : '请选择出生日期')
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
              .margin({ bottom: 12 })
              .onClick(() => {
                this.openBirthday();
              })

              this.FieldLabel('是否绝育', false)
              Row({ space: 8 }) {
                this.SegmentButton('已绝育', '', this.neutered, () => {
                  this.neutered = true;
                  this.normalizePhysiology();
                })
                this.SegmentButton('未绝育', '', !this.neutered, () => {
                  this.neutered = false;
                  this.normalizePhysiology();
                })
              }
              .width('100%')
              .margin({ bottom: 12 })

              FgSelect({
                label: '活动量',
                value: this.activityLevel,
                options: ACTIVITY_OPTIONS,
                onChange: (value: string) => {
                  this.activityLevel = value as ActivityLevel;
                }
              })
                .margin({ bottom: 12 })

              FgSelect({
                label: '生理状态',
                value: this.physiology,
                options: this.physiologyOptions(),
                onChange: (value: string) => {
                  this.physiology = value as Physiology;
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ bottom: 12 })
            .margin({ bottom: 20 })
            .border({ width: { bottom: 1 }, color: FG.line })

            Column() {
              this.BlockTitle('体况评分 BCS')
              Text('俯视与侧视观察腰线与肋骨触感，选最接近的一档；4-5 分为理想体态。')
                .fontSize(FG.textLabel)
                .lineHeight(20)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ bottom: 12 })

              BcsScale({
                value: this.bcs,
                onChange: (value: number) => {
                  this.bcs = value;
                }
              })

              BcsReference({ species: this.species })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ bottom: 12 })

            Row() {
              this.DeleteButton()
              Blank()
              FgButton({
                label: '保存修改',
                variant: 'primary',
                loading: this.saving,
                onTap: () => {
                  this.save();
                }
              })
            }
            .width('100%')
            .margin({ top: 16 })
            .padding({ top: 16 })
            .border({ width: { top: 1 }, color: FG.line })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(FG.s4)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)
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
