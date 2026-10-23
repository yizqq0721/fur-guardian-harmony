import { FG } from '../common/Theme';
import { iconPaths } from './IconData';

/** Lucide 线性图标（24 viewBox），颜色、线宽可跟随页面 token */
@Component
export struct Icon {
  name: string = 'paw-print';
  iconSize: number = 16;
  color: string = FG.ink;
  weight: number = 1.5;

  build() {
    Shape() {
      ForEach(iconPaths(this.name), (d: string, index: number) => {
        Path()
          .commands(d)
          .stroke(this.color)
          .strokeWidth(this.weight)
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
          .fill(Color.Transparent)
      }, (d: string, index: number) => `${index}-${d}`)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .viewPort({ x: 0, y: 0, width: 24, height: 24 })
  }
}
