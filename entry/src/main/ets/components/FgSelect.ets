import { FG } from '../common/Theme';
import { SelectOption } from '../models/Types';
import { Icon } from './Icon';

@Component
export struct FgSelect {
  label: string = '';
  value: string = '';
  placeholder: string = '请选择';
  options: SelectOption[] = [];
  hint: string = '';
  onChange: (value: string) => void = () => {
  };

  private selectedLabel(): string {
    const found: SelectOption | undefined = this.options.find((item: SelectOption) => item.value === this.value);
    return found ? found.label : '';
  }

  private menu(): MenuElement[] {
    const items: MenuElement[] = [];
    this.options.forEach((option: SelectOption) => {
      items.push({
        value: option.label,
        action: () => {
          this.onChange(option.value);
        }
      });
    });
    return items;
  }

  build() {
    Column() {
      if (this.label !== '') {
        Text(this.label)
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.5)
          .margin({ bottom: 6 })
          .width('100%')
      }

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          Text(this.selectedLabel() !== '' ? this.selectedLabel() : this.placeholder)
            .fontSize(16)
            .fontColor(this.selectedLabel() !== '' ? FG.ink : FG.inkMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          Icon({ name: 'chevron-down', iconSize: 16, color: FG.inkMuted })
        }
        .width('100%')
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .backgroundColor(FG.surface)
      .borderRadius(FG.radius)
      .border({ width: 1, color: FG.line })
      .bindMenu(this.menu())

      if (this.hint !== '') {
        Text(this.hint)
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .margin({ top: 6 })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
