import { Vec2 } from './Vec2';

/**
 * Exponential low-pass filter for the accelerometer x/y axes:
 * filtered = filtered + α × (raw − filtered).
 * A small α gives a smooth but slow value; α = 1 gives the raw value.
 */
export class AccelFilter {
  private alpha: number;
  private value?: Vec2;

  constructor(alpha: number) {
    this.alpha = alpha;
  }

  setAlpha(alpha: number): void {
    this.alpha = alpha;
  }

  update(raw: Vec2): Vec2 {
    const previous = this.value;
    if (previous === undefined) {
      // The first sample has no history: start from it, not from zero.
      this.value = new Vec2(raw.x, raw.y);
    } else {
      this.value = new Vec2(previous.x + this.alpha * (raw.x - previous.x),
        previous.y + this.alpha * (raw.y - previous.y));
    }
    return this.value;
  }

  reset(): void {
    this.value = undefined;
  }
}
