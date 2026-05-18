<script lang="ts">
import ProjectCard from '$lib/components/ProjectCard.svelte';
import { projects } from '$lib/projects';
</script>

<svelte:head>
	<title>Prosjekter — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel page-head">
	<p class="prompt">$ tree ./prosjekter -L 1</p>
	<h1>Prosjekter</h1>
	<p>
		En liten samling med verktøy, AI-eksperimenter og ting som fortsatt blinker <span>≠</span> i margen.
	</p>
</section>

<section class="project-grid">
	{#each projects as project}
		<ProjectCard {project} />
	{/each}
</section>

<style>
	.page-head {
		display: grid;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	h1,
		p {
		margin: 0;
	}

	.page-head p:last-child {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.page-head span {
		color: var(--color-primary);
	}

	.project-grid {
		display: grid;
		gap: 1rem;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
	}
</style>
