import { createFlowField } from './flow-engine.js';

let cleanup = () => {};
let mountFrame = 0;
let generation = 0;
let renderer = null;
let pendingConfig = null;
let canvas = null;
let exportUrl = null;
let exportTimer;

/** Elm owns configuration and UI; this adapter owns browser resources only. */
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

function mount(config, send) {
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
			send({
				domain: 'flow',
				action: 'error',
				data: 'Nettleseren kunne ikke starte lerretet. Prøv en annen nettleser.',
			});
			return;
		}
		const engine = renderer;
		const element = canvas;
		const media = window.matchMedia('(prefers-reduced-motion: reduce)');
		const emit = (action, data) => {
			if (generation === current) send({ domain: 'flow', action, data });
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
			emit('pointerUsed', null);
		};
		const clearPointer = () => {
			engine.clearPointer();
			emit('pointerUsed', null);
		};
		const releaseTouch = (event) => {
			if (event.pointerType !== 'mouse') clearPointer();
		};
		const visibility = () => engine.setVisible(!document.hidden);
		const motion = () => emit('motion', media.matches);
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
		emit('ready', media.matches);
	};
	// Elm's DOM patch and its commands may happen in the same animation frame.
	mountFrame = requestAnimationFrame(start);
}

function savePng(filename, send) {
	const current = generation;
	if (!canvas) return;
	const complete = (data) => {
		if (generation === current) send({ domain: 'flow', action: 'exported', data });
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

async function share(url, send) {
	const current = generation;
	let message;
	try {
		await navigator.clipboard.writeText(url);
		message = 'Lenken er kopiert. Den åpner dette universet fra starten.';
	} catch {
		message = 'Kopier lenken fra feltet under.';
	}
	if (current === generation) send({ domain: 'flow', action: 'shared', data: message });
}

export function handle(command, send) {
	if (command.domain !== 'flow') return;
	const { action, data } = command;
	switch (action) {
		case 'mount':
			mount(data, send);
			break;
		case 'configure':
			pendingConfig = data;
			renderer?.configure(data);
			break;
		case 'running':
			renderer?.setRunning(data);
			break;
		case 'restart':
			renderer?.restart();
			break;
		case 'pointer':
			renderer?.setPointer(data.x, data.y);
			break;
		case 'clearPointer':
			renderer?.clearPointer();
			break;
		case 'newSeed': {
			let seed = crypto.getRandomValues(new Uint32Array(1))[0] || 1;
			if (seed === data) seed = seed === 0xffffffff ? 1 : seed + 1;
			send({ domain: 'flow', action: 'seed', data: seed });
			break;
		}
		case 'share':
			void share(data, send);
			break;
		case 'selectShare':
			document.getElementById('flow-share')?.select();
			break;
		case 'png':
			savePng(data, send);
			break;
		case 'dispose':
			dispose();
			break;
		default:
			break;
	}
}
