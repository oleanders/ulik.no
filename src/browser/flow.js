import { createFlowField } from './flow-engine.js';

let cleanup = () => {};
let mountFrame = 0;
let generation = 0;
let renderer = null;
let pendingConfig = null;
let canvas = null;
let exportUrl = null;
let exportTimer;

/** Lustre owns configuration and UI; this adapter owns browser resources only. */
export function dispose() {
	generation += 1;
	cancelAnimationFrame(mountFrame);
	mountFrame = 0;
	cleanup();
	cleanup = () => {};
	renderer?.destroy();
	renderer = null;
	pendingConfig = null;
	canvas = null;
	clearTimeout(exportTimer);
	if (exportUrl) URL.revokeObjectURL(exportUrl);
	exportUrl = null;
}

export function mount(config, callbacks) {
	dispose();
	pendingConfig = config;
	const current = generation;
	const start = () => {
		if (generation !== current) return;
		canvas = document.getElementById('flow-canvas');
		const wrapper = document.getElementById('flow-wrapper');
		if (!canvas || !wrapper) {
			mountFrame = requestAnimationFrame(start);
			return;
		}
		renderer = createFlowField(canvas, pendingConfig);
		if (!renderer) {
			callbacks.on_error('Nettleseren kunne ikke starte lerretet. Prøv en annen nettleser.');
			return;
		}
		const engine = renderer;
		const element = canvas;
		const media = window.matchMedia('(prefers-reduced-motion: reduce)');
		const notify = (callback, ...args) => {
			if (generation === current) callback(...args);
		};
		const resize = () => {
			const rect = wrapper.getBoundingClientRect();
			engine.resize(rect.width, rect.height, window.devicePixelRatio);
		};
		const updatePointer = (event) => {
			const rect = element.getBoundingClientRect();
			if (!rect.width || !rect.height) return;
			engine.setPointer(
				(event.clientX - rect.left) / rect.width,
				(event.clientY - rect.top) / rect.height,
			);
			notify(callbacks.on_pointer_used);
		};
		const clearPointer = () => {
			engine.clearPointer();
			notify(callbacks.on_pointer_used);
		};
		const releaseTouch = (event) => {
			if (event.pointerType !== 'mouse') clearPointer();
		};
		const visibility = () => engine.setVisible(!document.hidden);
		const motion = () => notify(callbacks.on_motion, media.matches);
		const handlers = [
			['pointermove', updatePointer],
			['pointerdown', updatePointer],
			['pointerup', releaseTouch],
			['pointerleave', clearPointer],
			['pointercancel', clearPointer],
			['blur', clearPointer],
		];
		for (const [event, handler] of handlers) element.addEventListener(event, handler);
		document.addEventListener('visibilitychange', visibility);
		media.addEventListener('change', motion);
		const observer = new ResizeObserver(resize);
		observer.observe(wrapper);
		resize();
		visibility();
		cleanup = () => {
			observer.disconnect();
			for (const [event, handler] of handlers) element.removeEventListener(event, handler);
			document.removeEventListener('visibilitychange', visibility);
			media.removeEventListener('change', motion);
		};
		notify(callbacks.on_ready, media.matches);
	};
	// Lustre's DOM patch and its commands may happen in the same animation frame.
	mountFrame = requestAnimationFrame(start);
}

export function savePng(filename, onExported) {
	const current = generation;
	if (!canvas) return;
	const complete = (data) => {
		if (generation === current) onExported(data);
	};
	try {
		canvas.toBlob((blob) => {
			if (generation !== current) return;
			if (!blob) {
				complete('Kunne ikke lage bildet. Prøv igjen.');
				return;
			}
			clearTimeout(exportTimer);
			if (exportUrl) URL.revokeObjectURL(exportUrl);
			exportUrl = URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = exportUrl;
			link.download = filename;
			link.click();
			complete('PNG-bildet er klart for nedlasting.');
			exportTimer = setTimeout(() => {
				if (exportUrl) URL.revokeObjectURL(exportUrl);
				exportUrl = null;
			}, 1000);
		}, 'image/png');
	} catch {
		complete('Kunne ikke lage bildet. Prøv igjen.');
	}
}

export async function share(url, onShared) {
	const current = generation;
	let message;
	try {
		await navigator.clipboard.writeText(url);
		message = 'Lenken er kopiert. Den åpner dette universet fra starten.';
	} catch {
		message = 'Kopier lenken fra feltet under.';
	}
	if (current === generation) onShared(message);
}

export function configure(config) {
	pendingConfig = config;
	renderer?.configure(config);
}
export function setRunning(running) {
	renderer?.setRunning(running);
}
export function restart() {
	renderer?.restart();
}
export function setPointer(x, y) {
	renderer?.setPointer(x, y);
}
export function clearPointer() {
	renderer?.clearPointer();
}
export function newSeed(previous) {
	let seed = crypto.getRandomValues(new Uint32Array(1))[0] || 1;
	if (seed === previous) seed = seed === 0xffffffff ? 1 : seed + 1;
	return seed;
}
export function selectShare() {
	document.getElementById('flow-share')?.select();
}
