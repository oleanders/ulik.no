import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
	compareTextParts,
	dispose,
	errorMessageFrom,
	startSharing,
	stopSharing,
	supportsDisplayMedia,
} from './tools.js';

function deferred() {
	let resolve;
	let reject;
	const promise = new Promise((accept, fail) => {
		resolve = accept;
		reject = fail;
	});
	return { promise, resolve, reject };
}

function mediaStream(label = 'Test window') {
	const track = new EventTarget();
	track.label = label;
	track.stop = vi.fn();
	const audio = { stop: vi.fn() };
	return {
		track,
		audio,
		getTracks: () => [track, audio],
		getVideoTracks: () => [track],
	};
}

const flush = async () => {
	await Promise.resolve();
	await Promise.resolve();
};

let preview;
let getDisplayMedia;
let frames;
let nextFrame;
let started;
let stopped;
let failed;

beforeEach(() => {
	frames = new Map();
	nextFrame = 0;
	preview = { srcObject: null, muted: false, play: vi.fn().mockResolvedValue(undefined) };
	getDisplayMedia = vi.fn();
	started = vi.fn();
	stopped = vi.fn();
	failed = vi.fn();
	vi.stubGlobal('navigator', { mediaDevices: { getDisplayMedia } });
	vi.stubGlobal('document', { getElementById: vi.fn(() => preview) });
	vi.stubGlobal('requestAnimationFrame', (callback) => {
		const frame = ++nextFrame;
		frames.set(frame, callback);
		return frame;
	});
	vi.stubGlobal('cancelAnimationFrame', (frame) => {
		frames.delete(frame);
	});
});

afterEach(() => {
	dispose();
	vi.unstubAllGlobals();
	vi.restoreAllMocks();
});

describe('typed browser tools', () => {
	it('preserves line and whitespace-sensitive word diff semantics', () => {
		expect(compareTextParts('one\ntwo\n', 'one\nthree\n', false)).toEqual([
			{ count: 1, added: false, removed: false, value: 'one\n' },
			{ count: 1, added: false, removed: true, value: 'two\n' },
			{ count: 1, added: true, removed: false, value: 'three\n' },
		]);
		expect(compareTextParts('a b', 'a  b', true).some((part) => part.added)).toBe(true);
	});

	it('detects unavailable APIs and reports an actionable failure', () => {
		vi.stubGlobal('navigator', {});
		expect(supportsDisplayMedia()).toBe(false);
		startSharing(false, started, stopped, failed);
		expect(failed).toHaveBeenCalledWith('Denne nettleseren støtter ikke getDisplayMedia.');
		expect(started).not.toHaveBeenCalled();
	});

	it('starts a muted preview and stops both video and audio resources', async () => {
		const stream = mediaStream();
		getDisplayMedia.mockResolvedValue(stream);
		startSharing(true, started, stopped, failed);
		await flush();
		expect(getDisplayMedia).toHaveBeenCalledWith({
			video: { frameRate: { ideal: 30, max: 60 } },
			audio: true,
		});
		expect(started).toHaveBeenCalledWith('Test window');
		for (const frame of frames.values()) frame();
		frames.clear();
		expect(preview.srcObject).toBe(stream);
		expect(preview.muted).toBe(true);
		expect(preview.play).toHaveBeenCalledOnce();
		stopSharing();
		expect(stream.track.stop).toHaveBeenCalledOnce();
		expect(stream.audio.stop).toHaveBeenCalledOnce();
		expect(preview.srcObject).toBeNull();
	});

	it('releases capture and queued preview on an external browser stop', async () => {
		const stream = mediaStream();
		getDisplayMedia.mockResolvedValue(stream);
		startSharing(false, started, stopped, failed);
		await flush();
		stream.track.dispatchEvent(new Event('ended'));
		expect(stopped).toHaveBeenCalledOnce();
		expect(stream.track.stop).toHaveBeenCalledOnce();
		expect(stream.audio.stop).toHaveBeenCalledOnce();
		expect(frames.size).toBe(0);
		expect(preview.srcObject).toBeNull();
	});

	it('stops a late permission result after route cleanup without updating the page', async () => {
		const permission = deferred();
		const stream = mediaStream();
		getDisplayMedia.mockReturnValue(permission.promise);
		startSharing(false, started, stopped, failed);
		dispose();
		permission.resolve(stream);
		await flush();
		expect(stream.track.stop).toHaveBeenCalledOnce();
		expect(stream.audio.stop).toHaveBeenCalledOnce();
		expect(started).not.toHaveBeenCalled();
		expect(stopped).not.toHaveBeenCalled();
		expect(failed).not.toHaveBeenCalled();
		expect(frames.size).toBe(0);
	});

	it('keeps only the latest repeated capture request', async () => {
		const first = deferred();
		const second = deferred();
		const oldStream = mediaStream('Old window');
		const newStream = mediaStream('New window');
		getDisplayMedia.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		startSharing(false, started, stopped, failed);
		startSharing(true, started, stopped, failed);
		second.resolve(newStream);
		await flush();
		first.resolve(oldStream);
		await flush();
		expect(started).toHaveBeenCalledExactlyOnceWith('New window');
		expect(oldStream.track.stop).toHaveBeenCalledOnce();
		expect(oldStream.audio.stop).toHaveBeenCalledOnce();
		expect(newStream.track.stop).not.toHaveBeenCalled();
		oldStream.track.dispatchEvent(new Event('ended'));
		expect(stopped).not.toHaveBeenCalled();
	});

	it('does not surface a stale permission rejection after cleanup', async () => {
		const permission = deferred();
		getDisplayMedia.mockReturnValue(permission.promise);
		startSharing(false, started, stopped, failed);
		dispose();
		permission.reject(new DOMException('cancelled', 'NotAllowedError'));
		await flush();
		expect(failed).not.toHaveBeenCalled();
	});

	it.each([
		['NotAllowedError', 'Skjermdeling ble avbrutt eller blokkert. Prøv igjen og tillat tilgang.'],
		['NotFoundError', 'Fant ingen skjermkilder å dele.'],
		['AbortError', 'Skjermdeling ble avbrutt før den startet.'],
		['NotReadableError', 'Skjermdeling feilet: NotReadableError'],
	])('retains a useful message for %s', async (name, message) => {
		getDisplayMedia.mockRejectedValue(new DOMException('test', name));
		startSharing(false, started, stopped, failed);
		await flush();
		expect(failed).toHaveBeenCalledWith(message);
		expect(started).not.toHaveBeenCalled();
		expect(preview.srcObject).toBeNull();
	});

	it('does not expose arbitrary error objects', () => {
		expect(errorMessageFrom(new Error('internal details'))).toBe(
			'Noe gikk galt under oppstart av skjermdeling.',
		);
	});
});
