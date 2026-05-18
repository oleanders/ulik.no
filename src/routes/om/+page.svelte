<svelte:head>
	<title>Om — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel about">
	<p class="prompt">$ cat ./om.txt</p>
	<h1>Om</h1>
	<p>
		Her samler jeg prototyper, verktøy og idéer som lukter litt kode, kanskje litt språkmodell og litt ren
		nysgjerrighet.
	</p>
	<p>
		Målet med ulik.no er å være et eksperimentrom for små prosjekter, AI-testing og ting som ikke
		passer inn andre steder.
	</p>
</section>

<style>
	.about {
		display: grid;
		gap: 1rem;
	}

	h1,
	p {
		margin: 0;
	}

	.about p {
		max-width: 65ch;
		color: var(--color-text-soft);
	}
</style>
