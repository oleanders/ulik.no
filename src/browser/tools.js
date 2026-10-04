import { diffLines, diffWordsWithSpace } from 'diff';

let displayStream = null;
let requestId = 0;
let previewFrame = null;

/** Gleam owns page state and markup; JavaScript owns only browser resources. */
function clearStream() {
	if (previewFrame !== null) {
		cancelAnimationFrame(previewFrame);
		previewFrame = null;
	}
	const stream = displayStream;
	displayStream = null;
	if (stream) {
		for (const track of stream.getTracks()) track.stop();
	}
	const preview =
		typeof document === 'undefined' ? null : document.getElementById('screen-preview');
	if (preview) preview.srcObject = null;
}

export function compareTextParts(left, right, byWords) {
	return (byWords ? diffWordsWithSpace : diffLines)(left, right);
}

export function supportsDisplayMedia() {
	return (
		typeof navigator !== 'undefined' &&
		typeof navigator.mediaDevices?.getDisplayMedia === 'function'
	);
}

export function errorMessageFrom(error) {
	if (!(error instanceof DOMException)) {
		return 'Noe gikk galt under oppstart av skjermdeling.';
	}
	switch (error.name) {
		case 'NotAllowedError':
			return 'Skjermdeling ble avbrutt eller blokkert. Prøv igjen og tillat tilgang.';
		case 'NotFoundError':
			return 'Fant ingen skjermkilder å dele.';
		case 'AbortError':
			return 'Skjermdeling ble avbrutt før den startet.';
		default:
			return `Skjermdeling feilet: ${error.name}`;
	}
}

/** Explicit callbacks match the typed Screen Message constructors. */
export function startSharing(includeAudio, onStarted, onStopped, onFailed) {
	void requestSharing(includeAudio, onStarted, onStopped, onFailed);
}

async function requestSharing(includeAudio, onStarted, onStopped, onFailed) {
	const currentRequest = ++requestId;
	clearStream();
	if (!supportsDisplayMedia()) {
		onFailed('Denne nettleseren støtter ikke getDisplayMedia.');
		return;
	}

	try {
		const stream = await navigator.mediaDevices.getDisplayMedia({
			video: { frameRate: { ideal: 30, max: 60 } },
			audio: includeAudio,
		});
		// A newer request or route cleanup invalidates late permission results.
		if (currentRequest !== requestId) {
			for (const track of stream.getTracks()) track.stop();
			return;
		}
		displayStream = stream;
		const [videoTrack] = stream.getVideoTracks();
		videoTrack?.addEventListener(
			'ended',
			() => {
				if (displayStream !== stream) return;
				clearStream();
				onStopped();
			},
			{ once: true },
		);
		onStarted(videoTrack?.label ?? 'Ingen aktiv kilde');
		previewFrame = requestAnimationFrame(() => {
			previewFrame = null;
			const preview = document.getElementById('screen-preview');
			if (preview && displayStream === stream) {
				// Muting the property also prevents feedback in browsers where a muted
				// attribute alone only sets the video's defaultMuted property.
				preview.muted = true;
				preview.srcObject = stream;
				preview.play()?.catch(() => {});
			}
		});
	} catch (error) {
		if (currentRequest !== requestId) return;
		clearStream();
		onFailed(errorMessageFrom(error));
	}
}

export function stopSharing() {
	dispose();
}

export function dispose() {
	requestId += 1;
	clearStream();
}
