<script lang="ts">
import { onMount } from 'svelte';
import ProjectCard from '$lib/components/ProjectCard.svelte';
import SurpriseLink from '$lib/components/SurpriseLink.svelte';
import { categoryLabels, projects } from '$lib/projects';
import type { ProjectCategory } from '$lib/types';

let ready = $state(false);
onMount(() => {
	ready = true;
});

let category = $state<ProjectCategory | 'alle'>('alle');
const categories: (ProjectCategory | 'alle')[] = ['alle', 'lek', 'kunst', 'verktoy'];
const filtered = $derived(
	projects.filter((project) => category === 'alle' || project.category === category),
);
</script>

<svelte:head>
	<title>Prosjekter — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel page-head">
	<p class="prompt">$ tree ./prosjekter -L 1</p>
	<h1>Prosjekter</h1>
	<p>Vil du leke, lage noe eller løse en liten floke? Velg et sidespor.</p>
	<div><SurpriseLink /></div>
</section>

<div class="filters" role="group" aria-label="Filtrer prosjekter">
	{#each categories as choice}
		<button type="button" disabled={!ready} aria-pressed={category === choice} onclick={() => { category = choice; }}>{choice === 'alle' ? 'Alle' : categoryLabels[choice]}</button>
	{/each}
</div>
<p class="count" role="status">Viser {filtered.length} av {projects.length} prosjekter</p>
<section class="project-grid" aria-label="Prosjekter">
	{#each filtered as project}<ProjectCard {project} />{/each}
</section>

<style>
	.page-head {
		display: grid;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	h1, p {
		margin: 0;
	}

	.page-head > p:not(.prompt) {
		max-width: 65ch;
		color: var(--color-text-soft);
		line-height: 1.7;
	}

	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 0.6rem;
	}

	button {
		min-height: 44px;
		padding: 0.6rem 0.9rem;
		background: var(--color-surface);
		color: var(--color-text-soft);
		border: 1px solid var(--color-border-strong);
		border-radius: 0.4rem;
		font-size: 0.8rem;
		cursor: pointer;
	}

	button[aria-pressed='true'] {
		color: var(--color-primary);
		border-color: var(--color-primary);
		background: #0a251a;
	}

	button:hover {
		color: var(--color-secondary);
		border-color: var(--color-secondary);
	}

	button:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 3px;
	}

	.count {
		color: var(--color-text-soft);
		font-size: 0.75rem;
		margin: 1rem 0;
	}

	.project-grid {
		display: grid;
		gap: 1rem;
		grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr));
	}
</style>
