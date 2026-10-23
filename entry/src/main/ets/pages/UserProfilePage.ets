import { common } from '@kit.AbilityKit';
import { UserApi } from '../api/Api';
import { FG } from '../common/Theme';
import { FgButton } from '../components/FgButton';
import { FgInput } from '../components/FgInput';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { GeoAddress, UserProfile } from '../models/Types';
import { locateAndSave } from '../utils/Geo';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

/** 用户信息：昵称与当前位置，定位结果用于天气与遛弯建议 */
@Component
export struct UserProfilePage {
  @State private loading: boolean = true;
  @State private saving: boolean = false;
  @State private locating: boolean = false;
  @State private username: string = '';
  @State private userId: number = 0;
  @State private nickname: string = '';
  @State private location: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      const profile: UserProfile = await UserApi.profile();
      this.fill(profile);
    } catch (err) {
      console.warn(`fetch profile failed: ${JSON.stringify(err)}`);
    } finally {
      this.loading = false;
    }
  }

  private fill(profile: UserProfile): void {
    this.userId = profile.userId;
    this.username = profile.username;
    this.nickname = profile.nickname ?? '';
    this.location = profile.location ?? '';
  }

  private async locate(): Promise<void> {
    this.locating = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const address: GeoAddress | null = await locateAndSave(context);
      if (address !== null) {
        this.location = address.label;
      }
    } finally {
      this.locating = false;
    }
  }

  private async save(): Promise<void> {
    this.saving = true;
    try {
      const profile: UserProfile = await UserApi.update({
        nickname: this.nickname,
        location: this.location
      });
      this.fill(profile);
      AppStorage.setOrCreate('fg_nickname', profile.nickname ?? '');
      AppStorage.setOrCreate('fg_location', profile.location ?? '');
      showToast('用户信息已保存');
    } catch (err) {
      console.warn(`update profile failed: ${JSON.stringify(err)}`);
    } finally {
      this.saving = false;
    }
  }

  @Builder
  MetaItem(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(FG.textLabel)
        .letterSpacing(0.4)
        .fontColor(FG.inkMuted)
        .width('100%')
      Text(value.length > 0 ? value : '—')
        .fontSize(FG.textLead)
        .fontColor(FG.ink)
        .width('100%')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '用户信息',
          breadcrumb: '账号 / 用户信息',
          description: '昵称与当前位置；定位结果用于顶部天气和遛弯建议。',
          backLabel: '设置',
          onBack: () => {
            Nav.pop();
          }
        })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 64 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Column() {
            Column() {
              Text('账号')
                .fontFamily(FG.serif)
                .fontSize(FG.textH3)
                .fontWeight(FontWeight.Medium)
                .fontColor(FG.ink)
                .width('100%')
                .margin({ bottom: 12 })

              Row() {
                this.MetaItem('登录账号', this.username)
                this.MetaItem('用户 ID', `${this.userId}`)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column() {
              Text('资料')
                .fontFamily(FG.serif)
                .fontSize(FG.textH3)
                .fontWeight(FontWeight.Medium)
                .fontColor(FG.ink)
                .width('100%')
                .margin({ bottom: 12 })

              FgInput({
                label: '昵称',
                value: this.nickname,
                placeholder: '例如：豆豆爸',
                maxLength: 50,
                hint: `${this.nickname.length} / 50`,
                onChange: (value: string) => {
                  this.nickname = value;
                }
              })

              Text('当前位置')
                .fontSize(FG.textLabel)
                .fontWeight(FontWeight.Medium)
                .letterSpacing(0.5)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ top: 16, bottom: 6 })

              Row() {
                Icon({ name: 'map-pin', iconSize: 15, color: FG.inkMuted })
                Text(this.location.length > 0 ? this.location : '尚未获取位置')
                  .fontSize(FG.textBody)
                  .fontColor(this.location.length > 0 ? FG.ink : FG.inkMuted)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                  .margin({ left: 8 })
                FgButton({
                  label: this.locating ? '定位中…' : (this.location.length > 0 ? '重新定位' : '获取当前位置'),
                  variant: 'secondary',
                  icon: 'locate-fixed',
                  small: true,
                  loading: this.locating,
                  onTap: () => {
                    this.locate();
                  }
                })
              }
              .width('100%')
              .padding({ left: 12, right: 8, top: 6, bottom: 6 })
              .backgroundColor(FG.paper)
              .borderRadius(FG.radius)
              .border({ width: 1, color: FG.line })
              .alignItems(VerticalAlign.Center)

              Text('用于顶部天气与遛弯提醒，只保存到区/县，不记录详细地址。')
                .fontSize(FG.textLabel)
                .lineHeight(19)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ top: 6 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 20 })
            .padding({ top: 20 })
            .border({ width: { top: 1 }, color: FG.line })

            Row() {
              Text('返回设置')
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
                .onClick(() => {
                  Nav.pop();
                })
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
            .margin({ top: 24 })
            .padding({ top: 20 })
            .border({ width: { top: 1 }, color: FG.line })
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(FG.s5)
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: FG.line })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
