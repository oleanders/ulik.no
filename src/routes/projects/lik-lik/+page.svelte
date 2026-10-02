<script lang="ts">
import { onMount } from 'svelte';
import {
	contextOpacity,
	type IllusionId,
	INITIAL_STRENGTH,
	illusions,
	lineEndpoints,
	surroundingCircles,
	TARGET_COLOR,
	TARGET_LENGTH,
	TARGET_RADIUS,
} from './illusions';

let ready = $state(false);
let selected = $state<IllusionId>('farge');
let revealed = $state(false);
let strength = $state(INITIAL_STRENGTH);
const current = $derived(illusions.find((illusion) => illusion.id === selected) ?? illusions[0]);
const opacity = $derived(contextOpacity(strength, revealed));
const endpoints = lineEndpoints();
const circlesA = surroundingCircles(180, 43, 89);
const circlesB = surroundingCircles(540, 13, 48);

onMount(() => {
	ready = true;
});

function reset() {
	revealed = false;
	strength = INITIAL_STRENGTH;
}

function select(id: IllusionId) {
	selected = id;
	reset();
}
</script>

<svelte:head><title>lik≠lik — ≠ ulik.no</title></svelte:head>

<section class="terminal-panel experiment" aria-labelledby="illusion-title">
	<div class="heading">
		<div><p class="prompt">$ ./lik --se-en-gang-til</p><h1 id="illusion-title">lik≠lik</h1></div>
		<p>Det du ser <span aria-hidden="true">≠</span> det du måler.</p>
	</div>
	<div class="choices" role="group" aria-label="Velg illusjon">
		{#each illusions as illusion, i}
			<button type="button" disabled={!ready} aria-pressed={selected === illusion.id} onclick={() => select(illusion.id)}><span>0{i + 1}</span> {illusion.title}</button>
		{/each}
	</div>
	<div class="question"><h2>{current.question}</h2><span>{illusions.findIndex((illusion) => illusion.id === selected) + 1} / {illusions.length}</span></div>
	<div class="stage">
		<svg viewBox="0 0 720 310" role="img" aria-labelledby="scene-title scene-description">
			<title id="scene-title">{current.question}</title>
			<desc id="scene-description">{selected === 'farge' ? 'To like fargefelt på ulik bakgrunn.' : selected === 'sirkler' ? 'To like midtsirkler, omgitt av store og små sirkler.' : 'To like vannrette linjer med vinkler i ulike retninger ved endene.'} Bruk kontrollene under bildet for å fjerne omgivelsene og vise målene.</desc>
			{#if selected === 'farge'}
				<g opacity={opacity} data-testid="context">
					<rect width="360" height="260" fill="#101612" />
					<rect x="360" width="360" height="260" fill="#e2e8e4" />
				</g>
				{#each [180, 540] as x}
					<rect data-testid="color-target" x={x - 48} y="82" width="96" height="96" fill={TARGET_COLOR} />
				{/each}
				<text x="180" y="292">A</text><text x="540" y="292">B</text>
			{:else if selected === 'sirkler'}
				<g opacity={opacity} data-testid="context" fill="#427167">
					{#each [...circlesA, ...circlesB] as circle}<circle cx={circle.x} cy={circle.y} r={circle.radius} />{/each}
				</g>
				{#each [180, 540] as x}<circle data-testid="circle-target" cx={x} cy="135" r={TARGET_RADIUS} fill="#ffc879" />{/each}
				{#if revealed}<path class="measure" d={`M152 175 H208 M152 167 V183 M208 167 V183 M512 175 H568 M512 167 V183 M568 167 V183`} />{/if}
				<text x="180" y="292">A</text><text x="540" y="292">B</text>
			{:else}
				<g opacity={opacity} data-testid="context" stroke="#86c6b4" stroke-width="5" fill="none" stroke-linecap="butt">
					<path d="M264 45 L220 90 L264 135 M456 45 L500 90 L456 135" />
					<path d="M176 175 L220 220 L176 265 M544 175 L500 220 L544 265" />
				</g>
				{#each [90, 220] as y}<line data-testid="line-target" x1={endpoints.x1} x2={endpoints.x2} y1={y} y2={y} stroke="#ffc879" stroke-width="5" />{/each}
				<text x="105" y="98">A</text><text x="105" y="228">B</text>
				{#if revealed}<path class="measure" d="M220 50 V260 M500 50 V260 M220 155 H500" />{/if}
			{/if}
		</svg>
	</div>
	<div class="controls">
		<button class="reveal" type="button" disabled={!ready} aria-pressed={revealed} onclick={() => { revealed = !revealed; }}>{revealed ? 'Vis illusjonen igjen' : 'Avslør likheten'}</button>
		<button type="button" disabled={!ready} onclick={reset}>Nullstill</button>
		<div class="slider">
			<label for="context-strength">Omgivelser <output for="context-strength">{revealed ? 0 : strength}%</output></label>
			<input id="context-strength" type="range" min="0" max="100" step="1" value={revealed ? 0 : strength} oninput={(event) => { strength = event.currentTarget.valueAsNumber; }} disabled={!ready || revealed} aria-describedby="slider-help" />
			<span id="slider-help">Dra mot 0 for å se uten omgivelsene.</span>
		</div>
	</div>
	<div class="answer" aria-live="polite" aria-atomic="true">
		{#if revealed}
			<strong>A = B. Helt likt.</strong>
			<p>{selected === 'farge' ? `Begge feltene: ${TARGET_COLOR}.` : selected === 'sirkler' ? `Begge midtsirklene: radius ${TARGET_RADIUS} i tegningen.` : `Begge strekene: ${TARGET_LENGTH} enheter i tegningen.`}</p>
			<p>{current.explanation}</p>
		{:else}
			<strong>Stol på øynene. Så sjekker du.</strong>
			<p>Trykk «Avslør likheten», eller dra ned omgivelsene. Selve feltene, sirklene og strekene endres ikke.</p>
		{/if}
	</div>
	<div class="bottom"><a href={current.source} target="_blank" rel="noreferrer">Les om fenomenet ↗<span class="sr-only">: {current.sourceLabel} (åpnes i ny fane)</span></a><p>Opplevelsen kan variere fra person til person. Ingen fasit på hva du ser.</p></div>
	<noscript><p>Slå på JavaScript for å bruke kontrollene. I tegningen over er begge feltene {TARGET_COLOR}.</p></noscript>
</section>

<style>
	.experiment {
		display: grid;
		gap: 1.2rem;
	}

	.heading, .question, .bottom {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.heading .prompt {
		font-size: 0.75rem;
	}

	h1 {
		margin: 0.6rem 0 0;
		font-size: clamp(2rem, 6vw, 3.5rem);
	}

	.heading > p {
		font-size: 0.85rem;
		color: var(--color-text-soft);
	}

	.heading > p span {
		color: var(--color-primary);
	}

	.choices {
		display: flex;
		flex-wrap: wrap;
		gap: 0.6rem;
	}

	button {
		min-height: 44px;
		padding: 0.7rem 1rem;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.4rem;
		background: var(--color-surface-alt);
		color: var(--color-text);
		font-size: 0.8rem;
		cursor: pointer;
	}

	button:hover {
		border-color: var(--color-secondary);
	}

	button:disabled {
		opacity: 0.55;
		cursor: default;
	}

	.choices button[aria-pressed='true'] {
		border-color: var(--color-primary);
		color: var(--color-primary);
		background: #0a251a;
	}

	.choices span {
		color: var(--color-text-soft);
		font-size: 0.7rem;
		margin-right: 0.4rem;
	}

	.question h2 {
		font-size: clamp(1rem, 2.5vw, 1.35rem);
		margin: 0;
		line-height: 1.5;
	}

	.question > span {
		font-size: 0.75rem;
		color: var(--color-text-soft);
	}

	.stage {
		overflow: hidden;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.65rem;
		background: #171e1a;
	}

	svg {
		display: block;
		width: 100%;
		height: auto;
	}

	svg text {
		fill: #e0e0e0;
		font: 22px monospace;
		text-anchor: middle;
	}

	.measure {
		fill: none;
		stroke: #00ccff;
		stroke-width: 2;
		stroke-dasharray: 5 5;
	}

	.controls {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.7rem;
	}

	.reveal {
		background: var(--color-primary);
		color: #052116;
		border-color: var(--color-primary);
		font-weight: 700;
	}

	.reveal:hover {
		background: var(--color-secondary);
	}

	.slider {
		display: grid;
		gap: 0.35rem;
		margin-left: auto;
		min-width: min(100%, 260px);
	}

	label {
		display: flex;
		justify-content: space-between;
		gap: 1rem;
		font-size: 0.8rem;
	}

	output {
		color: var(--color-secondary);
	}

	input {
		width: 100%;
		height: 24px;
		margin: 0;
		accent-color: var(--color-primary);
	}

	#slider-help {
		font-size: 0.7rem;
		color: var(--color-text-soft);
	}

	button:focus-visible, input:focus-visible, a:focus-visible {
		outline: 2px solid var(--color-secondary);
		outline-offset: 4px;
	}

	.answer {
		padding: 1.2rem;
		border-left: 2px solid var(--color-primary);
		background: #101713;
		line-height: 1.7;
	}

	.answer strong {
		font-size: 0.95rem;
	}

	p {
		margin: 0;
	}

	.answer p {
		margin-top: 0.5rem;
		max-width: 80ch;
		color: var(--color-text-soft);
		font-size: 0.85rem;
	}

	.bottom {
		align-items: start;
		font-size: 0.7rem;
		line-height: 1.7;
	}

	.bottom p {
		max-width: 55ch;
		color: var(--color-text-soft);
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip-path: inset(50%);
		white-space: nowrap;
		border: 0;
	}

	@media (max-width: 640px) {
		.slider {
			margin-left: 0;
			width: 100%;
			margin-top: 0.5rem;
		}

		.choices {
			display: grid;
			grid-template-columns: repeat(3, minmax(0, 1fr));
		}

		.choices button {
			padding: 0.65rem 0.4rem;
			font-size: 0.72rem;
		}

		.choices span {
			display: block;
			margin: 0 0 0.35rem;
		}

	}
</style>
