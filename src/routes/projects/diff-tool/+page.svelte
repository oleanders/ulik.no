<script lang="ts">
import { type Change, diffLines, diffWordsWithSpace } from 'diff';

const exampleLeft = `# handleliste
melk
brød
egg
kaffe
sjokolade`;

const exampleRight = `# handleliste
havremelk
brød
egg
kaffe
te
mørk sjokolade`;

let left = $state(exampleLeft);
let right = $state(exampleRight);
let mode = $state<'lines' | 'words'>('lines');

const changes = $derived<Change[]>(
	mode === 'lines' ? diffLines(left, right) : diffWordsWithSpace(left, right),
);

const stats = $derived(() => {
	let added = 0;
	let removed = 0;
	for (const part of changes) {
		const count = mode === 'lines' ? (part.count ?? 0) : part.value.length;
		if (part.added) added += count;
		else if (part.removed) removed += count;
	}
	return { added, removed };
});

const clear = () => {
	left = '';
	right = '';
};

const swap = () => {
	[left, right] = [right, left];
};
</script>

<svelte:head>
	<title>tekst≠diff — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ diff ./venstre.txt ./hoyre.txt</p>
	<div class="head-row">
		<h1>tekst≠diff</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="desc">
		Lim inn tekst i de to boksene, så vises forskjellene under. Bytt mellom linje- og ordsammenlikning,
		bytt om sidene, eller tøm alt.
	</p>
	<div class="controls">
		<div class="mode" role="group" aria-label="Sammenlikningsmodus">
			<button type="button" class:active={mode === 'lines'} onclick={() => (mode = 'lines')}>
				linjer
			</button>
			<button type="button" class:active={mode === 'words'} onclick={() => (mode = 'words')}>
				ord
			</button>
		</div>
		<button type="button" onclick={swap}>↔ bytt</button>
		<button type="button" onclick={clear}>tøm</button>
	</div>
</section>

<section class="inputs">
	<label class="pane">
		<span class="pane-head">~ /venstre</span>
		<textarea bind:value={left} spellcheck="false" placeholder="lim inn første tekst…"></textarea>
	</label>
	<label class="pane">
		<span class="pane-head">~ /høyre</span>
		<textarea bind:value={right} spellcheck="false" placeholder="lim inn andre tekst…"></textarea>
	</label>
</section>

<section class="terminal-panel diff-output" aria-label="Diff-resultat">
	<div class="diff-head">
		<p class="prompt">$ cat ./diff.patch</p>
		<div class="stats">
			<span class="added">+{stats().added}</span>
			<span class="removed">-{stats().removed}</span>
		</div>
	</div>

	{#if left === '' && right === ''}
		<p class="empty">ingen inndata enda.</p>
	{:else if changes.length === 1 && !changes[0].added && !changes[0].removed}
		<p class="empty">tekstene er identiske.</p>
	{:else}
		<pre class="diff"><!--
		-->{#each changes as part}<!--
			-->{#if part.added}<span class="line added">{part.value}</span><!--
			-->{:else if part.removed}<span class="line removed">{part.value}</span><!--
			-->{:else}<span class="line context">{part.value}</span><!--
			-->{/if}<!--
		-->{/each}</pre>
	{/if}
</section>

<style>
	.head {
		display: grid;
		gap: 0.75rem;
		margin-bottom: 1.25rem;
	}

	.head-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	h1 {
		margin: 0;
	}

	.desc {
		max-width: 65ch;
		color: var(--color-text-soft);
		margin: 0;
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

	.controls {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.mode {
		display: inline-flex;
		gap: 0;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		overflow: hidden;
	}

	.mode button {
		border: none;
		border-radius: 0;
	}

	.mode button.active {
		background: var(--color-surface);
		color: var(--color-primary);
	}

	button {
		font-family: inherit;
		font-size: 0.9rem;
		padding: 0.4rem 0.85rem;
		background: var(--color-surface-alt);
		color: var(--color-text);
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		cursor: pointer;
	}

	button:hover,
	button:focus-visible {
		border-color: var(--color-secondary);
		color: var(--color-secondary);
	}

	.inputs {
		display: grid;
		gap: 1rem;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		margin-bottom: 1.25rem;
	}

	.pane {
		display: grid;
		gap: 0.5rem;
	}

	.pane-head {
		color: var(--color-text-muted);
		font-size: 0.9rem;
	}

	textarea {
		font-family: inherit;
		font-size: 0.95rem;
		min-height: 240px;
		padding: 0.85rem;
		background: var(--color-surface-alt);
		color: var(--color-text);
		border: 1px solid var(--color-border);
		border-radius: 0.6rem;
		resize: vertical;
		line-height: 1.5;
	}

	textarea:focus-visible {
		outline: none;
		border-color: var(--color-secondary);
	}

	.diff-output {
		display: grid;
		gap: 0.75rem;
	}

	.diff-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.stats {
		display: flex;
		gap: 0.75rem;
		font-size: 0.9rem;
	}

	.added {
		color: var(--color-primary);
	}

	.removed {
		color: #ff6b6b;
	}

	.empty {
		margin: 0;
		color: var(--color-text-muted);
	}

	.diff {
		margin: 0;
		padding: 0.75rem;
		background: #050505;
		border: 1px solid var(--color-border);
		border-radius: 0.5rem;
		font-family: inherit;
		font-size: 0.9rem;
		line-height: 1.55;
		white-space: pre-wrap;
		word-break: break-word;
		overflow-x: auto;
		max-height: 60vh;
	}

	.line.added {
		background: rgba(0, 255, 136, 0.15);
		color: var(--color-primary);
	}

	.line.removed {
		background: rgba(255, 107, 107, 0.15);
		color: #ff6b6b;
		text-decoration: line-through;
		text-decoration-color: rgba(255, 107, 107, 0.5);
	}

	.line.context {
		color: var(--color-text-soft);
	}
</style>
