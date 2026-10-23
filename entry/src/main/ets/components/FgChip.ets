import { FG } from '../common/Theme';
import { Icon } from './Icon';

@Component
export struct FgChip {
  label: string = '';
  tone: string = 'default';
  icon: string = '';

  private bg(): string {
    if (this.tone === 'ok') {
      return FG.accentSoft;
    }
    if (this.tone === 'warn') {
      return FG.warningSoft;
    }
    if (this.tone === 'danger') {
      return FG.dangerSoft;
    }
    return FG.paper;
  }

  private fg(): string {
    if (this.tone === 'ok') {
      return FG.accent;
    }
    if (this.tone === 'warn') {
      return FG.warning;
    }
    if (this.tone === 'danger') {
      return FG.danger;
    }
    return FG.inkMuted;
  }

  build() {
    Row() {
      if (this.icon !== '') {
        Icon({ name: this.icon, iconSize: 12, color: this.fg() })
          .margin({ right: 3 })
      }
      Text(this.label)
        .fontSize(FG.textLabel)
        .fontColor(this.fg())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(22)
    .padding({ left: 8, right: 8 })
    .borderRadius(6)
    .backgroundColor(this.bg())
    .border({
      width: this.tone === 'default' ? 1 : 0,
      color: this.tone === 'default' ? FG.line : '#00000000'
    })
    .alignItems(VerticalAlign.Center)
  }
}
