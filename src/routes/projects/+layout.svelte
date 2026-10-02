<script lang="ts">
import { page } from '$app/state';
import SurpriseLink from '$lib/components/SurpriseLink.svelte';
import { getOnwardProjects, projects } from '$lib/projects';

let { children } = $props();
const current = $derived(
	projects.find((project) => project.id === page.url.pathname.split('/')[2]),
);
const onward = $derived(getOnwardProjects(current?.id ?? ''));
</script>

{@render children()}

{#if current}
	<nav class="onward terminal-panel" aria-label="Utforsk videre">
		<div class="head"><div><p class="prompt">$ cd ../neste</p><h2>Prøv noe mer</h2></div><a class="catalog" href="/projects">Alle prosjekter →</a></div>
		<div class="choices">
			{#if onward.related}
				<a class="suggestion" href={onward.related.href}><span>I samme spor</span><strong>{onward.related.title} ↗</strong><span>{onward.related.hook}</span></a>
			{/if}
			{#if onward.different}
				<a class="suggestion" href={onward.different.href}><span>Noe helt annet</span><strong>{onward.different.title} ↗</strong><span>{onward.different.hook}</span></a>
			{/if}
		</div>
		<div><SurpriseLink excludeId={current.id} /></div>
	</nav>
{/if}

<style>
	.onward {
		margin-top: 2rem;
		display: grid;
		gap: 1.2rem;
	}

	.head {
		display: flex;
		justify-content: space-between;
		align-items: end;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.prompt, .catalog {
		font-size: 0.8rem;
	}

	h2 {
		margin: 0.6rem 0 0;
		font-size: 1.2rem;
	}

	.choices {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr));
		gap: 1rem;
	}

	.suggestion {
		display: grid;
		gap: 0.65rem;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		padding: 1rem;
	}

	.suggestion:hover {
		border-color: var(--color-secondary);
	}

	.suggestion span {
		font-size: 0.8rem;
		line-height: 1.5;
		color: var(--color-text-soft);
	}

	.suggestion span:first-child {
		color: var(--color-secondary);
		font-size: 0.7rem;
	}

	a:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 3px;
	}
</style>
