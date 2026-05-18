<script lang="ts">
import type { PageProps } from './$types';

const statusLabels = {
	active: 'aktiv',
	wip: 'under arbeid',
	idea: 'idé',
} as const;

let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>{data.project.title} — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel project-page">
	<p class="prompt">$ cat ./prosjekter/{data.project.id}/status.log</p>
	<div class="project-head">
		<h1>{data.project.title}</h1>
		<span class={`status ${data.project.status}`}>{statusLabels[data.project.status]}</span>
	</div>
	<p class="description">{data.project.description}</p>

	<div class="tags">
		{#each data.project.tags as tag}
			<span>[{tag}]</span>
		{/each}
	</div>
</section>

<section class="terminal-panel construction">
	<p class="prompt">$ tail -f deploy.log</p>
	<div class="notice">
		<span class="signal" aria-hidden="true">≠</span>
		<div>
			<h2>Under konstruksjon</h2>
			<p>Denne prosjektsiden er på vei opp. Inntil videre er prosjektet trygt parkert i terminalkøen.</p>
		</div>
	</div>
</section>

<style>
	.project-page,
		.construction {
		display: grid;
		gap: 1rem;
	}

	.project-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		flex-wrap: wrap;
	}

	h1,
		h2,
		p {
		margin: 0;
	}

	.description {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.65rem;
		color: var(--color-secondary);
	}

	.notice {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.signal {
		font-size: clamp(2.5rem, 8vw, 4rem);
		line-height: 1;
		color: var(--color-primary);
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

	.status.wip {
		color: #ffd166;
	}

	.status.idea {
		color: var(--color-secondary);
	}

	@media (max-width: 640px) {
		.notice {
			align-items: flex-start;
			flex-direction: column;
		}
	}
</style>
