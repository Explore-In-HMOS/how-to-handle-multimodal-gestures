import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';

/** Deadzone, filter and touch settings, saved in preferences. */
export class InputSettings {
  deadzone: number = Constants.DEFAULT_DEADZONE;
  alpha: number = Constants.DEFAULT_ALPHA;
  sensitivity: number = Constants.DEFAULT_SENSITIVITY;
  inertia: boolean = true;

  copy(): InputSettings {
    const settings = new InputSettings();
    settings.deadzone = this.deadzone;
    settings.alpha = this.alpha;
    settings.sensitivity = this.sensitivity;
    settings.inertia = this.inertia;
    return settings;
  }

  static load(context: common.Context): InputSettings {
    const settings = new InputSettings();
    try {
      const prefs = preferences.getPreferencesSync(context, { name: Constants.PREFS_NAME });
      settings.deadzone = prefs.getSync('deadzone', settings.deadzone) as number;
      settings.alpha = prefs.getSync('alpha', settings.alpha) as number;
      settings.sensitivity = prefs.getSync('sensitivity', settings.sensitivity) as number;
      settings.inertia = prefs.getSync('inertia', settings.inertia) as boolean;
    } catch (err) {
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'Settings load failed: %{public}s', JSON.stringify(err));
    }
    return settings;
  }

  save(context: common.Context): void {
    try {
      const prefs = preferences.getPreferencesSync(context, { name: Constants.PREFS_NAME });
      prefs.putSync('deadzone', this.deadzone);
      prefs.putSync('alpha', this.alpha);
      prefs.putSync('sensitivity', this.sensitivity);
      prefs.putSync('inertia', this.inertia);
      prefs.flush().catch((err: Error) => {
        hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'Settings flush failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'Settings save failed: %{public}s', JSON.stringify(err));
    }
  }

  static round(value: number, step: number): number {
    return Math.round(value / step) * step;
  }
}
