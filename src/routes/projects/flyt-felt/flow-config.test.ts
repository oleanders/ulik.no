import { describe, expect, it } from 'vitest';
import {
	configQuery,
	DEFAULT_CONFIG,
	PRESETS,
	parseConfig,
	presetConfig,
	seededRandom,
} from './flow-config';

describe('flow configuration', () => {
	it('round-trips all presets, seed and custom controls', () => {
		for (const preset of PRESETS) {
			const config = { ...presetConfig(preset.id, 4294967295), speed: 0.3, attraction: -1.8 };
			expect(parseConfig(configQuery(config))).toEqual(config);
		}
	});

	it('uses the selected preset as defaults for omitted controls', () => {
		expect(parseConfig('?v=1&preset=glod')).toEqual(presetConfig('glod'));
		expect(parseConfig('')).toEqual(DEFAULT_CONFIG);
	});

	it('bounds and snaps finite numeric controls', () => {
		expect(parseConfig('?speed=999&density=-100&attraction=-90&hue=1000')).toEqual({
			...DEFAULT_CONFIG,
			speed: 2,
			density: 300,
			attraction: -2,
			hue: 359,
		});
		const result = parseConfig('?speed=0.321&density=849&attraction=0.32&hue=12.2');
		expect(result).toMatchObject({ speed: 0.3, density: 800, attraction: 0.3, hue: 12 });
	});

	it.each([
		'NaN',
		'Infinity',
		'-Infinity',
		'1e9',
		'<script>',
		' ',
		'',
		'1.12345',
	])('rejects malformed numeric input %s', (value) => {
		const params = new URLSearchParams({
			speed: value,
			density: value,
			attraction: value,
			hue: value,
		});
		expect(parseConfig(params.toString())).toEqual(DEFAULT_CONFIG);
	});

	it.each([
		'0',
		'-1',
		'4294967296',
		'1.5',
		'Infinity',
		'1e2',
		'',
	])('rejects invalid seed %s', (seed) => {
		expect(parseConfig(`?seed=${seed}`).seed).toBe(DEFAULT_CONFIG.seed);
	});

	it('ignores unknown fields and does not propagate them into shared URLs', () => {
		const config = parseConfig(
			'?v=1&preset=unknown&seed=5&email=private&redirect=https://example.com',
		);
		expect(config.preset).toBe('nordlys');
		expect(config.seed).toBe(5);
		expect([...new URLSearchParams(configQuery(config)).keys()]).toEqual([
			'v',
			'preset',
			'seed',
			'speed',
			'density',
			'attraction',
			'hue',
		]);
	});

	it('rejects unknown versions and oversized URLs', () => {
		expect(parseConfig('?v=2&preset=glod&seed=10')).toEqual(DEFAULT_CONFIG);
		expect(parseConfig(`?seed=1&extra=${'x'.repeat(1000)}`)).toEqual(DEFAULT_CONFIG);
	});

	it('produces deterministic and distinct bounded random sequences', () => {
		const sequence = (seed: number) => {
			const random = seededRandom(seed);
			return Array.from({ length: 500 }, random);
		};
		expect(sequence(12)).toEqual(sequence(12));
		expect(sequence(12)).not.toEqual(sequence(13));
		expect(sequence(0xffffffff).every((value) => value >= 0 && value < 1)).toBe(true);
	});
});
