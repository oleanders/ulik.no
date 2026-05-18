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
	}

	.card:hover,
		.card:focus-visible {
		border-color: var(--color-secondary);
		transform: translateY(-2px);
		box-shadow: 0 0 18px rgba(0, 204, 255, 0.12);
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
</style>
