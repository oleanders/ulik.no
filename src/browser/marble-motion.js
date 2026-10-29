import { MARBLE_LIFT, MARBLE_RADIUS, sampleRun, sampleTrack } from './marble-path.js';

export const EXIT_DURATION = 1.4;
export const EXIT_GRAVITY = 3.8;
const FADE_START = 0.45;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const scale = (vector, amount) => ({
	x: vector.x * amount,
	y: vector.y * amount,
	z: vector.z * amount,
});
const length = (vector) => Math.hypot(vector.x, vector.y, vector.z);
const normalize = (vector) => scale(vector, 1 / (length(vector) || 1));
const rollingAxis = (tangent) => normalize({ x: tangent.z, y: 0, z: -tangent.x });
const identity = () => ({ x: 0, y: 0, z: 0, w: 1 });

function multiply(a, b) {
	const result = {
		x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
		w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
	};
	const norm = Math.hypot(result.x, result.y, result.z, result.w);
	return { x: result.x / norm, y: result.y / norm, z: result.z / norm, w: result.w / norm };
}

function rotate(quaternion, axis, angle) {
	const sine = Math.sin(angle / 2);
	return multiply(
		{ x: axis.x * sine, y: axis.y * sine, z: axis.z * sine, w: Math.cos(angle / 2) },
		quaternion,
	);
}

/** Precompute orientation along the path; rendering cadence cannot change the rolling history. */
export function buildMotion(track) {
	const orientations = [identity()];
	const intervals = [];
	let airborneSpin = null;
	for (let index = 0; index < track.points.length - 1; index += 1) {
		const a = track.points[index];
		const b = track.points[index + 1];
		const airborne = a.airborne || b.airborne;
		const midpoint = sampleTrack(track, (a.distance + b.distance) / 2);
		let axis = rollingAxis(midpoint.tangent);
		let angle = (b.distance - a.distance) / MARBLE_RADIUS;
		if (airborne) {
			if (!airborneSpin) {
				const launch = sampleTrack(track, a.distance);
				airborneSpin = { axis: rollingAxis(launch.tangent), speed: a.speed / MARBLE_RADIUS };
			}
			axis = airborneSpin.axis;
			angle = airborneSpin.speed * (b.time - a.time);
		} else airborneSpin = null;
		intervals.push({ axis, angle, airborne, angularSpeed: angle / (b.time - a.time) });
		orientations.push(rotate(orientations.at(-1), axis, angle));
	}
	const end = sampleRun(track, track.duration);
	return {
		track,
		orientations,
		intervals,
		end,
		exitVelocity: scale(end.tangent, end.speed),
		exitSpin: { axis: intervals.at(-1).axis, speed: end.speed / MARBLE_RADIUS },
		duration: track.duration + EXIT_DURATION,
	};
}

/** A reset is simply sampling t=0 again. Airborne spin is constant, including the final fall. */
export function sampleMotion(motion, seconds) {
	const { track } = motion;
	const elapsed = clamp(Number.isFinite(seconds) ? seconds : 0, 0, motion.duration);
	if (elapsed >= track.duration) {
		const time = elapsed - track.duration;
		const { end, exitVelocity: velocity, exitSpin: spin } = motion;
		const fade = clamp((time - FADE_START) / (EXIT_DURATION - FADE_START), 0, 1);
		const opacity = 1 - fade * fade * (3 - 2 * fade);
		const visible = time < EXIT_DURATION - 1e-10;
		const position = {
			x: end.x + velocity.x * time,
			y: end.y + MARBLE_LIFT + velocity.y * time - 0.5 * EXIT_GRAVITY * time ** 2,
			z: end.z + velocity.z * time,
		};
		return {
			...end,
			phase: visible ? 'falling' : 'gone',
			position,
			velocity: { x: velocity.x, y: velocity.y - EXIT_GRAVITY * time, z: velocity.z },
			rotation: rotate(motion.orientations.at(-1), spin.axis, spin.speed * time),
			angularVelocity: scale(spin.axis, spin.speed),
			opacity: visible ? opacity : 0,
			visible,
			airborne: visible,
			speed: Math.hypot(velocity.x, velocity.y - EXIT_GRAVITY * time, velocity.z),
			time: elapsed,
		};
	}
	const point = sampleRun(track, elapsed);
	let low = 0;
	let high = track.points.length - 1;
	while (low + 1 < high) {
		const middle = Math.floor((low + high) / 2);
		if (track.points[middle].time <= elapsed) low = middle;
		else high = middle;
	}
	const a = track.points[low];
	const b = track.points[high];
	const interval = motion.intervals[low];
	const fraction = interval.airborne
		? (elapsed - a.time) / (b.time - a.time)
		: (point.distance - a.distance) / (b.distance - a.distance);
	return {
		...point,
		phase: 'track',
		position: { x: point.x, y: point.y + MARBLE_LIFT, z: point.z },
		velocity: scale(point.tangent, point.speed),
		rotation: rotate(motion.orientations[low], interval.axis, interval.angle * fraction),
		angularVelocity: scale(
			interval.axis,
			interval.airborne ? interval.angularSpeed : point.speed / MARBLE_RADIUS,
		),
		opacity: 1,
		visible: true,
	};
}
