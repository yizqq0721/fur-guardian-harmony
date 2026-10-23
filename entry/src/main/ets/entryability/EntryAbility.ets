import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onCreate');
    PersistentStorage.persistProp('fg_token', '');
    PersistentStorage.persistProp('fg_userId', 0);
    PersistentStorage.persistProp('fg_nickname', '');
    PersistentStorage.persistProp('fg_isAdmin', false);
    PersistentStorage.persistProp('fg_location', '');
    PersistentStorage.persistProp('fg_currentPetId', 0);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'FurGuardian', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'FurGuardian', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#F7F6F2',
        statusBarContentColor: '#16181A',
        navigationBarColor: '#F7F6F2',
        navigationBarContentColor: '#16181A'
      });
    } catch (err) {
      hilog.error(DOMAIN, 'FurGuardian', 'Failed to configure window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'FurGuardian', '%{public}s', 'Ability onBackground');
  }
}
