import { FG } from '../common/Theme';

class InlineSeg {
  text: string = '';
  bold: boolean = false;
  code: boolean = false;
  link: boolean = false;
}

class MdBlock {
  type: string = 'p';
  level: number = 0;
  text: string = '';
  items: string[] = [];
  rows: string[][] = [];
}

function makeSeg(text: string, bold: boolean, code: boolean, link: boolean): InlineSeg {
  const seg: InlineSeg = new InlineSeg();
  seg.text = text;
  seg.bold = bold;
  seg.code = code;
  seg.link = link;
  return seg;
}

/** 轻量 Markdown 解析：标题 / 段落 / 列表 / 引用 / 代码块 / 表格 / 分隔线 */
function parseInline(text: string): InlineSeg[] {
  const segs: InlineSeg[] = [];
  const pattern: RegExp = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g;
  let last: number = 0;
  let match: RegExpExecArray | null = pattern.exec(text);
  while (match !== null) {
    if (match.index > last) {
      segs.push(makeSeg(text.substring(last, match.index), false, false, false));
    }
    const token: string = match[0];
    if (token.startsWith('**')) {
      segs.push(makeSeg(token.substring(2, token.length - 2), true, false, false));
    } else if (token.startsWith('`')) {
      segs.push(makeSeg(token.substring(1, token.length - 1), false, true, false));
    } else {
      const close: number = token.indexOf('](');
      segs.push(makeSeg(token.substring(1, close), false, false, true));
    }
    last = match.index + token.length;
    match = pattern.exec(text);
  }
  if (last < text.length) {
    segs.push(makeSeg(text.substring(last), false, false, false));
  }
  if (segs.length === 0) {
    segs.push(makeSeg(text, false, false, false));
  }
  return segs;
}

function splitTableRow(line: string): string[] {
  let content: string = line.trim();
  if (content.startsWith('|')) {
    content = content.substring(1);
  }
  if (content.endsWith('|')) {
    content = content.substring(0, content.length - 1);
  }
  return content.split('|').map((cell: string) => cell.trim());
}

function parseMarkdown(content: string): MdBlock[] {
  const lines: string[] = content.replace(/\r\n/g, '\n').split('\n');
  const blocks: MdBlock[] = [];
  let i: number = 0;

  while (i < lines.length) {
    const line: string = lines[i];
    const trimmed: string = line.trim();

    if (trimmed.length === 0) {
      i++;
      continue;
    }

    if (trimmed.startsWith('```')) {
      const block: MdBlock = new MdBlock();
      block.type = 'code';
      i++;
      const code: string[] = [];
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.push(lines[i]);
        i++;
      }
      i++;
      block.text = code.join('\n');
      blocks.push(block);
      continue;
    }

    const heading: RegExpMatchArray | null = trimmed.match(/^(#{1,4})\s+(.*)$/);
    if (heading !== null) {
      const block: MdBlock = new MdBlock();
      block.type = 'h';
      block.level = heading[1].length;
      block.text = heading[2];
      blocks.push(block);
      i++;
      continue;
    }

    if (/^(-{3,}|\*{3,})$/.test(trimmed)) {
      const block: MdBlock = new MdBlock();
      block.type = 'hr';
      blocks.push(block);
      i++;
      continue;
    }

    if (trimmed.startsWith('|')) {
      const tableLines: string[] = [];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        tableLines.push(lines[i]);
        i++;
      }
      const block: MdBlock = new MdBlock();
      block.type = 'table';
      tableLines.forEach((row: string, idx: number) => {
        if (idx === 1 && row.indexOf('---') >= 0) {
          return;
        }
        block.rows.push(splitTableRow(row));
      });
      blocks.push(block);
      continue;
    }

    if (trimmed.startsWith('>')) {
      const quotes: string[] = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quotes.push(lines[i].trim().replace(/^>\s?/, ''));
        i++;
      }
      const block: MdBlock = new MdBlock();
      block.type = 'quote';
      block.text = quotes.join('\n');
      blocks.push(block);
      continue;
    }

    const listMatch: RegExpMatchArray | null = trimmed.match(/^([-*+]|\d+\.)\s+(.*)$/);
    if (listMatch !== null) {
      const ordered: boolean = /^\d+\.$/.test(listMatch[1]);
      const block: MdBlock = new MdBlock();
      block.type = ordered ? 'ol' : 'ul';
      while (i < lines.length) {
        const current: RegExpMatchArray | null = lines[i].trim().match(/^([-*+]|\d+\.)\s+(.*)$/);
        if (current === null) {
          break;
        }
        block.items.push(current[2]);
        i++;
      }
      blocks.push(block);
      continue;
    }

    const paragraph: string[] = [];
    while (i < lines.length) {
      const current: string = lines[i].trim();
      if (current.length === 0 || current.startsWith('#') || current.startsWith('>') ||
        current.startsWith('|') || current.startsWith('```') ||
        /^([-*+]|\d+\.)\s+/.test(current) || /^(-{3,}|\*{3,})$/.test(current)) {
        break;
      }
      paragraph.push(current);
      i++;
    }
    const block: MdBlock = new MdBlock();
    block.type = 'p';
    block.text = paragraph.join('\n');
    blocks.push(block);
  }
  return blocks;
}

@Component
export struct MarkdownView {
  @Prop @Watch('onContentChange') content: string = '';
  @State private blocks: MdBlock[] = [];
  fontSize: number = FG.textLead;
  textColor: string = FG.ink;

  aboutToAppear(): void {
    this.blocks = parseMarkdown(this.content);
  }

  onContentChange(): void {
    this.blocks = parseMarkdown(this.content);
  }

  private headingSize(level: number): number {
    if (level <= 1) {
      return this.fontSize + 8;
    }
    if (level === 2) {
      return this.fontSize + 4;
    }
    if (level === 3) {
      return this.fontSize + 2;
    }
    return this.fontSize;
  }

  @Builder
  inlineText(text: string, size: number, color: string, lineHeight: number) {
    Text() {
      ForEach(parseInline(text), (seg: InlineSeg, index: number) => {
        if (seg.code) {
          Span(seg.text)
            .fontFamily(FG.mono)
            .fontSize(size - 1)
            .fontColor(FG.accent)
        } else if (seg.bold) {
          Span(seg.text)
            .fontSize(size)
            .fontWeight(FontWeight.Bold)
            .fontColor(color)
        } else if (seg.link) {
          Span(seg.text)
            .fontSize(size)
            .fontColor(FG.accent)
            .decoration({ type: TextDecorationType.Underline })
        } else {
          Span(seg.text)
            .fontSize(size)
            .fontColor(color)
        }
      }, (seg: InlineSeg, index: number) => `${index}-${seg.text}`)
    }
    .fontSize(size)
    .fontColor(color)
    .lineHeight(lineHeight)
    .width('100%')
  }

  @Builder
  blockView(block: MdBlock) {
    if (block.type === 'h') {
      Text() {
        ForEach(parseInline(block.text), (seg: InlineSeg, index: number) => {
          Span(seg.text)
            .fontFamily(FG.serif)
            .fontSize(this.headingSize(block.level))
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
        }, (seg: InlineSeg, index: number) => `${index}-${seg.text}`)
      }
      .lineHeight(this.headingSize(block.level) * 1.4)
      .margin({ top: 14, bottom: 6 })
      .width('100%')
    } else if (block.type === 'code') {
      Text(block.text)
        .fontFamily(FG.mono)
        .fontSize(12)
        .fontColor(FG.ink)
        .lineHeight(20)
        .width('100%')
        .padding(12)
        .backgroundColor(FG.paper)
        .border({ width: 1, color: FG.line })
        .borderRadius(FG.radius)
        .margin({ top: 4, bottom: 12 })
    } else if (block.type === 'hr') {
      Divider()
        .color(FG.line)
        .strokeWidth(1)
        .margin({ top: 16, bottom: 16 })
    } else if (block.type === 'quote') {
      Row() {
        Column()
          .width(2)
          .backgroundColor(FG.lineStrong)
          .alignSelf(ItemAlign.Stretch)
        Column() {
          this.inlineText(block.text, FG.textBody, FG.inkMuted, 24)
        }
        .layoutWeight(1)
        .padding({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ bottom: 12 })
    } else if (block.type === 'ul' || block.type === 'ol') {
      Column() {
        ForEach(block.items, (item: string, index: number) => {
          Row() {
            Text(block.type === 'ol' ? `${index + 1}.` : '•')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .width(20)
            this.inlineText(item, FG.textBody, FG.ink, 24)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          .margin({ bottom: 4 })
        }, (item: string, index: number) => `${index}-${item}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .margin({ bottom: 10 })
    } else if (block.type === 'table') {
      Column() {
        ForEach(block.rows, (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (cell: string, cellIndex: number) => {
              Text(cell)
                .fontSize(12)
                .fontWeight(rowIndex === 0 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(rowIndex === 0 ? FG.ink : FG.ink)
                .layoutWeight(1)
                .padding({ left: 8, right: 8, top: 7, bottom: 7 })
                .border({ width: { right: cellIndex < row.length - 1 ? 1 : 0 }, color: FG.line })
            }, (cell: string, cellIndex: number) => `${cellIndex}-${cell}`)
          }
          .width('100%')
          .backgroundColor(rowIndex === 0 ? FG.paper : FG.surface)
          .border({ width: { bottom: 1 }, color: FG.line })
        }, (row: string[], rowIndex: number) => `${rowIndex}-${row.join('|')}`)
      }
      .width('100%')
      .border({ width: 1, color: FG.line })
      .borderRadius(4)
      .clip(true)
      .margin({ bottom: 12 })
    } else {
      Column() {
        this.inlineText(block.text, this.fontSize, this.textColor, this.fontSize * 1.75)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 10 })
    }
  }

  build() {
    Column() {
      ForEach(this.blocks, (block: MdBlock, index: number) => {
        this.blockView(block)
      }, (block: MdBlock, index: number) => `${index}-${block.type}`)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
