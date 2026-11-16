export class Constants {
  // Accelerometer: 20 ms (50 Hz) sampling, in nanoseconds.
  static readonly ACCEL_INTERVAL_NS: number = 20000000;
  static readonly SIM_INTERVAL_MS: number = 20;
  static readonly SIM_JITTER: number = 0.4;

  static readonly DEFAULT_DEADZONE: number = 0.6;
  static readonly DEADZONE_MIN: number = 0;
  static readonly DEADZONE_MAX: number = 1.5;
  static readonly DEADZONE_STEP: number = 0.1;
  static readonly DEFAULT_ALPHA: number = 0.2;
  static readonly ALPHA_MIN: number = 0.05;
  static readonly ALPHA_MAX: number = 1;
  static readonly ALPHA_STEP: number = 0.05;
  static readonly DEFAULT_SENSITIVITY: number = 1;
  static readonly SENSITIVITY_MIN: number = 0.5;
  static readonly SENSITIVITY_MAX: number = 3;
  static readonly SENSITIVITY_STEP: number = 0.5;

  // Tilt: object speed in vp/s for each m/s² after the deadzone.
  static readonly TILT_GAIN: number = 40;
  // Tilt input waits this long after the finger leaves the screen.
  static readonly TOUCH_RELEASE_MS: number = 300;
  // A crown event marks the crown as the active source for this long.
  static readonly CROWN_ACTIVE_MS: number = 300;

  // Crown: zoom change per degree of rotation.
  static readonly ZOOM_PER_DEGREE: number = 0.004;
  static readonly ZOOM_MIN: number = 0.5;
  static readonly ZOOM_MAX: number = 2;
  static readonly OBJECT_RADIUS: number = 14;

  // Inertia: velocity factor per 16.67 ms frame, and the speed where it stops.
  static readonly FRICTION_PER_FRAME: number = 0.92;
  static readonly MIN_INERTIA_SPEED: number = 5;
  // A frame longer than this (app was paused) is limited, so the object does not jump.
  static readonly MAX_FRAME_MS: number = 50;

  static readonly CHART_POINTS: number = 60;
  static readonly CHART_REFRESH_MS: number = 100;
  static readonly CHART_RANGE: number = 3;

  static readonly PREFS_NAME: string = 'gesturemix';
  static readonly LOG_LIMIT: number = 20;
  static readonly LOG_DOMAIN: number = 0x0024;
  static readonly LOG_TAG: string = 'GestureMix';
}
