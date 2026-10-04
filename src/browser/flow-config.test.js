import { describe, expect, it } from 'vitest';
import { seededRandom } from './flow-config.js';

describe('seeded canvas randomness', () => {
	it('produces deterministic, distinct, bounded sequences including the largest URL seed', () => {
		const sequence = (seed) => Array.from({ length: 500 }, seededRandom(seed));
		expect(sequence(12)).toEqual(sequence(12));
		expect(sequence(12)).not.toEqual(sequence(13));
		expect(sequence(0xffffffff).every((value) => value >= 0 && value < 1)).toBe(true);
	});
});
