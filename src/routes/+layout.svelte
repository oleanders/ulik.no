<script lang="ts">
import '../app.css';
import { version } from '$app/environment';
import favicon from '$lib/assets/favicon.svg';
import DeployStatus from '$lib/components/DeployStatus.svelte';

let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<meta
		name="description"
		content="Terminal-inspirert hjemmeside for AI-eksperimenter, små prosjekter og digitale sidespor på ulik.no"
	/>
</svelte:head>

<div class="layout">
	<header class="shell-header">
		<nav aria-label="Hovednavigasjon">
			<a href="/" class="logo" aria-label="ulik.no hjem">≠</a>
			<div class="nav-links">
				<a href="/">~/hjem</a>
				<a href="/projects">~/prosjekter</a>
			</div>
		</nav>
	</header>

	<main>
		{@render children()}
	</main>

	<footer class="shell-footer">
		<span>≠ ulik.no — {version}</span>
		<DeployStatus />
	</footer>
</div>

<style>
	.layout {
		min-height: 100vh;
		display: grid;
		grid-template-rows: auto 1fr auto;
	}

	.shell-header,
	.shell-footer {
		width: min(1100px, calc(100% - 2rem));
		margin: 0 auto;
	}

	nav {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 1.25rem 0 1rem;
		border-bottom: 1px solid var(--color-border);
	}

	main {
		width: min(1100px, calc(100% - 2rem));
		margin: 0 auto;
		padding: 2rem 0 4rem;
	}

	.logo {
		font-size: clamp(2rem, 6vw, 3.5rem);
		font-weight: 800;
		line-height: 1;
		color: var(--color-primary);
		text-shadow: 0 0 24px color-mix(in srgb, var(--color-primary) 35%, transparent);
	}

	.logo:hover {
		color: var(--color-secondary);
	}

	.nav-links {
		display: flex;
		flex-wrap: wrap;
		justify-content: flex-end;
		gap: 1rem;
	}

	.nav-links a {
		color: var(--color-text);
		padding: 0.35rem 0.65rem;
		border: 1px solid transparent;
		border-radius: 999px;
	}

	.nav-links a:hover,
		.nav-links a:focus-visible {
		border-color: var(--color-border-strong);
		background: var(--color-surface);
	}

	.shell-footer {
		padding: 0 0 2rem;
		color: var(--color-text-muted);
		font-size: 0.9rem;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		flex-wrap: wrap;
	}

	@media (max-width: 640px) {
		nav {
			align-items: flex-start;
			flex-direction: column;
		}

		.nav-links {
			justify-content: flex-start;
		}
	}
</style>
