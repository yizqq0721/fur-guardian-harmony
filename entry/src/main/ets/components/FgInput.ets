import { FG } from '../common/Theme';

@Component
export struct FgInput {
  label: string = '';
  @Prop @Watch('onValueChange') value: string = '';
  placeholder: string = '';
  hint: string = '';
  error: string = '';
  password: boolean = false;
  multiline: boolean = false;
  numberOnly: boolean = false;
  maxLength: number = 100;
  editable: boolean = true;
  onChange: (value: string) => void = () => {
  };
  @State private inputText: string = '';
  @State private focused: boolean = false;

  aboutToAppear(): void {
    this.inputText = this.value;
  }

  onValueChange(): void {
    if (this.inputText !== this.value) {
      this.inputText = this.value;
    }
  }

  private borderColor(): string {
    if (this.error !== '') {
      return FG.danger;
    }
    return this.focused ? FG.accent : FG.line;
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

      if (this.multiline) {
        TextArea({ text: this.inputText, placeholder: this.placeholder })
          .width('100%')
          .constraintSize({ minHeight: 88 })
          .fontSize(16)
          .fontColor(FG.ink)
          .placeholderColor(FG.inkMuted)
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: this.borderColor() })
          .padding(12)
          .maxLength(this.maxLength)
          .enabled(this.editable)
          .onChange((value: string) => {
            this.inputText = value;
            this.onChange(value);
          })
          .onFocus(() => {
            this.focused = true;
          })
          .onBlur(() => {
            this.focused = false;
          })
      } else {
        TextInput({ text: this.inputText, placeholder: this.placeholder })
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor(FG.ink)
          .placeholderColor(FG.inkMuted)
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: this.borderColor() })
          .padding({ left: 12, right: 12 })
          .maxLength(this.maxLength)
          .type(this.password ? InputType.Password : (this.numberOnly ? InputType.Number : InputType.Normal))
          .enabled(this.editable)
          .onChange((value: string) => {
            this.inputText = value;
            this.onChange(value);
          })
          .onFocus(() => {
            this.focused = true;
          })
          .onBlur(() => {
            this.focused = false;
          })
      }

      if (this.error !== '') {
        Text(this.error)
          .fontSize(FG.textLabel)
          .fontColor(FG.danger)
          .margin({ top: 6 })
          .width('100%')
      } else if (this.hint !== '') {
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
