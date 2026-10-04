// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { dispose, drop, reset } from './falling.js';

let frames;
let nextFrame;
let send;
let media;
let animations;
const callbacks = () => ({ on_reset: send, on_count: send, on_settled: send });

function frame() {
	const callbacks = [...frames.values()];
	frames.clear();
	for (const callback of callbacks) callback(100);
}

beforeEach(() => {
	frames = new Map();
	nextFrame = 0;
	send = vi.fn();
	animations = [];
	vi.stubGlobal('requestAnimationFrame', (callback) => {
		frames.set(++nextFrame, callback);
		return nextFrame;
	});
	vi.stubGlobal('cancelAnimationFrame', (id) => frames.delete(id));
	media = { matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() };
	vi.stubGlobal('matchMedia', () => media);
	document.body.innerHTML =
		'<header><a class="logo">ulik.no</a></header><main><div class="falling-page"><section class="terminal-panel head"><h1>fall≠ned</h1><p>Tekst</p></section><div data-no-fall><button>reset side</button></div></div></main>';
	document.body.style.overflow = 'scroll';
	vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({
		left: 10,
		top: 20,
		width: 200,
		height: 80,
	});
	HTMLElement.prototype.animate = vi.fn(() => {
		let finish;
		const finished = new Promise((resolve) => {
			finish = resolve;
		});
		const animation = { finished, finish, cancel: vi.fn() };
		animations.push(animation);
		return animation;
	});
});

afterEach(() => {
	dispose();
	delete HTMLElement.prototype.animate;
	vi.unstubAllGlobals();
	vi.restoreAllMocks();
});

describe('falling DOM lifecycle', () => {
	it('drops only outermost targets and restores the original nodes and overflow', async () => {
		const original = document.querySelector('.head');
		original.style.visibility = 'visible';
		original.querySelector('p').style.color = 'rgb(12, 34, 56)';
		drop(callbacks());
		frame();
		expect(document.querySelectorAll('.fall-clone')).toHaveLength(2);
		expect(document.querySelector('[data-no-fall] button').style.visibility).toBe('');
		expect(original.style.visibility).toBe('hidden');
		expect(document.querySelector('.fall-clone p').style.color).toBe('rgb(12, 34, 56)');
		expect(document.body.style.overflow).toBe('hidden');
		await Promise.resolve();
		reset();
		expect(document.querySelectorAll('.fall-clone')).toHaveLength(0);
		expect(document.querySelector('.head')).toBe(original);
		expect(original.style.visibility).toBe('visible');
		expect(document.body.style.overflow).toBe('scroll');
	});

	it('reset and navigation cancel animations and reject their late completion', async () => {
		media.matches = false;
		drop(callbacks());
		frame();
		expect(animations).toHaveLength(2);
		send.mockClear();
		dispose();
		for (const animation of animations) {
			expect(animation.cancel).toHaveBeenCalledTimes(1);
			animation.finish();
		}
		await Promise.resolve();
		await Promise.resolve();
		expect(send).not.toHaveBeenCalled();
		expect(document.querySelector('.falling-layer')).toBeNull();
		expect(document.querySelector('.logo').style.visibility).toBe('');
	});

	it('repeated drops keep one clone layer and Escape asks Gleam to restore the page', () => {
		for (let index = 0; index < 3; index++) {
			drop(callbacks());
			frame();
			expect(document.querySelectorAll('.falling-layer')).toHaveLength(1);
			expect(document.querySelectorAll('.fall-clone')).toHaveLength(2);
		}
		window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
		expect(send).toHaveBeenCalledWith();
	});

	it('can be reset before the initial mount frame', () => {
		drop(callbacks());
		reset();
		frame();
		expect(document.querySelector('.falling-layer')).toBeNull();
		expect(document.body.style.overflow).toBe('scroll');
	});
});
