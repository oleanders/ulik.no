<script lang="ts">
import { onMount } from 'svelte';

let canvas: HTMLCanvasElement;
let wrapper: HTMLDivElement;
let running = $state(true);
let hue = $state(160);

type Particle = {
	x: number;
	y: number;
	vx: number;
	vy: number;
	life: number;
};

let restart: (() => void) | null = null;

onMount(() => {
	const ctx = canvas.getContext('2d');
	if (!ctx) return;

	let width = 0;
	let height = 0;
	let particles: Particle[] = [];
	let frame = 0;
	let rafId = 0;
	let pointer = { x: 0, y: 0, active: false };

	const resize = () => {
		const dpr = window.devicePixelRatio || 1;
		const rect = wrapper.getBoundingClientRect();
		width = rect.width;
		height = rect.height;
		canvas.width = width * dpr;
		canvas.height = height * dpr;
		canvas.style.width = `${width}px`;
		canvas.style.height = `${height}px`;
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		ctx.fillStyle = '#0a0a0a';
		ctx.fillRect(0, 0, width, height);
	};

	const seed = (count: number) => {
		particles = Array.from({ length: count }, () => ({
			x: Math.random() * width,
			y: Math.random() * height,
			vx: 0,
			vy: 0,
			life: Math.random() * 200,
		}));
	};

	const noise = (x: number, y: number, t: number) => {
		return (
			Math.sin(x * 0.0035 + t * 0.0008) +
			Math.cos(y * 0.0042 + t * 0.0011) +
			Math.sin((x + y) * 0.002 + t * 0.0005)
		);
	};

	const tick = () => {
		frame++;

		ctx.fillStyle = 'rgba(10, 10, 10, 0.04)';
		ctx.fillRect(0, 0, width, height);

		for (const p of particles) {
			const angle = noise(p.x, p.y, frame) * Math.PI;
			p.vx = p.vx * 0.85 + Math.cos(angle) * 0.9;
			p.vy = p.vy * 0.85 + Math.sin(angle) * 0.9;

			if (pointer.active) {
				const dx = p.x - pointer.x;
				const dy = p.y - pointer.y;
				const distSq = dx * dx + dy * dy;
				const radius = 140;
				if (distSq < radius * radius && distSq > 0.5) {
					const dist = Math.sqrt(distSq);
					const force = (1 - dist / radius) * 4;
					p.vx += (dx / dist) * force;
					p.vy += (dy / dist) * force;
				}
			}

			p.x += p.vx;
			p.y += p.vy;
			p.life -= 1;

			if (p.x < 0 || p.x > width || p.y < 0 || p.y > height || p.life <= 0) {
				p.x = Math.random() * width;
				p.y = Math.random() * height;
				p.vx = 0;
				p.vy = 0;
				p.life = 200 + Math.random() * 200;
			}

			const localHue = (hue + p.x * 0.05 + p.y * 0.05) % 360;
			ctx.fillStyle = `hsla(${localHue}, 90%, 60%, 0.5)`;
			ctx.fillRect(p.x, p.y, 1.2, 1.2);
		}

		if (running) rafId = requestAnimationFrame(tick);
	};

	restart = () => {
		cancelAnimationFrame(rafId);
		rafId = requestAnimationFrame(tick);
	};

	resize();
	seed(900);
	rafId = requestAnimationFrame(tick);

	const updatePointer = (event: PointerEvent) => {
		const rect = canvas.getBoundingClientRect();
		pointer.x = event.clientX - rect.left;
		pointer.y = event.clientY - rect.top;
		pointer.active = true;
	};

	const clearPointer = () => {
		pointer.active = false;
	};

	canvas.addEventListener('pointermove', updatePointer);
	canvas.addEventListener('pointerdown', updatePointer);
	canvas.addEventListener('pointerleave', clearPointer);
	canvas.addEventListener('pointercancel', clearPointer);

	const observer = new ResizeObserver(() => {
		resize();
		seed(900);
	});
	observer.observe(wrapper);

	return () => {
		cancelAnimationFrame(rafId);
		observer.disconnect();
		canvas.removeEventListener('pointermove', updatePointer);
		canvas.removeEventListener('pointerdown', updatePointer);
		canvas.removeEventListener('pointerleave', clearPointer);
		canvas.removeEventListener('pointercancel', clearPointer);
		restart = null;
	};
});

const toggle = () => {
	running = !running;
	if (running && restart) restart();
};

const shiftHue = () => {
	hue = (hue + 40) % 360;
};
</script>

<svelte:head>
	<title>flyt≠felt — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ ./flyt-felt --start</p>
	<div class="head-row">
		<h1>flyt≠felt</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="desc">
		Et abstrakt, bevegelig bilde der småpartikler følger et en bevegelig strek. Hver piksel
		bestemmer retningen sin selv — derfor blir bildet ulikt hver gang. Beveg muspekeren over
		bildet for å dytte partiklene.
	</p>
	<div class="controls">
		<button type="button" onclick={toggle}>
			{running ? 'pause' : 'spill av'}
		</button>
		<button type="button" onclick={shiftHue}>skift farge</button>
	</div>
</section>

<div class="canvas-wrap" bind:this={wrapper}>
	<canvas bind:this={canvas} aria-label="Abstrakt bevegelig flow field"></canvas>
</div>

<style>
	.head {
		display: grid;
		gap: 0.75rem;
		margin-bottom: 1.25rem;
	}

	.head-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	h1 {
		margin: 0;
	}

	.desc {
		max-width: 65ch;
		color: var(--color-text-soft);
		margin: 0;
	}

	.status {
		padding: 0.25rem 0.55rem;
		border-radius: 999px;
		border: 1px solid currentColor;
		font-size: 0.8rem;
	}

	.status.active {
		color: var(--color-primary);
	}

	.controls {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	button {
		font-family: inherit;
		font-size: 0.9rem;
		padding: 0.4rem 0.85rem;
		background: var(--color-surface-alt);
		color: var(--color-text);
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		cursor: pointer;
	}

	button:hover,
	button:focus-visible {
		border-color: var(--color-secondary);
		color: var(--color-secondary);
	}

	.canvas-wrap {
		position: relative;
		width: 100%;
		aspect-ratio: 16 / 9;
		border: 1px solid var(--color-border);
		border-radius: 0.9rem;
		overflow: hidden;
		background: #0a0a0a;
	}

	canvas {
		display: block;
		width: 100%;
		height: 100%;
		cursor: crosshair;
		touch-action: none;
	}
</style>
