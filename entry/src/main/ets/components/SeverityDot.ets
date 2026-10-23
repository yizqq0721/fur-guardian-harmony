import { FG } from '../common/Theme';

@Component
export struct SeverityDot {
  level: string = 'info';
  label: string = '';

  private dotColor(): string {
    if (this.level === 'danger') {
      return FG.danger;
    }
    if (this.level === 'warn' || this.level === 'warning') {
      return FG.warning;
    }
    if (this.level === 'success') {
      return FG.success;
    }
    return FG.inkMuted;
  }

  build() {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(this.dotColor())
      if (this.label !== '') {
        Text(this.label)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 8 })
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
