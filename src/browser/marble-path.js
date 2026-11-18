/** Pure, deterministic geometry for a guided marble run. Distances are world units. */
export const SEGMENT_TYPES = ['sweep', 'spiral', 'jump'];
export const MARBLE_RADIUS = 0.27;
export const RAIL_HALF_WIDTH = 0.19;
export const RAIL_RADIUS = 0.047;
export const MARBLE_LIFT = Math.sqrt((MARBLE_RADIUS + RAIL_RADIUS) ** 2 - RAIL_HALF_WIDTH ** 2);
export const JUMP_START = 0.38;
export const JUMP_END = 0.62;
const LENGTH = 7.3;
const DROP = 1.65;
const TURN_RADIUS = 1.3;
const TURN_ANGLE = (Math.PI * 2) / 3;
const RUNUP_RADIUS = 2.9;
const RUNUP_ARC = (RUNUP_RADIUS * Math.PI) / 2;
const RUNUP_DROP = (DROP / LENGTH) * RUNUP_ARC;
const INITIAL_SPEED = 0.28;
const DEFAULT_SEGMENTS = ['sweep', 'spiral', 'jump'];
const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const distance = (a, b) => Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z);
const lerp = (a, b, t) => a + (b - a) * t;

export function normalizeConfig(config = {}) {
	return {
		segments: DEFAULT_SEGMENTS.map((fallback, index) =>
			SEGMENT_TYPES.includes(config.segments?.[index]) ? config.segments[index] : fallback,
		),
		camera: config.camera === 'follow' ? 'follow' : 'overview',
		color: ['coral', 'mint', 'violet'].includes(config.color) ? config.color : 'coral',
	};
}

function hermite(a, b, da, db, t, width) {
	return (
		(2 * t ** 3 - 3 * t ** 2 + 1) * a +
		(t ** 3 - 2 * t ** 2 + t) * da * width +
		(-2 * t ** 3 + 3 * t ** 2) * b +
		(t ** 3 - t ** 2) * db * width
	);
}

/** The open middle of a jump is an exact parabola, tangent to both approach ramps. */
function jumpHeight(t) {
	const shoulder = 0.7;
	const rise = 0.26;
	const gapWidth = JUMP_END - JUMP_START;
	const slope = (4 * rise) / gapWidth;
	if (t < JUMP_START) return hermite(0, shoulder, 0, slope, t / JUMP_START, JUMP_START);
	if (t > JUMP_END)
		return hermite(shoulder, 0, -slope, 0, (t - JUMP_END) / (1 - JUMP_END), 1 - JUMP_END);
	const u = (t - JUMP_START) / gapWidth;
	return shoulder + 4 * rise * u * (1 - u);
}

/** Every interchangeable piece has identical endpoint positions and endpoint tangents. */
export function segmentPoint(kind, progress) {
	const t = clamp(progress, 0, 1);
	const envelope = Math.sin(Math.PI * t) ** 2;
	let x = LENGTH * t;
	let z = 0;
	let lift = 0;
	if (kind === 'spiral') {
		x += 1.8 * (Math.sin(2 * Math.PI * t) - 0.5 * Math.sin(4 * Math.PI * t));
		z = 2.9 * envelope;
	} else if (kind === 'jump') {
		lift = jumpHeight(t);
	} else {
		z = 0.8 * envelope;
	}
	return { x, y: -DROP * t + lift, z, airborne: kind === 'jump' && t > JUMP_START && t < JUMP_END };
}

function transform(point, origin, heading) {
	return {
		x: origin.x + point.x * Math.cos(heading) - point.z * Math.sin(heading),
		y: origin.y + point.y,
		z: origin.z + point.x * Math.sin(heading) + point.z * Math.cos(heading),
		airborne: point.airborne ?? false,
	};
}

/** Build a closed-looking triangular circuit that descends from the start to the finish. */
export function buildTrack(segments = DEFAULT_SEGMENTS) {
	const kinds = normalizeConfig({ segments }).segments;
	const points = [];
	const sections = [];
	let origin = { x: -LENGTH / 2, y: 7.1, z: -4.9 };
	let heading = 0;
	const add = (point, section, kind, t) => {
		const previous = points.at(-1);
		const step = previous ? distance(previous, point) : 0;
		if (previous && step < 1e-9) return;
		const startHeight = 7.1 + RUNUP_DROP;
		const speed = (p) =>
			Math.min(7.2, Math.sqrt(INITIAL_SPEED ** 2 + 6 * Math.max(0, startHeight - p.y)));
		points.push({
			...point,
			section,
			kind,
			t,
			speed: speed(point),
			distance: (previous?.distance ?? 0) + step,
			time: (previous?.time ?? 0) + (previous ? step / ((speed(previous) + speed(point)) / 2) : 0),
		});
	};
	// A permanent downhill approach gives every first piece the same rolling entry.
	// Its quarter-turn stays inside the platform and meets slot 1 tangentially.
	for (let index = 0; index <= 100; index += 1) {
		const t = index / 100;
		const angle = (Math.PI / 2) * t;
		add(
			{
				x: origin.x - RUNUP_RADIUS * Math.cos(angle),
				y: origin.y + RUNUP_DROP * (1 - t),
				z: origin.z + RUNUP_RADIUS * (1 - Math.sin(angle)),
				airborne: false,
			},
			-1,
			'runup',
			t,
		);
	}
	const runup = {
		start: 0,
		end: points.length - 1,
		length: points.at(-1).distance,
		duration: points.at(-1).time,
	};
	for (let index = 0; index < 3; index += 1) {
		const kind = kinds[index];
		const start = points.length ? points.length - 1 : 0;
		for (let i = 0; i <= 200; i += 1) {
			const t = i / 200;
			add(transform(segmentPoint(kind, t), origin, heading), index, kind, t);
		}
		sections.push({ kind, index, start, end: points.length - 1 });
		origin = transform(segmentPoint(kind, 1), origin, heading);
		if (index < 2) {
			const turnDrop = (DROP / LENGTH) * TURN_RADIUS * TURN_ANGLE;
			for (let i = 1; i <= 70; i += 1) {
				const angle = (i / 70) * TURN_ANGLE;
				add(
					transform(
						{
							x: TURN_RADIUS * Math.sin(angle),
							y: -turnDrop * (i / 70),
							z: TURN_RADIUS * (1 - Math.cos(angle)),
						},
						origin,
						heading,
					),
					-1,
					'connector',
					i / 70,
				);
			}
			origin = { ...points.at(-1) };
			heading += TURN_ANGLE;
		}
	}
	const finish = {
		index: points.length - 1,
		distance: points.at(-1).distance,
		time: points.at(-1).time,
	};
	// A fixed, gently upturned run-out carries the ball clear of the deck after the finish gate.
	const runoutLength = 2.6;
	const runoutTurn = (-Math.PI * 4) / 9;
	const runoutRadius = runoutLength / runoutTurn;
	const runoutOrigin = { ...points.at(-1) };
	for (let index = 1; index <= 80; index += 1) {
		const t = index / 80;
		add(
			transform(
				{
					x: runoutRadius * Math.sin(runoutTurn * t),
					y: hermite(0, -0.16, -DROP / LENGTH, 0.16, t, runoutLength),
					z: runoutRadius * (1 - Math.cos(runoutTurn * t)),
				},
				runoutOrigin,
				heading,
			),
			-1,
			'runout',
			t,
		);
	}
	// Anticipate tight horizontal bends with bounded acceleration and braking.
	for (let index = 1; index < points.length - 1; index += 1) {
		const a = points[index - 1];
		const b = points[index];
		const c = points[index + 1];
		if (b.airborne) continue;
		const before = Math.atan2(b.z - a.z, b.x - a.x);
		const after = Math.atan2(c.z - b.z, c.x - b.x);
		const turn = Math.abs(Math.atan2(Math.sin(after - before), Math.cos(after - before)));
		const curvature = turn / Math.max(0.001, (distance(a, b) + distance(b, c)) / 2);
		b.speed = Math.min(b.speed, Math.sqrt(6.5 / Math.max(0.001, curvature)));
	}
	for (let index = points.length - 2; index > 0; index -= 1) {
		const point = points[index];
		const next = points[index + 1];
		point.speed = Math.min(
			point.speed,
			Math.sqrt(next.speed ** 2 + 2 * 2.4 * (next.distance - point.distance)),
		);
	}
	for (let index = 1; index < points.length; index += 1) {
		const point = points[index];
		const previous = points[index - 1];
		const step = point.distance - previous.distance;
		// Speed lost in a bend is not magically restored: only the next descent supplies energy.
		const gravitySpeed = Math.sqrt(
			Math.max(0.25 ** 2, previous.speed ** 2 + 6 * (previous.y - point.y)),
		);
		point.speed = Math.min(
			point.speed,
			gravitySpeed,
			Math.sqrt(previous.speed ** 2 + 2 * 2.5 * step),
		);
		point.time = previous.time + (2 * step) / (previous.speed + point.speed);
	}
	runup.duration = points[runup.end].time;
	finish.time = points[finish.index].time;
	const length = points.at(-1).distance;
	const duration = points.at(-1).time;
	return { points, sections, runup, finish, length, duration, signature: kinds.join('-') };
}

function sampleBy(track, value, key) {
	const points = track.points;
	const target = clamp(Number.isFinite(value) ? value : 0, 0, points.at(-1)[key]);
	let low = 0;
	let high = points.length - 1;
	while (low + 1 < high) {
		const mid = Math.floor((low + high) / 2);
		if (points[mid][key] <= target) low = mid;
		else high = mid;
	}
	const a = points[low];
	const b = points[high];
	const intervalTime = b.time - a.time;
	const intervalDistance = b.distance - a.distance;
	const fraction = (target - a[key]) / Math.max(1e-12, b[key] - a[key]);
	const acceleration = (b.speed - a.speed) / intervalTime;
	const localTime =
		key === 'time'
			? target - a.time
			: (2 * (target - a.distance)) /
				(a.speed + Math.sqrt(Math.max(0, a.speed ** 2 + 2 * acceleration * (target - a.distance))));
	const timeFraction = clamp(localTime / intervalTime, 0, 1);
	const t =
		target === b[key]
			? 1
			: key === 'time'
				? clamp(
						(a.speed * localTime + 0.5 * acceleration * localTime ** 2) / intervalDistance,
						0,
						1,
					)
				: fraction;
	const directionAt = (index) => {
		const before = points[Math.max(0, index - 1)];
		const after = points[Math.min(points.length - 1, index + 1)];
		const length = distance(before, after);
		return {
			x: (after.x - before.x) / length,
			y: (after.y - before.y) / length,
			z: (after.z - before.z) / length,
		};
	};
	const from = directionAt(low);
	const to = directionAt(high);
	const tangent = { x: lerp(from.x, to.x, t), y: lerp(from.y, to.y, t), z: lerp(from.z, to.z, t) };
	const tangentLength = Math.hypot(tangent.x, tangent.y, tangent.z);
	return {
		x: lerp(a.x, b.x, t),
		y: lerp(a.y, b.y, t),
		z: lerp(a.z, b.z, t),
		distance: lerp(a.distance, b.distance, t),
		time: a.time + localTime,
		progress: lerp(a.distance, b.distance, t) / track.length,
		speed: lerp(a.speed, b.speed, timeFraction),
		kind: t === 1 ? b.kind : a.kind,
		section: t === 1 ? b.section : a.section,
		airborne: t === 0 ? a.airborne : t === 1 ? b.airborne : a.airborne || b.airborne,
		tangent: {
			x: tangent.x / tangentLength,
			y: tangent.y / tangentLength,
			z: tangent.z / tangentLength,
		},
	};
}

export const sampleTrack = (track, distanceAlong) => sampleBy(track, distanceAlong, 'distance');
export const sampleRun = (track, elapsedSeconds) => sampleBy(track, elapsedSeconds, 'time');

/** Rail spans stop exactly at takeoff and restart exactly at landing. */
export function railSpans(track) {
	const spans = [];
	let current = [];
	for (const point of track.points) {
		if (point.airborne) {
			if (current.length > 1) spans.push(current);
			current = [];
		} else current.push(point);
	}
	if (current.length > 1) spans.push(current);
	return spans;
}
