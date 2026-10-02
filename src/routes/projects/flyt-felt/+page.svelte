<script lang="ts">
import { onMount } from 'svelte';
import { afterNavigate } from '$app/navigation';
import { page } from '$app/state';
import {
	configQuery,
	DEFAULT_CONFIG,
	type FlowConfig,
	LIMITS,
	PRESETS,
	type PresetId,
	parseConfig,
	presetConfig,
} from './flow-config';
import { createFlowField, type FlowController } from './flow-engine';

let canvas: HTMLCanvasElement;
let wrapper: HTMLDivElement;
let config = $state<FlowConfig>({ ...DEFAULT_CONFIG });
let running = $state(false);
let ready = $state(false);
let reducedMotion = $state(false);
let message = $state('');
let shareUrl = $state('');
let exporting = $state(false);
let engine = $state.raw<FlowController | null>(null);
let keyboardPointer = $state({ x: 0.5, y: 0.5 });
let keyboardActive = $state(false);
let exportUrl: string | null = null;
let exportTimer: ReturnType<typeof setTimeout> | undefined;
let mounted = false;
const activePreset = $derived(PRESETS.find((preset) => preset.id === config.preset) ?? PRESETS[0]);

// Includes Back/Forward and client-side navigation to another shared composition.
afterNavigate(() => {
	config = parseConfig(page.url.search);
	shareUrl = '';
	message = '';
	keyboardPointer = { x: 0.5, y: 0.5 };
	keyboardActive = false;
});

$effect(() => engine?.configure(config));
$effect(() => engine?.setRunning(running));

onMount(() => {
	mounted = true;
	const media = window.matchMedia('(prefers-reduced-motion: reduce)');
	reducedMotion = media.matches;
	running = !media.matches;
	config = parseConfig(window.location.search);
	engine = createFlowField(canvas, config);
	if (!engine) {
		message = 'Nettleseren kunne ikke starte lerretet. Prøv en annen nettleser.';
		return;
	}
	const renderer = engine;
	renderer.setVisible(!document.hidden);
	ready = true;

	const resize = () => {
		const rect = wrapper.getBoundingClientRect();
		renderer.resize(rect.width, rect.height, window.devicePixelRatio);
	};
	resize();
	const observer = new ResizeObserver(resize);
	observer.observe(wrapper);

	const updatePointer = (event: PointerEvent) => {
		keyboardActive = false;
		const rect = canvas.getBoundingClientRect();
		if (!rect.width || !rect.height) return;
		renderer.setPointer(
			(event.clientX - rect.left) / rect.width,
			(event.clientY - rect.top) / rect.height,
		);
	};
	const clearPointer = () => {
		keyboardActive = false;
		renderer.clearPointer();
	};
	const releaseTouch = (event: PointerEvent) => {
		if (event.pointerType !== 'mouse') clearPointer();
	};
	const visibilityChange = () => renderer.setVisible(!document.hidden);
	const motionChange = () => {
		reducedMotion = media.matches;
		if (media.matches) running = false;
	};
	canvas.addEventListener('pointermove', updatePointer);
	canvas.addEventListener('pointerdown', updatePointer);
	canvas.addEventListener('pointerup', releaseTouch);
	canvas.addEventListener('pointerleave', clearPointer);
	canvas.addEventListener('pointercancel', clearPointer);
	canvas.addEventListener('blur', clearPointer);
	document.addEventListener('visibilitychange', visibilityChange);
	media.addEventListener('change', motionChange);

	return () => {
		mounted = false;
		renderer.destroy();
		observer.disconnect();
		canvas.removeEventListener('pointermove', updatePointer);
		canvas.removeEventListener('pointerdown', updatePointer);
		canvas.removeEventListener('pointerup', releaseTouch);
		canvas.removeEventListener('pointerleave', clearPointer);
		canvas.removeEventListener('pointercancel', clearPointer);
		canvas.removeEventListener('blur', clearPointer);
		document.removeEventListener('visibilitychange', visibilityChange);
		media.removeEventListener('change', motionChange);
		clearTimeout(exportTimer);
		if (exportUrl) URL.revokeObjectURL(exportUrl);
		engine = null;
	};
});

function selectPreset(id: PresetId): void {
	config = presetConfig(id, config.seed);
	shareUrl = '';
	message = '';
}

function updateControl(key: keyof typeof LIMITS, event: Event): void {
	const input = event.currentTarget;
	if (!(input instanceof HTMLInputElement)) return;
	if (!Number.isFinite(input.valueAsNumber)) return;
	const { min, max } = LIMITS[key];
	config = { ...config, [key]: Math.min(max, Math.max(min, input.valueAsNumber)) };
	shareUrl = '';
	message = '';
}

function newUniverse(): void {
	const values = crypto.getRandomValues(new Uint32Array(1));
	let seed = values[0] || 1;
	if (seed === config.seed) seed = seed === 0xffffffff ? 1 : seed + 1;
	config = { ...config, seed };
	shareUrl = '';
	message = 'Et nytt univers er klart.';
}

function restart(): void {
	engine?.restart();
	keyboardPointer = { x: 0.5, y: 0.5 };
	keyboardActive = false;
	message = 'Samme univers, tilbake til starten.';
}

function keyboardControl(event: KeyboardEvent): void {
	if (event.code === 'Space') {
		event.preventDefault();
		running = !running;
		return;
	}
	if (event.key === 'Escape') {
		keyboardActive = false;
		engine?.clearPointer();
		return;
	}
	const directions: Record<string, [number, number]> = {
		ArrowLeft: [-0.05, 0],
		ArrowRight: [0.05, 0],
		ArrowUp: [0, -0.05],
		ArrowDown: [0, 0.05],
	};
	const direction = directions[event.key];
	if (!direction) return;
	event.preventDefault();
	keyboardPointer.x = Math.min(1, Math.max(0, keyboardPointer.x + direction[0]));
	keyboardPointer.y = Math.min(1, Math.max(0, keyboardPointer.y + direction[1]));
	keyboardActive = true;
	engine?.setPointer(keyboardPointer.x, keyboardPointer.y);
}

async function share(): Promise<void> {
	// Construct a fresh URL: never forward unknown parameters, fragments or pointer history.
	const url = new URL(window.location.pathname, window.location.origin);
	url.search = configQuery(config);
	shareUrl = url.href;
	try {
		await navigator.clipboard.writeText(shareUrl);
		if (mounted) message = 'Lenken er kopiert. Den åpner dette universet fra starten.';
	} catch {
		if (mounted) message = 'Kopier lenken fra feltet under.';
	}
}

function savePng(): void {
	if (!ready || exporting) return;
	exporting = true;
	const filename = `flyt-felt-${config.preset}-${config.seed}.png`;
	canvas.toBlob((blob) => {
		if (!mounted) return;
		exporting = false;
		if (!blob) {
			message = 'Kunne ikke lage bildet. Prøv igjen.';
			return;
		}
		clearTimeout(exportTimer);
		if (exportUrl) URL.revokeObjectURL(exportUrl);
		exportUrl = URL.createObjectURL(blob);
		const link = document.createElement('a');
		link.href = exportUrl;
		link.download = filename;
		link.click();
		message = 'PNG-bildet er klart for nedlasting.';
		exportTimer = setTimeout(() => {
			if (exportUrl) URL.revokeObjectURL(exportUrl);
			exportUrl = null;
		}, 1000);
	}, 'image/png');
}
</script>

<svelte:head>
	<title>flyt≠felt — ≠ ulik.no</title>
</svelte:head>

<section class="head" aria-labelledby="flow-title">
	<p class="prompt">$ ./flyt-felt --utforsk</p>
	<div class="head-row">
		<h1 id="flow-title">flyt≠felt</h1>
		<span class="status" class:active={ready && running}>
			{!ready ? 'starter' : running ? 'i bevegelse' : 'på pause'}
		</span>
	</div>
	<p class="desc">Små partikler. Egne veier. Velg en stemning, form strømmen og ta vare på et øyeblikk.</p>
</section>

<section class="studio" aria-label="Ditt flytfelt">
	<div class="canvas-wrap" bind:this={wrapper}>
		<canvas
			bind:this={canvas}
			tabindex="0"
			aria-label={`Flytfelt: ${activePreset.name}`}
			aria-describedby="flow-help"
			onkeydown={keyboardControl}
		>
			Et generativt bilde av fargede partikler. Nettleseren må støtte canvas for å vise det.
		</canvas>
		{#if keyboardActive}
			<span class="keyboard-pointer" aria-hidden="true" style:left={`${keyboardPointer.x * 100}%`} style:top={`${keyboardPointer.y * 100}%`}></span>
		{/if}
	</div>
	<div class="canvas-footer">
		<span>{activePreset.name} / seed <span data-testid="flow-seed">{config.seed}</span></span>
		<span>{config.density} partikler · lokalt i nettleseren</span>
	</div>
	<div class="toolbar">
		<button type="button" class="primary" disabled={!ready} onclick={() => running = !running}>
			{running ? 'pause' : 'spill av'}
		</button>
		<button type="button" disabled={!ready} onclick={newUniverse}>nytt univers</button>
		<button type="button" disabled={!ready} onclick={restart}>start på nytt</button>
		<button type="button" disabled={!ready || exporting} onclick={savePng}>
			{exporting ? 'lager bilde …' : 'lagre PNG'}
		</button>
		<button type="button" disabled={!ready} onclick={share}>del univers</button>
	</div>
	<p class="help" id="flow-help">
		Beveg pekeren eller dra én finger over bildet. Med tastatur: fokuser bildet og bruk piltastene.
		Mellomrom pauser, Esc slipper feltet. Du kan rulle siden utenfor bildet.
	</p>
	{#if reducedMotion}
		<p class="motion-note">Redusert bevegelse er valgt. Bildet starter stille; spill av når du vil.</p>
	{/if}
</section>

<section class="terminal-panel settings" aria-label="Innstillinger for flytfelt">
	<fieldset class="presets">
		<legend>01 / velg en stemning</legend>
		<div class="preset-grid">
			{#each PRESETS as preset}
				<button
					type="button"
					class="preset"
					aria-pressed={config.preset === preset.id}
					onclick={() => selectPreset(preset.id)}
				>
					<span class="preset-name">{preset.name}</span>
					<span class="preset-description">{preset.description}</span>
				</button>
			{/each}
		</div>
	</fieldset>
	<fieldset class="adjustments">
		<legend>02 / finn din flyt</legend>
		<div class="slider-grid">
			<label for="flow-speed">
				<span>Fart <output for="flow-speed">{config.speed.toFixed(2)}×</output></span>
				<input id="flow-speed" type="range" {...LIMITS.speed} value={config.speed} oninput={(event) => updateControl('speed', event)} />
				<small>rolig → rask</small>
			</label>
			<label for="flow-density">
				<span>Tetthet <output for="flow-density">{config.density}</output></span>
				<input id="flow-density" type="range" {...LIMITS.density} value={config.density} oninput={(event) => updateControl('density', event)} />
				<small>luftig → tett</small>
			</label>
			<label for="flow-attraction">
				<span>Tiltrekning <output for="flow-attraction">{config.attraction.toFixed(1)}</output></span>
				<input id="flow-attraction" type="range" {...LIMITS.attraction} value={config.attraction} oninput={(event) => updateControl('attraction', event)} />
				<small>dytt ← 0 → trekk, ved pekeren</small>
			</label>
			<label for="flow-hue">
				<span>Fargetone <output for="flow-hue">{config.hue}°</output></span>
				<input id="flow-hue" type="range" {...LIMITS.hue} value={config.hue} oninput={(event) => updateControl('hue', event)} />
				<small>hele fargesirkelen</small>
			</label>
		</div>
	</fieldset>
	<div class="settings-footer">
		<p>Endringer tegner universet fra starten. Seedet beholdes.</p>
		<button type="button" onclick={() => selectPreset(config.preset)}>nullstill innstillinger</button>
	</div>
</section>

<div class="sharing">
	<p class="feedback" role="status">{message}</p>
	{#if shareUrl}
		<label for="flow-share">Lenke til universet</label>
		<input id="flow-share" type="url" readonly value={shareUrl} onclick={(event) => event.currentTarget.select()} />
		<p class="help">Lenken inneholder bare innstillinger og seed. Bevegelsene dine og det ferdige bildet følger ikke med. Bruk PNG for å bevare akkurat dette øyeblikket.</p>
	{/if}
</div>

<style>
	.head { display: grid; gap: 0.65rem; margin-bottom: 1.5rem; }
	.head-row { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
	h1 { margin: 0; font-size: clamp(2rem, 5vw, 3rem); letter-spacing: -0.06em; }
	.desc { max-width: 75ch; color: var(--color-text-soft); margin: 0; line-height: 1.65; }
	.status { padding: 0.3rem 0.65rem; border-radius: 999px; border: 1px solid var(--color-border-strong); font-size: 0.75rem; color: var(--color-text-soft); }
	.status.active { color: var(--color-primary); }
	.canvas-wrap { position: relative; width: 100%; aspect-ratio: 16 / 9; border: 1px solid var(--color-border-strong); border-radius: 0.8rem 0.8rem 0 0; overflow: hidden; background: #0a0a0a; }
	canvas { display: block; width: 100%; height: 100%; cursor: crosshair; touch-action: none; }
	.keyboard-pointer { position: absolute; width: 1rem; height: 1rem; transform: translate(-50%, -50%); border: 1px solid var(--color-secondary); border-radius: 50%; box-shadow: 0 0 0 3px #0a0a0a; pointer-events: none; }
	canvas:focus-visible { outline: 2px solid var(--color-secondary); outline-offset: -4px; }
	.canvas-footer { display: flex; justify-content: space-between; gap: 0.5rem 1rem; flex-wrap: wrap; padding: 0.75rem 1rem; border: 1px solid var(--color-border-strong); border-top: 0; background: var(--color-surface); color: var(--color-text-soft); font-size: 0.75rem; border-radius: 0 0 0.8rem 0.8rem; }
	.toolbar { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0; }
	button { padding: 0.65rem 0.9rem; min-height: 44px; background: var(--color-surface-alt); color: var(--color-text); border: 1px solid var(--color-border-strong); border-radius: 0.5rem; cursor: pointer; font-size: 0.85rem; }
	button:hover { border-color: var(--color-secondary); }
	button:focus-visible, input:focus-visible { outline: 2px solid var(--color-secondary); outline-offset: 3px; }
	button:disabled { cursor: wait; opacity: 0.5; }
	button.primary { color: var(--color-primary); border-color: var(--color-primary); min-width: 7rem; }
	.help, .motion-note { font-size: 0.8rem; color: var(--color-text-soft); line-height: 1.7; max-width: 95ch; }
	.motion-note { color: var(--color-secondary); }
	.settings { margin-top: 1.5rem; display: grid; gap: 1.5rem; }
	fieldset { padding: 0; margin: 0; border: 0; min-width: 0; }
	legend { color: var(--color-primary); font-size: 0.8rem; margin-bottom: 0.9rem; }
	.preset-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.75rem; }
	.preset { display: grid; gap: 0.5rem; text-align: left; padding: 1rem; }
	.preset[aria-pressed='true'] { border-color: var(--color-primary); background: color-mix(in srgb, var(--color-primary) 7%, var(--color-surface)); }
	.preset-name { color: var(--color-text); font-size: 1rem; }
	.preset[aria-pressed='true'] .preset-name { color: var(--color-primary); }
	.preset-description { color: var(--color-text-soft); font-size: 0.75rem; line-height: 1.7; }
	.slider-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1.4rem 2rem; }
	.slider-grid label { display: grid; gap: 0.5rem; font-size: 0.85rem; }
	.slider-grid label > span { display: flex; justify-content: space-between; gap: 1rem; }
	output { color: var(--color-primary); font-variant-numeric: tabular-nums; }
	input[type='range'] { width: 100%; min-height: 32px; margin: 0; accent-color: var(--color-primary); cursor: pointer; }
	small { font-size: 0.7rem; color: var(--color-text-soft); }
	.settings-footer { border-top: 1px solid var(--color-border); padding-top: 1rem; display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; }
	.settings-footer p { color: var(--color-text-soft); font-size: 0.75rem; margin: 0; line-height: 1.6; }
	.sharing { margin-top: 1rem; font-size: 0.8rem; }
	.feedback { min-height: 1.5em; color: var(--color-secondary); line-height: 1.6; }
	input[type='url'] { width: 100%; margin-top: 0.5rem; padding: 0.8rem; border: 1px solid var(--color-border-strong); border-radius: 0.5rem; color: var(--color-text); background: var(--color-surface); }
	@media (max-width: 600px) {
		.preset-grid { grid-template-columns: 1fr; }
		.preset { padding: 0.8rem; gap: 0.25rem; }
		.slider-grid { grid-template-columns: 1fr; }
		.canvas-footer { padding: 0.7rem; font-size: 0.65rem; }
		.toolbar button { flex: 1 1 auto; }
	}
</style>
