<script lang="ts">
import { goto } from '$app/navigation';
import { pickSurprise } from '$lib/projects';

let { excludeId }: { excludeId?: string } = $props();
</script>

<button type="button" onclick={() => goto(pickSurprise(excludeId).href)}>Overrask meg <span aria-hidden="true">↗</span></button>

<style>
	button {
		min-height: 44px;
		padding: 0.75rem 1rem;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.4rem;
		background: transparent;
		color: var(--color-text);
		cursor: pointer;
		font-size: 0.85rem;
	}

	button:hover, button:focus-visible {
		border-color: var(--color-secondary);
		color: var(--color-secondary);
	}

	button:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 3px;
	}

	span {
		margin-left: 0.5rem;
	}
</style>
