import { afterEach, describe, expect, it, vi } from 'vitest';
import * as robot from './robot.js';
import * as loader from './robot-loader.js';

vi.mock('./robot.js', () => ({
	mount: vi.fn(),
	dispose: vi.fn(),
	setInput: vi.fn(),
	setRunning: vi.fn(),
	reset: vi.fn(),
}));

const callbacks = { on_error: vi.fn() };
async function imported() {
	await vi.dynamicImportSettled();
}

afterEach(() => {
	loader.dispose();
	vi.clearAllMocks();
});

describe('lazy WebGL adapter lifecycle', () => {
	it('loads the world on demand and forwards explicit controls', async () => {
		loader.mount(callbacks);
		await imported();
		expect(robot.mount).toHaveBeenCalledWith(callbacks);
		loader.setInput(['w']);
		loader.setRunning(true);
		loader.reset();
		expect(robot.setInput).toHaveBeenCalledWith(['w']);
		expect(robot.setRunning).toHaveBeenCalledWith(true);
		expect(robot.reset).toHaveBeenCalledTimes(1);
	});

	it('does not mount a world when navigation cancels a pending import', async () => {
		loader.mount(callbacks);
		loader.dispose();
		await imported();
		expect(robot.mount).not.toHaveBeenCalled();
	});

	it('only the latest mount survives fast navigation', async () => {
		loader.mount(callbacks);
		const latest = { on_error: vi.fn() };
		loader.mount(latest);
		await imported();
		expect(robot.mount).toHaveBeenCalledTimes(1);
		expect(robot.mount).toHaveBeenCalledWith(latest);
	});
});
