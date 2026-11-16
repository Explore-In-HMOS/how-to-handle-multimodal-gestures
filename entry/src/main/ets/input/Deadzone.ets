import { Vec2 } from './Vec2';

/**
 * Radial deadzone with rescaling:
 * - a vector shorter than the deadzone becomes zero (wrist jitter);
 * - a longer vector keeps its direction, and its length becomes
 *   (length − deadzone). The output starts at 0 at the edge of the
 *   deadzone, so there is no jump when the tilt leaves it.
 */
export class Deadzone {
  static apply(value: Vec2, deadzone: number): Vec2 {
    const length = value.length();
    if (length <= deadzone || length === 0) {
      return Vec2.ZERO;
    }
    const scale = (length - deadzone) / length;
    return new Vec2(value.x * scale, value.y * scale);
  }
}
