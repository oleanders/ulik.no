<script lang="ts">
import FlowPreview from '$lib/components/FlowPreview.svelte';
import ProjectCard from '$lib/components/ProjectCard.svelte';
import SurpriseLink from '$lib/components/SurpriseLink.svelte';
import { projects } from '$lib/projects';

const featured = ['fall-haug', 'morsekode', 'diff-tool'].flatMap((id) =>
	projects.filter((project) => project.id === id),
);
</script>

<svelte:head>
	<title>≠ ulik.no</title>
</svelte:head>

<section class="hero terminal-panel" aria-labelledby="home-title">
	<div class="intro">
		<p class="prompt">$ ./ulik --utforsk</p>
		<h1 id="home-title"><span aria-hidden="true">≠</span> ulik.no</h1>
		<p class="tagline">ulik alt annet.</p>
		<p class="description">Små eksperimenter. Rare ideer.<br />Ting du kan prøve, ikke bare lese om.</p>
		<div class="actions">
			<a class="primary" href="/projects/flyt-felt">Lek med flyt≠felt <span aria-hidden="true">→</span></a>
			<SurpriseLink />
		</div>
		<a class="catalog" href="/projects">Se alle {projects.length} prosjekter ↓</a>
	</div>
	<FlowPreview />
</section>

<section class="discovery" aria-labelledby="discovery-title">
	<div class="section-head">
		<div><p class="prompt">$ ls ./muligheter</p><h2 id="discovery-title">Hvor vil du begynne?</h2></div>
		<a href="/projects">Hele katalogen →</a>
	</div>
	<div class="project-grid">
		{#each featured as project}<ProjectCard {project} />{/each}
	</div>
	<p class="note">Ingen konto. Bare nysgjerrighet.</p>
</section>

<style>
	.hero {
		display: grid;
		grid-template-columns: 1fr 1.15fr;
		gap: 2rem;
		padding: 2rem;
		align-items: center;
	}

	.intro {
		display: grid;
		gap: 1.25rem;
		min-width: 0;
	}

	h1, h2, p {
		margin: 0;
	}

	h1 {
		font-size: clamp(2.5rem, 5vw, 4rem);
		letter-spacing: -0.06em;
		line-height: 1.2;
	}

	h1 span {
		color: var(--color-primary);
		text-shadow: 0 0 24px #00ff8840;
	}

	.tagline {
		color: var(--color-secondary);
		font-size: 1.1rem;
	}

	.description {
		color: var(--color-text-soft);
		font-size: 0.9rem;
		line-height: 1.8;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.65rem;
		margin-top: 0.5rem;
	}

	.primary {
		display: inline-flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 0.8rem 1rem;
		min-height: 44px;
		border-radius: 0.4rem;
		background: var(--color-primary);
		color: #052116;
		font-size: 0.85rem;
		font-weight: 700;
	}

	.primary:hover {
		background: var(--color-secondary);
	}

	a:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 4px;
	}

	.catalog {
		font-size: 0.8rem;
		color: var(--color-text-soft);
		width: fit-content;
		padding-block: 0.5rem;
	}

	.discovery {
		margin-top: 3rem;
	}

	.section-head {
		display: flex;
		align-items: end;
		justify-content: space-between;
		gap: 1rem;
		flex-wrap: wrap;
		margin-bottom: 1.25rem;
	}

	.section-head .prompt {
		font-size: 0.8rem;
		margin-bottom: 0.6rem;
	}

	.section-head a {
		font-size: 0.8rem;
	}

	h2 {
		font-size: clamp(1.1rem, 2vw, 1.4rem);
	}

	.project-grid {
		display: grid;
		gap: 1rem;
		grid-template-columns: repeat(3, minmax(0, 1fr));
	}

	.note {
		color: var(--color-text-soft);
		font-size: 0.75rem;
		margin-top: 1.2rem;
	}

	@media (max-width: 800px) {
		.hero {
			grid-template-columns: 1fr;
			gap: 1.5rem;
			padding: 1.25rem;
		}

		.project-grid {
			grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr));
		}

	}
</style>
