import { FG } from '../common/Theme';
import { SourceChip } from '../components/SourceChip';
import { StatTile } from '../components/StatTile';
import { ApiError, showToast } from '../utils/Http';
import { UserStore } from '../stores/UserStore';

class PreviewMetric {
  label: string;
  value: string;
  unit: string;
  caption: string;

  constructor(label: string, value: string, unit: string, caption: string) {
    this.label = label;
    this.value = value;
    this.unit = unit;
    this.caption = caption;
  }
}

const PREVIEW_METRICS: PreviewMetric[] = [
  new PreviewMetric('RER 静息能量需求', '234', 'kcal/日', '70 × 5.1^0.75'),
  new PreviewMetric('MER 每日维持能量', '337', 'kcal/日', '× 1.44 系数'),
  new PreviewMetric('每日主粮', '79', 'g/日', '≈ 39 g/餐 × 2 餐')
];

@Component
export struct AuthPage {
  @State mode: string = 'login';
  @State username: string = '';
  @State password: string = '';
  @State nickname: string = '';
  @State loading: boolean = false;
  @State errorMessage: string = '';

  private toggleMode(): void {
    this.mode = this.mode === 'login' ? 'register' : 'login';
    this.errorMessage = '';
  }

  private validate(): boolean {
    if (this.username.length === 0) {
      this.errorMessage = '请输入账号';
      return false;
    }
    if (this.password.length === 0) {
      this.errorMessage = '请输入密码';
      return false;
    }
    if (this.mode === 'register') {
      if (this.username.length < 3 || this.username.length > 50) {
        this.errorMessage = '账号长度 3-50 个字符';
        return false;
      }
      if (this.password.length < 6 || this.password.length > 50) {
        this.errorMessage = '密码长度 6-50 个字符';
        return false;
      }
    }
    return true;
  }

  private async submit(): Promise<void> {
    if (this.loading || !this.validate()) {
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      if (this.mode === 'login') {
        await UserStore.login(this.username, this.password);
        showToast('登录成功');
      } else {
        await UserStore.register(this.username, this.password, this.nickname);
        await UserStore.login(this.username, this.password);
        AppStorage.setOrCreate('fg_pendingOnboarding', true);
        showToast('注册成功，已自动登录');
      }
    } catch (err) {
      const error: ApiError = err as ApiError;
      this.errorMessage = error.message !== undefined && error.message.length > 0 ? error.message : '操作失败，请稍后再试';
      if (this.mode === 'login') {
        showToast(this.errorMessage);
      }
    } finally {
      this.loading = false;
    }
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontWeight(FontWeight.Medium)
      .fontColor(FG.inkMuted)
      .letterSpacing(0.4)
      .margin({ bottom: 6 })
  }

  @Builder
  PreviewPanel() {
    Column() {
      Text('方案预览 · 示例数据')
        .fontSize(FG.textLabel)
        .fontWeight(FontWeight.Medium)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.5)
        .width('100%')

      Text('玩具贵宾 · 5.1 kg · BCS 5/9 · 已绝育')
        .fontFamily(FG.mono)
        .fontSize(12)
        .lineHeight(18)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 8, bottom: 16 })

      ForEach(PREVIEW_METRICS, (item: PreviewMetric, index: number) => {
        if (index > 0) {
          Column()
            .width('100%')
            .height(1)
            .backgroundColor(FG.line)
            .margin({ top: 16, bottom: 16 })
        }
        StatTile({
          label: item.label,
          value: item.value,
          unit: item.unit,
          caption: item.caption
        })
      }, (item: PreviewMetric) => item.label)

      Column()
        .width('100%')
        .height(1)
        .backgroundColor(FG.line)
        .margin({ top: 16, bottom: 16 })

      Column() {
        SourceChip({ label: 'GB/T 31216-2014' })
        Text('逐项判定该粮是否达标')
          .fontSize(FG.textLabel)
          .lineHeight(18)
          .fontColor(FG.inkMuted)
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: 420 })
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 32 })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Image($r('app.media.ic_paw'))
            .width(20)
            .height(20)
          Text('FurGuardian')
            .fontFamily(FG.serif)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
            .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)

        Text(this.mode === 'login' ? '登录' : '注册')
          .fontFamily(FG.serif)
          .fontSize(FG.textH1)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .margin({ top: FG.s5, bottom: FG.s2 })

        Text(this.mode === 'login'
          ? '进入你的宠物营养工作台，继续上次的方案。'
          : '创建一个账号，4 步生成个体化喂食方案。')
          .fontSize(13)
          .lineHeight(22)
          .fontColor(FG.inkMuted)
          .margin({ bottom: FG.s5 })

        this.FieldLabel('账号')
        TextInput({ text: this.username, placeholder: '请输入账号' })
          .type(InputType.Normal)
          .height(44)
          .fontSize(16)
          .fontColor(FG.ink)
          .placeholderColor('#A3A6AC')
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: FG.line })
          .padding({ left: 12, right: 12 })
          .margin({ bottom: 16 })
          .onChange((value: string) => {
            this.username = value;
          })

        if (this.mode === 'register') {
          this.FieldLabel('昵称')
          TextInput({ text: this.nickname, placeholder: '选填' })
            .type(InputType.Normal)
            .height(44)
            .fontSize(16)
            .fontColor(FG.ink)
            .placeholderColor('#A3A6AC')
            .backgroundColor(FG.surface)
            .borderRadius(FG.radius)
            .border({ width: 1, color: FG.line })
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 16 })
            .onChange((value: string) => {
              this.nickname = value;
            })
        }

        this.FieldLabel('密码')
        TextInput({ text: this.password, placeholder: this.mode === 'login' ? '请输入密码' : '6-50 个字符' })
          .type(InputType.Password)
          .height(44)
          .fontSize(16)
          .fontColor(FG.ink)
          .placeholderColor('#A3A6AC')
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: FG.line })
          .padding({ left: 12, right: 12 })
          .margin({ bottom: 8 })
          .onChange((value: string) => {
            this.password = value;
          })
          .onSubmit(() => {
            this.submit();
          })

        if (this.mode === 'login') {
          Text('演示账号 demo · 密码 demo123')
            .fontFamily(FG.mono)
            .fontSize(12)
            .fontColor(FG.inkMuted)
            .margin({ bottom: 16 })
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(FG.danger)
            .width('100%')
            .margin({ top: 4, bottom: 12 })
        }

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text(this.loading ? (this.mode === 'login' ? '登录中…' : '注册中…') : (this.mode === 'login' ? '登录' : '注册并登录'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .height(44)
        .borderRadius(FG.radius)
        .backgroundColor(this.loading ? '#8FAEA5' : FG.accent)
        .enabled(!this.loading)
        .onClick(() => {
          this.submit();
        })

        Row() {
          Text(this.mode === 'login' ? '还没有账号？' : '已有账号？')
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
          Text(this.mode === 'login' ? '注册' : '登录')
            .fontSize(FG.textBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.accent)
            .margin({ left: 4 })
            .height(44)
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.toggleMode();
            })
        }
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })

        this.PreviewPanel()
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
