/** Browser audio capabilities. Round rules, letters, scoring and voice choice live in Elm. */

/** @type {AudioContext | null} */
let audioContext = null;
let morseVersion = 0;
let speechVersion = 0;

/** @type {Map<ReturnType<typeof setTimeout>, (completed: boolean) => void>} */
const waits = new Map();
/** @type {Set<OscillatorNode>} */
const oscillators = new Set();
/** @type {SpeechSynthesisUtterance | null} */
let activeUtterance = null;
/** @type {(() => void) | null} */
let voicesChanged = null;
let ownsSpeech = false;

/** @typedef {(event: Record<string, unknown>) => void} Send */

/**
 * @param {{ domain: string, action: string, data?: Record<string, unknown> }} command
 * @param {Send} send
 */
export function handle(command, send) {
	if (command.domain !== 'audio') return;
	const data = command.data ?? {};

	switch (command.action) {
		case 'morse-init':
			dispose();
			break;
		case 'morse-unlock':
			void ensureAudio();
			break;
		case 'morse-play':
			void playMorse(data, send);
			break;
		case 'morse-stop':
			stopMorse();
			break;
		case 'nato-init':
			dispose();
			initSpeech(send);
			break;
		case 'nato-speak':
			speak(data, send);
			break;
		case 'nato-stop':
			stopSpeech();
			break;
	}
}

/** @returns {Promise<AudioContext | null>} */
async function ensureAudio() {
	try {
		if (!audioContext && typeof window.AudioContext === 'function') {
			audioContext = new window.AudioContext();
		}
		const context = audioContext;
		if (context?.state === 'suspended') await context.resume();
		return context;
	} catch {
		// The light remains useful when audio is unavailable or permission is denied.
		return null;
	}
}

/** @param {number} milliseconds */
function wait(milliseconds) {
	return new Promise((resolve) => {
		const timer = setTimeout(() => {
			waits.delete(timer);
			resolve(true);
		}, milliseconds);
		waits.set(timer, resolve);
	});
}

/** @param {AudioContext | null} context @param {number} milliseconds */
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

/** @param {Record<string, unknown>} data @param {Send} send */
async function playMorse(data, send) {
	stopMorse();
	const version = morseVersion;
	const request = data.request;
	const durations = Array.isArray(data.durations) ? data.durations : [];
	const gap = typeof data.gap === 'number' ? data.gap : 80;
	const context = await ensureAudio();
	if (version !== morseVersion) return;

	try {
		for (const duration of durations) {
			if (typeof duration !== 'number' || !Number.isFinite(duration) || duration <= 0) continue;
			if (version !== morseVersion) return;
			send({ domain: 'morse', action: 'signal', request, lightOn: true });
			try {
				tone(context, duration);
			} catch {
				// Hardware failures must not interrupt the visible signal or leave Elm busy.
			}
			if (!(await wait(duration)) || version !== morseVersion) return;
			send({ domain: 'morse', action: 'signal', request, lightOn: false });
			if (!(await wait(gap)) || version !== morseVersion) return;
		}
	} finally {
		if (version === morseVersion) {
			send({ domain: 'morse', action: 'done', request });
		}
	}
}

function stopMorse() {
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
			// An oscillator may have ended between the timer and route disposal.
		}
		oscillator.disconnect();
	}
	oscillators.clear();
}

/** @param {Send} send */
function initSpeech(send) {
	if (!('speechSynthesis' in window) || typeof window.SpeechSynthesisUtterance !== 'function') {
		send({ domain: 'nato', action: 'unavailable' });
		return;
	}
	voicesChanged = () => {
		send({
			domain: 'nato',
			action: 'voices',
			voices: window.speechSynthesis.getVoices().map((voice) => ({
				uri: voice.voiceURI,
				language: voice.lang,
			})),
		});
	};
	window.speechSynthesis.addEventListener('voiceschanged', voicesChanged);
	voicesChanged();
}

/** @param {Record<string, unknown>} data @param {Send} send */
function speak(data, send) {
	stopSpeech();
	const version = speechVersion;
	const request = data.request;
	try {
		const utterance = new window.SpeechSynthesisUtterance(String(data.text ?? ''));
		utterance.lang = String(data.language ?? 'nb-NO');
		utterance.rate = typeof data.rate === 'number' ? data.rate : 0.85;
		utterance.pitch = typeof data.pitch === 'number' ? data.pitch : 1;
		const voice = window.speechSynthesis
			.getVoices()
			.find((candidate) => candidate.voiceURI === data.voiceUri);
		if (voice) utterance.voice = voice;
		utterance.onend = () => finish('ended');
		utterance.onerror = () => finish('error');
		activeUtterance = utterance;
		ownsSpeech = true;
		window.speechSynthesis.speak(utterance);
	} catch {
		finish('error');
	}

	/** @param {string} action */
	function finish(action) {
		if (version !== speechVersion) return;
		activeUtterance = null;
		ownsSpeech = false;
		send({ domain: 'nato', action, request });
	}
}

function stopSpeech() {
	speechVersion += 1;
	if (activeUtterance) {
		activeUtterance.onend = null;
		activeUtterance.onerror = null;
		activeUtterance = null;
	}
	if (ownsSpeech && 'speechSynthesis' in window) window.speechSynthesis.cancel();
	ownsSpeech = false;
}

/** Stop sound, flash timers, speech and listeners on navigation or teardown. */
export function dispose() {
	stopMorse();
	stopSpeech();
	if (voicesChanged && 'speechSynthesis' in window) {
		window.speechSynthesis.removeEventListener('voiceschanged', voicesChanged);
	}
	voicesChanged = null;
	const context = audioContext;
	audioContext = null;
	if (context && context.state !== 'closed') void context.close().catch(() => {});
}
