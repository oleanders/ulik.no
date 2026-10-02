import { describe, expect, it } from 'vitest';
import {
	contextOpacity,
	INITIAL_STRENGTH,
	illusions,
	lineEndpoints,
	surroundingCircles,
	TARGET_COLOR,
	TARGET_LENGTH,
	TARGET_RADIUS,
} from './illusions';

describe('lik≠lik invariants', () => {
	it('has three unique curated scenes with source links', () => {
		expect(illusions.map((illusion) => illusion.id)).toEqual(['farge', 'sirkler', 'linjer']);
		expect(illusions.every((illusion) => illusion.source.startsWith('https://'))).toBe(true);
	});
	it('only varies context opacity and removes it completely on reveal', () => {
		expect(INITIAL_STRENGTH).toBe(100);
		for (const strength of [0, 25, 50, 75, 100]) {
			expect(contextOpacity(strength, false)).toBe(strength / 100);
			expect(contextOpacity(strength, true)).toBe(0);
		}
		expect(contextOpacity(-20, false)).toBe(0);
		expect(contextOpacity(120, false)).toBe(1);
	});
	it('keeps the target color, radius and line length fixed', () => {
		expect(TARGET_COLOR).toBe('#82978b');
		expect(TARGET_RADIUS).toBe(28);
		const { x1, x2 } = lineEndpoints();
		expect(x2 - x1).toBe(TARGET_LENGTH);
		expect(TARGET_LENGTH).toBe(280);
	});
	it('places six surrounding circles without changing the center target', () => {
		for (const [center, radius, distance] of [
			[180, 43, 89],
			[540, 13, 48],
		]) {
			const ring = surroundingCircles(center, radius, distance);
			expect(ring).toHaveLength(6);
			for (const circle of ring) {
				expect(circle.radius).toBe(radius);
				expect(Math.hypot(circle.x - center, circle.y - 135)).toBeCloseTo(distance);
				expect(distance - radius).toBeGreaterThan(TARGET_RADIUS);
			}
		}
	});
});
