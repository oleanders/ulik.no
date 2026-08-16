<script lang="ts">
type Subpage = 'oversikt' | 'motta' | 'sende';
type Round = {
	subpage: Subpage;
	target: string;
	user: string;
	correct: boolean;
};

const MORSE: Record<string, string> = {
	A: '.-',
	B: '-...',
	C: '-.-.',
	D: '-..',
	E: '.',
	F: '..-.',
	G: '--.',
	H: '....',
	I: '..',
	J: '.---',
	K: '-.-',
	L: '.-..',
	M: '--',
	N: '-.',
	O: '---',
	P: '.--.',
	Q: '--.-',
	R: '.-.',
	S: '...',
	T: '-',
	U: '..-',
	V: '...-',
	W: '.--',
	X: '-..-',
	Y: '-.--',
	Z: '--..',
	1: '.----',
	2: '..---',
	3: '...--',
	4: '....-',
	5: '.....',
	6: '-....',
	7: '--...',
	8: '---..',
	9: '----.',
	0: '-----',
};

const REVERSE: Record<string, string> = Object.fromEntries(
	Object.entries(MORSE).map(([letter, code]) => [code, letter]),
);

const ALPHABET = Object.keys(MORSE);
const WPM_MIN = 5;
const WPM_MAX = 30;
const DOT_THRESHOLD_MS = 250;
const MIN_KEY_MS = 40;

let { subpage }: { subpage: Subpage } = $props();

let wpm = $state(15);
let target = $state('');
let receiveAnswer = $state('');
let sendBuffer = $state('');
let feedback = $state('');
let streak = $state(0);
let roundHistory = $state<Round[]>([]);
let audioContext = $state<AudioContext | null>(null);
let isPlaying = $state(false);
let lightOn = $state(false);
let playingLetter = $state('');
let keyPressedAt = $state<number | null>(null);
let showCode = $state(false);
let roundsStarted = $state(false);
let answered = $state(false);

const dotDuration = $derived(1200 / wpm);
const dashDuration = $derived(dotDuration * 3);
const symbolGap = $derived(dotDuration);

const totalRounds = $derived(roundHistory.length);
const totalCorrect = $derived(roundHistory.filter((round) => round.correct).length);
const accuracy = $derived(totalRounds === 0 ? 0 : Math.round((totalCorrect / totalRounds) * 100));
const currentMorse = $derived(MORSE[target] ?? '');
const decodedSend = $derived(REVERSE[sendBuffer] ?? null);

const formattedMorse = $derived(
	currentMorse
		.split('')
		.map((char) => (char === '.' ? '·' : '—'))
		.join(''),
);

const formattedBuffer = $derived(
	sendBuffer
		.split('')
		.map((char) => (char === '.' ? '·' : '—'))
		.join(''),
);

const formatMorseCode = (code: string) =>
	code
		.split('')
		.map((char) => (char === '.' ? '·' : '—'))
		.join('');

const pickTarget = () => ALPHABET[Math.floor(Math.random() * ALPHABET.length)] ?? 'A';

const initAudio = () => {
	if (audioContext) return;
	audioContext = new AudioContext();
};

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const beep = async (ms: number) => {
	const ctx = audioContext;
	if (!ctx) return;

	if (ctx.state === 'suspended') {
		await ctx.resume();
	}

	const osc = ctx.createOscillator();
	const gain = ctx.createGain();
	osc.type = 'sine';
	osc.frequency.value = 700;
	gain.gain.setValueAtTime(0.0001, ctx.currentTime);
	gain.gain.exponentialRampToValueAtTime(0.15, ctx.currentTime + 0.01);
	gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + ms / 1000);
	osc.connect(gain);
	gain.connect(ctx.destination);
	osc.start();
	osc.stop(ctx.currentTime + ms / 1000);
	await wait(ms);
};

const playMorse = async (code: string) => {
	if (!audioContext) initAudio();
	if (isPlaying) return;

	isPlaying = true;
	for (let index = 0; index < code.length; index++) {
		const symbol = code[index];
		if (!symbol) continue;
		const duration = symbol === '-' ? dashDuration : dotDuration;
		lightOn = true;
		await beep(duration);
		lightOn = false;
		await wait(symbolGap);
	}
	isPlaying = false;
};

const playLetter = async (letter: string) => {
	if (isPlaying) return;
	playingLetter = letter;
	await playMorse(MORSE[letter] ?? '');
	playingLetter = '';
};

const handleOverviewKey = (event: KeyboardEvent) => {
	if (subpage !== 'oversikt' || isPlaying) return;

	const key = event.key.length === 1 ? event.key.toUpperCase() : event.key;
	if (MORSE[key]) {
		event.preventDefault();
		playLetter(key);
	}
};

const startRound = async () => {
	target = pickTarget();
	receiveAnswer = '';
	sendBuffer = '';
	feedback = '';
	answered = false;
	roundsStarted = true;

	if (subpage === 'motta') {
		await playMorse(currentMorse);
	}
};

const submitReceive = () => {
	const normalized = receiveAnswer.toUpperCase().trim();
	const correct = normalized === target;
	roundHistory = [{ subpage, target, user: normalized || '∅', correct }, ...roundHistory];
	streak = correct ? streak + 1 : 0;
	answered = true;
	feedback = correct
		? `Riktig! ${target} er ${formattedMorse}.`
		: `Det var ${target} (${formattedMorse}). Du svarte ${normalized || '∅'}.`;
};

const submitSend = () => {
	const decoded = decodedSend;
	const correct = decoded === target;
	roundHistory = [{ subpage, target, user: decoded ?? sendBuffer, correct }, ...roundHistory];
	streak = correct ? streak + 1 : 0;
	answered = true;

	if (correct) {
		feedback = `Riktig! ${formattedMorse} = ${target}.`;
		return;
	}

	if (decoded) {
		feedback = `Du sendte ${formattedBuffer} = ${decoded}, men det skulle være ${formattedMorse} = ${target}.`;
		return;
	}

	feedback = `${formattedBuffer} er ikke en gyldig morsekode. Riktig svar er ${formattedMorse} = ${target}.`;
};

const pressKey = () => {
	if (!audioContext) initAudio();
	keyPressedAt = performance.now();
};

const releaseKey = () => {
	if (keyPressedAt === null) return;
	const duration = performance.now() - keyPressedAt;
	keyPressedAt = null;
	if (duration < MIN_KEY_MS) return;
	const symbol = duration < DOT_THRESHOLD_MS ? '.' : '-';
	sendBuffer += symbol;
};

const addDot = () => {
	if (!audioContext) initAudio();
	sendBuffer += '.';
};

const addDash = () => {
	if (!audioContext) initAudio();
	sendBuffer += '-';
};

const backspace = () => {
	sendBuffer = sendBuffer.slice(0, -1);
};

const clearBuffer = () => {
	sendBuffer = '';
};

const handleKeyDown = (event: KeyboardEvent) => {
	if (event.repeat) return;
	if (event.code === 'Space') {
		event.preventDefault();
		pressKey();
	}
};

const handleKeyUp = (event: KeyboardEvent) => {
	if (event.code === 'Space') {
		event.preventDefault();
		releaseKey();
	}
};
</script>

<svelte:head>
	<title>morse≠kode — ≠ ulik.no</title>
</svelte:head>

<svelte:window onkeydown={handleOverviewKey} />

<section class="terminal-panel head">
	<p class="prompt">$ ./morse --subpage {subpage}</p>
	<div class="head-row">
		<h1>morse≠kode</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="desc">
		Øv deg på å sende og motta morsekode. Trykk start, lytt, se lyset og bruk mellomromstasten som
		nøkkel.
	</p>
	<div class="subpage-group" role="group" aria-label="Velg modus">
		<a class:active={subpage === 'oversikt'} aria-current={subpage === 'oversikt' ? 'page' : undefined} href="/projects/morsekode/oversikt">
			oversikt
		</a>
		<a class:active={subpage === 'motta'} aria-current={subpage === 'motta' ? 'page' : undefined} href="/projects/morsekode/motta">
			motta
		</a>
		<a class:active={subpage === 'sende'} aria-current={subpage === 'sende' ? 'page' : undefined} href="/projects/morsekode/sende">
			sende
		</a>
	</div>
</section>

<section class="terminal-panel game" aria-label="Morsekode-øving">
	<div class="settings">
		<label for="wpm">Hastighet (ord per minutt)</label>
		<input id="wpm" type="range" min={WPM_MIN} max={WPM_MAX} bind:value={wpm} />
		<span class="wpm-value">{wpm} WPM</span>
	</div>

	{#if subpage === 'oversikt'}
		<p class="hint">Trykk på en bokstav, eller trykk samme bokstav på tastaturet, for å høre og se koden.</p>
		<div class="letter-grid">
			{#each ALPHABET as letter}
				<button
					type="button"
					class="letter-tile {playingLetter === letter ? 'playing' : ''}"
					onclick={() => playLetter(letter)}
					disabled={isPlaying}
					aria-label="{letter}: {formatMorseCode(MORSE[letter] ?? '')}"
				>
					<span class="letter-tile-char">{letter}</span>
					<span class="letter-tile-morse">{formatMorseCode(MORSE[letter] ?? '')}</span>
				</button>
			{/each}
		</div>
		<div class="signal-preview">
			<button
				type="button"
				class="signal-light {lightOn ? 'active' : ''}"
				disabled
				aria-label="Forhåndsvisning av blink"
			>
				<span class="light-core"></span>
				<span class="light-glow"></span>
			</button>
		</div>
	{:else if !roundsStarted}
		<div class="start-area">
			<p class="hint">Trykk start for å få en bokstav eller et tall.</p>
			<button type="button" class="primary" onclick={() => startRound()}>Start øving</button>
		</div>
	{:else}
		<div class="target-area">
			<span class="target-label">{subpage === 'motta' ? 'Hva hører du?' : 'Send denne koden'}</span>
			<div class="target-card">
				{#if subpage === 'sende'}
					<span class="target-letter" aria-label="Målbokstav">{target}</span>
					<button type="button" class="small" onclick={() => (showCode = !showCode)}>
						{showCode ? 'skjul kode' : 'vis kode'}
					</button>
					{#if showCode}
						<p class="morse-hint">{formattedMorse}</p>
					{/if}
				{:else}
					<button
						type="button"
						class="signal-light {lightOn ? 'active' : ''}"
						aria-label="Spill av morsekode"
						onclick={() => playMorse(currentMorse)}
						disabled={isPlaying}
					>
						<span class="light-core"></span>
						<span class="light-glow"></span>
					</button>
					<button
						type="button"
						class="small"
						onclick={() => playMorse(currentMorse)}
						disabled={isPlaying}
					>
						{isPlaying ? 'spiller…' : 'spill av igjen'}
					</button>
					<button type="button" class="small" onclick={() => (showCode = !showCode)}>
						{showCode ? 'skjul kode' : 'vis kode'}
					</button>
					{#if showCode}
						<p class="morse-hint">{formattedMorse}</p>
					{/if}
				{/if}
			</div>
		</div>

		{#if answered}
			<div class="form-actions">
				<button type="button" class="primary" onclick={() => startRound()}>Neste runde</button>
			</div>
		{:else if subpage === 'motta'}
			<form
				class="answer-form"
				class:answered
				onsubmit={(event) => {
					event.preventDefault();
					submitReceive();
				}}
			>
				<label for="receive-answer">Bokstav eller tall</label>
				<input
					id="receive-answer"
					type="text"
					bind:value={receiveAnswer}
					placeholder="f.eks. A"
					maxlength="1"
					autocomplete="off"
					spellcheck="false"
				/>
				<div class="form-actions">
					<button type="submit">Sjekk svar</button>
				</div>
			</form>
		{:else}
			<div
				class="key-area"
				role="button"
				tabindex="0"
				aria-label="Morsenøkkel. Hold for prikk eller strek."
				onmousedown={pressKey}
				onmouseup={releaseKey}
				onmouseleave={() => {
					if (keyPressedAt !== null) releaseKey();
				}}
				onblur={() => {
					if (keyPressedAt !== null) releaseKey();
				}}
				onkeydown={handleKeyDown}
				onkeyup={handleKeyUp}
			>
				<span class="key-label">Trykk og hold</span>
				<span class="key-hint">kort = prikk, lang = strek</span>
			</div>

			<div class="manual-controls">
				<button type="button" onclick={addDot} aria-label="Legg til prikk">·</button>
				<button type="button" onclick={addDash} aria-label="Legg til strek">—</button>
				<button type="button" class="ghost" onclick={backspace}>slett</button>
				<button type="button" class="ghost" onclick={clearBuffer}>tøm</button>
			</div>

			<div class="send-buffer" aria-live="polite">
				{#if sendBuffer}
					<span class="buffer-chars">{formattedBuffer}</span>
					<span class="buffer-guess">{decodedSend ? `= ${decodedSend}` : '…'}</span>
				{:else}
					<span class="buffer-empty">trykk nøkkelen for å sende</span>
				{/if}
			</div>

			<div class="form-actions">
				<button type="button" class="primary" onclick={submitSend} disabled={sendBuffer.length === 0}>
					Sjekk sending
				</button>
			</div>
		{/if}

		{#if feedback}
			<p class="feedback">{feedback}</p>
		{/if}

		<div class="stats">
			<span class="stat">riktige: {totalCorrect}/{totalRounds}</span>
			<span class="stat">presisjon: {accuracy}%</span>
			<span class="stat">streak: {streak}</span>
		</div>
	{/if}
</section>

<section class="terminal-panel history" aria-label="Rundehistorikk">
	<p class="prompt">$ cat ./morse.log</p>
	<h2>Siste runder</h2>
	{#if roundHistory.length === 0}
		<p class="empty">Ingen runder enda. Kom igjen!</p>
	{:else}
		<ul class="history-list">
			{#each roundHistory as round}
				<li class="history-item {round.correct ? 'correct' : 'wrong'}">
					<span class="history-subpage">{round.subpage}</span>
					<span class="history-target">{round.target}</span>
					<span class="history-answer">{round.user}</span>
					<span class="history-result">{round.correct ? '✓' : '✕'}</span>
				</li>
			{/each}
		</ul>
	{/if}
</section>

<style>
	.head {
		display: grid;
		gap: 0.75rem;
		margin-bottom: 1rem;
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

	.status {
		padding: 0.25rem 0.55rem;
		border-radius: 999px;
		border: 1px solid currentColor;
		font-size: 0.8rem;
		color: var(--color-primary);
	}

	.desc {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.subpage-group {
		display: inline-flex;
		gap: 0;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		overflow: hidden;
		width: fit-content;
	}

	.subpage-group a {
		border: none;
		border-radius: 0;
		background: transparent;
		color: var(--color-text-soft);
		padding: 0.45rem 1rem;
		font: inherit;
		cursor: pointer;
	}

	.subpage-group a.active {
		background: var(--color-surface);
		color: var(--color-primary);
	}

	button {
		font: inherit;
		padding: 0.45rem 0.85rem;
		background: color-mix(in oklab, var(--color-primary) 15%, transparent);
		color: var(--color-primary);
		border: 1px solid var(--color-primary);
		border-radius: 0.45rem;
		cursor: pointer;
	}

	button.ghost {
		background: transparent;
		color: var(--color-text-soft);
		border-color: var(--color-text-soft);
	}

	button.primary {
		background: color-mix(in oklab, var(--color-primary) 22%, transparent);
		font-weight: 700;
	}

	button.small {
		padding: 0.3rem 0.6rem;
		font-size: 0.85rem;
	}

	button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.game {
		display: grid;
		gap: 1rem;
	}

	.settings {
		display: grid;
		gap: 0.35rem;
		max-width: 20rem;
	}

	.settings label {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	.wpm-value {
		color: var(--color-primary);
		font-size: 0.9rem;
	}

	input[type='range'] {
		width: 100%;
		accent-color: var(--color-primary);
	}

	.start-area {
		display: grid;
		gap: 0.75rem;
		place-items: start;
	}

	.hint {
		color: var(--color-text-soft);
	}

	.target-area {
		display: grid;
		gap: 0.5rem;
	}

	.target-label {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	.target-card {
		display: grid;
		gap: 0.75rem;
		place-items: center;
		padding: 1.5rem;
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		background: var(--color-surface-alt);
	}

	.target-letter {
		font-size: 5rem;
		font-weight: 800;
		color: var(--color-secondary);
		line-height: 1;
		text-shadow: 0 0 24px color-mix(in srgb, var(--color-secondary) 40%, transparent);
	}

	.morse-hint {
		font-size: 2rem;
		color: var(--color-primary);
		letter-spacing: 0.25em;
		margin: 0;
	}

	.signal-light {
		position: relative;
		width: 5rem;
		height: 5rem;
		border-radius: 50%;
		border: 2px solid var(--color-border-strong);
		background: var(--color-surface);
		display: grid;
		place-items: center;
		cursor: pointer;
		padding: 0;
	}

	.light-core {
		width: 2.5rem;
		height: 2.5rem;
		border-radius: 50%;
		background: var(--color-text-muted);
		transition:
			background 60ms ease,
			box-shadow 60ms ease;
	}

	.light-glow {
		position: absolute;
		inset: -20%;
		border-radius: 50%;
		background: radial-gradient(circle, var(--color-primary) 0%, transparent 65%);
		opacity: 0;
		pointer-events: none;
		transition: opacity 60ms ease;
	}

	.signal-light.active .light-core {
		background: var(--color-primary);
		box-shadow: 0 0 30px var(--color-primary);
	}

	.signal-light.active .light-glow {
		opacity: 0.35;
	}

	.answer-form {
		display: grid;
		gap: 0.45rem;
		max-width: 20rem;
	}

	.answer-form label {
		color: var(--color-text-soft);
		font-size: 0.95rem;
	}

	.answer-form input {
		border: 1px solid var(--color-border-strong);
		background: var(--color-surface-alt);
		color: var(--color-text);
		padding: 0.55rem 0.75rem;
		border-radius: 0.45rem;
		font: inherit;
		text-transform: uppercase;
	}

	.answer-form input:focus-visible {
		outline: none;
		border-color: var(--color-secondary);
	}

	.form-actions {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}

	.key-area {
		display: grid;
		place-items: center;
		gap: 0.25rem;
		padding: 2rem;
		border-radius: 1rem;
		border: 2px solid var(--color-border-strong);
		background: var(--color-surface-alt);
		cursor: pointer;
		user-select: none;
		transition:
			border-color 80ms ease,
			background 80ms ease,
			transform 80ms ease;
	}

	.key-area:active,
	.key-area:focus-visible:active {
		border-color: var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 12%, transparent);
		transform: scale(0.98);
	}

	.key-area:focus-visible {
		outline: none;
		border-color: var(--color-secondary);
	}

	.key-label {
		font-size: 1.25rem;
		font-weight: 700;
		color: var(--color-text);
	}

	.key-hint {
		font-size: 0.85rem;
		color: var(--color-text-soft);
	}

	.manual-controls {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}

	.manual-controls button {
		min-width: 3rem;
		font-size: 1.4rem;
	}

	.send-buffer {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		border: 1px dashed var(--color-border-strong);
		border-radius: 0.45rem;
		min-height: 3rem;
	}

	.buffer-chars {
		font-size: 1.8rem;
		color: var(--color-secondary);
		letter-spacing: 0.15em;
	}

	.buffer-guess {
		color: var(--color-text-soft);
		font-size: 1.1rem;
	}

	.buffer-empty {
		color: var(--color-text-muted);
	}

	.feedback {
		color: var(--color-text-soft);
		padding: 0.6rem 0.75rem;
		border-radius: 0.45rem;
		background: var(--color-surface-alt);
		border: 1px solid var(--color-border);
	}

	.stats {
		display: flex;
		gap: 0.75rem;
		flex-wrap: wrap;
		font-size: 0.9rem;
		color: var(--color-text-soft);
	}

	.stat {
		padding: 0.25rem 0.55rem;
		border: 1px solid var(--color-border);
		border-radius: 0.35rem;
	}

	.history {
		display: grid;
		gap: 0.75rem;
		margin-top: 1rem;
	}

	.history h2 {
		margin: 0;
		font-size: 1rem;
		color: var(--color-text-soft);
	}

	.empty {
		color: var(--color-text-soft);
	}

	.history-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: 0.4rem;
	}

	.history-item {
		display: grid;
		grid-template-columns: 5rem 3rem 3rem 2rem;
		gap: 0.5rem;
		align-items: center;
		padding: 0.45rem 0.6rem;
		border-radius: 0.35rem;
		border: 1px solid var(--color-border);
	}

	.history-item.correct {
		background: color-mix(in oklab, var(--color-primary) 10%, transparent);
	}

	.history-item.wrong {
		background: color-mix(in oklab, #ff8a80 10%, transparent);
	}

	.history-subpage {
		color: var(--color-text-soft);
		font-size: 0.85rem;
	}

	.history-target,
	.history-answer {
		font-weight: 700;
	}

	.history-result {
		color: var(--color-primary);
	}

	.history-item.wrong .history-result {
		color: #ff8a80;
	}

	.letter-grid {
		display: grid;
		gap: 0.6rem;
		grid-template-columns: repeat(auto-fit, minmax(5.5rem, 1fr));
	}

	.letter-tile {
		display: grid;
		place-items: center;
		gap: 0.25rem;
		padding: 0.6rem;
		border: 1px solid var(--color-border-strong);
		border-radius: 0.5rem;
		background: var(--color-surface-alt);
		color: var(--color-text);
		font: inherit;
		cursor: pointer;
		min-height: 5rem;
	}

	.letter-tile:hover,
	.letter-tile:focus-visible {
		border-color: var(--color-secondary);
		color: var(--color-secondary);
	}

	.letter-tile:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.letter-tile.playing {
		border-color: var(--color-primary);
		color: var(--color-primary);
		background: color-mix(in oklab, var(--color-primary) 18%, transparent);
		box-shadow: 0 0 24px color-mix(in oklab, var(--color-primary) 40%, transparent);
		opacity: 1;
	}

	.letter-tile-char {
		font-size: 1.4rem;
		font-weight: 700;
	}

	.letter-tile-morse {
		font-size: 0.75rem;
		color: var(--color-primary);
		letter-spacing: 0.12em;
		white-space: nowrap;
	}

	.signal-preview {
		display: grid;
		place-items: center;
		padding: 1rem;
	}
</style>
