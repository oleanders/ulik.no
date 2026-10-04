export const PRESETS = [
	{
		id: 'nordlys',
		name: 'Nordlys',
		description: 'Rolige bånd i grønt og blått.',
		speed: 0.75,
		density: 900,
		attraction: -1,
		hue: 145,
	},
	{
		id: 'virvel',
		name: 'Virvel',
		description: 'Kjølige strømmer rundt et stille sentrum.',
		speed: 1,
		density: 1200,
		attraction: 1,
		hue: 195,
	},
	{
		id: 'glod',
		name: 'Glød',
		description: 'Varme, raske spor med mer uro.',
		speed: 1.5,
		density: 600,
		attraction: -0.5,
		hue: 5,
	},
] as const;

export type PresetId = (typeof PRESETS)[number]['id'];
export type FlowConfig = {
	preset: PresetId;
	seed: number;
	speed: number;
	density: number;
	attraction: number;
	hue: number;
};

export const LIMITS = {
	speed: { min: 0.25, max: 2, step: 0.05 },
	density: { min: 300, max: 1500, step: 100 },
	attraction: { min: -2, max: 2, step: 0.1 },
	hue: { min: 0, max: 359, step: 1 },
} as const;

export function presetConfig(preset: PresetId, seed = 20261002): FlowConfig {
	const values = PRESETS.find((entry) => entry.id === preset) ?? PRESETS[0];
	return {
		preset: values.id,
		seed,
		speed: values.speed,
		density: values.density,
		attraction: values.attraction,
		hue: values.hue,
	};
}

export const DEFAULT_CONFIG = presetConfig('nordlys');

function readNumber(raw: string | null, fallback: number, key: keyof typeof LIMITS): number {
	if (raw === null || !/^-?\d{1,10}(\.\d{1,4})?$/.test(raw)) return fallback;
	const value = Number(raw);
	const { min, max, step } = LIMITS[key];
	const bounded = Math.min(max, Math.max(min, value));
	return Number((min + Math.round((bounded - min) / step) * step).toFixed(2));
}

/** Only a small, versioned configuration is accepted; unrelated URL data is ignored. */
export function parseConfig(search: string): FlowConfig {
	if (search.length > 1000) return { ...DEFAULT_CONFIG };
	const params = new URLSearchParams(search);
	if (params.has('v') && params.get('v') !== '1') return { ...DEFAULT_CONFIG };
	const preset = PRESETS.find((entry) => entry.id === params.get('preset')) ?? PRESETS[0];
	const defaults = presetConfig(preset.id);
	const rawSeed = params.get('seed');
	const seed = rawSeed && /^\d{1,10}$/.test(rawSeed) ? Number(rawSeed) : defaults.seed;
	return {
		preset: preset.id,
		seed: seed >= 1 && seed <= 0xffffffff ? seed : defaults.seed,
		speed: readNumber(params.get('speed'), defaults.speed, 'speed'),
		density: readNumber(params.get('density'), defaults.density, 'density'),
		attraction: readNumber(params.get('attraction'), defaults.attraction, 'attraction'),
		hue: readNumber(params.get('hue'), defaults.hue, 'hue'),
	};
}

export function configQuery(config: FlowConfig): string {
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
export function seededRandom(seed: number): () => number {
	let state = seed >>> 0;
	return () => {
		state = (state + 0x6d2b79f5) >>> 0;
		let value = Math.imul(state ^ (state >>> 15), state | 1);
		value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
		return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
	};
}
