import { describe, expect, it } from '@ohos/hypium';
import { GestureAccumulator, ObjectState } from '../main/ets/input/GestureAccumulator';
import { InputArbiter, InputSource } from '../main/ets/input/InputArbiter';
import { Vec2 } from '../main/ets/input/Vec2';

const ARENA: number = 100;
const T0: number = 1000000;

export default function gesturesTest() {
  describe('GestureAccumulator', () => {
    it('allPanDeltasOfOneFrameAreApplied', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.addPan(3, 1);
      accumulator.addPan(4, 2);
      accumulator.addPan(-2, 0);
      const state = accumulator.applyFrame(new ObjectState(), 16, Vec2.ZERO, ARENA);
      expect(state.x).assertEqual(5);
      expect(state.y).assertEqual(3);
      // The deltas are used one time only.
      expect(accumulator.applyFrame(state, 16, Vec2.ZERO, ARENA).x).assertEqual(5);
    });

    it('sensitivityScalesPanDeltas', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.sensitivity = 2;
      accumulator.addPan(10, 0);
      expect(accumulator.applyFrame(new ObjectState(), 16, Vec2.ZERO, ARENA).x).assertEqual(20);
    });

    it('objectStaysInsideTheRoundArena', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.addPan(300, 400);
      const state = accumulator.applyFrame(new ObjectState(), 16, Vec2.ZERO, ARENA);
      // Arena radius 100 minus object radius 14 at zoom 1.
      expect(Math.round(Math.sqrt(state.x * state.x + state.y * state.y))).assertEqual(86);
      // The direction is kept: 3:4.
      expect(Math.round(state.x / state.y * 100)).assertEqual(75);
    });

    it('crownChangesZoomInsideLimits', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.addCrown(50);
      const zoomed = accumulator.applyFrame(new ObjectState(), 16, Vec2.ZERO, ARENA);
      expect(Math.round(zoomed.zoom * 100)).assertEqual(120);
      accumulator.addCrown(100000);
      expect(accumulator.applyFrame(zoomed, 16, Vec2.ZERO, ARENA).zoom).assertEqual(2);
    });

    it('tiltIsAVelocity', 0, () => {
      const accumulator = new GestureAccumulator();
      // 40 vp/s for 50 ms is 2 vp.
      const state = accumulator.applyFrame(new ObjectState(), 50, new Vec2(40, 0), ARENA);
      expect(Math.round(state.x * 1000) / 1000).assertEqual(2);
    });

    it('inertiaSlowsDownAndStops', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.startInertia(100, 0);
      let state = new ObjectState();
      for (let i = 0; i < 200; i++) {
        state = accumulator.applyFrame(state, 16.67, Vec2.ZERO, 1000);
      }
      expect(accumulator.hasInertia()).assertFalse();
      expect(state.x > 0).assertTrue();
    });

    it('edgeStopsInertia', 0, () => {
      const accumulator = new GestureAccumulator();
      accumulator.startInertia(10000, 0);
      accumulator.applyFrame(new ObjectState(), 50, Vec2.ZERO, ARENA);
      expect(accumulator.hasInertia()).assertFalse();
    });
  });

  describe('InputArbiter', () => {
    it('touchBlocksTilt', 0, () => {
      const arbiter = new InputArbiter();
      arbiter.touchStart();
      expect(arbiter.tiltAllowed(T0)).assertFalse();
      expect(arbiter.source(T0, true)).assertEqual(InputSource.TOUCH);
    });

    it('tiltWaits300MsAfterTouch', 0, () => {
      const arbiter = new InputArbiter();
      arbiter.touchStart();
      arbiter.touchEnd(T0);
      expect(arbiter.tiltAllowed(T0 + 299)).assertFalse();
      expect(arbiter.tiltAllowed(T0 + 300)).assertTrue();
    });

    it('sourceShowsCrownThenTiltThenIdle', 0, () => {
      const arbiter = new InputArbiter();
      arbiter.crown(T0);
      expect(arbiter.source(T0 + 100, true)).assertEqual(InputSource.CROWN);
      expect(arbiter.source(T0 + 400, true)).assertEqual(InputSource.TILT);
      expect(arbiter.source(T0 + 400, false)).assertEqual(InputSource.IDLE);
    });
  });
}
