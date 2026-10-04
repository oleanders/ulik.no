import { diffLines, diffWordsWithSpace } from 'diff';

let displayStream = null;
let requestId = 0;
let previewFrame = null;

/** The browser owns media resources; Elm owns page state and markup. */
function clearStream() {
	if (previewFrame !== null) {
		cancelAnimationFrame(previewFrame);
		previewFrame = null;
	}
	if (displayStream) {
		for (const track of displayStream.getTracks()) track.stop();
		displayStream = null;
	}
	const preview = document.getElementById('screen-preview');
	if (preview) preview.srcObject = null;
}

function supportsDisplayMedia() {
	return typeof navigator.mediaDevices?.getDisplayMedia === 'function';
}

function errorMessageFrom(error) {
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

async function startSharing(includeAudio, send) {
	const currentRequest = ++requestId;
	clearStream();
	if (!supportsDisplayMedia()) {
		send({
			domain: 'screen',
			action: 'error',
			message: 'Denne nettleseren støtter ikke getDisplayMedia.',
		});
		return;
	}

	try {
		const stream = await navigator.mediaDevices.getDisplayMedia({
			video: { frameRate: { ideal: 30, max: 60 } },
			audio: includeAudio,
		});
		// A route change or a newer request must not leave a late permission result capturing.
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
				send({ domain: 'screen', action: 'stopped' });
			},
			{ once: true },
		);
		send({
			domain: 'screen',
			action: 'started',
			sourceLabel: videoTrack?.label ?? 'Ingen aktiv kilde',
		});
		// Elm has rendered the video by the next frame, including on client-side navigation.
		previewFrame = requestAnimationFrame(() => {
			previewFrame = null;
			const preview = document.getElementById('screen-preview');
			if (preview && displayStream === stream) {
				preview.srcObject = stream;
				preview.play()?.catch(() => {});
			}
		});
	} catch (error) {
		if (currentRequest !== requestId) return;
		clearStream();
		send({ domain: 'screen', action: 'error', message: errorMessageFrom(error) });
	}
}

/** Handle only browser APIs and the established diff algorithm, never page rendering. */
export function handle(command, send) {
	switch (command.action) {
		case 'diff': {
			const compare = command.mode === 'words' ? diffWordsWithSpace : diffLines;
			const changes = compare(command.left, command.right).map((part) => ({
				value: part.value,
				count: part.count ?? 0,
				added: Boolean(part.added),
				removed: Boolean(part.removed),
			}));
			send({ domain: 'diff', revision: command.revision, changes });
			break;
		}
		case 'screenSupport':
			send({ domain: 'screen', action: 'support', supported: supportsDisplayMedia() });
			break;
		case 'screenStart':
			void startSharing(Boolean(command.audio), send);
			break;
		case 'screenStop':
			dispose();
			break;
	}
}

export function dispose() {
	requestId += 1;
	clearStream();
}
