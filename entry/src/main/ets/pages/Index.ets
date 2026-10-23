import { AppShell } from '../components/AppShell';
import { AuthPage } from './AuthPage';
import { FoodFormPage } from './FoodFormPage';
import { NutritionPage } from './NutritionPage';
import { OnboardingPage } from './OnboardingPage';
import { PetHomePage } from './PetHomePage';
import { PetProfilePage } from './PetProfilePage';
import { PlaceholderPage } from './PlaceholderPage';
import { ReminderCalendarPage } from './ReminderCalendarPage';
import { RemindersPage } from './RemindersPage';
import { ReportDetailPage } from './ReportDetailPage';
import { ReportsPage } from './ReportsPage';

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
    if (AppStorage.get<boolean>('fg_foodsDirty') === undefined) {
      AppStorage.setOrCreate('fg_foodsDirty', false);
    }
  }

  private onTokenChange(): void {
    if (this.token.length === 0) {
      this.pathStack.clear();
    }
  }

  @Builder
  PageMap(name: string, param: Object) {
    NavDestination() {
      if (name === 'Onboarding') {
        OnboardingPage()
      } else if (name === 'PetHome') {
        PetHomePage()
      } else if (name === 'PetProfile') {
        PetProfilePage()
      } else if (name === 'FoodForm') {
        FoodFormPage({ editId: paramNumber(param) })
      } else if (name === 'Nutrition') {
        NutritionPage({ petId: paramNumber(param) })
      } else if (name === 'Reminders') {
        RemindersPage({ initialPetId: paramNumber(param), showBack: true })
      } else if (name === 'ReminderCalendar') {
        ReminderCalendarPage({ initialPetId: paramNumber(param) })
      } else if (name === 'Reports') {
        ReportsPage()
      } else if (name === 'ReportDetail') {
        ReportDetailPage({ reportId: paramNumber(param) })
      } else if (name === 'Knowledge') {
        PlaceholderPage({
          title: '知识库',
          description: 'AI 问答、会话记录与知识来源。',
          showBack: true
        })
      } else if (name === 'Nearby') {
        PlaceholderPage({
          title: '周边',
          description: '附近宠物医院与公园。',
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

function paramNumber(param: Object): number {
  return typeof param === 'number' ? param as number : 0;
}
