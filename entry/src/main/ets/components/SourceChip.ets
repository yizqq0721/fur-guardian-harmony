import { FG } from '../common/Theme';
import { Icon } from './Icon';

@Component
export struct SourceChip {
  label: string = '';

  build() {
    Row() {
      Icon({ name: 'link', iconSize: 12, color: FG.inkMuted })
      Text(this.label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 4 })
        .flexShrink(1)
    }
    .alignItems(VerticalAlign.Center)
    .constraintSize({ maxWidth: '100%' })
  }
}
