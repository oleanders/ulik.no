// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { dispose, handle } from './flow.js';
import { createFlowField } from './flow-engine.js';

vi.mock('./flow-engine.js', () => ({ createFlowField: vi.fn() }));

const config = { preset: 'nordlys', seed: 42, speed: 0.75, density: 900, attraction: -1, hue: 145 };
const command = (action, data = null) => ({ domain: 'flow', action, data });
let frames;
let nextFrame;
let engine;
let send;
let observer;
let media;

function frame() {
	const callbacks = [...frames.values()];
	frames.clear();
	for (const callback of callbacks) callback(100);
}

beforeEach(() => {
	frames = new Map();
	nextFrame = 0;
	send = vi.fn();
	engine = Object.fromEntries(
		[
			'configure',
			'resize',
			'setRunning',
			'setVisible',
			'setPointer',
			'clearPointer',
			'restart',
			'destroy',
		].map((name) => [name, vi.fn()]),
	);
	createFlowField.mockReturnValue(engine);
	vi.stubGlobal('requestAnimationFrame', (callback) => {
		frames.set(++nextFrame, callback);
		return nextFrame;
	});
	vi.stubGlobal('cancelAnimationFrame', (id) => frames.delete(id));
	observer = { observe: vi.fn(), disconnect: vi.fn() };
	vi.stubGlobal(
		'ResizeObserver',
		class {
			observe(...args) {
				observer.observe(...args);
			}
			disconnect() {
				observer.disconnect();
			}
		},
	);
	media = { matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() };
	vi.stubGlobal('matchMedia', () => media);
	document.body.innerHTML = '<div id="flow-wrapper"><canvas id="flow-canvas"></canvas></div>';
	document.getElementById('flow-wrapper').getBoundingClientRect = () => ({
		width: 960,
		height: 540,
	});
});

afterEach(() => {
	dispose();
	vi.unstubAllGlobals();
	vi.restoreAllMocks();
	vi.clearAllMocks();
});

describe('flow browser-resource adapter', () => {
	it('uses the latest Elm configuration when a control changes before mounting finishes', () => {
		handle(command('mount', config), send);
		const newer = { ...config, seed: 81 };
		handle(command('configure', newer), send);
		frame();
		expect(createFlowField).toHaveBeenCalledWith(document.getElementById('flow-canvas'), newer);
		expect(send).toHaveBeenCalledWith({ domain: 'flow', action: 'ready', data: true });
	});

	it('releases renderers, observers and event handlers on navigation', () => {
		handle(command('mount', config), send);
		frame();
		const canvas = document.getElementById('flow-canvas');
		dispose();
		send.mockClear();
		canvas.dispatchEvent(new Event('blur'));
		expect(send).not.toHaveBeenCalled();
		expect(engine.destroy).toHaveBeenCalledTimes(1);
		expect(observer.disconnect).toHaveBeenCalledTimes(1);
		expect(media.removeEventListener).toHaveBeenCalledWith('change', expect.any(Function));
	});

	it('cancels mounting when the user leaves before the canvas appears', () => {
		document.body.innerHTML = '';
		handle(command('mount', config), send);
		frame();
		expect(frames.size).toBe(1);
		dispose();
		frame();
		expect(frames.size).toBe(0);
		expect(createFlowField).not.toHaveBeenCalled();
	});

	it('drops delayed clipboard results after the route is disposed', async () => {
		let finish;
		Object.defineProperty(navigator, 'clipboard', {
			configurable: true,
			value: {
				writeText: vi.fn(
					() =>
						new Promise((resolve) => {
							finish = resolve;
						}),
				),
			},
		});
		handle(command('share', 'https://ulik.no/projects/flyt-felt?seed=42'), send);
		expect(navigator.clipboard.writeText).toHaveBeenCalledTimes(1);
		dispose();
		finish();
		await Promise.resolve();
		expect(send).not.toHaveBeenCalled();
	});

	it('keeps sharing useful when clipboard access is unavailable', async () => {
		Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined });
		handle(command('share', 'https://ulik.no/projects/flyt-felt?seed=42'), send);
		await Promise.resolve();
		expect(send).toHaveBeenCalledWith({
			domain: 'flow',
			action: 'shared',
			data: 'Kopier lenken fra feltet under.',
		});
	});
});
