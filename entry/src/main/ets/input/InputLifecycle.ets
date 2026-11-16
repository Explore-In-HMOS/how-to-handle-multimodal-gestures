import { sensor } from '@kit.SensorServiceKit';
import { Constants } from '../common/Constants';
import { LogLevel } from '../common/Logger';
import { Vec2 } from './Vec2';

export enum TiltSource {
  OFF = 'off',
  REAL = 'real',
  SIM = 'sim'
}

/**
 * Owns the accelerometer subscription. The page starts it in onPageShow and
 * stops it in onPageHide, so the sensor never runs while the watch face is
 * not visible (background, screen off). Without an accelerometer, or when
 * simulation is on, a 50 Hz timer gives values from the simulation sliders.
 */
export class InputLifecycle {
  simTilt: Vec2 = new Vec2(0, 0);
  simJitter: boolean = true;
  private simPhase: number = 0;
  private source: TiltSource = TiltSource.OFF;
  private simTimerId: number = -1;
  private onSample: (raw: Vec2) => void;
  private onLog: (message: string, level: LogLevel) => void;
  private callback = (data: sensor.AccelerometerResponse): void => {
    this.onSample(new Vec2(data.x, data.y));
  };

  constructor(onSample: (raw: Vec2) => void, onLog: (message: string, level: LogLevel) => void) {
    this.onSample = onSample;
    this.onLog = onLog;
  }

  getSource(): TiltSource {
    return this.source;
  }

  subscriptions(): number {
    return this.source === TiltSource.OFF ? 0 : 1;
  }

  start(simulate: boolean): TiltSource {
    this.stop();
    if (!simulate && this.subscribeReal()) {
      this.source = TiltSource.REAL;
      return this.source;
    }
    this.source = TiltSource.SIM;
    this.simTimerId = setInterval(() => this.simTick(), Constants.SIM_INTERVAL_MS);
    this.onLog('Simulated tilt started (50 Hz)', LogLevel.INFO);
    return this.source;
  }

  stop(): void {
    if (this.source === TiltSource.REAL) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER, this.callback);
        this.onLog('sensor.off(ACCELEROMETER)', LogLevel.INFO);
      } catch (err) {
        this.onLog(`sensor.off(ACCELEROMETER) failed: ${JSON.stringify(err)}`, LogLevel.ERROR);
      }
    } else if (this.source === TiltSource.SIM) {
      clearInterval(this.simTimerId);
      this.simTimerId = -1;
      this.onLog('Simulated tilt stopped', LogLevel.INFO);
    }
    this.source = TiltSource.OFF;
  }

  private subscribeReal(): boolean {
    try {
      sensor.getSingleSensorSync(sensor.SensorId.ACCELEROMETER);
    } catch (err) {
      this.onLog('ACCELEROMETER is not available: using simulated tilt', LogLevel.WARN);
      return false;
    }
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.callback, { interval: Constants.ACCEL_INTERVAL_NS });
      this.onLog('sensor.on(ACCELEROMETER), 50 Hz', LogLevel.INFO);
      return true;
    } catch (err) {
      this.onLog(`sensor.on(ACCELEROMETER) failed: ${JSON.stringify(err)}`, LogLevel.ERROR);
      return false;
    }
  }

  private simTick(): void {
    this.simPhase++;
    const jx = this.simJitter ? Math.sin(this.simPhase * 1.7) * Constants.SIM_JITTER : 0;
    const jy = this.simJitter ? Math.sin(this.simPhase * 2.3 + 1.1) * Constants.SIM_JITTER : 0;
    this.onSample(new Vec2(this.simTilt.x + jx, this.simTilt.y + jy));
  }
}
