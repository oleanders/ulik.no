import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
	dispose,
	initMorse,
	initSpeech,
	playMorse,
	speak,
	stopMorse,
	stopSpeech,
} from './audio.js';

let listeners;
let synthesis;
let utterances;

beforeEach(() => {
	vi.useFakeTimers();
	listeners = new Map();
	utterances = [];
	synthesis = {
		getVoices: vi.fn(() => [{ voiceURI: 'voice-nb', lang: 'nb-NO' }]),
		addEventListener: vi.fn((name, callback) => listeners.set(name, callback)),
		removeEventListener: vi.fn((name) => listeners.delete(name)),
		speak: vi.fn((utterance) => utterances.push(utterance)),
		cancel: vi.fn(),
	};
	vi.stubGlobal('window', {
		speechSynthesis: synthesis,
		SpeechSynthesisUtterance: class {
			constructor(text) {
				this.text = text;
			}
		},
		addEventListener: vi.fn((name, callback) => listeners.set(name, callback)),
		removeEventListener: vi.fn((name) => listeners.delete(name)),
	});
});

afterEach(() => {
	dispose();
	vi.useRealTimers();
	vi.unstubAllGlobals();
});

describe('Morse audio lifecycle', () => {
	it('flashes every signal and completes even without an audio device', async () => {
		const signal = vi.fn();
		const done = vi.fn();
		const playing = playMorse(7, [80, 240], 80, signal, done);
		await vi.runAllTimersAsync();
		await playing;
		expect(signal.mock.calls).toEqual([
			[7, true],
			[7, false],
			[7, true],
			[7, false],
		]);
		expect(done).toHaveBeenCalledExactlyOnceWith(7);
	});

	it('stops pending timers and does not send a late completion', async () => {
		const signal = vi.fn();
		const done = vi.fn();
		const playing = playMorse(1, [240], 80, signal, done);
		await vi.advanceTimersByTimeAsync(1);
		expect(signal).toHaveBeenCalledExactlyOnceWith(1, true);
		stopMorse();
		await vi.runAllTimersAsync();
		await playing;
		expect(signal).toHaveBeenCalledTimes(1);
		expect(done).not.toHaveBeenCalled();
		expect(vi.getTimerCount()).toBe(0);
	});

	it('invalidates an older playback when another one starts', async () => {
		const signal = vi.fn();
		const oldDone = vi.fn();
		const newDone = vi.fn();
		const first = playMorse(1, [240], 80, signal, oldDone);
		await vi.advanceTimersByTimeAsync(1);
		const second = playMorse(2, [80], 80, signal, newDone);
		await vi.runAllTimersAsync();
		await Promise.all([first, second]);
		expect(oldDone).not.toHaveBeenCalled();
		expect(newDone).toHaveBeenCalledExactlyOnceWith(2);
	});

	it('does not revive playback when an audio resume resolves after disposal', async () => {
		let resume;
		const close = vi.fn(async () => {});
		window.AudioContext = class {
			state = 'suspended';
			resume = () =>
				new Promise((resolve) => {
					resume = resolve;
				});
			close = close;
		};
		const signal = vi.fn();
		const done = vi.fn();
		const playing = playMorse(1, [80], 80, signal, done);
		dispose();
		resume();
		await playing;
		expect(close).toHaveBeenCalledTimes(1);
		expect(signal).not.toHaveBeenCalled();
		expect(done).not.toHaveBeenCalled();
	});

	it('removes overview key listeners on mode changes and navigation', () => {
		const key = vi.fn();
		initMorse(key);
		listeners.get('keydown')({ key: 'a' });
		expect(key).toHaveBeenCalledExactlyOnceWith('a');
		initMorse(null);
		expect(listeners.has('keydown')).toBe(false);
		initMorse(key);
		dispose();
		expect(listeners.has('keydown')).toBe(false);
	});
});

describe('NATO speech lifecycle', () => {
	it('reports current voices and removes its listener on disposal', () => {
		const voices = vi.fn();
		initSpeech(voices, vi.fn());
		expect(voices).toHaveBeenCalledExactlyOnceWith([['voice-nb', 'nb-NO']]);
		listeners.get('voiceschanged')();
		expect(voices).toHaveBeenCalledTimes(2);
		dispose();
		expect(listeners.has('voiceschanged')).toBe(false);
	});

	it('reports speech support failure explicitly', () => {
		delete window.SpeechSynthesisUtterance;
		const unavailable = vi.fn();
		initSpeech(vi.fn(), unavailable);
		expect(unavailable).toHaveBeenCalledTimes(1);
	});

	it('sets the selected voice and returns a typed completion callback', () => {
		const ended = vi.fn();
		speak(9, 'Alfa Bravo', 'nb-NO', 'voice-nb', ended, vi.fn());
		const utterance = utterances[0];
		expect(utterance).toMatchObject({
			text: 'Alfa Bravo',
			lang: 'nb-NO',
			rate: 0.85,
			pitch: 1,
			voice: { voiceURI: 'voice-nb' },
		});
		utterance.onend();
		utterance.onend();
		expect(ended).toHaveBeenCalledExactlyOnceWith(9);
	});

	it('invalidates late completion from cancelled speech', () => {
		const ended = vi.fn();
		speak(1, 'Alfa', 'nb-NO', '', ended, vi.fn());
		const late = utterances[0].onend;
		stopSpeech();
		late();
		expect(ended).not.toHaveBeenCalled();
		expect(utterances[0].onend).toBeNull();
		expect(synthesis.cancel).toHaveBeenCalledTimes(1);
	});

	it('does not cancel speech it did not start', () => {
		stopSpeech();
		dispose();
		expect(synthesis.cancel).not.toHaveBeenCalled();
	});

	it('reports a browser speech failure', () => {
		synthesis.speak.mockImplementation(() => {
			throw new Error('Audio unavailable');
		});
		const failed = vi.fn();
		speak(5, 'Alfa', 'nb-NO', '', vi.fn(), failed);
		expect(failed).toHaveBeenCalledExactlyOnceWith(5);
	});
});
