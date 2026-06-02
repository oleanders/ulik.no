<script lang="ts">
import { onMount } from 'svelte';

type NatoEntry = {
	letter: string;
	word: string;
};

const alphabet: NatoEntry[] = [
	{ letter: 'A', word: 'Alfa' },
	{ letter: 'B', word: 'Bravo' },
	{ letter: 'C', word: 'Charlie' },
	{ letter: 'D', word: 'Delta' },
	{ letter: 'E', word: 'Echo' },
	{ letter: 'F', word: 'Foxtrot' },
	{ letter: 'G', word: 'Golf' },
	{ letter: 'H', word: 'Hotel' },
	{ letter: 'I', word: 'India' },
	{ letter: 'J', word: 'Juliett' },
	{ letter: 'K', word: 'Kilo' },
	{ letter: 'L', word: 'Lima' },
	{ letter: 'M', word: 'Mike' },
	{ letter: 'N', word: 'November' },
	{ letter: 'O', word: 'Oscar' },
	{ letter: 'P', word: 'Papa' },
	{ letter: 'Q', word: 'Quebec' },
	{ letter: 'R', word: 'Romeo' },
	{ letter: 'S', word: 'Sierra' },
	{ letter: 'T', word: 'Tango' },
	{ letter: 'U', word: 'Uniform' },
	{ letter: 'V', word: 'Victor' },
	{ letter: 'W', word: 'Whiskey' },
	{ letter: 'X', word: 'X-ray' },
	{ letter: 'Y', word: 'Yankee' },
	{ letter: 'Z', word: 'Zulu' },
];

const wordsPerRound = 3;

let round = $state<NatoEntry[]>([]);
let answer = $state('');
let feedback = $state('');
let points = $state(0);
let attempts = $state(0);
let roundNumber = $state(0);
let roundAnswered = $state(false);
let gameStarted = $state(false);
let revealWords = $state(false);
let speaking = $state(false);
let speechSupported = $state(false);
let voices = $state<SpeechSynthesisVoice[]>([]);
let nextRoundButton = $state<HTMLButtonElement | null>(null);
let answerInput = $state<HTMLInputElement | null>(null);

const roundWords = $derived(round.map((entry) => entry.word).join(' '));
const expectedAnswer = $derived(round.map((entry) => entry.letter).join(''));
const scorePercent = $derived(attempts === 0 ? 0 : Math.round((points / attempts) * 100));

const randomEntries = (count: number): NatoEntry[] =>
	Array.from(
		{ length: count },
		() => alphabet[Math.floor(Math.random() * alphabet.length)] ?? alphabet[0],
	);

const stopSpeaking = () => {
	if (!speechSupported) return;
	window.speechSynthesis.cancel();
	speaking = false;
};

const speakRound = () => {
	if (!speechSupported || round.length === 0) return;

	stopSpeaking();

	const utterance = new SpeechSynthesisUtterance(roundWords);
	utterance.rate = 0.85;
	utterance.pitch = 1;
	utterance.lang = 'nb-NO';

	const matchingVoice =
		voices.find((voice) => voice.lang.toLowerCase().startsWith('nb')) ??
		voices.find((voice) => voice.lang.toLowerCase().startsWith('no')) ??
		voices.find((voice) => voice.lang.toLowerCase().startsWith('en')) ??
		null;

	if (matchingVoice) {
		utterance.voice = matchingVoice;
	}

	utterance.onend = () => {
		speaking = false;
	};
	utterance.onerror = () => {
		speaking = false;
		feedback = 'Klarte ikke å spille av tale i nettleseren.';
	};

	speaking = true;
	window.speechSynthesis.speak(utterance);
};

const startRound = (options: { autoSpeak?: boolean } = {}) => {
	stopSpeaking();
	roundNumber += 1;
	round = randomEntries(wordsPerRound);
	answer = '';
	feedback = '';
	revealWords = false;
	roundAnswered = false;

	if (options.autoSpeak && speechSupported) {
		queueMicrotask(() => {
			speakRound();
		});
	}
};

const startGame = () => {
	gameStarted = true;
	startRound({ autoSpeak: true });
};

const submitAnswer = () => {
	if (round.length === 0 || roundAnswered) return;

	const normalized = answer.toUpperCase().replace(/[^A-Z]/g, '');
	attempts += 1;
	roundAnswered = true;
	revealWords = true;

	if (normalized === expectedAnswer) {
		points += 1;
		feedback = `Riktig! ${roundWords} = ${expectedAnswer}.`;
		return;
	}

	feedback = `Nesten. Riktig svar er ${expectedAnswer} (${roundWords}).`;
};

$effect(() => {
	if (roundAnswered && nextRoundButton) {
		nextRoundButton.focus();
	}
});

$effect(() => {
	if (gameStarted && !roundAnswered && answerInput) {
		answerInput.focus();
	}
});

onMount(() => {
	speechSupported = typeof window !== 'undefined' && 'speechSynthesis' in window;
	if (!speechSupported) {
		feedback = 'Nettleseren din støtter ikke taleavspilling via Speech Synthesis.';
		return;
	}

	const updateVoices = () => {
		voices = window.speechSynthesis.getVoices();
	};

	updateVoices();
	window.speechSynthesis.addEventListener('voiceschanged', updateVoices);

	return () => {
		window.speechSynthesis.removeEventListener('voiceschanged', updateVoices);
		stopSpeaking();
	};
});
</script>

<svelte:head>
	<title>fonetisk≠spill — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ ./fonetisk-spill --start</p>
	<div class="head-row">
		<h1>fonetisk≠spill</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="description">
		Hør ord i det fonetiske alfabetet (for eksempel <code>Alfa Bravo</code>) og skriv bokstavene.
	</p>
</section>

<section class="terminal-panel game">
	{#if !gameStarted}
		<p class="prompt">$ play --start</p>
		<p class="description">Trykk start for å begynne. Ordene leses opp automatisk i hver runde.</p>
		<div class="actions">
			<button type="button" onclick={startGame}>Start spill</button>
		</div>
	{:else}
		<p class="prompt">$ play --round {roundNumber}</p>

		<div class="actions">
			<button type="button" onclick={speakRound} disabled={!speechSupported || speaking}>
				{speaking ? 'Spiller av…' : 'Spill av ord igjen'}
			</button>
			<button
				bind:this={nextRoundButton}
				type="button"
				class="ghost"
				class:ready={roundAnswered}
				onclick={() => startRound({ autoSpeak: true })}
				disabled={!roundAnswered}>Neste runde</button
			>
			<button type="button" class="ghost" onclick={() => (revealWords = !revealWords)}>
				{revealWords ? 'Skjul ord' : 'Vis ord'}
			</button>
		</div>

		{#if revealWords}
			<p class="round-words">{roundWords}</p>
		{/if}

		<form
			class="answer-form"
			onsubmit={(event) => {
				event.preventDefault();
				submitAnswer();
			}}
		>
			<label for="answer">Hvilke bokstaver hørte du?</label>
			<input
				bind:this={answerInput}
				id="answer"
				type="text"
				bind:value={answer}
				placeholder="f.eks. AB"
				autocomplete="off"
				spellcheck="false"
				disabled={roundAnswered}
			/>
			<button type="submit" disabled={roundAnswered}>Sjekk svar</button>
		</form>

		<p class="score">Poeng: {points}/{attempts} ({scorePercent}%)</p>
	{/if}

	{#if feedback}
		<p class="feedback">{feedback}</p>
	{/if}
</section>

<style>
	.head,
		.game {
		display: grid;
		gap: 0.85rem;
	}

	.game {
		margin-top: 1rem;
	}

	h1,
	p {
		margin: 0;
	}

	.head-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	.description {
		max-width: 68ch;
		color: var(--color-text-soft);
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

	.actions {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}

	button {
		border: 1px solid var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 15%, transparent);
		color: var(--color-primary);
		padding: 0.45rem 0.75rem;
		border-radius: 0.45rem;
		font: inherit;
		cursor: pointer;
	}

	button.ghost {
		border-color: var(--color-text-soft);
		color: var(--color-text-soft);
		background: transparent;
	}

	button.ghost.ready {
		border-color: var(--color-primary);
		color: var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 16%, transparent);
		box-shadow: 0 0 12px color-mix(in oklab, var(--color-primary) 30%, transparent);
	}

	button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.answer-form {
		display: grid;
		gap: 0.45rem;
		max-width: 24rem;
	}

	.answer-form label {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	input {
		border: 1px solid var(--color-border-strong);
		background: var(--color-surface-alt);
		color: var(--color-text);
		padding: 0.5rem 0.65rem;
		border-radius: 0.45rem;
	}

	input:focus-visible {
		outline: none;
		border-color: var(--color-secondary);
	}

	.round-words {
		padding: 0.55rem 0.7rem;
		border: 1px dashed var(--color-border-strong);
		border-radius: 0.45rem;
		color: var(--color-secondary);
		background: color-mix(in oklab, var(--color-secondary) 8%, transparent);
	}

	.score {
		color: var(--color-primary);
	}

	.feedback {
		color: var(--color-text-soft);
	}
</style>
