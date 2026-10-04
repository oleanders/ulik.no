import { describe, expect, it } from 'vitest';
import {
	buildTrack,
	JUMP_END,
	JUMP_START,
	normalizeConfig,
	railSpans,
	SEGMENT_TYPES,
	sampleRun,
	sampleTrack,
	segmentPoint,
} from './marble-path.js';

const separation = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
const derivative = (kind, t, h = 0.00001) => {
	const a = segmentPoint(kind, t);
	const b = segmentPoint(kind, t === 1 ? t - h : t + h);
	const sign = t === 1 ? -1 : 1;
	return { x: ((b.x - a.x) / h) * sign, y: ((b.y - a.y) / h) * sign, z: ((b.z - a.z) / h) * sign };
};

describe('interchangeable marble track geometry', () => {
	it('normalizes partial and invalid configuration without mutating it', () => {
		const config = { segments: ['spiral', 'bad'], color: 'nope', camera: 'follow' };
		expect(normalizeConfig(config)).toEqual({
			segments: ['spiral', 'spiral', 'jump'],
			color: 'coral',
			camera: 'follow',
		});
		expect(config.segments).toEqual(['spiral', 'bad']);
	});

	it.each(SEGMENT_TYPES)('%s has compatible endpoints and tangents', (kind) => {
		for (const t of [0, 1]) {
			expect(separation(segmentPoint(kind, t), segmentPoint('sweep', t))).toBeLessThan(1e-9);
			expect(separation(derivative(kind, t), derivative('sweep', t))).toBeLessThan(0.001);
		}
	});

	it('all 27 builds have finite, continuous descending routes and exact finish samples', () => {
		for (const first of SEGMENT_TYPES) {
			for (const second of SEGMENT_TYPES) {
				for (const third of SEGMENT_TYPES) {
					const track = buildTrack([first, second, third]);
					expect(track.points).toHaveLength(741);
					expect(track.duration).toBeGreaterThan(6);
					for (let i = 0; i < track.points.length; i += 1) {
						const point = track.points[i];
						for (const value of [point.x, point.y, point.z, point.distance, point.time])
							expect(Number.isFinite(value)).toBe(true);
						if (i > 0) {
							expect(separation(point, track.points[i - 1])).toBeLessThan(0.15);
							expect(point.distance).toBeGreaterThan(track.points[i - 1].distance);
							expect(point.time).toBeGreaterThan(track.points[i - 1].time);
						}
					}
					expect(track.points.at(-1).y).toBeGreaterThan(0.5);
					expect(track.points.at(-1).y).toBeLessThan(1);
					expect(separation(sampleRun(track, 9999), track.points.at(-1))).toBeLessThan(1e-9);
					expect(sampleRun(track, track.duration).progress).toBe(1);
					expect(separation(sampleTrack(track, -10), track.points[0])).toBe(0);
				}
			}
		}
	});

	it('spirals have actual horizontal turnbacks and remain separated at the crossing', () => {
		const a = segmentPoint('spiral', 0.4);
		const b = segmentPoint('spiral', 0.6);
		expect(b.x).toBeLessThan(a.x);
		// The loop crosses in plan near t=.21 and t=.79; its lower rail is well below its upper rail.
		let crossing = 0;
		for (let t = 0.05; t < 0.45; t += 0.001) {
			const left = segmentPoint('spiral', t);
			const right = segmentPoint('spiral', 1 - t);
			if (Math.abs(left.x - right.x) < 0.025) crossing = Math.abs(left.y - right.y);
		}
		expect(crossing).toBeGreaterThan(0.7);
	});

	it('jump gaps align with parabolic flight and smoothly join their ramps', () => {
		const track = buildTrack(['jump', 'jump', 'jump']);
		const spans = railSpans(track);
		expect(spans).toHaveLength(4);
		for (let index = 0; index < 3; index += 1) {
			expect(spans[index].at(-1).t).toBe(JUMP_START);
			expect(spans[index + 1][0].t).toBe(JUMP_END);
		}
		for (const t of [JUMP_START, JUMP_END]) {
			const h = 0.000001;
			const left = segmentPoint('jump', t - h);
			const middle = segmentPoint('jump', t);
			const right = segmentPoint('jump', t + h);
			expect(Math.abs((middle.y - left.y) / h - (right.y - middle.y) / h)).toBeLessThan(0.001);
		}
		expect(segmentPoint('jump', 0.5).airborne).toBe(true);
		expect(segmentPoint('jump', JUMP_START).airborne).toBe(false);
		expect(segmentPoint('jump', JUMP_END).airborne).toBe(false);
	});

	it('sampling is deterministic, normalized, and finite at both extremes', () => {
		const track = buildTrack();
		for (const time of [-3, 0, 2.25, track.duration, Number.NaN]) {
			const sample = sampleRun(track, time);
			expect(sample).toEqual(sampleRun(track, time));
			expect(Math.hypot(sample.tangent.x, sample.tangent.y, sample.tangent.z)).toBeCloseTo(1, 10);
			expect(sample.progress).toBeGreaterThanOrEqual(0);
			expect(sample.progress).toBeLessThanOrEqual(1);
		}
	});
});
