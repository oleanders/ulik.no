<script lang="ts">
import '../app.css';
import { version } from '$app/environment';
import { page } from '$app/state';
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
				<a
					href="/"
					class="menu-link"
					class:active={page.url.pathname === '/'}
					aria-current={page.url.pathname === '/' ? 'page' : undefined}>~/hjem</a
				>
				<a
					href="/projects"
					class="menu-link"
					class:active={page.url.pathname.startsWith('/projects')}
					aria-current={page.url.pathname.startsWith('/projects') ? 'page' : undefined}
					>~/prosjekter</a
				>
				<a
					href="/om"
					class="menu-link"
					class:active={page.url.pathname === '/om'}
					aria-current={page.url.pathname === '/om' ? 'page' : undefined}>~/om</a
				>
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

	.menu-link {
		position: relative;
		overflow: hidden;
		color: var(--color-text);
		padding: 0.35rem 0.65rem;
		border: 1px solid transparent;
		border-radius: 999px;
		transition:
			transform 130ms ease,
			border-color 130ms ease,
			box-shadow 130ms ease,
			color 130ms ease,
			background 130ms ease;
	}

	.menu-link::after {
		content: '';
		position: absolute;
		inset: -180% -40%;
		background: radial-gradient(circle, rgba(0, 255, 136, 0.7) 0%, rgba(0, 255, 136, 0) 68%);
		opacity: 0;
		pointer-events: none;
	}

	.menu-link:hover,
		.menu-link:focus-visible {
		border-color: var(--color-border-strong);
		background: var(--color-surface);
	}

	.menu-link:active {
		transform: translateY(1px) scale(0.96);
		border-color: var(--color-primary);
		box-shadow: 0 0 18px color-mix(in srgb, var(--color-primary) 45%, transparent);
	}

	.menu-link:active::after {
		animation: nav-click 260ms ease-out;
	}

	.menu-link.active {
		font-weight: 700;
		color: var(--color-primary);
		border-color: color-mix(in srgb, var(--color-primary) 65%, transparent);
		background: color-mix(in srgb, var(--color-primary) 14%, transparent);
		text-shadow: 0 0 12px color-mix(in srgb, var(--color-primary) 45%, transparent);
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

	@keyframes nav-click {
		from {
			opacity: 0.75;
			transform: scale(0.15);
		}
		to {
			opacity: 0;
			transform: scale(1.2);
		}
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
