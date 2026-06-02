<script lang="ts">
import { onMount } from 'svelte';

type NatoEntry = {
	letter: string;
	word: string;
};

type RoundHistoryLetter = {
	letter: string;
	correct: boolean;
};

type RoundHistoryEntry = {
	roundNumber: number;
	letters: RoundHistoryLetter[];
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

const minWordsAllowed = 1;
const maxWordsAllowed = 10;
const defaultMinWordsPerRound = 3;
const defaultMaxWordsPerRound = 5;
const speechLanguageOptions = [
	{ value: 'nb-NO', label: 'Norsk bokmål (nb-NO)' },
	{ value: 'nn-NO', label: 'Norsk nynorsk (nn-NO)' },
	{ value: 'en-US', label: 'Engelsk (USA) (en-US)' },
	{ value: 'en-GB', label: 'Engelsk (Storbritannia) (en-GB)' },
] as const;

let round = $state<NatoEntry[]>([]);
let answer = $state('');
let feedback = $state('');
let roundNumber = $state(0);
let roundAnswered = $state(false);
let gameStarted = $state(false);
let submittedAnswer = $state('');
let revealWords = $state(false);
let speaking = $state(false);
let speechSupported = $state(false);
let voices = $state<SpeechSynthesisVoice[]>([]);
let speechLanguage = $state<(typeof speechLanguageOptions)[number]['value']>('nb-NO');
let minWordsPerRound = $state(defaultMinWordsPerRound);
let maxWordsPerRound = $state(defaultMaxWordsPerRound);
let roundHistory = $state<RoundHistoryEntry[]>([]);
let nextRoundButton = $state<HTMLButtonElement | null>(null);
let answerInput = $state<HTMLInputElement | null>(null);

const roundWords = $derived(round.map((entry) => entry.word).join(' '));
const expectedAnswer = $derived(round.map((entry) => entry.letter).join(''));
const answerBreakdown = $derived(
	round.map((entry, index) => {
		const userLetter = submittedAnswer[index] ?? '∅';
		return {
			word: entry.word,
			expected: entry.letter,
			user: userLetter,
			correct: userLetter === entry.letter,
		};
	}),
);
const totalLettersAttempted = $derived(
	roundHistory.reduce((sum, historyEntry) => sum + historyEntry.letters.length, 0),
);
const totalCorrectLetters = $derived(
	roundHistory.reduce(
		(sum, historyEntry) => sum + historyEntry.letters.filter((letter) => letter.correct).length,
		0,
	),
);
const overallPercent = $derived(
	totalLettersAttempted === 0 ? 0 : Math.round((totalCorrectLetters / totalLettersAttempted) * 100),
);
const minWordOptions = $derived(
	Array.from(
		{ length: maxWordsPerRound - minWordsAllowed + 1 },
		(_, index) => minWordsAllowed + index,
	),
);
const maxWordOptions = $derived(
	Array.from(
		{ length: maxWordsAllowed - minWordsPerRound + 1 },
		(_, index) => minWordsPerRound + index,
	),
);

const randomEntries = (count: number): NatoEntry[] =>
	Array.from(
		{ length: count },
		() => alphabet[Math.floor(Math.random() * alphabet.length)] ?? alphabet[0],
	);

const clampWordCount = (value: number, fallback: number): number => {
	const safeValue = Number.isFinite(value) ? Math.round(value) : fallback;
	return Math.min(maxWordsAllowed, Math.max(minWordsAllowed, safeValue));
};

const sanitizeWordSettings = () => {
	const normalizedMin = clampWordCount(minWordsPerRound, defaultMinWordsPerRound);
	const normalizedMax = clampWordCount(maxWordsPerRound, defaultMaxWordsPerRound);
	minWordsPerRound = Math.min(normalizedMin, normalizedMax);
	maxWordsPerRound = Math.max(normalizedMin, normalizedMax);
};

const getWordsPerRound = () => {
	sanitizeWordSettings();
	return minWordsPerRound + Math.floor(Math.random() * (maxWordsPerRound - minWordsPerRound + 1));
};

const countCorrectLetters = (letters: RoundHistoryLetter[]) =>
	letters.reduce((sum, letter) => sum + Number(letter.correct), 0);

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
	utterance.lang = speechLanguage;

	const selectedLanguagePrefix = speechLanguage.split('-')[0]?.toLowerCase() ?? '';
	const matchingVoice =
		voices.find((voice) => voice.lang.toLowerCase() === speechLanguage.toLowerCase()) ??
		voices.find((voice) => voice.lang.toLowerCase().startsWith(`${selectedLanguagePrefix}-`)) ??
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
	round = randomEntries(getWordsPerRound());
	answer = '';
	submittedAnswer = '';
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
	sanitizeWordSettings();
	roundHistory = [];
	gameStarted = true;
	startRound({ autoSpeak: true });
};

const submitAnswer = () => {
	if (round.length === 0 || roundAnswered) return;

	const normalized = answer.toUpperCase().replace(/[^A-Z]/g, '');
	const currentRoundLetters = round.map((entry, index) => {
		const userLetter = normalized[index] ?? '∅';
		return {
			letter: userLetter,
			correct: userLetter === entry.letter,
		};
	});

	submittedAnswer = normalized;
	roundHistory = [{ roundNumber, letters: currentRoundLetters }, ...roundHistory];
	roundAnswered = true;
	revealWords = true;

	const correctLetters = countCorrectLetters(currentRoundLetters);
	if (correctLetters === round.length) {
		feedback = `Riktig! ${roundWords} = ${expectedAnswer}.`;
		return;
	}

	feedback = `${correctLetters}/${round.length} riktige. Riktig svar er ${expectedAnswer} (${roundWords}).`;
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
		Øv deg på det fonetiske alfabetet ved å høre ord (for eksempel <code>alfa</code> og <code>bravo</code>) og skriv riktige bokstaver.
	</p>
</section>

<section class="terminal-panel game">
	{#if !gameStarted}
		<p class="prompt">$ play --start</p>
		<p class="description">Trykk start for å begynne. Ordene leses opp automatisk i hver runde.</p>
		<div class="round-settings">
			<p class="settings-title">Antall ord per oppgave</p>
			<div class="settings-grid">
				<label for="min-words">
					Min
					<select id="min-words" bind:value={minWordsPerRound}>
						{#each minWordOptions as option}
							<option value={option}>{option}</option>
						{/each}
					</select>
				</label>
				<label for="max-words">
					Maks
					<select id="max-words" bind:value={maxWordsPerRound}>
						{#each maxWordOptions as option}
							<option value={option}>{option}</option>
						{/each}
					</select>
				</label>
			</div>
			<p class="settings-hint">Velg mellom {minWordsAllowed} og {maxWordsAllowed}. Standard er 3–5.</p>
		</div>
		<div class="actions">
			<button type="button" onclick={startGame}>Start spill</button>
		</div>
	{:else}
		<div class="game-layout">
			<div class="game-main">
				<p class="prompt">$ play --round {roundNumber}</p>

				<div class="voice-settings">
					<label for="speech-language">Språk for opplesning</label>
					<select id="speech-language" bind:value={speechLanguage} disabled={!speechSupported || speaking}>
						{#each speechLanguageOptions as option}
							<option value={option.value}>{option.label}</option>
						{/each}
					</select>
				</div>

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
					<p class="round-words" aria-label="Ord i runden">
						{#each answerBreakdown as item}
							<span class={`round-word ${roundAnswered ? (item.correct ? 'correct' : 'wrong') : ''}`}>
								{item.word}
							</span>
						{/each}
					</p>
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
			</div>

			<aside class="history-panel" aria-label="Rundehistorikk">
				<h2>Runder</h2>
				<p class="history-summary">
					Oppsummering: {totalCorrectLetters}/{totalLettersAttempted} riktige bokstaver ({overallPercent}%)
				</p>
				{#if roundHistory.length === 0}
					<p class="history-empty">Ingen runder enda.</p>
				{:else}
					<div class="history-list">
						{#each roundHistory as historyEntry}
							<div class="history-item">
								<p class="history-round">
									Runde {historyEntry.roundNumber} — {countCorrectLetters(historyEntry.letters)}/{
										historyEntry.letters.length
									}
								</p>
								<div class="history-letters">
									{#each historyEntry.letters as historyLetter}
										<span class={`submitted-letter ${historyLetter.correct ? 'correct' : 'wrong'}`}>
											{historyLetter.letter}
										</span>
									{/each}
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</aside>
		</div>
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

	.game-layout {
		display: grid;
		gap: 1rem;
		grid-template-columns: minmax(0, 1fr) minmax(14rem, 18rem);
		align-items: start;
	}

	.game-main {
		display: grid;
		gap: 0.85rem;
	}

	.history-panel {
		display: grid;
		gap: 0.6rem;
		padding: 0.7rem;
		border: 1px solid var(--color-border);
		border-radius: 0.45rem;
		background: var(--color-surface-alt);
	}

	.history-panel h2 {
		margin: 0;
		font-size: 1rem;
		color: var(--color-text-soft);
	}

	.history-empty {
		color: var(--color-text-soft);
		font-size: 0.9rem;
	}

	.history-summary {
		color: var(--color-primary);
		font-size: 0.9rem;
	}

	.history-list {
		display: grid;
		gap: 0.55rem;
	}

	.history-item {
		display: grid;
		gap: 0.35rem;
		padding: 0.5rem;
		border: 1px solid var(--color-border);
		border-radius: 0.4rem;
	}

	.history-round {
		color: var(--color-text-soft);
		font-size: 0.85rem;
	}

	.history-letters {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
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

	.voice-settings {
		display: grid;
		gap: 0.45rem;
		max-width: 24rem;
	}

	.voice-settings label {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	.round-settings {
		display: grid;
		gap: 0.45rem;
		max-width: 24rem;
	}

	.settings-title {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	.settings-grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 0.6rem;
	}

	.settings-grid label {
		display: grid;
		gap: 0.3rem;
		color: var(--color-text-soft);
		font-size: 0.9rem;
	}

	.settings-hint {
		color: var(--color-text-soft);
		font-size: 0.85rem;
	}

	select,
	input {
		border: 1px solid var(--color-border-strong);
		background: var(--color-surface-alt);
		color: var(--color-text);
		padding: 0.5rem 0.65rem;
		border-radius: 0.45rem;
		font: inherit;
	}

	select:focus-visible,
	input:focus-visible {
		outline: none;
		border-color: var(--color-secondary);
	}

	.round-words {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		padding: 0.55rem 0.7rem;
		border: 1px dashed var(--color-border-strong);
		border-radius: 0.45rem;
		color: var(--color-secondary);
		background: color-mix(in oklab, var(--color-secondary) 8%, transparent);
	}

	.round-word {
		padding: 0.15rem 0.35rem;
		border-radius: 0.35rem;
	}

	.round-word.correct {
		color: var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 14%, transparent);
	}

	.round-word.wrong {
		color: #ff8a80;
		background: color-mix(in oklab, #ff8a80 14%, transparent);
	}

	.submitted-letter {
		padding: 0.15rem 0.4rem;
		border: 1px solid var(--color-border);
		border-radius: 0.35rem;
		min-width: 1.75rem;
		text-align: center;
	}

	.submitted-letter.correct {
		color: var(--color-primary);
		border-color: color-mix(in oklab, var(--color-primary) 55%, var(--color-border));
		background: color-mix(in oklab, var(--color-primary) 14%, transparent);
	}

	.submitted-letter.wrong {
		color: #ff8a80;
		border-color: color-mix(in oklab, #ff8a80 65%, var(--color-border));
		background: color-mix(in oklab, #ff8a80 14%, transparent);
	}

	.feedback {
		color: var(--color-text-soft);
	}

	@media (max-width: 900px) {
		.game-layout {
			grid-template-columns: minmax(0, 1fr);
		}
	}
</style>
