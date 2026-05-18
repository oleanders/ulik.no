<script lang="ts">
import ProjectCard from '$lib/components/ProjectCard.svelte';
import { projects } from '$lib/projects';
</script>

<svelte:head>
	<title>≠ ulik.no</title>
</svelte:head>

<section class="hero terminal-panel">
	<p class="prompt">$ whoami</p>
	<div class="hero-mark" aria-hidden="true">≠</div>
	<h1>ulik.no</h1>
	<p class="tagline">
		ulik alt annet.
		<span class="cursor" aria-hidden="true"></span>
	</p>
	<p class="intro">
		Et lite terminalvindu for AI-eksperimenter, små digitale sidespor og prosjekter som får lov til å
		være annerledes.
	</p>
</section>

<section class="terminal-panel projects">
	<div class="section-head">
		<p class="prompt">$ ls ./prosjekter</p>
		<a href="/projects">åpne katalogen →</a>
	</div>

	<div class="project-grid">
		{#each projects as project}
			<ProjectCard {project} />
		{/each}
	</div>
</section>

<style>
	.hero,
		.projects {
		display: grid;
		gap: 1rem;
	}

	.hero {
		padding-top: 1rem;
	}

	.projects {
		margin-top: 1.25rem;
	}

	.hero-mark {
		font-size: clamp(5rem, 18vw, 10rem);
		line-height: 0.9;
		color: var(--color-primary);
		text-shadow: 0 0 32px color-mix(in srgb, var(--color-primary) 45%, transparent);
	}

	h1 {
		margin: 0;
		font-size: clamp(2.5rem, 7vw, 5rem);
	}

	.tagline {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		margin: 0;
		font-size: clamp(1.1rem, 2.6vw, 1.5rem);
		color: var(--color-secondary);
	}

	.cursor {
		display: inline-block;
		width: 0.75ch;
		height: 1.1em;
		background: currentColor;
		animation: blink 1s steps(1) infinite;
	}

	.intro {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.section-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.project-grid {
		display: grid;
		gap: 1rem;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
	}

	@keyframes blink {
		0%,
		49% {
			opacity: 1;
		}

		50%,
		100% {
			opacity: 0;
		}
	}
</style>
