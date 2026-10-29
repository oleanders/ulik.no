import { describe, expect, it } from 'vitest';
import { buildMotion, EXIT_DURATION, EXIT_GRAVITY, sampleMotion } from './marble-motion.js';
import { buildTrack, MARBLE_RADIUS, SEGMENT_TYPES } from './marble-path.js';

const length = (v) => Math.hypot(v.x, v.y, v.z);
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
const quaternionDistance = (a, b) => {
	const dot = Math.abs(a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w);
	return 2 * Math.acos(Math.min(1, dot));
};

describe('natural deterministic marble motion', () => {
	it('gives identical positions and rolling orientations at any rendering cadence', () => {
		const motion = buildMotion(buildTrack());
		const targets = [1.234, 4.73, 8.912, motion.track.duration + 0.61];
		for (const target of targets) {
			const expected = sampleMotion(motion, target);
			for (const fps of [6, 24, 60, 144]) {
				for (let time = 0; time < target; time += 1 / fps) sampleMotion(motion, time);
				expect(sampleMotion(motion, target)).toEqual(expected);
			}
		}
	});

	it('rolls through actual arc distance divided by radius rather than per-frame chords', () => {
		const motion = buildMotion(buildTrack(['spiral', 'sweep', 'jump']));
		for (let index = 0; index < motion.intervals.length; index += 1) {
			const interval = motion.intervals[index];
			if (interval.airborne) continue;
			const traveled =
				motion.track.points[index + 1].distance - motion.track.points[index].distance;
			expect(interval.angle).toBeCloseTo(traveled / MARBLE_RADIUS, 12);
			expect(
				quaternionDistance(motion.orientations[index], motion.orientations[index + 1]),
			).toBeCloseTo(interval.angle, 8);
		}
	});

	it('conserves spin axis and angular velocity across every jump', () => {
		const motion = buildMotion(buildTrack(['jump', 'jump', 'jump']));
		for (const section of motion.track.sections) {
			const points = motion.track.points
				.slice(section.start, section.end + 1)
				.filter((point) => point.airborne);
			const launch = sampleMotion(motion, points[0].time);
			for (const point of points)
				expect(
					distance(sampleMotion(motion, point.time).angularVelocity, launch.angularVelocity),
				).toBeLessThan(1e-9);
		}
	});

	it('keeps position, velocity and spin continuous as the run-out becomes a ballistic hop', () => {
		const motion = buildMotion(buildTrack());
		const h = 0.00001;
		const before = sampleMotion(motion, motion.track.duration - h);
		const launch = sampleMotion(motion, motion.track.duration);
		const after = sampleMotion(motion, motion.track.duration + h);
		expect(before.phase).toBe('track');
		expect(launch.phase).toBe('falling');
		expect(launch.speed).toBeGreaterThan(2);
		expect(launch.velocity.y).toBeGreaterThan(0);
		expect(distance(before.position, launch.position)).toBeLessThan(0.0001);
		expect(distance(before.velocity, launch.velocity)).toBeLessThan(0.001);
		expect(distance(after.velocity, launch.velocity)).toBeCloseTo(EXIT_GRAVITY * h, 9);
		expect(quaternionDistance(before.rotation, launch.rotation)).toBeLessThan(0.001);
		expect(distance(before.angularVelocity, launch.angularVelocity)).toBeLessThan(0.002);
	});

	it('coasts horizontally without halting, falls under gravity, fades, then disappears', () => {
		const motion = buildMotion(buildTrack());
		const launch = sampleMotion(motion, motion.track.duration);
		const flight = sampleMotion(motion, motion.track.duration + 0.9);
		const gone = sampleMotion(motion, motion.duration);
		expect(flight.phase).toBe('falling');
		expect(flight.visible).toBe(true);
		expect(flight.opacity).toBeGreaterThan(0);
		expect(flight.opacity).toBeLessThan(1);
		expect(flight.position.x).toBeCloseTo(launch.position.x + launch.velocity.x * 0.9, 10);
		expect(flight.position.z).toBeCloseTo(launch.position.z + launch.velocity.z * 0.9, 10);
		expect(flight.position.y).toBeCloseTo(
			launch.position.y + launch.velocity.y * 0.9 - 0.5 * EXIT_GRAVITY * 0.9 ** 2,
			10,
		);
		expect(flight.angularVelocity).toEqual(launch.angularVelocity);
		expect(gone.phase).toBe('gone');
		expect(gone.visible).toBe(false);
		expect(gone.airborne).toBe(false);
		expect(gone.opacity).toBe(0);
		expect(motion.duration).toBeCloseTo(motion.track.duration + EXIT_DURATION, 10);
		expect(sampleMotion(motion, motion.duration + 100)).toEqual(gone);
		expect(sampleMotion(motion, 0).visible).toBe(true);
		expect(sampleMotion(motion, 0).rotation).toEqual({ x: 0, y: 0, z: 0, w: 1 });
	});

	it('all 27 combinations exit outside the platform and have bounded acceleration and finite motion', () => {
		for (const a of SEGMENT_TYPES) {
			for (const b of SEGMENT_TYPES) {
				for (const c of SEGMENT_TYPES) {
					const track = buildTrack([a, b, c]);
					const motion = buildMotion(track);
					const launch = sampleMotion(motion, track.duration);
					expect(Math.hypot(launch.position.x, launch.position.z + 0.6)).toBeGreaterThan(
						7.35 + MARBLE_RADIUS,
					);
					expect(
						launch.position.x * launch.velocity.x + (launch.position.z + 0.6) * launch.velocity.z,
					).toBeGreaterThan(0);
					expect(track.finish.distance).toBeLessThan(track.length - 2.5);
					for (let index = 1; index < track.points.length; index += 1) {
						const previous = track.points[index - 1];
						const point = track.points[index];
						const acceleration = (point.speed - previous.speed) / (point.time - previous.time);
						expect(acceleration).toBeLessThanOrEqual(2.500001);
						expect(acceleration).toBeGreaterThanOrEqual(-2.400001);
					}
					for (let t = 0; t <= motion.duration; t += 0.17) {
						const sample = sampleMotion(motion, t);
						for (const value of [
							...Object.values(sample.position),
							...Object.values(sample.rotation),
							sample.speed,
						])
							expect(Number.isFinite(value)).toBe(true);
						expect(Math.hypot(...Object.values(sample.rotation))).toBeCloseTo(1, 10);
						expect(length(sample.velocity)).toBeGreaterThan(0);
					}
				}
			}
		}
	});
});
