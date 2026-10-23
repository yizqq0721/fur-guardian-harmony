import { FG } from '../common/Theme';
import { Icon } from './Icon';

export type FgButtonVariant = 'primary' | 'secondary' | 'text' | 'danger';

/** 与 Element Plus 主题一致的按钮：8px 圆角、无阴影、移动端 44vp 触摸高度 */
@Component
export struct FgButton {
  label: string = '';
  variant: FgButtonVariant = 'primary';
  icon: string = '';
  small: boolean = false;
  disabled: boolean = false;
  loading: boolean = false;
  fillWidth: boolean = false;
  onTap: () => void = () => {
  };

  private bg(): string {
    if (this.variant === 'primary') {
      return FG.accent;
    }
    if (this.variant === 'danger') {
      return FG.danger;
    }
    return '#00000000';
  }

  private fg(): string {
    if (this.variant === 'primary' || this.variant === 'danger') {
      return FG.surface;
    }
    if (this.variant === 'text') {
      return FG.accent;
    }
    return FG.ink;
  }

  private borderStroke(): string {
    return this.variant === 'secondary' ? FG.lineStrong : '#00000000';
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: !this.disabled && !this.loading }) {
      Row() {
        if (this.loading) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(this.fg())
            .margin({ right: 6 })
        } else if (this.icon !== '') {
          Icon({ name: this.icon, iconSize: this.small ? 14 : 16, color: this.fg() })
            .margin({ right: 6 })
        }
        Text(this.label)
          .fontSize(this.small ? 13 : 14)
          .fontWeight(this.variant === 'primary' ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.fg())
      }
      .alignItems(VerticalAlign.Center)
    }
    .height(44)
    .constraintSize({ minWidth: this.fillWidth ? '100%' : 0 })
    .padding({ left: this.small ? 10 : 16, right: this.small ? 10 : 16 })
    .borderRadius(this.small ? 6 : FG.radius)
    .backgroundColor(this.bg())
    .border({ width: 1, color: this.borderStroke() })
    .enabled(!this.disabled && !this.loading)
    .opacity(this.disabled ? 0.55 : 1)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onTap();
      }
    })
  }
}
