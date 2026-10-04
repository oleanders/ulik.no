/** Browser capabilities only. Gleam owns letters, timing rules, scoring and voice selection. */
let audioContext = null;
let morseVersion = 0;
let speechVersion = 0;
const waits = new Map();
const oscillators = new Set();
let activeUtterance = null;
let voicesChanged = null;
let overviewKeydown = null;
let ownsSpeech = false;

export function initMorse(onKey) {
	dispose();
	if (onKey && typeof window !== 'undefined') {
		overviewKeydown = (event) => onKey(event.key);
		window.addEventListener('keydown', overviewKeydown);
	}
}

export function unlockAudio() {
	void ensureAudio();
}

async function ensureAudio() {
	try {
		if (!audioContext && typeof window.AudioContext === 'function') {
			audioContext = new window.AudioContext();
		}
		const context = audioContext;
		if (context?.state === 'suspended') await context.resume();
		return context;
	} catch {
		// Flashing continues when sound is unavailable or permission is denied.
		return null;
	}
}

function wait(milliseconds) {
	return new Promise((resolve) => {
		const timer = setTimeout(() => {
			waits.delete(timer);
			resolve(true);
		}, milliseconds);
		waits.set(timer, resolve);
	});
}

function tone(context, milliseconds) {
	if (context?.state !== 'running') return;
	const oscillator = context.createOscillator();
	const gain = context.createGain();
	const end = context.currentTime + milliseconds / 1000;
	oscillator.type = 'sine';
	oscillator.frequency.value = 700;
	gain.gain.setValueAtTime(0.0001, context.currentTime);
	gain.gain.exponentialRampToValueAtTime(0.15, context.currentTime + 0.01);
	gain.gain.exponentialRampToValueAtTime(0.0001, end);
	oscillator.connect(gain);
	gain.connect(context.destination);
	oscillators.add(oscillator);
	oscillator.onended = () => {
		oscillators.delete(oscillator);
		oscillator.disconnect();
		gain.disconnect();
	};
	oscillator.start();
	oscillator.stop(end);
}

export async function playMorse(request, durations, gap, onSignal, onDone) {
	stopMorse();
	const version = morseVersion;
	const context = await ensureAudio();
	if (version !== morseVersion) return;
	try {
		for (const duration of durations) {
			if (!Number.isFinite(duration) || duration <= 0) continue;
			if (version !== morseVersion) return;
			onSignal(request, true);
			try {
				tone(context, duration);
			} catch {
				// Hardware errors must not leave a round busy.
			}
			if (!(await wait(duration)) || version !== morseVersion) return;
			onSignal(request, false);
			if (!(await wait(gap)) || version !== morseVersion) return;
		}
	} finally {
		if (version === morseVersion) onDone(request);
	}
}

export function stopMorse() {
	morseVersion += 1;
	for (const [timer, resolve] of waits) {
		clearTimeout(timer);
		resolve(false);
	}
	waits.clear();
	for (const oscillator of oscillators) {
		try {
			oscillator.stop();
		} catch {
			// May already have ended during navigation.
		}
		oscillator.disconnect();
	}
	oscillators.clear();
}

export function initSpeech(onVoices, onUnavailable) {
	dispose();
	if (
		typeof window === 'undefined' ||
		!('speechSynthesis' in window) ||
		typeof window.SpeechSynthesisUtterance !== 'function'
	) {
		onUnavailable();
		return;
	}
	voicesChanged = () => {
		onVoices(window.speechSynthesis.getVoices().map((voice) => [voice.voiceURI, voice.lang]));
	};
	window.speechSynthesis.addEventListener('voiceschanged', voicesChanged);
	voicesChanged();
}

export function speak(request, text, language, voiceUri, onEnded, onFailed) {
	stopSpeech();
	const version = speechVersion;
	let completed = false;
	const finish = (callback) => {
		if (version !== speechVersion || completed) return;
		completed = true;
		activeUtterance = null;
		ownsSpeech = false;
		callback(request);
	};
	try {
		const utterance = new window.SpeechSynthesisUtterance(text);
		utterance.lang = language;
		utterance.rate = 0.85;
		utterance.pitch = 1;
		const voice = window.speechSynthesis
			.getVoices()
			.find((candidate) => candidate.voiceURI === voiceUri);
		if (voice) utterance.voice = voice;
		utterance.onend = () => finish(onEnded);
		utterance.onerror = () => finish(onFailed);
		activeUtterance = utterance;
		ownsSpeech = true;
		window.speechSynthesis.speak(utterance);
	} catch {
		finish(onFailed);
	}
}

export function stopSpeech() {
	speechVersion += 1;
	if (activeUtterance) {
		activeUtterance.onend = null;
		activeUtterance.onerror = null;
		activeUtterance = null;
	}
	if (ownsSpeech && typeof window !== 'undefined' && 'speechSynthesis' in window)
		window.speechSynthesis.cancel();
	ownsSpeech = false;
}

/** Route cleanup invalidates pending promises before releasing resources. */
export function dispose() {
	stopMorse();
	stopSpeech();
	if (typeof window !== 'undefined') {
		if (voicesChanged && 'speechSynthesis' in window)
			window.speechSynthesis.removeEventListener('voiceschanged', voicesChanged);
		if (overviewKeydown) window.removeEventListener('keydown', overviewKeydown);
	}
	voicesChanged = null;
	overviewKeydown = null;
	const context = audioContext;
	audioContext = null;
	if (context && context.state !== 'closed') void context.close().catch(() => {});
}
