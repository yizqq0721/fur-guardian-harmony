import { FG } from '../common/Theme';

export const DEFAULT_DISCLAIMER: string =
  '本内容仅供参考，不构成医疗建议。如宠物出现抽搐、呼吸困难、拒食超过 24 小时等紧急情况，请立即就医。';

@Component
export struct DisclaimerBar {
  text: string = DEFAULT_DISCLAIMER;

  build() {
    Text(this.text)
      .fontSize(FG.textLabel)
      .lineHeight(19)
      .fontColor(FG.inkMuted)
      .width('100%')
      .padding({ top: 12 })
      .margin({ top: 16 })
      .border({ width: { top: 1 }, color: FG.line })
  }
}
