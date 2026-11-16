import { Constants } from '../common/Constants';

export enum InputSource {
  IDLE = 'IDLE',
  TOUCH = 'TOUCH',
  CROWN = 'CROWN',
  TILT = 'TILT'
}

/**
 * Priority between the inputs: touch wins. While a finger is on the
 * screen, and for 300 ms after it leaves, tilt does not move the object.
 * The crown changes the zoom only, so it does not block the other inputs.
 */
export class InputArbiter {
  private touchActive: boolean = false;
  private touchEndedAt: number = 0;
  private crownAt: number = 0;

  touchStart(): void {
    this.touchActive = true;
  }

  touchEnd(now: number): void {
    this.touchActive = false;
    this.touchEndedAt = now;
  }

  crown(now: number): void {
    this.crownAt = now;
  }

  tiltAllowed(now: number): boolean {
    return !this.touchActive && (this.touchEndedAt === 0 || now - this.touchEndedAt >= Constants.TOUCH_RELEASE_MS);
  }

  /** The source shown on the screen. `tiltMoving` is true when tilt is out of the deadzone. */
  source(now: number, tiltMoving: boolean): InputSource {
    if (this.touchActive) {
      return InputSource.TOUCH;
    }
    if (this.crownAt > 0 && now - this.crownAt < Constants.CROWN_ACTIVE_MS) {
      return InputSource.CROWN;
    }
    if (tiltMoving && this.tiltAllowed(now)) {
      return InputSource.TILT;
    }
    return InputSource.IDLE;
  }

  reset(): void {
    this.touchActive = false;
    this.touchEndedAt = 0;
    this.crownAt = 0;
  }
}
