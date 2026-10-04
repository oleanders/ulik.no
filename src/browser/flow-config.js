export function configQuery(config) {
	return new URLSearchParams({
		v: '1',
		preset: config.preset,
		seed: String(config.seed),
		speed: String(config.speed),
		density: String(config.density),
		attraction: String(config.attraction),
		hue: String(config.hue),
	}).toString();
}

/** Mulberry32: stable particle positions and field offsets for a shared seed. */
export function seededRandom(seed) {
	let state = seed >>> 0;
	return () => {
		state = (state + 0x6d2b79f5) >>> 0;
		let value = Math.imul(state ^ (state >>> 15), state | 1);
		value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
		return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
	};
}
