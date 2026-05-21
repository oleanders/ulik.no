<script lang="ts">
import { onDestroy } from 'svelte';

type ShareState = 'idle' | 'sharing' | 'error';

let previewElement = $state<HTMLVideoElement | null>(null);
let displayStream = $state<MediaStream | null>(null);
let shareState = $state<ShareState>('idle');
let statusText = $state('Trykk start for å velge skjerm, vindu eller fane.');
let includeAudio = $state(false);

const supportsDisplayMedia =
	typeof navigator !== 'undefined' && typeof navigator.mediaDevices?.getDisplayMedia === 'function';

const sourceLabel = $derived(displayStream?.getVideoTracks()[0]?.label ?? 'Ingen aktiv kilde');

const clearPreview = () => {
	if (previewElement) {
		previewElement.srcObject = null;
	}
};

const stopSharing = () => {
	if (displayStream) {
		for (const track of displayStream.getTracks()) {
			track.stop();
		}
	}

	displayStream = null;
	shareState = 'idle';
	clearPreview();
};

const errorMessageFrom = (error: unknown): string => {
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
};

const bindStream = (stream: MediaStream) => {
	displayStream = stream;
	shareState = 'sharing';
	statusText = 'Skjermdeling er aktiv.';

	const [videoTrack] = stream.getVideoTracks();
	videoTrack?.addEventListener('ended', () => {
		statusText = 'Skjermdeling ble stoppet fra nettleseren.';
		stopSharing();
	});
};

const startSharing = async () => {
	if (!supportsDisplayMedia) {
		shareState = 'error';
		statusText = 'Denne nettleseren støtter ikke getDisplayMedia.';
		return;
	}

	stopSharing();

	try {
		const stream = await navigator.mediaDevices.getDisplayMedia({
			video: {
				frameRate: {
					ideal: 30,
					max: 60,
				},
			},
			audio: includeAudio,
		});

		bindStream(stream);
	} catch (error) {
		shareState = 'error';
		statusText = errorMessageFrom(error);
		clearPreview();
	}
};

$effect(() => {
	if (previewElement) {
		previewElement.srcObject = displayStream;
	}
});

onDestroy(() => {
	stopSharing();
});
</script>

<svelte:head>
	<title>skjerm≠deling — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ ./skjermdeling-lab --start</p>
	<div class="head-row">
		<h1>skjerm≠deling</h1>
		<span class={`status ${shareState}`}>{shareState === 'sharing' ? 'aktiv' : 'klar'}</span>
	</div>
	<p class="description">
		En enkel testlab for skjermdeling i nettleseren med <code>navigator.mediaDevices.getDisplayMedia</code>.
	</p>
</section>

<section class="terminal-panel controls">
	<p class="prompt">$ getdisplaymedia --preview</p>
	<div class="actions">
		<button type="button" onclick={startSharing} disabled={!supportsDisplayMedia || shareState === 'sharing'}>
			Start skjermdeling
		</button>
		<button type="button" class="ghost" onclick={stopSharing} disabled={shareState !== 'sharing'}>
			Stopp
		</button>
	</div>

	<label class="option">
		<input type="checkbox" bind:checked={includeAudio} disabled={shareState === 'sharing'} />
		Del systemlyd hvis tilgjengelig
	</label>

	<p class={`status-line ${shareState}`}>{statusText}</p>
	<p class="source">Kilde: {sourceLabel}</p>

	<div class="preview" data-active={shareState === 'sharing'}>
		<video bind:this={previewElement} autoplay playsinline muted controls={shareState === 'sharing'}></video>
	</div>
</section>

<style>
	.head,
	.controls {
		display: grid;
		gap: 0.85rem;
	}

	.controls {
		margin-top: 1rem;
	}

	h1,
	p {
		margin: 0;
	}

	.head-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	.description {
		max-width: 68ch;
		color: var(--color-text-soft);
	}

	.actions {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}

	button {
		border: 1px solid var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 15%, transparent);
		color: var(--color-primary);
		padding: 0.45rem 0.75rem;
		border-radius: 0.45rem;
		font: inherit;
		cursor: pointer;
	}

	button.ghost {
		border-color: var(--color-text-soft);
		color: var(--color-text-soft);
		background: transparent;
	}

	button:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.option {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		color: var(--color-text-soft);
	}

	.status {
		padding: 0.25rem 0.55rem;
		border-radius: 999px;
		border: 1px solid currentColor;
		font-size: 0.8rem;
	}

	.status.idle,
	.status.sharing {
		color: var(--color-primary);
	}

	.status.error {
		color: #ff8a80;
	}

	.status-line {
		font-size: 0.95rem;
	}

	.status-line.idle {
		color: var(--color-text-soft);
	}

	.status-line.sharing {
		color: var(--color-primary);
	}

	.status-line.error {
		color: #ff8a80;
	}

	.source {
		color: var(--color-secondary);
		font-size: 0.9rem;
	}

	.preview {
		border: 1px dashed var(--color-border);
		border-radius: 0.7rem;
		padding: 0.5rem;
		background: color-mix(in oklab, var(--color-bg-panel) 82%, black);
	}

	.preview video {
		display: block;
		width: 100%;
		max-height: min(64vh, 580px);
		background: #000;
		border-radius: 0.45rem;
	}

	.preview[data-active='false'] video {
		min-height: 220px;
	}
</style>
