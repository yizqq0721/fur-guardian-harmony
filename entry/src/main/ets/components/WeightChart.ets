import { FG } from '../common/Theme';
import { WeightLog } from '../models/Types';
import { dateText } from '../utils/Format';

/** 体重折线：无第三方图表库，用 Canvas 复刻原 ECharts 的面积 + 折线 + 末点标注 */
@Component
export struct WeightChart {
  @Prop @Watch('onLogsChange') logs: WeightLog[] = [];
  chartHeight: number = 240;
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private chartW: number = 0;
  private chartH: number = 0;

  onLogsChange(): void {
    this.draw();
  }

  private draw(): void {
    const w: number = this.chartW;
    const h: number = this.chartH;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);
    const logs: WeightLog[] = this.logs.slice().sort((a: WeightLog, b: WeightLog) => a.recordedAt.localeCompare(b.recordedAt));
    if (logs.length === 0) {
      this.ctx.fillStyle = FG.inkMuted;
      this.ctx.font = '13px sans-serif';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('暂无体重记录', w / 2, h / 2);
      return;
    }

    const left: number = 40;
    const right: number = 16;
    const top: number = 30;
    const bottom: number = 26;
    const plotW: number = w - left - right;
    const plotH: number = h - top - bottom;

    let min: number = Math.min(...logs.map((l: WeightLog) => l.weightKg));
    let max: number = Math.max(...logs.map((l: WeightLog) => l.weightKg));
    if (min === max) {
      min -= 1;
      max += 1;
    }
    const pad: number = (max - min) * 0.15;
    min -= pad;
    max += pad;

    const xOf = (i: number): number => logs.length === 1 ? left + plotW / 2 : left + (i * plotW) / (logs.length - 1);
    const yOf = (v: number): number => top + ((max - v) / (max - min)) * plotH;

    this.ctx.font = '11px sans-serif';
    this.ctx.lineWidth = 1;
    for (let i = 0; i < 4; i++) {
      const gy: number = top + (plotH * i) / 3;
      this.ctx.beginPath();
      this.ctx.strokeStyle = FG.line;
      this.ctx.moveTo(left, gy);
      this.ctx.lineTo(w - right, gy);
      this.ctx.stroke();

      const value: number = max - ((max - min) * i) / 3;
      this.ctx.fillStyle = FG.inkMuted;
      this.ctx.textAlign = 'right';
      this.ctx.fillText(value.toFixed(1), left - 8, gy + 4);
    }

    this.ctx.textAlign = 'left';
    this.ctx.fillStyle = FG.inkMuted;
    this.ctx.fillText('kg', 4, 16);

    const labelIdx: number[] = [0, Math.floor((logs.length - 1) / 2), logs.length - 1]
      .filter((v: number, i: number, arr: number[]) => arr.indexOf(v) === i);
    this.ctx.textAlign = 'center';
    labelIdx.forEach((i: number) => {
      this.ctx.fillStyle = FG.inkMuted;
      this.ctx.fillText(dateText(logs[i].recordedAt).substring(5), xOf(i), h - 8);
    });

    this.ctx.beginPath();
    this.ctx.moveTo(xOf(0), yOf(logs[0].weightKg));
    logs.forEach((log: WeightLog, i: number) => {
      if (i > 0) {
        this.ctx.lineTo(xOf(i), yOf(log.weightKg));
      }
    });
    this.ctx.lineTo(xOf(logs.length - 1), top + plotH);
    this.ctx.lineTo(xOf(0), top + plotH);
    this.ctx.closePath();
    this.ctx.fillStyle = FG.accentSoft;
    this.ctx.fill();

    this.ctx.beginPath();
    logs.forEach((log: WeightLog, i: number) => {
      if (i === 0) {
        this.ctx.moveTo(xOf(i), yOf(log.weightKg));
      } else {
        this.ctx.lineTo(xOf(i), yOf(log.weightKg));
      }
    });
    this.ctx.strokeStyle = FG.accent;
    this.ctx.lineWidth = 1.5;
    this.ctx.stroke();

    logs.forEach((log: WeightLog, i: number) => {
      this.ctx.beginPath();
      this.ctx.arc(xOf(i), yOf(log.weightKg), i === logs.length - 1 ? 3.5 : 2, 0, Math.PI * 2);
      this.ctx.fillStyle = FG.accent;
      this.ctx.fill();
    });

    const last: WeightLog = logs[logs.length - 1];
    this.ctx.fillStyle = FG.ink;
    this.ctx.font = 'bold 13px sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(`${last.weightKg} kg`, xOf(logs.length - 1), yOf(last.weightKg) - 10);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartHeight)
      .onReady(() => {
        this.draw();
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const newW: number = Number(newArea.width);
        const newH: number = Number(newArea.height);
        if (newW !== this.chartW || newH !== this.chartH) {
          this.chartW = newW;
          this.chartH = newH;
          this.draw();
        }
      })
  }
}
