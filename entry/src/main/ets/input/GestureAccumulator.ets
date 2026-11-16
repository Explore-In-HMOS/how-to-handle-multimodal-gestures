import { Constants } from '../common/Constants';
import { Vec2 } from './Vec2';

export class ObjectState {
  x: number = 0;
  y: number = 0;
  zoom: number = 1;

  copy(): ObjectState {
    const state = new ObjectState();
    state.x = this.x;
    state.y = this.y;
    state.zoom = this.zoom;
    return state;
  }

  equals(other: ObjectState): boolean {
    return this.x === other.x && this.y === other.y && this.zoom === other.zoom;
  }
}

/**
 * Collects input between frames and applies it once per frame:
 * - pan deltas and crown degrees are added up, so no delta is lost when
 *   many events come in one frame;
 * - tilt is a velocity (vp/s), integrated with the frame time;
 * - inertia continues the pan velocity after release and slows down;
 * - the object stays inside the round arena (polar clamp).
 */
export class GestureAccumulator {
  sensitivity: number = Constants.DEFAULT_SENSITIVITY;
  private pending: Vec2 = new Vec2(0, 0);
  private pendingDegrees: number = 0;
  private velocity: Vec2 = new Vec2(0, 0);

  addPan(dx: number, dy: number): void {
    this.pending = new Vec2(this.pending.x + dx, this.pending.y + dy);
  }

  addCrown(degrees: number): void {
    this.pendingDegrees += degrees;
  }

  startInertia(vx: number, vy: number): void {
    this.velocity = new Vec2(vx, vy);
  }

  stopInertia(): void {
    this.velocity = new Vec2(0, 0);
  }

  hasInertia(): boolean {
    return this.velocity.length() > 0;
  }

  /** Returns the new state. `arenaRadius` is the radius of the round area in vp. */
  applyFrame(state: ObjectState, frameMs: number, tilt: Vec2, arenaRadius: number): ObjectState {
    const dt = Math.min(Math.max(frameMs, 0), Constants.MAX_FRAME_MS) / 1000;
    const next = state.copy();

    next.zoom = Math.min(Math.max(state.zoom + this.pendingDegrees * Constants.ZOOM_PER_DEGREE, Constants.ZOOM_MIN),
      Constants.ZOOM_MAX);
    next.x += this.pending.x * this.sensitivity + (tilt.x + this.velocity.x) * dt;
    next.y += this.pending.y * this.sensitivity + (tilt.y + this.velocity.y) * dt;
    this.pending = new Vec2(0, 0);
    this.pendingDegrees = 0;

    if (this.hasInertia()) {
      const friction = Math.pow(Constants.FRICTION_PER_FRAME, dt * 1000 / 16.67);
      this.velocity = new Vec2(this.velocity.x * friction, this.velocity.y * friction);
      if (this.velocity.length() < Constants.MIN_INERTIA_SPEED) {
        this.stopInertia();
      }
    }

    const maxRadius = Math.max(arenaRadius - Constants.OBJECT_RADIUS * next.zoom, 0);
    const distance = Math.sqrt(next.x * next.x + next.y * next.y);
    if (distance > maxRadius) {
      const scale = distance === 0 ? 0 : maxRadius / distance;
      next.x *= scale;
      next.y *= scale;
      // The edge stops the throw.
      this.stopInertia();
    }
    return next;
  }

  reset(): void {
    this.pending = new Vec2(0, 0);
    this.pendingDegrees = 0;
    this.stopInertia();
  }
}
