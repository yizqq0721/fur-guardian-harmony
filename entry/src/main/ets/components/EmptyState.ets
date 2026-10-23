import { FG } from '../common/Theme';

function circlePath(cx: number, cy: number, r: number): string {
  return `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}`;
}

function artPaths(variant: string): string[] {
  if (variant === 'pets') {
    return [
      'M20 62h56a10 10 0 0 1-4 8H24a10 10 0 0 1-4-8Z',
      'M76 44c0-10 8-16 16-16s14 6 14 14-6 12-12 12',
      circlePath(98, 26, 5)
    ];
  }
  if (variant === 'foods') {
    return [
      'M28 30h34v40a6 6 0 0 1-6 6H34a6 6 0 0 1-6-6V30Z',
      'M34 30v-8h22v8',
      circlePath(86, 42, 14),
      'M96 52l12 12'
    ];
  }
  if (variant === 'search') {
    return [
      'M30 70V40l-6-14 14 8h18l14-8-6 14v30',
      'M44 52h2',
      'M58 52h2',
      'M92 34a10 10 0 0 0-10 10v4',
      circlePath(92, 52, 10),
      'M92 62a10 10 0 0 0 10-10',
      circlePath(92, 72, 1.5)
    ];
  }
  if (variant === 'success') {
    return [
      'M34 74V46c0-10 8-18 18-18s18 8 18 18v28',
      'M34 46l-10-8 4 14',
      'M70 46l10-8-4 14',
      circlePath(46, 52, 1.5),
      circlePath(58, 52, 1.5),
      circlePath(98, 30, 12),
      'M93 30l4 4 7-8'
    ];
  }
  if (variant === 'warning') {
    return [
      'M60 14l26 10v22c0 16-11 26-26 30-15-4-26-14-26-30V24l26-10Z',
      'M44 46h8l4-8 6 14 4-6h10'
    ];
  }
  return [
    'M26 22h68v46H26Z',
    'M26 38h68'
  ];
}

@Component
export struct EmptyState {
  description: string = '';
  variant: string = 'default';

  build() {
    Column() {
      Shape() {
        ForEach(artPaths(this.variant), (d: string, index: number) => {
          Path()
            .commands(d)
            .stroke(FG.accent)
            .strokeWidth(1.5)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .fill(Color.Transparent)
        }, (d: string, index: number) => `${index}-${d}`)
      }
      .width(120)
      .height(90)
      .viewPort({ x: 0, y: 0, width: 120, height: 90 })
      .opacity(0.55)

      Text(this.description)
        .fontSize(15)
        .fontColor(FG.inkMuted)
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 24, bottom: 24 })
  }
}
