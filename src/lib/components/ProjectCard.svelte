<script lang="ts">
import { categoryLabels } from '$lib/projects';
import type { Project } from '$lib/types';
import ProjectPreview from './ProjectPreview.svelte';

let { project }: { project: Project } = $props();
</script>

<a class="card" href={project.href}>
	<ProjectPreview id={project.id} />
	<div class="body">
		<div class="meta">
			<span>{categoryLabels[project.category]}</span>
			{#if project.status !== 'active'}<span class="status">{project.status === 'wip' ? 'Under arbeid' : 'Idé'}</span>{/if}
		</div>
		<h2>{project.title}</h2>
		<p>{project.hook}</p>
		<div class="foot"><span>{project.interaction}</span><span class="arrow" aria-hidden="true">↗</span></div>
	</div>
</a>

<style>
	.card {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		background: var(--color-surface-alt);
		transition: border-color 140ms ease, transform 140ms ease;
	}

	.card:hover, .card:focus-visible {
		border-color: var(--color-secondary);
		transform: translateY(-3px);
	}

	.card:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 4px;
	}

	.body {
		padding: 1.1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		flex: 1;
	}

	.meta, .foot {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.75rem;
	}

	.meta {
		color: var(--color-secondary);
		font-size: 0.7rem;
		flex-wrap: wrap;
	}

	h2, p {
		margin: 0;
	}

	h2 {
		color: var(--color-text);
		font-size: 1.1rem;
	}

	p {
		color: var(--color-text-soft);
		font-size: 0.85rem;
		line-height: 1.6;
	}

	.status {
		color: #ffd166;
	}

	.foot {
		margin-top: auto;
		padding-top: 0.75rem;
		color: var(--color-text-soft);
		font-size: 0.7rem;
	}

	.arrow {
		font-size: 1.5rem;
		color: var(--color-primary);
	}

	@media (prefers-reduced-motion: reduce) {
		.card {
			transition: none;
		}

		.card:hover, .card:focus-visible {
			transform: none;
		}

	}
</style>
