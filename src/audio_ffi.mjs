import * as audio from './browser/audio.js';
import { toList } from './gleam.mjs';

export const dispose = audio.dispose;
export const stop_morse = audio.stopMorse;
export const stop_speech = audio.stopSpeech;
export const unlock_audio = audio.unlockAudio;

export function random_between(minimum, maximum) {
	return minimum + Math.floor(Math.random() * (maximum - minimum + 1));
}

export function focus(id) {
	if (typeof document !== 'undefined') document.getElementById(id)?.focus();
}

export function init_morse(overview, onKey) {
	audio.initMorse(overview ? onKey : null);
}

export function play_morse(request, durations, gap, onSignal, onDone) {
	void audio.playMorse(request, durations.toArray(), gap, onSignal, onDone);
}

export function init_speech(onVoices, onUnavailable) {
	audio.initSpeech((voices) => onVoices(toList(voices)), onUnavailable);
}

export const speak = audio.speak;
