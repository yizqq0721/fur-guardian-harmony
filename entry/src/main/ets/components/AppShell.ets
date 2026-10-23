import { FG } from '../common/Theme';
import { Pet } from '../models/Types';
import { AdminUsersPage } from '../pages/AdminUsersPage';
import { FoodsPage } from '../pages/FoodsPage';
import { KnowledgePage } from '../pages/KnowledgePage';
import { NearbyPage } from '../pages/NearbyPage';
import { PetsPage } from '../pages/PetsPage';
import { PetStore } from '../stores/PetStore';
import { UserStore } from '../stores/UserStore';
import { Nav } from '../utils/Nav';
import { RemindersPage } from '../pages/RemindersPage';
import { ReportsPage } from '../pages/ReportsPage';
import { AppTopBar } from './AppTopBar';

interface NavEntry {
  label: string;
  tab: number;
  adminOnly: boolean;
}

@Component
export struct AppShell {
  @StorageLink('fg_nickname') nickname: string = '';
  @StorageLink('fg_isAdmin') isAdmin: boolean = false;
  @StorageLink('fg_activeTab') activeTab: number = 0;
  @StorageLink('fg_drawerOpen') drawerOpen: boolean = false;
  @StorageLink('fg_pendingOnboarding') pendingOnboarding: boolean = false;
  @StorageLink('fg_location') location: string = '';

  aboutToAppear(): void {
    Nav.clear();
    PetStore.fetchPets().catch((err: Object) => {
      console.warn(`fetch pets failed: ${JSON.stringify(err)}`);
    });
    UserStore.fetchProfile(true).catch((err: Object) => {
      console.warn(`fetch profile failed: ${JSON.stringify(err)}`);
    });
    if (this.pendingOnboarding) {
      AppStorage.setOrCreate('fg_pendingOnboarding', false);
      setTimeout(() => {
        Nav.push('Onboarding');
      }, 60);
    }
  }

  private navEntries(): NavEntry[] {
    const entries: NavEntry[] = [
      { label: '我的宠物', tab: 0, adminOnly: false },
      { label: '食品库', tab: 1, adminOnly: false },
      { label: '提醒', tab: 2, adminOnly: false },
      { label: '周报', tab: 3, adminOnly: false },
      { label: '知识库', tab: 4, adminOnly: false },
      { label: '周边', tab: 5, adminOnly: false }
    ];
    if (this.isAdmin) {
      entries.push({ label: '用户管理', tab: 6, adminOnly: true });
    }
    return entries;
  }

  private selectTab(tab: number): void {
    AppStorage.setOrCreate('fg_activeTab', tab);
    this.drawerOpen = false;
    Nav.clear();
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '提示',
      message: '确定退出登录吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出登录',
        fontColor: FG.danger,
        action: () => {
          this.drawerOpen = false;
          Nav.clear();
          UserStore.logout().catch((err: Object) => {
            console.warn(`logout failed: ${JSON.stringify(err)}`);
          });
        }
      }
    });
  }

  @Builder
  DrawerNavItem(label: string, tab: number) {
    Row() {
      Text(label)
        .fontSize(FG.textLead)
        .fontColor(this.activeTab === tab ? FG.accent : FG.ink)
        .fontWeight(this.activeTab === tab ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .borderRadius(FG.radius)
    .backgroundColor(this.activeTab === tab ? FG.accentSoft : Color.Transparent)
    .onClick(() => {
      this.selectTab(tab);
    })
  }

  @Builder
  DrawerLinkItem(label: string, page: string) {
    Row() {
      Text(label)
        .fontSize(FG.textLead)
        .fontColor(FG.ink)
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .borderRadius(FG.radius)
    .onClick(() => {
      this.drawerOpen = false;
      Nav.push(page);
    })
  }

  @Builder
  Drawer() {
    Column() {
      Row() {
        Image($r('app.media.ic_paw'))
          .width(20)
          .height(20)
        Text(this.nickname.length > 0 ? this.nickname : '用户')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .margin({ left: 8 })
        Blank()
        if (this.location.length > 0) {
          Text(this.location)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .margin({ bottom: 4 })

      Scroll() {
        Column() {
          ForEach(this.navEntries(), (item: NavEntry) => {
            this.DrawerNavItem(item.label, item.tab)
          }, (item: NavEntry) => `nav-${item.tab}`)

          Column()
            .width('100%')
            .height(1)
            .backgroundColor(FG.line)
            .margin({ top: 8, bottom: 8 })

          this.DrawerLinkItem('用户信息', 'UserProfile')
          this.DrawerLinkItem('设置', 'Settings')

          Row() {
            Text('退出登录')
              .fontSize(FG.textLead)
              .fontColor(FG.danger)
          }
          .width('100%')
          .height(48)
          .padding({ left: 12, right: 12 })
          .borderRadius(FG.radius)
          .onClick(() => {
            this.confirmLogout();
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .constraintSize({ maxHeight: '75%' })
    .padding({ left: 8, right: 8, top: 8, bottom: 12 })
    .backgroundColor(FG.surface)
    .border({ width: { bottom: 1 }, color: FG.line })
    .margin({ top: FG.topbarH })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        AppTopBar({
          onMenuClick: () => {
            this.drawerOpen = true;
          }
        })

        Tabs({ barPosition: BarPosition.Start, index: this.activeTab }) {
          TabContent() {
            if (this.activeTab === 0) {
              PetsPage()
            }
          }

          TabContent() {
            if (this.activeTab === 1) {
              FoodsPage()
            }
          }

          TabContent() {
            if (this.activeTab === 2) {
              RemindersPage()
            }
          }

          TabContent() {
            if (this.activeTab === 3) {
              ReportsPage()
            }
          }

          TabContent() {
            if (this.activeTab === 4) {
              KnowledgePage()
            }
          }

          TabContent() {
            if (this.activeTab === 5) {
              NearbyPage()
            }
          }

          TabContent() {
            if (this.activeTab === 6 && this.isAdmin) {
              AdminUsersPage()
            }
          }
        }
        .barHeight(0)
        .scrollable(false)
        .layoutWeight(1)
        .onChange((index: number) => {
          AppStorage.setOrCreate('fg_activeTab', index);
        })
      }
      .width('100%')
      .height('100%')

      if (this.drawerOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(22,24,26,0.32)')
          .onClick(() => {
            this.drawerOpen = false;
          })

        this.Drawer()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
