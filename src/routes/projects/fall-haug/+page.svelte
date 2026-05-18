<script lang="ts">
import { onMount } from 'svelte';

type Snapshot = {
	element: HTMLElement;
	visibility: string;
};

let running = $state(false);
let cloneCount = $state(0);

let snapshots: Snapshot[] = [];
let clones: HTMLElement[] = [];
let previousOverflow = '';

const selectors = [
	'header .logo',
	'header .menu-link',
	'main .terminal-panel',
	'main h1',
	'main p',
	'main button',
	'main textarea',
	'main canvas',
	'main .card',
	'footer > span',
	'footer > a',
].join(',');

const reset = () => {
	for (const clone of clones) clone.remove();
	for (const snap of snapshots) snap.element.style.visibility = snap.visibility;
	clones = [];
	snapshots = [];
	cloneCount = 0;
	running = false;
	document.body.style.overflow = previousOverflow;
};

const dropAll = async () => {
	reset();
	running = true;
	previousOverflow = document.body.style.overflow;
	document.body.style.overflow = 'hidden';

	const all = Array.from(document.querySelectorAll<HTMLElement>(selectors));
	const filtered = all.filter((element) => {
		if (element.closest('[data-no-fall]')) return false;
		const rect = element.getBoundingClientRect();
		return rect.width > 12 && rect.height > 12;
	});
	const targets = filtered.filter(
		(element) => !filtered.some((other) => other !== element && other.contains(element)),
	);

	const floorY = window.innerHeight - 95;
	const animations: Promise<Animation>[] = [];

	for (const [index, element] of targets.entries()) {
		const rect = element.getBoundingClientRect();
		const clone = element.cloneNode(true) as HTMLElement;
		clone.setAttribute('aria-hidden', 'true');
		clone.classList.add('fall-clone');
		clone.style.position = 'fixed';
		clone.style.left = `${rect.left}px`;
		clone.style.top = `${rect.top}px`;
		clone.style.width = `${rect.width}px`;
		clone.style.height = `${rect.height}px`;
		clone.style.margin = '0';
		clone.style.zIndex = '9999';
		clone.style.pointerEvents = 'none';
		document.body.append(clone);

		snapshots.push({ element, visibility: element.style.visibility });
		element.style.visibility = 'hidden';
		clones.push(clone);

		const centerX = rect.left + rect.width / 2;
		const centerY = rect.top + rect.height / 2;
		const targetX = centerX + (Math.random() - 0.5) * Math.min(90, rect.width * 0.45);
		const targetY = floorY - Math.random() * 70;
		const dx = targetX - centerX;
		const dy = targetY - centerY;
		const rotation = (Math.random() - 0.5) * 78;
		const shakeX = Math.max(3, Math.min(12, rect.width * 0.08));
		const shakeY = Math.max(2, Math.min(8, rect.height * 0.06));
		const baseDelay = 280;
		const extraDelay = element.closest('.head') ? 750 : 0;
		const delay = baseDelay + index * 28 + Math.random() * 70 + extraDelay;
		const duration = 1450 + Math.abs(dy) * 1.25 + Math.random() * 360;

		const animation = clone.animate(
			[
				{ transform: 'translate3d(0, 0, 0) rotate(0deg)' },
				{
					transform: `translate3d(${-shakeX}px, ${-shakeY}px, 0) rotate(${-3 - Math.random() * 2}deg)`,
					offset: 0.08,
				},
				{
					transform: `translate3d(${shakeX}px, ${shakeY}px, 0) rotate(${3 + Math.random() * 2}deg)`,
					offset: 0.16,
				},
				{
					transform: `translate3d(${-shakeX * 0.7}px, ${-shakeY * 0.5}px, 0) rotate(${-2 - Math.random()}deg)`,
					offset: 0.33,
				},
				{
					transform: `translate3d(${dx * 0.9}px, ${dy - 14}px, 0) rotate(${rotation * 0.58}deg)`,
					offset: 0.88,
				},
				{ transform: `translate3d(${dx}px, ${dy + 8}px, 0) rotate(${rotation}deg)`, offset: 0.94 },
				{ transform: `translate3d(${dx}px, ${dy}px, 0) rotate(${rotation}deg)` },
			],
			{
				duration,
				delay,
				easing: 'cubic-bezier(0.18, 0.65, 0.2, 1)',
				fill: 'forwards',
			},
		);
		animations.push(animation.finished);
	}

	cloneCount = targets.length;
	await Promise.allSettled(animations);
	running = false;
};

onMount(() => {
	void dropAll();
	return () => reset();
});
</script>

<svelte:head>
	<title>fall≠ned — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ ./fall-haug --slipp-alt</p>
	<div class="head-row">
		<h1>fall≠ned</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="desc">
		Denne versjonen slipper de faktiske elementene på siden: logo, meny, seksjoner, footer, og denne info-boksen ned.
	</p>
</section>

<section class="terminal-panel dock">
	<div class="controls">
		<button type="button" disabled={running} onclick={() => void dropAll()}>
			{running ? 'slipper…' : 'slipp alt igjen'}
		</button>
	</div>
	<p class="meta">{cloneCount > 0 ? `${cloneCount} elementer sluppet.` : 'forbereder slipp...'}</p>
</section>

<div class="reset-wrap" data-no-fall>
	<button type="button" class="reset-fixed" onclick={reset}>reset side</button>
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

	h1,
	p {
		margin: 0;
	}

	.desc {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.meta {
		font-size: 0.86rem;
		color: var(--color-text-muted);
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
		flex-wrap: wrap;
		gap: 0.6rem;
	}

	.dock {
		display: grid;
		gap: 0.7rem;
	}

	.reset-wrap {
		position: fixed;
		right: 1rem;
		bottom: 1rem;
		z-index: 10001;
	}

	.reset-fixed {
		box-shadow: 0 0 18px color-mix(in srgb, var(--color-primary) 30%, transparent);
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

	button:disabled {
		opacity: 0.55;
		cursor: wait;
	}

	:global(.fall-clone) {
		box-shadow: 0 8px 22px rgba(0, 0, 0, 0.36);
		transform-origin: center;
	}
</style>
