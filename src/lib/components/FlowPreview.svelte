<script lang="ts">
import { onMount } from 'svelte';

let canvas: HTMLCanvasElement;
let ready = $state(false);
let paused = $state(true);
let reducedMotion = $state(false);
let syncPlayback = () => {};
let changePattern = () => {};

onMount(() => {
	const context = canvas.getContext('2d');
	if (!context) return;
	const ctx = context;
	const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
	let visible = false;
	let width = 0;
	let height = 0;
	let frame = 0;
	let raf = 0;
	let lastTime = 0;
	let variation = 0;
	let hue = 150;
	let pointer: { x: number; y: number } | null = null;
	let particles: { x: number; y: number; life: number }[] = [];

	function step() {
		frame++;
		ctx.fillStyle = 'rgba(10, 16, 15, 0.055)';
		ctx.fillRect(0, 0, width, height);
		for (const p of particles) {
			const angle =
				(Math.sin(p.x * 0.009 + variation) + Math.cos(p.y * 0.012 + frame * 0.002)) * Math.PI;
			let dx = Math.cos(angle) * 2;
			let dy = Math.sin(angle) * 2;
			if (pointer) {
				const distance = Math.hypot(p.x - pointer.x, p.y - pointer.y);
				if (distance > 1 && distance < 90) {
					dx += ((p.x - pointer.x) / distance) * 3;
					dy += ((p.y - pointer.y) / distance) * 3;
				}
			}
			ctx.strokeStyle = `hsla(${hue + p.x * 0.12}, 85%, 65%, 0.6)`;
			ctx.beginPath();
			ctx.moveTo(p.x, p.y);
			p.x += dx;
			p.y += dy;
			ctx.lineTo(p.x, p.y);
			ctx.stroke();
			if (--p.life < 0 || p.x < 0 || p.x > width || p.y < 0 || p.y > height) {
				p.x = Math.random() * width;
				p.y = Math.random() * height;
				p.life = 100 + Math.random() * 160;
			}
		}
	}

	function seed() {
		ctx.fillStyle = '#0a100f';
		ctx.fillRect(0, 0, width, height);
		particles = Array.from({ length: 180 }, () => ({
			x: Math.random() * width,
			y: Math.random() * height,
			life: 100 + Math.random() * 160,
		}));
		// A still composition is useful before playback and with reduced motion.
		for (let i = 0; i < 45; i++) step();
	}

	function tick(time: number) {
		if (time - lastTime >= 1000 / 30) {
			step();
			lastTime = time;
		}
		raf = requestAnimationFrame(tick);
	}

	syncPlayback = () => {
		cancelAnimationFrame(raf);
		if (!paused && visible && !document.hidden && width > 0) {
			lastTime = 0;
			raf = requestAnimationFrame(tick);
		}
	};
	changePattern = () => {
		variation += 0.8;
		hue = (hue + 45) % 360;
		seed();
	};
	const resize = new ResizeObserver(() => {
		const rect = canvas.getBoundingClientRect();
		if (!rect.width || !rect.height || (width === rect.width && height === rect.height)) return;
		width = rect.width;
		height = rect.height;
		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		canvas.width = Math.round(width * dpr);
		canvas.height = Math.round(height * dpr);
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		seed();
		syncPlayback();
	});
	const intersection = new IntersectionObserver(([entry]) => {
		visible = entry.isIntersecting;
		syncPlayback();
	});
	const updateMotion = () => {
		reducedMotion = motion.matches;
		paused = motion.matches;
		syncPlayback();
	};
	const updatePointer = (event: PointerEvent) => {
		const rect = canvas.getBoundingClientRect();
		pointer = { x: event.clientX - rect.left, y: event.clientY - rect.top };
	};
	const clearPointer = () => {
		pointer = null;
	};
	updateMotion();
	resize.observe(canvas);
	intersection.observe(canvas);
	motion.addEventListener('change', updateMotion);
	document.addEventListener('visibilitychange', syncPlayback);
	canvas.addEventListener('pointermove', updatePointer);
	canvas.addEventListener('pointerdown', updatePointer);
	canvas.addEventListener('pointerleave', clearPointer);
	canvas.addEventListener('pointercancel', clearPointer);
	canvas.addEventListener('pointerup', clearPointer);
	ready = true;

	return () => {
		cancelAnimationFrame(raf);
		resize.disconnect();
		intersection.disconnect();
		motion.removeEventListener('change', updateMotion);
		document.removeEventListener('visibilitychange', syncPlayback);
		canvas.removeEventListener('pointermove', updatePointer);
		canvas.removeEventListener('pointerdown', updatePointer);
		canvas.removeEventListener('pointerleave', clearPointer);
		canvas.removeEventListener('pointercancel', clearPointer);
		canvas.removeEventListener('pointerup', clearPointer);
		syncPlayback = () => {};
		changePattern = () => {};
	};
});
</script>

<div class="preview">
	<div class="preview-head"><span>01 / flyt≠felt</span><span>prøv her ↓</span></div>
	<div class="art">
		<svg class="fallback" viewBox="0 0 500 300" aria-hidden="true">
			{#each Array.from({ length: 18 }, (_, i) => i) as line}
				<path d={`M -20 ${line * 18} Q 170 ${300 - line * 12} 260 ${line * 15} T 520 ${line * 16}`} />
			{/each}
		</svg>
		<canvas bind:this={canvas} class:ready aria-label="Forhåndsvisning av flyt≠felt: fargede spor som følger et strømningsfelt"></canvas>
	</div>
	<div class="preview-foot">
		<p>{reducedMotion ? 'Et stille mønster. Start bevegelsen hvis du vil.' : 'Beveg pekeren eller berør bildet.'}</p>
		<div class="controls">
			<button type="button" disabled={!ready} onclick={() => { paused = !paused; syncPlayback(); }} aria-pressed={!paused}>
				{paused ? 'Start bevegelse' : 'Pause bevegelse'}
			</button>
			<button type="button" disabled={!ready} onclick={() => changePattern()}>Nytt mønster</button>
		</div>
	</div>
</div>

<style>
	.preview {
		overflow: hidden;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.8rem;
		background: #0a100f;
	}

	.preview-head, .preview-foot {
		padding: 0.9rem 1rem;
	}

	.preview-head {
		display: flex;
		justify-content: space-between;
		gap: 1rem;
		color: var(--color-primary);
		font-size: 0.8rem;
		border-bottom: 1px solid var(--color-border);
	}

	.preview-head span:last-child {
		color: var(--color-text-soft);
	}

	.art {
		position: relative;
		height: clamp(220px, 27vw, 320px);
	}

	canvas, .fallback {
		position: absolute;
		width: 100%;
		height: 100%;
	}

	canvas {
		opacity: 0;
	}

	canvas.ready {
		opacity: 1;
	}

	.fallback {
		fill: none;
		stroke: var(--color-primary);
		stroke-width: 1;
		opacity: 0.65;
	}

	.preview-foot {
		border-top: 1px solid var(--color-border);
	}

	p {
		margin: 0 0 0.8rem;
		font-size: 0.78rem;
		color: var(--color-text-soft);
		line-height: 1.5;
	}

	.controls {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	button {
		padding: 0.55rem 0.7rem;
		min-height: 44px;
		font-size: 0.75rem;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.35rem;
		background: var(--color-surface);
		color: var(--color-text);
		cursor: pointer;
	}

	button:hover, button:focus-visible {
		border-color: var(--color-secondary);
		color: var(--color-secondary);
	}

	button:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 3px;
	}

	button:disabled {
		opacity: 0.5;
		cursor: default;
	}
</style>
