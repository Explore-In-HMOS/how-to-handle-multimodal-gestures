import { describe, expect, it } from '@ohos/hypium';
import { AccelFilter } from '../main/ets/input/AccelFilter';
import { Deadzone } from '../main/ets/input/Deadzone';
import { Vec2 } from '../main/ets/input/Vec2';

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}

export default function filtersTest() {
  describe('AccelFilter', () => {
    it('firstSamplePassesThrough', 0, () => {
      const filter = new AccelFilter(0.2);
      const value = filter.update(new Vec2(1, -2));
      expect(value.x).assertEqual(1);
      expect(value.y).assertEqual(-2);
    });

    it('movesAlphaOfTheWayToTheNewValue', 0, () => {
      const filter = new AccelFilter(0.2);
      filter.update(new Vec2(0, 0));
      const value = filter.update(new Vec2(1, 0));
      expect(round(value.x)).assertEqual(0.2);
    });

    it('convergesToAConstantInput', 0, () => {
      const filter = new AccelFilter(0.2);
      filter.update(new Vec2(0, 0));
      let value = new Vec2(0, 0);
      for (let i = 0; i < 50; i++) {
        value = filter.update(new Vec2(2, 0));
      }
      expect(round(value.x)).assertEqual(2);
    });

    it('resetForgetsTheHistory', 0, () => {
      const filter = new AccelFilter(0.2);
      filter.update(new Vec2(5, 5));
      filter.reset();
      expect(filter.update(new Vec2(1, 1)).x).assertEqual(1);
    });
  });

  describe('Deadzone', () => {
    it('smallVectorBecomesZero', 0, () => {
      const value = Deadzone.apply(new Vec2(0.3, 0.4), 0.6);
      expect(value.x).assertEqual(0);
      expect(value.y).assertEqual(0);
    });

    it('outputStartsAtZeroOnTheEdge', 0, () => {
      // Length 1.0, deadzone 0.6: the output length is 0.4.
      const value = Deadzone.apply(new Vec2(0.6, 0.8), 0.6);
      expect(round(value.length())).assertEqual(0.4);
    });

    it('directionIsKept', 0, () => {
      const value = Deadzone.apply(new Vec2(0, -2), 0.5);
      expect(value.x).assertEqual(0);
      expect(round(value.y)).assertEqual(-1.5);
    });

    it('zeroDeadzonePassesThrough', 0, () => {
      const value = Deadzone.apply(new Vec2(0.1, 0.05), 0);
      expect(round(value.x)).assertEqual(0.1);
      expect(round(value.y)).assertEqual(0.05);
    });
  });
}
