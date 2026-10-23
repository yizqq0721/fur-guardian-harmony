import { pasteboard } from '@kit.BasicServicesKit';
import { AiApi, KnowledgeApi, TipApi } from '../api/Api';
import { FG } from '../common/Theme';
import { DisclaimerBar } from '../components/DisclaimerBar';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { FgSelect } from '../components/FgSelect';
import { Icon } from '../components/Icon';
import { MarkdownView } from '../components/MarkdownView';
import { PageHeader } from '../components/PageHeader';
import { SeverityDot } from '../components/SeverityDot';
import { SourceChip } from '../components/SourceChip';
import {
  AiQueryResp,
  AiSource,
  ChatMessage,
  ChatSession,
  ChatSource,
  CursorPage,
  KnowledgeDoc,
  SelectOption
} from '../models/Types';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';
import { dateText, dateTimeText, monthDayText, timeShort } from '../utils/Format';

const LAST_CHAT_KEY: string = 'fg_lastChatId';
const PAGE_SIZE: number = 10;
const REDLINE_TEXT: string =
  '您描述的症状可能属于紧急情况。请立即带宠物前往最近的宠物医院，本平台不提供居家处理建议。';
const SUGGESTED: string[] = ['幼犬一天喂几顿？', '猫可以喝牛奶吗？', '换粮怎么过渡？', '狗狗掉毛厉害怎么办？'];

class CiteSeg {
  text: string = '';
  cite: number = 0;
}

class ThreadRow {
  kind: string = 'ai';
  key: string = '';
  text: string = '';
  label: string = '';
  message: ChatMessage | null = null;
  segments: CiteSeg[] = [];
}

class SessionGroup {
  label: string = '';
  items: ChatSession[] = [];
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function localNow(): string {
  const now: Date = new Date();
  return `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}T` +
    `${pad2(now.getHours())}:${pad2(now.getMinutes())}:${pad2(now.getSeconds())}`;
}

function parseDate(value: string): Date | null {
  const date: Date = new Date(value.replace(' ', 'T'));
  return isNaN(date.getTime()) ? null : date;
}

function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

@Component
export struct KnowledgePage {
  initialPrompt: string = '';
  showBack: boolean = false;

  @State private mode: string = 'chat';
  @State private sessions: ChatSession[] = [];
  @State private sessionsCursor: string = '';
  @State private sessionsMore: boolean = false;
  @State private loadingSessions: boolean = false;
  @State private loadingMoreSessions: boolean = false;
  @State private sessKeyword: string = '';
  @State private drawerOpen: boolean = false;

  @State private activeId: number = 0;
  @State private messages: ChatMessage[] = [];
  @State private messagesCursor: string = '';
  @State private messagesMore: boolean = false;
  @State private loadingMessages: boolean = false;
  @State private loadingMore: boolean = false;

  @State private draft: string = '';
  @State private asking: boolean = false;
  @State private askingQuestion: string = '';
  @State private askError: string = '';
  @State private persistError: boolean = false;
  @State private renaming: boolean = false;
  @State private renameValue: string = '';

  @State private searchQuery: string = '';
  @State private searchSpecies: string = '';
  @State private searchLifeStage: string = '';
  @State private searching: boolean = false;
  @State private searched: boolean = false;
  @State private docs: KnowledgeDoc[] = [];
  @State private activeTopic: string = '';
  @State private activeDoc: KnowledgeDoc | null = null;

  @StorageLink('fg_currentPetId') currentPetId: number = 0;

  private threadScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.init();
  }

  private async init(): Promise<void> {
    await this.loadSessions();
    const last: number = AppStorage.get<number>(LAST_CHAT_KEY) ?? 0;
    let restore: ChatSession | undefined = this.sessions.find((s: ChatSession) => s.id === last);
    if (restore === undefined && this.sessions.length > 0) {
      restore = this.sessions[0];
    }
    if (restore !== undefined) {
      await this.openChat(restore.id);
    }
    if (this.initialPrompt.length > 0) {
      this.draft = this.initialPrompt.substring(0, 500);
    }
  }

  private petId(): number | undefined {
    return this.currentPetId > 0 ? this.currentPetId : undefined;
  }

  private activeChat(): ChatSession | null {
    const found: ChatSession | undefined = this.sessions.find((s: ChatSession) => s.id === this.activeId);
    return found ?? null;
  }

  private visibleSessions(): ChatSession[] {
    const keyword: string = this.sessKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.sessions;
    }
    return this.sessions.filter((s: ChatSession) => s.title.toLowerCase().includes(keyword));
  }

  private sessionGroups(): SessionGroup[] {
    const groups: SessionGroup[] = [];
    this.visibleSessions().forEach((session: ChatSession) => {
      const label: string = this.groupLabel(session.updatedAt);
      let group: SessionGroup | undefined = groups.find((g: SessionGroup) => g.label === label);
      if (group === undefined) {
        group = new SessionGroup();
        group.label = label;
        groups.push(group);
      }
      group.items.push(session);
    });
    return groups;
  }

  private groupLabel(value: string): string {
    const date: Date | null = parseDate(value);
    if (date === null) {
      return '更早';
    }
    const now: Date = new Date();
    if (sameDay(date, now)) {
      return '今天';
    }
    const yesterday: Date = new Date(now.getTime());
    yesterday.setDate(yesterday.getDate() - 1);
    if (sameDay(date, yesterday)) {
      return '昨天';
    }
    return '更早';
  }

  private timeText(value: string): string {
    const date: Date | null = parseDate(value);
    if (date === null) {
      return value;
    }
    const now: Date = new Date();
    if (sameDay(date, now)) {
      return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
    }
    const yesterday: Date = new Date(now.getTime());
    yesterday.setDate(yesterday.getDate() - 1);
    if (sameDay(date, yesterday)) {
      return '昨天';
    }
    return `${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
  }

  private dayLabel(value: string): string {
    const date: Date | null = parseDate(value);
    if (date === null) {
      return value;
    }
    const now: Date = new Date();
    if (sameDay(date, now)) {
      return '今天';
    }
    const yesterday: Date = new Date(now.getTime());
    yesterday.setDate(yesterday.getDate() - 1);
    if (sameDay(date, yesterday)) {
      return '昨天';
    }
    return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
  }

  private clockText(value: string): string {
    const date: Date | null = parseDate(value);
    if (date === null) {
      return '';
    }
    return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
  }

  private severityLabel(value: string): string {
    return value === 'emergency' ? '紧急' : (value === 'caution' ? '注意' : '科普');
  }

  private severityLevel(value: string): string {
    return value === 'emergency' ? 'danger' : (value === 'caution' ? 'warning' : 'info');
  }

  private sourceTypeLabel(value?: string): string {
    if (value === undefined || value.length === 0) {
      return '知识库';
    }
    if (value === 'standard') {
      return '标准';
    }
    if (value === 'book') {
      return '书籍';
    }
    if (value === 'official') {
      return '官方指南';
    }
    if (value === 'article') {
      return '文章';
    }
    return value;
  }

  private speciesLabel(value?: string): string {
    if (value === undefined) {
      return '';
    }
    return value === 'dog' ? '犬' : (value === 'cat' ? '猫' : (value === 'both' ? '犬猫通用' : value));
  }

  private lifeStageLabel(value?: string): string {
    if (value === undefined) {
      return '';
    }
    const key: string = value.toLowerCase();
    if (key === 'young' || key === 'baby') {
      return '幼年';
    }
    if (key === 'adult') {
      return '成年';
    }
    if (key === 'senior') {
      return '老年';
    }
    if (key === 'all') {
      return '全阶段';
    }
    return value;
  }

  private topicList(field?: string, limit: number = 3): string[] {
    if (field === undefined || field.length === 0) {
      return [];
    }
    return field.split(/[,，、;；]/).map((t: string) => t.trim()).filter((t: string) => t.length > 0).slice(0, limit);
  }

  private plainText(content?: string): string {
    if (content === undefined || content.length === 0) {
      return '';
    }
    return content
      .replace(/```[\s\S]*?```/g, ' ')
      .replace(/!\[[^\]]*]\([^)]*\)/g, ' ')
      .replace(/\[([^\]]*)]\([^)]*\)/g, '$1')
      .replace(/^\s{0,3}#{1,6}\s+/gm, '')
      .replace(/^\s{0,3}>\s?/gm, '')
      .replace(/^\s*[-*+]\s+/gm, '')
      .replace(/^\s*\d+\.\s+/gm, '')
      .replace(/^\s*\|?(?:\s*:?-+:?\s*\|)+.*$/gm, '')
      .replace(/[|*_~`]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private segments(content: string, count: number): CiteSeg[] {
    const segs: CiteSeg[] = [];
    if (count === 0) {
      const single: CiteSeg = new CiteSeg();
      single.text = content;
      segs.push(single);
      return segs;
    }
    const pattern: RegExp = /\[(\d{1,2})\]/g;
    let last: number = 0;
    let match: RegExpExecArray | null = pattern.exec(content);
    while (match !== null) {
      const index: number = Number(match[1]);
      if (index >= 1 && index <= count) {
        if (match.index > last) {
          const plain: CiteSeg = new CiteSeg();
          plain.text = content.substring(last, match.index);
          segs.push(plain);
        }
        const cite: CiteSeg = new CiteSeg();
        cite.cite = index;
        segs.push(cite);
        last = match.index + match[0].length;
      }
      match = pattern.exec(content);
    }
    if (last < content.length) {
      const tail: CiteSeg = new CiteSeg();
      tail.text = content.substring(last);
      segs.push(tail);
    }
    if (segs.length === 0) {
      const empty: CiteSeg = new CiteSeg();
      empty.text = content;
      segs.push(empty);
    }
    return segs;
  }

  private threadRows(): ThreadRow[] {
    const rows: ThreadRow[] = [];
    let day: string = '';
    this.messages.forEach((message: ChatMessage) => {
      const currentDay: string = message.createdAt.length >= 10 ? message.createdAt.substring(0, 10) : '';
      if (currentDay !== day) {
        day = currentDay;
        const sep: ThreadRow = new ThreadRow();
        sep.kind = 'day';
        sep.key = `d-${currentDay}`;
        sep.label = this.dayLabel(message.createdAt);
        rows.push(sep);
      }
      const row: ThreadRow = new ThreadRow();
      row.key = `m-${message.id}`;
      row.message = message;
      if (message.role === 'user') {
        row.kind = 'user';
        row.text = message.content;
      } else {
        row.kind = 'ai';
        row.segments = this.segments(message.content, message.sources.length);
      }
      rows.push(row);
    });
    return rows;
  }

  private relatedDocs(): KnowledgeDoc[] {
    const current: KnowledgeDoc | null = this.activeDoc;
    if (current === null) {
      return [];
    }
    const mine: string[] = this.topicList(current.topics, 99);
    return this.docs
      .filter((doc: KnowledgeDoc) => doc.id !== current.id)
      .filter((doc: KnowledgeDoc) => this.topicList(doc.topics, 99).some((t: string) => mine.includes(t)))
      .slice(0, 5);
  }

  private dedupeSessions(rows: ChatSession[]): ChatSession[] {
    const seen: Set<number> = new Set<number>();
    const result: ChatSession[] = [];
    rows.forEach((row: ChatSession) => {
      if (!seen.has(row.id)) {
        seen.add(row.id);
        result.push(row);
      }
    });
    return result;
  }

  private dedupeMessages(rows: ChatMessage[]): ChatMessage[] {
    const seen: Set<number> = new Set<number>();
    const result: ChatMessage[] = [];
    rows.forEach((row: ChatMessage) => {
      if (!seen.has(row.id)) {
        seen.add(row.id);
        result.push(row);
      }
    });
    return result;
  }

  private async loadSessions(): Promise<void> {
    this.loadingSessions = true;
    try {
      const page: CursorPage<ChatSession> = await KnowledgeApi.sessions(undefined, 20);
      this.sessions = page.records;
      this.sessionsCursor = page.nextCursor ?? '';
      this.sessionsMore = page.hasMore;
    } catch (err) {
      console.warn(`load sessions failed: ${JSON.stringify(err)}`);
    } finally {
      this.loadingSessions = false;
    }
  }

  private async loadMoreSessions(): Promise<void> {
    if (this.sessionsCursor.length === 0) {
      return;
    }
    this.loadingMoreSessions = true;
    try {
      const page: CursorPage<ChatSession> = await KnowledgeApi.sessions(this.sessionsCursor, 20);
      this.sessions = this.dedupeSessions(this.sessions.concat(page.records));
      this.sessionsCursor = page.nextCursor ?? '';
      this.sessionsMore = page.hasMore;
    } catch (err) {
      console.warn(`load more sessions failed: ${JSON.stringify(err)}`);
    } finally {
      this.loadingMoreSessions = false;
    }
  }

  private async fetchMessages(id: number, silent: boolean = false): Promise<void> {
    if (!silent) {
      this.loadingMessages = true;
    }
    try {
      const page: CursorPage<ChatMessage> = await KnowledgeApi.messages(id, undefined, PAGE_SIZE);
      this.messages = page.records;
      this.messagesCursor = page.nextCursor ?? '';
      this.messagesMore = page.hasMore;
    } catch (err) {
      console.warn(`load messages failed: ${JSON.stringify(err)}`);
    } finally {
      if (!silent) {
        this.loadingMessages = false;
      }
    }
  }

  private async loadMoreMessages(): Promise<void> {
    if (this.activeId <= 0 || this.messagesCursor.length === 0) {
      return;
    }
    this.loadingMore = true;
    try {
      const page: CursorPage<ChatMessage> = await KnowledgeApi.messages(this.activeId, this.messagesCursor, PAGE_SIZE);
      this.messages = this.dedupeMessages(page.records.concat(this.messages));
      this.messagesCursor = page.nextCursor ?? '';
      this.messagesMore = page.hasMore;
    } catch (err) {
      console.warn(`load more messages failed: ${JSON.stringify(err)}`);
    } finally {
      this.loadingMore = false;
    }
  }

  private async openChat(id: number): Promise<void> {
    if (id === this.activeId) {
      this.drawerOpen = false;
      return;
    }
    this.drawerOpen = false;
    this.activeId = id;
    this.askError = '';
    this.persistError = false;
    this.renaming = false;
    AppStorage.setOrCreate(LAST_CHAT_KEY, id);
    await this.fetchMessages(id, false);
    this.scrollBottomSoon();
  }

  private newChat(): void {
    this.drawerOpen = false;
    this.activeId = 0;
    this.messages = [];
    this.messagesCursor = '';
    this.messagesMore = false;
    this.askError = '';
    this.persistError = false;
    this.renaming = false;
    this.draft = '';
    AppStorage.setOrCreate(LAST_CHAT_KEY, 0);
  }

  private scrollBottomSoon(): void {
    setTimeout(() => {
      this.threadScroller.scrollEdge(Edge.Bottom);
    }, 80);
  }

  private localMessage(role: string, content: string, sources: ChatSource[], redLine: boolean,
    fallback: boolean, seq: number): ChatMessage {
    const message: ChatMessage = {
      id: -seq,
      role: role as 'user' | 'ai',
      content: content,
      sources: sources,
      isRedLine: redLine,
      isFallback: fallback,
      createdAt: localNow()
    };
    return message;
  }

  private async submit(raw: string): Promise<void> {
    const question: string = raw.trim();
    if (question.length === 0 || this.asking) {
      return;
    }
    this.asking = true;
    this.askingQuestion = question;
    this.askError = '';
    this.persistError = false;
    this.draft = '';
    this.scrollBottomSoon();

    let answer: string = '';
    let sources: ChatSource[] = [];
    let fallback: boolean = false;
    let redline: boolean = false;
    try {
      let hit: boolean = false;
      try {
        hit = await TipApi.checkRedline(question);
      } catch (err) {
        hit = false;
      }
      redline = hit;
      if (redline) {
        answer = REDLINE_TEXT;
      } else {
        const resp: AiQueryResp = await AiApi.query(question, this.petId());
        answer = resp.content;
        fallback = resp.isFallback;
        resp.sources.forEach((source: AiSource) => {
          const item: ChatSource = {
            docId: source.docId,
            title: source.title,
            sourceName: source.sourceName
          };
          sources.push(item);
        });
      }
    } catch (err) {
      this.askError = err instanceof Error && err.message.length > 0 ? err.message : '请求失败，请稍后重试';
      this.asking = false;
      return;
    }

    try {
      if (this.activeId <= 0) {
        const created: ChatSession = await KnowledgeApi.createChat(question.substring(0, 20), this.petId());
        this.sessions = this.dedupeSessions([created].concat(this.sessions));
        this.activeId = created.id;
        AppStorage.setOrCreate(LAST_CHAT_KEY, created.id);
      }
      const seq: number = this.messages.length + 1;
      this.messages = this.messages.concat([
        this.localMessage('user', question, [], false, false, seq),
        this.localMessage('ai', answer, sources, redline, fallback, seq + 1)
      ]);
      this.scrollBottomSoon();
      try {
        await KnowledgeApi.append(this.activeId, {
          question: question,
          answer: answer,
          sourceDocIds: sources.map((source: ChatSource) => source.docId),
          isRedLine: redline,
          isFallback: fallback
        });
      } catch (err) {
        this.persistError = true;
        return;
      }
      await this.fetchMessages(this.activeId, true);
      await this.refreshSessions();
    } catch (err) {
      this.askError = err instanceof Error && err.message.length > 0 ? err.message : '请求失败，请稍后重试';
    } finally {
      this.asking = false;
      this.askingQuestion = '';
      this.scrollBottomSoon();
    }
  }

  private async refreshSessions(): Promise<void> {
    try {
      const page: CursorPage<ChatSession> = await KnowledgeApi.sessions(undefined, 20);
      this.sessions = page.records;
      this.sessionsCursor = page.nextCursor ?? '';
      this.sessionsMore = page.hasMore;
    } catch (err) {
      console.warn(`refresh sessions failed: ${JSON.stringify(err)}`);
    }
  }

  private startRename(): void {
    const chat: ChatSession | null = this.activeChat();
    if (chat === null) {
      return;
    }
    this.renameValue = chat.title;
    this.renaming = true;
  }

  private async commitRename(): Promise<void> {
    const chat: ChatSession | null = this.activeChat();
    if (!this.renaming || chat === null) {
      return;
    }
    this.renaming = false;
    const title: string = this.renameValue.trim();
    if (title.length === 0 || title === chat.title) {
      return;
    }
    const prev: string = chat.title;
    chat.title = title;
    this.sessions = this.sessions.slice();
    try {
      await KnowledgeApi.rename(chat.id, title);
    } catch (err) {
      chat.title = prev;
      this.sessions = this.sessions.slice();
    }
  }

  private async startRenameFor(session: ChatSession): Promise<void> {
    if (session.id !== this.activeId) {
      await this.openChat(session.id);
    }
    this.startRename();
  }

  private confirmRemove(session: ChatSession): void {
    AlertDialog.show({
      title: '删除会话',
      message: `删除「${session.title}」及其全部消息？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: FG.danger,
        action: () => {
          this.removeSession(session);
        }
      }
    });
  }

  private async removeSession(session: ChatSession): Promise<void> {
    try {
      await KnowledgeApi.remove(session.id);
    } catch (err) {
      return;
    }
    this.sessions = this.sessions.filter((s: ChatSession) => s.id !== session.id);
    if (session.id === this.activeId) {
      if (this.sessions.length > 0) {
        await this.openChat(this.sessions[0].id);
      } else {
        this.newChat();
      }
    }
    showToast('已删除');
  }

  private sessionMenu(session: ChatSession): MenuElement[] {
    return [
      {
        value: '重命名',
        action: () => {
          this.startRenameFor(session);
        }
      },
      {
        value: '删除',
        action: () => {
          this.confirmRemove(session);
        }
      }
    ];
  }

  private exportChat(): void {
    const chat: ChatSession | null = this.activeChat();
    if (chat === null) {
      return;
    }
    const lines: string[] = [`# ${chat.title}`, ''];
    this.messages.forEach((message: ChatMessage) => {
      lines.push(`**${message.role === 'user' ? '我' : 'FurGuardian'}** · ${this.clockText(message.createdAt)}`);
      lines.push('');
      lines.push(message.content);
      if (message.sources.length > 0) {
        lines.push('');
        message.sources.forEach((source: ChatSource) => {
          lines.push(`- 来源：${source.title}（${source.sourceName}）`);
        });
      }
      lines.push('');
    });
    lines.push('> 以上内容由知识库检索生成，不构成医疗建议。');
    const data: pasteboard.PasteData = pasteboard.createData('text/plain', lines.join('\n'));
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      showToast('会话内容已复制到剪贴板');
    }).catch(() => {
      showToast('复制失败，请稍后重试');
    });
  }

  private async openSource(source: ChatSource): Promise<void> {
    this.mode = 'browse';
    this.activeTopic = '';
    this.searchQuery = source.title;
    await this.searchDocs();
    const hit: KnowledgeDoc | undefined = this.docs.find((doc: KnowledgeDoc) => doc.id === source.docId);
    if (hit !== undefined) {
      this.activeDoc = hit;
    }
  }

  private async searchDocs(): Promise<void> {
    if (this.searchQuery.trim().length === 0) {
      showToast('请输入检索关键词');
      return;
    }
    this.searching = true;
    try {
      this.docs = await AiApi.search(
        this.searchQuery.trim(),
        this.searchSpecies.length > 0 ? this.searchSpecies : undefined,
        this.searchLifeStage.length > 0 ? this.searchLifeStage : undefined,
        10
      );
      this.searched = true;
      this.activeDoc = null;
    } catch (err) {
      console.warn(`search failed: ${JSON.stringify(err)}`);
    } finally {
      this.searching = false;
    }
  }

  private pickTopic(topic: string): void {
    this.activeTopic = topic;
    this.searchQuery = topic;
    this.searchDocs();
  }

  private speciesOptions(): SelectOption[] {
    return [
      { value: '', label: '全部物种' },
      { value: 'dog', label: '犬' },
      { value: 'cat', label: '猫' }
    ];
  }

  private stageOptions(): SelectOption[] {
    return [
      { value: '', label: '全部阶段' },
      { value: 'young', label: '幼年' },
      { value: 'adult', label: '成年' },
      { value: 'senior', label: '老年' }
    ];
  }

  @Builder
  HeaderView() {
    Row() {
      if (this.showBack) {
        Row() {
          Icon({ name: 'arrow-left', iconSize: 18, color: FG.inkMuted })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 4 })
        .onClick(() => {
          Nav.pop();
        })
      }

      Row() {
        Icon({ name: 'history', iconSize: 16, color: FG.inkMuted })
        Text('历史')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 4 })
      }
      .height(32)
      .padding({ left: 8, right: 8 })
      .borderRadius(6)
      .backgroundColor(FG.paper)
      .onClick(() => {
        this.drawerOpen = true;
      })

      Column() {
        if (this.renaming) {
          TextInput({ text: this.renameValue })
            .width('100%')
            .height(34)
            .fontSize(FG.textLead)
            .fontColor(FG.ink)
            .backgroundColor(FG.surface)
            .border({ width: 1, color: FG.accent })
            .borderRadius(6)
            .padding({ left: 8, right: 8 })
            .maxLength(100)
            .onChange((value: string) => {
              this.renameValue = value;
            })
            .onSubmit(() => {
              this.commitRename();
            })
            .onBlur(() => {
              this.commitRename();
            })
        } else {
          Text(this.activeChat() !== null ? (this.activeChat() as ChatSession).title : '新对话')
            .fontSize(FG.textLead)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .onClick(() => {
              this.startRename();
            })
        }
        if (this.activeChat() !== null) {
          Text(`${(this.activeChat() as ChatSession).messageCount} 条 · ${(this.activeChat() as ChatSession).sourceCount} 个来源`)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10, right: 10 })

      if (this.messages.length > 0) {
        Row() {
          Icon({ name: 'download', iconSize: 16, color: FG.inkMuted })
          Text('导出')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 4 })
        }
        .height(32)
        .padding({ left: 8, right: 8 })
        .borderRadius(6)
        .onClick(() => {
          this.exportChat();
        })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .backgroundColor(FG.surface)
  }

  @Builder
  SkeletonBlock(isUser: boolean) {
    Column() {
      Column()
        .width(isUser ? 130 : 180)
        .height(12)
        .borderRadius(4)
        .backgroundColor(FG.line)
      Column()
        .width(isUser ? 190 : 250)
        .height(12)
        .borderRadius(4)
        .backgroundColor(FG.line)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(isUser ? HorizontalAlign.End : HorizontalAlign.Start)
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  WelcomeView() {
    Column() {
      Text('问问 FurGuardian')
        .fontFamily(FG.serif)
        .fontSize(FG.textH2)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
      Text('喂养、护理、症状都能问。回答只取自已审核的知识库条目，并附上来源。')
        .fontSize(FG.textBody)
        .lineHeight(22)
        .fontColor(FG.inkMuted)
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(SUGGESTED, (question: string) => {
          Column() {
            Text(question)
              .fontSize(FG.textBody)
              .lineHeight(21)
              .fontColor(FG.ink)
              .width('100%')
          }
          .width('48%')
          .padding(14)
          .margin({ bottom: 10 })
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)
          .onClick(() => {
            this.submit(question);
          })
        }, (question: string) => question)
      }
      .width('100%')
      .margin({ top: 24 })

      Text('或浏览知识库')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .decoration({ type: TextDecorationType.Underline })
        .margin({ top: 8 })
        .onClick(() => {
          this.mode = 'browse';
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 32, left: 4, right: 4 })
  }

  @Builder
  UserBubble(text: string) {
    Row() {
      Text(text)
        .fontSize(FG.textBody)
        .lineHeight(23)
        .fontColor(FG.ink)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(FG.paper)
        .border({ width: 1, color: FG.line })
        .borderRadius(FG.radius)
        .constraintSize({ maxWidth: '82%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ bottom: 12 })
  }

  @Builder
  AiSources(sources: ChatSource[]) {
    Column() {
      Text('参考来源')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.5)
        .width('100%')
      ForEach(sources, (source: ChatSource) => {
        Row() {
          Column() {
            Text(source.title)
              .fontSize(FG.textBody)
              .lineHeight(20)
              .fontColor(FG.ink)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row() {
              if (source.severity !== undefined && source.severity.length > 0) {
                SeverityDot({
                  level: this.severityLevel(source.severity),
                  label: this.severityLabel(source.severity)
                })
                  .margin({ right: 8 })
              }
              Text(this.sourceTypeLabel(source.sourceType))
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
            }
            .margin({ top: 4 })
            Text(source.sourceName)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Icon({ name: 'chevron-right', iconSize: 16, color: FG.lineStrong })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(FG.surface)
        .border({ width: 1, color: FG.line })
        .borderRadius(FG.radius)
        .margin({ top: 8 })
        .onClick(() => {
          this.openSource(source);
        })
      }, (source: ChatSource) => `${source.docId}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }

  @Builder
  AiMessageView(row: ThreadRow) {
    if (row.message !== null && (row.message as ChatMessage).isRedLine) {
      Column() {
        Row() {
          Icon({ name: 'shield-alert', iconSize: 16, color: FG.danger })
          Text('建议尽快就医')
            .fontSize(FG.textBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.danger)
            .margin({ left: 6 })
        }
        .width('100%')
        Text((row.message as ChatMessage).content)
          .fontSize(FG.textBody)
          .lineHeight(23)
          .fontColor(FG.ink)
          .width('100%')
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(FG.dangerSoft)
      .border({ width: { left: 3 }, color: FG.danger })
      .borderRadius(FG.radius)
      .margin({ bottom: 16 })
    } else {
      Column() {
        Row() {
          Text('AI')
            .fontSize(FG.textLabel)
            .letterSpacing(0.5)
            .fontColor(FG.inkMuted)
          if (row.message !== null && (row.message as ChatMessage).isFallback) {
            FgChip({ label: '降级回答', tone: 'warn' })
              .margin({ left: 6 })
          }
          Blank()
          Text(row.message !== null ? this.clockText((row.message as ChatMessage).createdAt) : '')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          ForEach(row.segments, (segment: CiteSeg, index: number) => {
            if (segment.cite > 0) {
              Text(`${segment.cite}`)
                .fontSize(11)
                .fontColor(FG.accent)
                .textAlign(TextAlign.Center)
                .constraintSize({ minWidth: 20 })
                .height(20)
                .padding({ left: 4, right: 4 })
                .backgroundColor(FG.accentSoft)
                .borderRadius(4)
                .margin({ left: 2, right: 2, top: 2 })
            } else {
              Text(segment.text)
                .fontSize(FG.textLead)
                .lineHeight(26)
                .fontColor(FG.ink)
            }
          }, (segment: CiteSeg, index: number) => `${index}-${segment.cite}-${segment.text.length}`)
        }
        .width('100%')
        .margin({ top: 4 })

        if (row.message !== null && (row.message as ChatMessage).sources.length > 0) {
          this.AiSources((row.message as ChatMessage).sources)
        }

        Text('以上建议仅供参考，不构成医疗建议。')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 20 })
    }
  }

  @Builder
  ThreadRowView(row: ThreadRow) {
    if (row.kind === 'day') {
      Text(row.label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8, bottom: 14 })
    } else if (row.kind === 'user') {
      this.UserBubble(row.text)
    } else {
      this.AiMessageView(row)
    }
  }

  @Builder
  AskingView() {
    Column() {
      this.UserBubble(this.askingQuestion)
      Column() {
        Row() {
          Text('AI')
            .fontSize(FG.textLabel)
            .letterSpacing(0.5)
            .fontColor(FG.inkMuted)
          Circle()
            .width(6)
            .height(6)
            .fill(FG.accent)
            .margin({ left: 8, right: 6 })
          Text('正在生成回答…')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
        }
        .width('100%')
        this.SkeletonBlock(false)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  ChatThread() {
    Scroll(this.threadScroller) {
      Column() {
        if (this.messagesMore) {
          Text(this.loadingMore ? '加载中…' : '加载更早的消息')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: 14 })
            .onClick(() => {
              this.loadMoreMessages();
            })
        }

        if (this.loadingMessages) {
          ForEach([1, 2, 3], (item: number) => {
            this.SkeletonBlock(item === 1)
          }, (item: number) => `sk-${item}`)
        } else if (this.activeId === 0 && !this.asking && this.askError.length === 0) {
          this.WelcomeView()
        } else {
          ForEach(this.threadRows(), (row: ThreadRow) => {
            this.ThreadRowView(row)
          }, (row: ThreadRow) => row.key)

          if (this.asking) {
            this.AskingView()
          }

          if (this.askError.length > 0) {
            Column() {
              Row() {
                Icon({ name: 'triangle-alert', iconSize: 16, color: FG.danger })
                Text('这次没答上来')
                  .fontSize(FG.textBody)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(FG.danger)
                  .margin({ left: 6 })
              }
              Text(this.askError)
                .fontSize(FG.textBody)
                .lineHeight(22)
                .fontColor(FG.ink)
                .width('100%')
                .margin({ top: 8 })
              Text('重试')
                .fontSize(FG.textLabel)
                .fontColor(FG.accent)
                .decoration({ type: TextDecorationType.Underline })
                .margin({ top: 10 })
                .onClick(() => {
                  this.submit(this.askingQuestion.length > 0 ? this.askingQuestion : this.draft);
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor(FG.dangerSoft)
            .border({ width: { left: 3 }, color: FG.danger })
            .borderRadius(FG.radius)
            .margin({ bottom: 16 })
          }

          if (this.persistError) {
            Text('这次问答没能存入历史，刷新后会丢失。')
              .fontSize(FG.textLabel)
              .fontColor(FG.warning)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 4, bottom: 12 })
          }

          if (this.messages.length === 0 && !this.asking && this.askError.length === 0 && this.activeId > 0) {
            Text('这个会话还没有内容，直接提问即可。')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 32 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  Composer() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(SUGGESTED.slice(0, 3), (question: string) => {
          Text(question)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .height(26)
            .padding({ left: 8, right: 8 })
            .backgroundColor(FG.paper)
            .border({ width: 1, color: FG.line })
            .borderRadius(13)
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.draft = question;
            })
        }, (question: string) => `chip-${question}`)
      }
      .width('100%')

      Row() {
        TextArea({ text: this.draft, placeholder: '描述症状或喂养问题，例如：幼犬一天喂几顿？' })
          .layoutWeight(1)
          .constraintSize({ minHeight: 44, maxHeight: 96 })
          .fontSize(FG.textBody)
          .fontColor(FG.ink)
          .placeholderColor(FG.inkMuted)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .maxLength(500)
          .maxLines(4)
          .onChange((value: string) => {
            this.draft = value;
          })
          .onSubmit((enterKey: EnterKeyType) => {
            if (enterKey === EnterKeyType.Send || enterKey === EnterKeyType.Go) {
              this.submit(this.draft);
            }
          })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Icon({ name: 'arrow-up', iconSize: 18, color: FG.surface })
        }
        .width(36)
        .height(36)
        .backgroundColor(FG.accent)
        .opacity(this.draft.trim().length === 0 || this.asking ? 0.4 : 1)
        .enabled(this.draft.trim().length > 0 && !this.asking)
        .margin({ left: 10, bottom: 4 })
        .onClick(() => {
          this.submit(this.draft);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row() {
        Text('回答基于知识库检索，不构成医疗建议。')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
        Blank()
        Text(`${this.draft.length}/500`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 8 })
    .border({ width: { top: 1 }, color: FG.line })
    .backgroundColor(FG.surface)
  }

  @Builder
  SessionRow(session: ChatSession) {
    Row() {
      Column() {
        Text(session.title)
          .fontSize(FG.textBody)
          .fontWeight(session.id === this.activeId ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(session.id === this.activeId ? FG.accent : FG.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${session.messageCount} 条 · ${session.sourceCount} 个来源`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.timeText(session.updatedAt))
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .margin({ left: 6 })

      Row() {
        Icon({ name: 'more-horizontal', iconSize: 16, color: FG.inkMuted })
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .margin({ left: 2 })
      .bindMenu(this.sessionMenu(session))
    }
    .width('100%')
    .padding({ left: 12, right: 6, top: 10, bottom: 10 })
    .borderRadius(FG.radius)
    .backgroundColor(session.id === this.activeId ? FG.accentSoft : Color.Transparent)
    .onClick(() => {
      this.openChat(session.id);
    })
  }

  @Builder
  SessionSheet() {
    Column() {
      Row() {
        Text('知识问答')
          .fontSize(FG.textBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
        Blank()
        Row() {
          Icon({ name: 'square-pen', iconSize: 16, color: FG.inkMuted })
          Text('新建')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ left: 4 })
        }
        .height(32)
        .padding({ left: 8, right: 8 })
        .borderRadius(6)
        .backgroundColor(FG.paper)
        .onClick(() => {
          this.newChat();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 8 })

      Row() {
        Icon({ name: 'search', iconSize: 16, color: FG.inkMuted })
        TextInput({ text: this.sessKeyword, placeholder: '搜索会话' })
          .layoutWeight(1)
          .height(36)
          .fontSize(FG.textBody)
          .fontColor(FG.ink)
          .placeholderColor(FG.inkMuted)
          .backgroundColor(Color.Transparent)
          .padding({ left: 6, right: 6 })
          .onChange((value: string) => {
            this.sessKeyword = value;
          })
      }
      .width('92%')
      .height(40)
      .padding({ left: 10, right: 10 })
      .backgroundColor(FG.paper)
      .borderRadius(FG.radius)
      .border({ width: 1, color: FG.line })
      .alignSelf(ItemAlign.Center)

      Scroll() {
        Column() {
          if (this.loadingSessions) {
            Text('正在加载会话…')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .width('100%')
              .padding(16)
          } else if (this.visibleSessions().length === 0) {
            Text(this.sessions.length > 0 ? '没有匹配的会话' : '还没有对话，从右侧问第一个问题开始。')
              .fontSize(FG.textLabel)
              .lineHeight(20)
              .fontColor(FG.inkMuted)
              .width('100%')
              .padding(16)
          }

          ForEach(this.sessionGroups(), (group: SessionGroup) => {
            Text(group.label)
              .fontSize(FG.textLabel)
              .letterSpacing(0.5)
              .fontColor(FG.inkMuted)
              .width('100%')
              .padding({ left: 12, top: 12, bottom: 6 })
            ForEach(group.items, (session: ChatSession) => {
              this.SessionRow(session)
            }, (session: ChatSession) => `s-${session.id}`)
          }, (group: SessionGroup) => `g-${group.label}`)

          if (this.sessionsMore) {
            Text(this.loadingMoreSessions ? '加载中…' : '加载更早的对话')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 14, bottom: 14 })
              .onClick(() => {
                this.loadMoreSessions();
              })
          }
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Row() {
        Icon({ name: 'book-open', iconSize: 16, color: FG.accent })
        Text('浏览知识库')
          .fontSize(FG.textBody)
          .fontColor(FG.accent)
          .margin({ left: 8 })
        Blank()
        Icon({ name: 'chevron-right', iconSize: 16, color: FG.inkMuted })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .border({ width: { top: 1 }, color: FG.line })
      .onClick(() => {
        this.drawerOpen = false;
        this.mode = 'browse';
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(FG.surface)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ChatView() {
    Column() {
      this.HeaderView()
      this.ChatThread()
      this.Composer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(FG.surface)
    .bindSheet($$this.drawerOpen, this.SessionSheet(), {
      height: '86%',
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: false
    })
  }

  @Builder
  SearchHero() {
    Column() {
      Text('关键词检索')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.5)
        .width('100%')

      Row() {
        Row() {
          Icon({ name: 'search', iconSize: 18, color: FG.inkMuted })
          TextInput({ text: this.searchQuery, placeholder: '搜索知识条目，例如：猫 换粮 软便' })
            .layoutWeight(1)
            .height(44)
            .fontSize(FG.textBody)
            .fontColor(FG.ink)
            .placeholderColor(FG.inkMuted)
            .backgroundColor(Color.Transparent)
            .padding({ left: 8, right: 8 })
            .maxLength(200)
            .onChange((value: string) => {
              this.searchQuery = value;
              if (this.activeTopic !== value) {
                this.activeTopic = '';
              }
            })
            .onSubmit(() => {
              this.searchDocs();
            })
        }
        .layoutWeight(1)
        .height(44)
        .padding({ left: 10, right: 10 })
        .backgroundColor(FG.surface)
        .border({ width: 1, color: FG.line })
        .borderRadius(FG.radius)

        FgButton({
          label: '检索',
          variant: 'primary',
          loading: this.searching,
          onTap: () => {
            this.searchDocs();
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 8 })

      Column()
        .width('100%')
        .height(1)
        .backgroundColor(FG.line)
        .margin({ top: 16, bottom: 14 })

      Text('常见主题')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.5)
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(['营养', '护理', '症状', '季节'], (topic: string) => {
          Text(topic)
            .fontSize(FG.textLabel)
            .fontColor(this.activeTopic === topic ? FG.accent : FG.inkMuted)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.activeTopic === topic ? FG.accentSoft : FG.paper)
            .border({ width: 1, color: this.activeTopic === topic ? FG.accentSoft : FG.line })
            .borderRadius(14)
            .margin({ right: 8, top: 6 })
            .onClick(() => {
              this.pickTopic(topic);
            })
        }, (topic: string) => `topic-${topic}`)
      }
      .width('100%')

      Text('限定条件')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .letterSpacing(0.5)
        .width('100%')
        .margin({ top: 12 })

      Row() {
        Column() {
          FgSelect({
            value: this.searchSpecies,
            placeholder: '物种',
            options: this.speciesOptions(),
            onChange: (value: string) => {
              this.searchSpecies = value;
            }
          })
        }
        .layoutWeight(1)

        Column() {
          FgSelect({
            value: this.searchLifeStage,
            placeholder: '生命阶段',
            options: this.stageOptions(),
            onChange: (value: string) => {
              this.searchLifeStage = value;
            }
          })
        }
        .layoutWeight(1)
        .margin({ left: 10 })
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  DocRow(doc: KnowledgeDoc) {
    Column() {
      Row() {
        Text(doc.title)
          .fontSize(FG.textLead)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (doc.severity !== undefined && doc.severity.length > 0) {
          SeverityDot({ level: this.severityLevel(doc.severity), label: this.severityLabel(doc.severity) })
            .margin({ left: 8 })
        }
      }
      .width('100%')

      if (doc.content !== undefined && doc.content.length > 0) {
        Text(this.plainText(doc.content))
          .fontSize(FG.textBody)
          .lineHeight(21)
          .fontColor(FG.inkMuted)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })
      }

      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        SourceChip({ label: doc.sourceName !== undefined && doc.sourceName.length > 0 ? doc.sourceName : '未知来源' })
          .margin({ right: 10 })
        if (doc.updatedAt !== undefined && doc.updatedAt.length > 0) {
          Text(dateText(doc.updatedAt))
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ right: 10, top: 2 })
        }
        ForEach(this.topicList(doc.topics), (topic: string) => {
          FgChip({ label: topic })
            .margin({ right: 6, top: 2 })
        }, (topic: string) => `dt-${doc.id}-${topic}`)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 10 })
    .onClick(() => {
      this.activeDoc = doc;
    })
  }

  @Builder
  DocDetail() {
    Column() {
      Row() {
        Icon({ name: 'arrow-left', iconSize: 18, color: FG.inkMuted })
        Text('返回结果列表')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 6 })
      }
      .height(32)
      .onClick(() => {
        this.activeDoc = null;
      })

      Text((this.activeDoc as KnowledgeDoc).title)
        .fontFamily(FG.serif)
        .fontSize(FG.textH2)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .lineHeight(32)
        .width('100%')
        .margin({ top: 8 })

      Text(`来源 · ${(this.activeDoc as KnowledgeDoc).sourceName !== undefined && ((this.activeDoc as KnowledgeDoc).sourceName as string).length > 0 ? (this.activeDoc as KnowledgeDoc).sourceName : '未知'}` +
        ((this.activeDoc as KnowledgeDoc).updatedAt !== undefined ? ` · ${dateText((this.activeDoc as KnowledgeDoc).updatedAt)}` : ''))
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 8 })

      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        if ((this.activeDoc as KnowledgeDoc).severity !== undefined && ((this.activeDoc as KnowledgeDoc).severity as string).length > 0) {
          SeverityDot({
            level: this.severityLevel((this.activeDoc as KnowledgeDoc).severity as string),
            label: this.severityLabel((this.activeDoc as KnowledgeDoc).severity as string)
          })
            .margin({ right: 8, top: 2 })
        }
        if ((this.activeDoc as KnowledgeDoc).species !== undefined && ((this.activeDoc as KnowledgeDoc).species as string).length > 0) {
          FgChip({ label: this.speciesLabel((this.activeDoc as KnowledgeDoc).species) })
            .margin({ right: 6, top: 2 })
        }
        if ((this.activeDoc as KnowledgeDoc).lifeStage !== undefined && ((this.activeDoc as KnowledgeDoc).lifeStage as string).length > 0) {
          FgChip({ label: this.lifeStageLabel((this.activeDoc as KnowledgeDoc).lifeStage) })
            .margin({ right: 6, top: 2 })
        }
        ForEach(this.topicList((this.activeDoc as KnowledgeDoc).topics, 6), (topic: string) => {
          FgChip({ label: topic })
            .margin({ right: 6, top: 2 })
        }, (topic: string) => `detail-topic-${topic}`)
      }
      .width('100%')
      .margin({ top: 10, bottom: 12 })

      Column() {
        MarkdownView({ content: (this.activeDoc as KnowledgeDoc).content ?? '' })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text('引用出处')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .letterSpacing(0.5)
          .width('100%')
        SourceChip({
          label: (this.activeDoc as KnowledgeDoc).sourceName !== undefined
            ? (this.activeDoc as KnowledgeDoc).sourceName as string
            : ((this.activeDoc as KnowledgeDoc).sourceUrl ?? '')
        })
          .margin({ top: 6 })
        Text('以上内容摘编自该来源，用于日常喂养参考，不作为诊疗依据。')
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(FG.paper)
      .border({ width: { left: 3 }, color: FG.lineStrong })
      .margin({ top: 16 })

      if (this.relatedDocs().length > 0) {
        Column() {
          Text('相关条目')
            .fontFamily(FG.serif)
            .fontSize(FG.textH3)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
            .width('100%')
            .margin({ top: 20, bottom: 8 })

          ForEach(this.relatedDocs(), (doc: KnowledgeDoc) => {
            Row() {
              Icon({ name: 'chevron-right', iconSize: 18, color: FG.inkMuted })
              Column() {
                Text(doc.title)
                  .fontSize(FG.textBody)
                  .fontColor(FG.ink)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(`${doc.sourceName !== undefined && doc.sourceName.length > 0 ? doc.sourceName : '未知来源'}` +
                  `${doc.updatedAt !== undefined ? ` · ${dateText(doc.updatedAt)}` : ''}`)
                  .fontSize(FG.textLabel)
                  .fontColor(FG.inkMuted)
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 4 })
              if (doc.severity !== undefined && doc.severity.length > 0) {
                SeverityDot({ level: this.severityLevel(doc.severity), label: this.severityLabel(doc.severity) })
                  .margin({ left: 6 })
              }
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: FG.line })
            .onClick(() => {
              this.activeDoc = doc;
            })
          }, (doc: KnowledgeDoc) => `rel-${doc.id}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DisclaimerBar()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  BrowseNotice() {
    Column() {
      Row() {
        Icon({ name: 'messages-square', iconSize: 18, color: FG.ink })
        Text('问答挪到会话里了')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .margin({ left: 8 })
      }
      .width('100%')
      Text('提问、追问的历史都会保留在「知识问答」，这里只负责按关键词浏览知识库。')
        .fontSize(FG.textBody)
        .lineHeight(21)
        .fontColor(FG.inkMuted)
        .width('100%')
        .margin({ top: 8 })
      FgButton({
        label: '返回知识问答',
        variant: 'primary',
        icon: 'arrow-left',
        fillWidth: true,
        onTap: () => {
          this.mode = 'chat';
        }
      })
        .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 16 })
  }

  @Builder
  BrowseView() {
    Scroll() {
      Column() {
        PageHeader({
          title: '知识库',
          description: '检索循证的犬猫营养、护理与症状知识，每条结果标注来源与风险等级。',
          breadcrumb: '知识库 / 浏览',
          backLabel: this.showBack ? '返回' : '知识问答',
          onBack: () => {
            if (this.showBack) {
              Nav.pop();
            } else {
              this.mode = 'chat';
            }
          },
          showActions: true
        }) {
          FgButton({
            label: '返回知识问答',
            variant: 'primary',
            icon: 'messages-square',
            onTap: () => {
              this.mode = 'chat';
            }
          })
        }

        this.SearchHero()

        if (this.activeDoc === null) {
          Row() {
            Icon({ name: 'book-open', iconSize: 20, color: FG.ink })
            Text('检索结果')
              .fontFamily(FG.serif)
              .fontSize(FG.textH3)
              .fontWeight(FontWeight.Bold)
              .fontColor(FG.ink)
              .margin({ left: 8 })
            Blank()
            if (this.searched) {
              Text(`${this.docs.length} 条`)
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
            }
          }
          .width('100%')
          .margin({ top: 20, bottom: 8 })

          if (this.searched && this.docs.length === 0) {
            EmptyState({ variant: 'search', description: '没有检索到相关条目' })
          } else if (!this.searched) {
            Text('输入关键词或选择主题，结果会显示在这里。')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .width('100%')
              .padding({ top: 8, bottom: 8 })
          } else {
            ForEach(this.docs, (doc: KnowledgeDoc) => {
              this.DocRow(doc)
            }, (doc: KnowledgeDoc) => `doc-${doc.id}`)
          }

          this.BrowseNotice()
        } else {
          Column() {
            this.DocDetail()
          }
          .width('100%')
          .padding({ top: 16 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 20, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  build() {
    if (this.mode === 'chat') {
      this.ChatView()
    } else {
      this.BrowseView()
    }
  }
}
