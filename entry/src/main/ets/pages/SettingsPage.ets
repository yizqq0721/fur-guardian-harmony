import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { UserApi } from '../api/Api';
import { FG } from '../common/Theme';
import { FgButton } from '../components/FgButton';
import { FgInput } from '../components/FgInput';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { SeverityDot } from '../components/SeverityDot';
import { MailSettings, Pet } from '../models/Types';
import { UserStore } from '../stores/UserStore';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

/** 设置：账号概览、通知/邮件提醒与应用信息 */
@Component
export struct SettingsPage {
  @StorageLink('fg_nickname') nickname: string = '';
  @StorageLink('fg_location') location: string = '';
  @StorageLink('fg_userId') userId: number = 0;
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_inAppNotify') inAppNotify: boolean = true;
  @State private notificationGranted: boolean = false;
  @State private email: string = '';
  @State private emailEnabled: boolean = false;
  @State private savingMail: boolean = false;

  aboutToAppear(): void {
    this.checkNotification();
    this.loadMailSettings();
  }

  private async checkNotification(): Promise<void> {
    try {
      this.notificationGranted = await notificationManager.isNotificationEnabled();
    } catch (err) {
      this.notificationGranted = false;
      console.warn(`check notification failed: ${JSON.stringify(err)}`);
    }
  }

  private requestNotification(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    notificationManager.requestEnableNotification(context).then(() => {
      this.notificationGranted = true;
      showToast('通知已开启');
    }).catch((err: Object) => {
      console.warn(`request notification failed: ${JSON.stringify(err)}`);
      this.notificationGranted = false;
      showToast('通知未开启，可在系统设置中允许通知');
    });
  }

  private async sendTest(): Promise<void> {
    if (this.inAppNotify) {
      showToast('测试通知：到点的提醒会这样提醒你');
    }
    if (!this.notificationGranted) {
      this.requestNotification();
      return;
    }
    const request: notificationManager.NotificationRequest = {
      id: 1001,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: 'FurGuardian 测试通知',
          text: '到点的提醒将同时出现在站内和系统通知中。'
        }
      }
    };
    try {
      await notificationManager.publish(request);
      showToast('测试通知已发送');
    } catch (err) {
      console.warn(`publish notification failed: ${JSON.stringify(err)}`);
      showToast('测试通知发送失败，请检查通知权限');
    }
  }

  private onInAppNotifyChange(value: boolean): void {
    this.inAppNotify = value;
    AppStorage.setOrCreate('fg_inAppNotify', value);
    showToast(value ? '站内提醒已开启' : '站内提醒已关闭');
  }

  private async loadMailSettings(): Promise<void> {
    try {
      const settings: MailSettings = await UserApi.mailSettings();
      this.email = settings.email;
      this.emailEnabled = settings.enabled;
    } catch (err) {
      console.warn(`load mail settings failed: ${JSON.stringify(err)}`);
    }
  }

  private async saveEmail(): Promise<void> {
    this.savingMail = true;
    try {
      const value: string = this.email.trim();
      const settings: MailSettings = await UserApi.updateMailSettings({
        email: value,
        enabled: value.length > 0 ? this.emailEnabled : false
      });
      this.email = settings.email;
      this.emailEnabled = settings.enabled;
      showToast(value.length > 0 ? '邮箱已保存' : '邮箱已清除，邮件提醒已关闭');
    } catch (err) {
      console.warn(`save mail settings failed: ${JSON.stringify(err)}`);
    } finally {
      this.savingMail = false;
    }
  }

  private async toggleEmail(value: boolean): Promise<void> {
    if (value && this.email.trim().length === 0) {
      this.emailEnabled = false;
      showToast('请先填写邮箱并保存');
      return;
    }
    const previous: boolean = this.emailEnabled;
    this.emailEnabled = value;
    this.savingMail = true;
    try {
      const settings: MailSettings = await UserApi.updateMailSettings({
        email: this.email.trim(),
        enabled: value
      });
      this.emailEnabled = settings.enabled;
      showToast(value ? '邮件提醒已开启' : '邮件提醒已关闭');
    } catch (err) {
      this.emailEnabled = previous;
      console.warn(`toggle mail settings failed: ${JSON.stringify(err)}`);
    } finally {
      this.savingMail = false;
    }
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '提示',
      message: '确定退出登录吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出登录',
        fontColor: FG.danger,
        action: () => {
          UserStore.logout().catch((err: Object) => {
            console.warn(`logout failed: ${JSON.stringify(err)}`);
          });
          AppStorage.setOrCreate('fg_activeTab', 0);
          AppStorage.setOrCreate('fg_drawerOpen', false);
          Nav.clear();
        }
      }
    });
  }

  @Builder
  SectionTitle(icon: string, title: string) {
    Row() {
      Icon({ name: icon, iconSize: 20, color: FG.inkMuted })
      Text(title)
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Medium)
        .fontColor(FG.ink)
        .margin({ left: 8 })
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  RowText(label: string, desc: string) {
    Column() {
      Text(label)
        .fontSize(FG.textBody)
        .fontColor(FG.ink)
        .width('100%')
      if (desc.length > 0) {
        Text(desc)
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 3 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  SimpleRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FG.textBody)
        .fontColor(FG.ink)
        .layoutWeight(1)
      Text(value.length > 0 ? value : '—')
        .fontSize(FG.textBody)
        .fontColor(FG.ink)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '设置',
          breadcrumb: '账号 / 设置',
          description: '账号信息与通知授权，仅影响本机的提醒体验。',
          backLabel: '返回',
          onBack: () => {
            Nav.pop();
          }
        })

        Column() {
          this.SectionTitle('user', '账号')
          this.SimpleRow('昵称', this.nickname)
          Row() {
            this.RowText('当前位置', '顶部天气与遛弯建议按该位置查询')
            Row() {
              Text(this.location.length > 0 ? this.location : '未定位')
                .fontSize(FG.textBody)
                .fontColor(FG.ink)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 120 })
              FgButton({
                label: '定位',
                variant: 'secondary',
                small: true,
                onTap: () => {
                  Nav.push('UserProfile');
                }
              })
                .margin({ left: 8 })
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: FG.line })
          .alignItems(VerticalAlign.Center)
          this.SimpleRow('用户 ID', `${this.userId}`)
          this.SimpleRow('宠物数量', `${this.pets.length} 只`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column() {
          this.SectionTitle('bell', '通知')

          Row() {
            this.RowText('系统通知', '授权后，到点的提醒可通过系统通知推送')
            Row() {
              SeverityDot({ level: this.notificationGranted ? 'success' : 'info' })
              FgButton({
                label: this.notificationGranted ? '已授权' : '开启通知',
                variant: this.notificationGranted ? 'secondary' : 'primary',
                small: true,
                disabled: this.notificationGranted,
                onTap: () => {
                  this.requestNotification();
                }
              })
                .margin({ left: 8 })
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: FG.line })
          .alignItems(VerticalAlign.Center)

          Row() {
            this.RowText('站内提醒', '打开应用时，到点的待办会弹出提示')
            Toggle({ type: ToggleType.Switch, isOn: this.inAppNotify })
              .selectedColor(FG.accent)
              .onChange((isOn: boolean) => {
                this.onInAppNotifyChange(isOn);
              })
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: FG.line })
          .alignItems(VerticalAlign.Center)

          Row() {
            this.RowText('测试通知', '确认当前设备能否正常收到提醒')
            FgButton({
              label: '发送测试',
              variant: 'secondary',
              small: true,
              onTap: () => {
                this.sendTest();
              }
            })
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .alignItems(VerticalAlign.Center)

          Text('邮件提醒')
            .fontFamily(FG.serif)
            .fontSize(FG.textLead)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.ink)
            .width('100%')
            .margin({ top: 16 })

          Text('到点后把待办发到邮箱，适合不常打开应用的日子。需要服务端配置 SMTP 后才会真正发信。')
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ top: 4, bottom: 12 })

          Text('接收邮箱')
            .fontSize(FG.textLabel)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(0.5)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ bottom: 6 })

          Row() {
            Column() {
              FgInput({
                value: this.email,
                placeholder: 'you@example.com',
                maxLength: 120,
                onChange: (value: string) => {
                  this.email = value;
                }
              })
            }
            .layoutWeight(1)

            FgButton({
              label: '保存',
              variant: 'primary',
              small: true,
              loading: this.savingMail,
              onTap: () => {
                this.saveEmail();
              }
            })
              .margin({ left: 8, bottom: 2 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)

          Text('留空保存会清除邮箱并关闭邮件提醒')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .width('100%')
            .margin({ top: 6 })

          Row() {
            this.RowText('邮件提醒', '按提醒时间发送，已打卡的待办不会重复发送')
            Toggle({ type: ToggleType.Switch, isOn: this.emailEnabled })
              .selectedColor(FG.accent)
              .enabled(this.email.trim().length > 0 && !this.savingMail)
              .onChange((isOn: boolean) => {
                this.toggleEmail(isOn);
              })
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .margin({ top: 8 })
          .border({ width: { top: 1 }, color: FG.line })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 24 })
        .padding({ top: 20 })
        .border({ width: { top: 1 }, color: FG.line })

        Column() {
          this.SectionTitle('info', '关于')
          Text('FurGuardian 是日常营养管理与健康趋势追踪工具，不是兽医诊疗系统。所有营养数值由确定性算法产出，AI 生成内容仅供参考，不构成医疗建议。')
            .fontSize(FG.textBody)
            .lineHeight(25)
            .fontColor(FG.inkMuted)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 24 })
        .padding({ top: 20 })
        .border({ width: { top: 1 }, color: FG.line })

        Row() {
          Row() {
            Icon({ name: 'log-out', iconSize: 20, color: FG.danger })
            Column() {
              Text('退出登录')
                .fontSize(FG.textBody)
                .fontColor(FG.ink)
                .width('100%')
              Text('退出后需要重新登录才能查看宠物档案')
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 8 })
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Center)

          FgButton({
            label: '退出登录',
            variant: 'danger',
            small: true,
            onTap: () => {
              this.confirmLogout();
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
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
