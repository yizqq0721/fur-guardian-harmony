import { AdminApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { AdminPet, AdminUser, AdminUserDetail, PageResult } from '../models/Types';
import { dateText, dateTimeText } from '../utils/Format';
import { showToast } from '../utils/Http';

/** 用户管理：搜索、状态启停与宠物档案查看 */
@Component
export struct AdminUsersPage {
  @StorageLink('fg_userId') currentUserId: number = 0;
  @State private users: AdminUser[] = [];
  @State private loading: boolean = true;
  @State private keyword: string = '';
  @State private page: number = 1;
  @State private pageSize: number = 20;
  @State private total: number = 0;
  @State private pages: number = 1;
  @State private detailOpen: boolean = false;
  @State private detailLoading: boolean = false;
  @State private detail: AdminUserDetail | null = null;
  @State private togglingId: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      const result: PageResult<AdminUser> = await AdminApi.listUsers(
        this.page,
        this.pageSize,
        this.keyword.trim().length > 0 ? this.keyword.trim() : undefined
      );
      this.users = result.records;
      this.total = result.total;
      this.pages = Math.max(1, result.pages);
    } catch (err) {
      this.users = [];
      console.warn(`fetch admin users failed: ${JSON.stringify(err)}`);
    } finally {
      this.loading = false;
    }
  }

  private search(): void {
    this.page = 1;
    this.load();
  }

  private initial(user: AdminUser): string {
    return user.username.length > 0 ? user.username.substring(0, 1).toUpperCase() : '?';
  }

  private canToggle(user: AdminUser): boolean {
    return !user.isAdmin && user.id !== this.currentUserId;
  }

  private async openDetail(user: AdminUser): Promise<void> {
    this.detailOpen = true;
    this.detailLoading = true;
    this.detail = null;
    try {
      this.detail = await AdminApi.getUser(user.id);
    } catch (err) {
      console.warn(`fetch admin user detail failed: ${JSON.stringify(err)}`);
    } finally {
      this.detailLoading = false;
    }
  }

  private toggleStatus(user: AdminUser): void {
    const next: number = user.status === 1 ? 0 : 1;
    const title: string = next === 0 ? '禁用账号' : '启用账号';
    const message: string = next === 0
      ? `禁用后「${user.username}」将无法再登录，确定继续吗？`
      : `确定启用「${user.username}」吗？`;
    AlertDialog.show({
      title: title,
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: next === 0 ? '禁用' : '启用',
        fontColor: next === 0 ? FG.danger : FG.accent,
        action: () => {
          this.applyStatus(user.id, next);
        }
      }
    });
  }

  private async applyStatus(id: number, status: number): Promise<void> {
    this.togglingId = id;
    try {
      await AdminApi.updateStatus(id, status);
      showToast(status === 1 ? '已启用' : '已禁用');
      await this.load();
    } catch (err) {
      console.warn(`update user status failed: ${JSON.stringify(err)}`);
    } finally {
      this.togglingId = 0;
    }
  }

  private petSexText(sex?: string): string {
    if (sex === 'female') {
      return '母';
    }
    if (sex === 'male') {
      return '公';
    }
    return '—';
  }

  @Builder
  SearchBar() {
    Row() {
      Icon({ name: 'search', iconSize: 18, color: FG.inkMuted })
        .margin({ left: 12 })
      TextInput({ text: this.keyword, placeholder: '搜索账号或昵称' })
        .layoutWeight(1)
        .height(44)
        .fontSize(16)
        .fontColor(FG.ink)
        .placeholderColor(FG.inkMuted)
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 8 })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.keyword = value;
        })
        .onSubmit(() => {
          this.search();
        })
      if (this.keyword.length > 0) {
        Icon({ name: 'x', iconSize: 16, color: FG.inkMuted })
          .margin({ right: 8 })
          .onClick(() => {
            this.keyword = '';
            this.search();
          })
      }
      FgButton({
        label: '搜索',
        variant: 'primary',
        small: true,
        onTap: () => {
          this.search();
        }
      })
        .margin({ right: 8 })
    }
    .width('100%')
    .height(52)
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  UserCard(user: AdminUser) {
    Column() {
      Row() {
        Row() {
          Text(this.initial(user))
            .fontSize(FG.textBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.accent)
            .textAlign(TextAlign.Center)
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(FG.accentSoft)
          Column() {
            Row() {
              Text(user.username)
                .fontSize(FG.textLead)
                .fontWeight(FontWeight.Medium)
                .fontColor(FG.ink)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (user.isAdmin) {
                FgChip({ label: '管理员', tone: 'ok' })
                  .margin({ left: 6 })
              }
            }
            .alignItems(VerticalAlign.Center)

            Text(user.nickname !== undefined && user.nickname.length > 0 ? user.nickname : '未设置昵称')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 8 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        FgChip({
          label: user.status === 1 ? '正常' : '已禁用',
          tone: user.status === 1 ? 'ok' : 'warn'
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(`ID ${user.id}`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
        Text('·')
          .fontSize(FG.textLabel)
          .fontColor(FG.lineStrong)
          .margin({ left: 6, right: 6 })
        Text(`${user.petCount} 只宠物`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
        Text('·')
          .fontSize(FG.textLabel)
          .fontColor(FG.lineStrong)
          .margin({ left: 6, right: 6 })
        Text(`注册 ${dateTimeText(user.createdAt)}`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ top: 10 })

      Row() {
        Blank()
        Text('详情')
          .fontSize(FG.textBody)
          .fontColor(FG.accent)
          .onClick(() => {
            this.openDetail(user);
          })
        if (this.canToggle(user)) {
          Text(this.togglingId === user.id ? '处理中…' : (user.status === 1 ? '禁用' : '启用'))
            .fontSize(FG.textBody)
            .fontColor(this.togglingId === user.id ? FG.inkMuted : (user.status === 1 ? FG.danger : FG.accent))
            .margin({ left: 20 })
            .onClick(() => {
              if (this.togglingId === 0) {
                this.toggleStatus(user);
              }
            })
        }
      }
      .width('100%')
      .padding({ top: 10 })
      .margin({ top: 10 })
      .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .margin({ bottom: 12 })
  }

  @Builder
  DetailMetaRow(label: string, value: string, chip: string) {
    Row() {
      Text(label)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width(72)
      Text(value.length > 0 ? value : '—')
        .fontSize(FG.textBody)
        .fontColor(FG.ink)
        .layoutWeight(1)
      if (chip.length > 0) {
        FgChip({ label: chip, tone: 'ok' })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PetRow(pet: AdminPet) {
    Row() {
      Column() {
        Text(pet.name)
          .fontSize(FG.textBody)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
          .width('100%')
        Text(`${pet.species === 'cat' ? '猫' : '犬'} · ${pet.breed !== undefined && pet.breed.length > 0 ? pet.breed : '未填写品种'} · ${this.petSexText(pet.sex)}`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(dateText(pet.birthday))
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  DetailSheet() {
    Scroll() {
      Column() {
        Row() {
          Text('用户详情')
            .fontFamily(FG.serif)
            .fontSize(FG.textH3)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
          Blank()
          if (this.detail !== null) {
            FgChip({
              label: (this.detail as AdminUserDetail).status === 1 ? '正常' : '已禁用',
              tone: (this.detail as AdminUserDetail).status === 1 ? 'ok' : 'warn'
            })
          }
        }
        .width('100%')
        .margin({ bottom: 8 })

        if (this.detailLoading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 48 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.detail !== null) {
          this.DetailMetaRow('用户 ID', `${(this.detail as AdminUserDetail).id}`, '')
          this.DetailMetaRow('账号', (this.detail as AdminUserDetail).username, (this.detail as AdminUserDetail).isAdmin ? '管理员' : '')
          this.DetailMetaRow('昵称', (this.detail as AdminUserDetail).nickname ?? '未设置', '')
          this.DetailMetaRow('注册时间', dateTimeText((this.detail as AdminUserDetail).createdAt), '')
          this.DetailMetaRow('最近更新', dateTimeText((this.detail as AdminUserDetail).updatedAt), '')

          Row() {
            Text('宠物档案')
              .fontFamily(FG.serif)
              .fontSize(FG.textH3)
              .fontWeight(FontWeight.Medium)
              .fontColor(FG.ink)
            Text(`${(this.detail as AdminUserDetail).pets.length}`)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ left: 6 })
              .padding({ left: 8, right: 8 })
              .height(22)
              .borderRadius(6)
              .backgroundColor(FG.paper)
              .border({ width: 1, color: FG.line })
          }
          .width('100%')
          .margin({ top: 20, bottom: 8 })
          .alignItems(VerticalAlign.Center)

          if ((this.detail as AdminUserDetail).pets.length === 0) {
            Text('该用户还没有宠物档案。')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ top: 4 })
          } else {
            ForEach((this.detail as AdminUserDetail).pets, (pet: AdminPet) => {
              this.PetRow(pet)
            }, (pet: AdminPet) => `admin-pet-${pet.id}`)
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 12, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '用户管理',
          breadcrumb: '管理后台',
          description: '查看注册用户及其宠物档案，必要时禁用异常账号。管理员账号只能由数据库预置，不开放注册。',
          showActions: true
        }) {
          FgButton({
            label: '刷新',
            variant: 'secondary',
            icon: 'refresh-cw',
            small: true,
            onTap: () => {
              this.load();
            }
          })
        }

        this.SearchBar()

        Text(`共 ${this.total} 个用户`)
          .fontSize(FG.textBody)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ top: 12, bottom: 12 })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 48 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.users.length === 0) {
          EmptyState({
            variant: 'search',
            description: this.keyword.length > 0 ? '没有匹配的用户' : '还没有注册用户'
          })
        } else {
          ForEach(this.users, (user: AdminUser) => {
            this.UserCard(user)
          }, (user: AdminUser) => `admin-user-${user.id}`)

          Row() {
            FgButton({
              label: '上一页',
              variant: 'secondary',
              small: true,
              disabled: this.page <= 1,
              onTap: () => {
                if (this.page > 1) {
                  this.page -= 1;
                  this.load();
                }
              }
            })
            Text(`第 ${this.page} / ${this.pages} 页`)
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ left: 12, right: 12 })
            FgButton({
              label: '下一页',
              variant: 'secondary',
              small: true,
              disabled: this.page >= this.pages,
              onTap: () => {
                if (this.page < this.pages) {
                  this.page += 1;
                  this.load();
                }
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8 })

          Text('禁用后该账号将无法再登录；管理员账号不能禁用自己。')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 12 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .bindSheet($$this.detailOpen, this.DetailSheet(), {
      height: '82%',
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: true
    })
  }
}
