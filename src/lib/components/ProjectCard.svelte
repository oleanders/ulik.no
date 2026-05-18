<script lang="ts">
import type { Project } from '$lib/types';

const statusLabels = {
	active: 'aktiv',
	wip: 'under arbeid',
	idea: 'idé',
} as const;

let { project }: { project: Project } = $props();
</script>

<a class="card" href={project.href}>
	<div class="card-head">
		<h2>{project.title}</h2>
		<span class={`status ${project.status}`}>{statusLabels[project.status]}</span>
	</div>

	<p>{project.description}</p>

	<div class="tags" aria-label="Merkelappar">
		{#each project.tags as tag}
			<span>[{tag}]</span>
		{/each}
	</div>
</a>

<style>
	.card {
		display: grid;
		gap: 1rem;
		height: 100%;
		padding: 1rem;
		border: 1px solid var(--color-border);
		border-radius: 0.9rem;
		background: var(--color-surface-alt);
		position: relative;
		overflow: hidden;
		transition:
			transform 140ms ease,
			border-color 140ms ease,
			box-shadow 140ms ease;
		will-change: transform;
	}

	.card::after {
		content: '';
		position: absolute;
		inset: -40%;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(0, 204, 255, 0.7) 0%, rgba(0, 204, 255, 0) 62%);
		opacity: 0;
		pointer-events: none;
	}

	.card:hover,
		.card:focus-visible {
		border-color: var(--color-secondary);
		transform: translateY(-2px);
		box-shadow: 0 0 18px rgba(0, 204, 255, 0.12);
	}

	.card:active {
		transform: translateY(1px) scale(0.97);
		border-color: var(--color-primary);
		box-shadow:
			0 0 0 1px color-mix(in srgb, var(--color-primary) 45%, transparent),
			0 0 26px rgba(0, 255, 136, 0.28),
			inset 0 0 14px rgba(0, 255, 136, 0.22);
	}

	.card:active::after {
		animation: click-flash 320ms ease-out;
	}

	.card-head {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 0.75rem;
	}

	h2,
		p {
		margin: 0;
	}

	h2 {
		font-size: 1.1rem;
		color: var(--color-text);
	}

	p {
		color: var(--color-text-soft);
		line-height: 1.6;
	}

	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.65rem;
		color: var(--color-secondary);
		font-size: 0.9rem;
	}

	.status {
		padding: 0.25rem 0.55rem;
		border-radius: 999px;
		border: 1px solid currentColor;
		font-size: 0.8rem;
		white-space: nowrap;
	}

	.status.active {
		color: var(--color-primary);
	}

	.status.wip {
		color: #ffd166;
	}

	.status.idea {
		color: var(--color-secondary);
	}

	@keyframes click-flash {
		from {
			opacity: 0.8;
			transform: scale(0.1);
		}

		to {
			opacity: 0;
			transform: scale(2.2);
		}
	}
</style>
