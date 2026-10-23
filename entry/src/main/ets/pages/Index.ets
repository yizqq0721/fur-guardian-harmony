import { AppShell } from '../components/AppShell';
import { AuthPage } from './AuthPage';
import { OnboardingPage } from './OnboardingPage';
import { PetHomePage } from './PetHomePage';
import { PetProfilePage } from './PetProfilePage';
import { PlaceholderPage } from './PlaceholderPage';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageLink('fg_token') @Watch('onTokenChange') token: string = '';

  aboutToAppear(): void {
    AppStorage.setOrCreate('fg_pathStack', this.pathStack);
    if (AppStorage.get<Object[]>('fg_pets') === undefined) {
      AppStorage.setOrCreate('fg_pets', [] as Object[]);
    }
    if (AppStorage.get<boolean>('fg_petsLoaded') === undefined) {
      AppStorage.setOrCreate('fg_petsLoaded', false);
    }
    if (AppStorage.get<number>('fg_activeTab') === undefined) {
      AppStorage.setOrCreate('fg_activeTab', 0);
    }
    if (AppStorage.get<boolean>('fg_drawerOpen') === undefined) {
      AppStorage.setOrCreate('fg_drawerOpen', false);
    }
    if (AppStorage.get<boolean>('fg_pendingOnboarding') === undefined) {
      AppStorage.setOrCreate('fg_pendingOnboarding', false);
    }
  }

  private onTokenChange(): void {
    if (this.token.length === 0) {
      this.pathStack.clear();
    }
  }

  @Builder
  PageMap(name: string) {
    NavDestination() {
      if (name === 'Onboarding') {
        OnboardingPage()
      } else if (name === 'PetHome') {
        PetHomePage()
      } else if (name === 'PetProfile') {
        PetProfilePage()
      } else if (name === 'Nutrition') {
        PlaceholderPage({
          title: '营养方案',
          description: '主粮、热量与喂食建议。',
          showBack: true
        })
      } else if (name === 'Reminders') {
        PlaceholderPage({
          title: '提醒',
          description: '喂食、遛弯、驱虫与疫苗提醒。',
          showBack: true
        })
      } else if (name === 'Settings') {
        PlaceholderPage({
          title: '设置',
          description: '账号、邮件提醒与应用设置。',
          showBack: true
        })
      } else if (name === 'UserProfile') {
        PlaceholderPage({
          title: '用户信息',
          description: '昵称、当前位置与账号概览。',
          showBack: true
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
  }

  build() {
    Stack() {
      Image($r('app.media.site_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(247,246,242,0.62)')

      Navigation(this.pathStack) {
        if (this.token.length > 0) {
          AppShell()
        } else {
          AuthPage()
        }
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.PageMap)
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(FG_PAPER)
  }
}

const FG_PAPER: string = '#F7F6F2';
