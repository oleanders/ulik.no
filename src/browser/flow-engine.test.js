import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createFlowField } from './flow-engine.js';

const DEFAULT_CONFIG = {
	preset: 'nordlys',
	seed: 20261002,
	speed: 0.75,
	density: 900,
	attraction: -1,
	hue: 145,
};
const GLOD_CONFIG = {
	preset: 'glod',
	seed: 99,
	speed: 1.5,
	density: 600,
	attraction: -0.5,
	hue: 5,
};

function makeCanvas() {
	const context = { fillStyle: '', fillRect: vi.fn(), setTransform: vi.fn() };
	const canvas = { width: 0, height: 0, getContext: vi.fn(() => context) };
	// A minimal canvas double keeps deterministic renderer/lifecycle tests independent of a GPU.
	return { canvas: canvas, context };
}

describe('flow renderer', () => {
	let frames;
	let nextFrame;
	beforeEach(() => {
		frames = new Map();
		nextFrame = 0;
		vi.stubGlobal('requestAnimationFrame', (callback) => {
			frames.set(++nextFrame, callback);
			return nextFrame;
		});
		vi.stubGlobal('cancelAnimationFrame', (id) => frames.delete(id));
	});
	afterEach(() => vi.unstubAllGlobals());

	function frame(now) {
		const queued = [...frames.values()];
		frames.clear();
		for (const callback of queued) callback(now);
	}

	it('renders the same seeded still after repeated restarts', () => {
		const { canvas, context } = makeCanvas();
		const engine = createFlowField(canvas, DEFAULT_CONFIG);
		engine?.resize(960, 540, 1);
		const first = [...context.fillRect.mock.calls];
		context.fillRect.mockClear();
		engine?.restart();
		expect(context.fillRect.mock.calls).toEqual(first);
		expect(frames.size).toBe(0);
	});

	it('keeps one animation loop and stops immediately on pause, hide or destroy', () => {
		const { canvas, context } = makeCanvas();
		const engine = createFlowField(canvas, DEFAULT_CONFIG);
		engine?.resize(960, 540, 1);
		for (let i = 0; i < 10; i++) engine?.setRunning(true);
		expect(frames.size).toBe(1);
		frame(100);
		frame(134);
		expect(frames.size).toBe(1);
		engine?.setRunning(false);
		expect(frames.size).toBe(0);
		const count = context.fillRect.mock.calls.length;
		frame(1000);
		expect(context.fillRect.mock.calls.length).toBe(count);
		engine?.setRunning(true);
		engine?.setVisible(false);
		expect(frames.size).toBe(0);
		engine?.setVisible(true);
		expect(frames.size).toBe(1);
		engine?.destroy();
		engine?.setRunning(true);
		expect(frames.size).toBe(0);
	});

	it('caps pixel ratio and avoids restarting on unchanged resize/configuration', () => {
		const { canvas, context } = makeCanvas();
		const engine = createFlowField(canvas, DEFAULT_CONFIG);
		engine?.resize(400, 225, 4);
		expect([canvas.width, canvas.height]).toEqual([800, 450]);
		context.fillRect.mockClear();
		engine?.resize(400, 225, 4);
		engine?.configure({ ...DEFAULT_CONFIG });
		expect(context.fillRect).not.toHaveBeenCalled();
	});

	it('redraws preset and density changes while paused and clears pointer on restart', () => {
		const { canvas, context } = makeCanvas();
		const engine = createFlowField(canvas, DEFAULT_CONFIG);
		engine?.resize(960, 540, 1);
		context.fillRect.mockClear();
		engine?.setPointer(0.5, 0.5);
		engine?.configure(GLOD_CONFIG);
		expect(context.fillRect).toHaveBeenCalledTimes(1 + 70 * (600 + 1));
		const snapshot = [...context.fillRect.mock.calls];
		context.fillRect.mockClear();
		engine?.restart();
		expect(context.fillRect.mock.calls).toEqual(snapshot);
		expect(frames.size).toBe(0);
	});

	it('fails gracefully when canvas is unsupported', () => {
		const canvas = { getContext: () => null };
		expect(createFlowField(canvas, DEFAULT_CONFIG)).toBeNull();
	});
});
