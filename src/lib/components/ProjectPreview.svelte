<script lang="ts">
let { id }: { id: string } = $props();
</script>

<svg viewBox="0 0 360 160" aria-hidden="true" focusable="false">
	{#if id === 'flyt-felt'}
		{#each Array.from({ length: 16 }, (_, i) => i) as line}
			<path class="flow" style={`opacity: ${0.35 + line * 0.035}`} d={`M -10 ${line * 12} C 100 ${160 - line * 9}, 200 ${line * 10 - 40}, 380 ${line * 10 + 30}`} />
		{/each}
	{:else if id === 'robot-tohjul'}
		<path class="grid" d="M0 140 H360 M0 110 H360 M0 90 H360 M60 160 L150 70 M300 160 L210 70 M180 160 V70" />
		<g transform="translate(130 40)">
			<rect x="0" y="40" width="16" height="48" rx="6" class="solid" />
			<rect x="84" y="40" width="16" height="48" rx="6" class="solid" />
			<path d="M16 25 L50 10 L84 25 V73 L50 88 L16 73 Z M16 25 L50 40 L84 25 M50 40 V88" />
			<circle cx="32" cy="49" r="3" class="solid" /><circle cx="68" cy="49" r="3" class="solid" />
		</g>
	{:else if id === 'fall-haug'}
		<g transform="translate(35 92) rotate(-12)"><rect width="82" height="35" rx="4" /><text x="12" y="23">header</text></g>
		<g transform="translate(125 94) rotate(8)"><rect width="94" height="35" rx="4" /><text x="12" y="23">button</text></g>
		<g transform="translate(225 87) rotate(-22)"><rect width="88" height="35" rx="4" /><text x="16" y="23">footer</text></g>
		<path class="secondary" d="M85 20 V60 M77 52 L85 60 L93 52 M260 12 V47 M252 39 L260 47 L268 39" />
		<path class="grid" d="M24 139 H336" />
	{:else if id === 'fonetisk-alfabet'}
		<text class="big" x="34" y="95">A</text><path class="secondary" d="M108 80 H142 M134 72 L142 80 L134 88" />
		<text x="164" y="85" class="word">ALFA</text>
		{#each [10, 25, 40, 28, 16, 33, 48, 25, 12] as height, i}
			<path class="secondary" d={`M${168 + i * 13} ${117 - height / 2} v${height}`} />
		{/each}
	{:else if id === 'prompt-lab'}
		<rect class="grid" x="35" y="27" width="290" height="106" rx="7" />
		<text x="55" y="60">$ ./prompt-lab</text><text class="muted" x="55" y="93">under bygging_</text>
	{:else if id === 'diff-tool'}
		<text class="muted" x="26" y="30">før</text><text class="muted" x="202" y="30">etter</text>
		<path class="grid" d="M180 20 V142 M26 50 H155 M202 50 H332 M26 126 H155 M202 126 H332" />
		<rect class="removed" x="18" y="66" width="145" height="40" rx="4" /><text class="removed-text" x="28" y="92">− likt</text>
		<rect class="added" x="196" y="66" width="145" height="40" rx="4" /><text x="206" y="92">+ ulikt</text>
	{:else if id === 'skjermdeling-lab'}
		<rect x="42" y="23" width="195" height="108" rx="6" /><path d="M112 145 H168 M140 131 V145" />
		<rect class="screen" x="154" y="64" width="163" height="78" rx="5" />
		<path class="secondary" d="M188 100 H277 M265 89 L277 100 L265 111" />
	{:else if id === 'morsekode'}
		<text class="muted" x="28" y="35">... / --- / ...</text>
		{#each [40, 62, 84, 273, 295, 317] as x}<circle cx={x} cy="86" r="6" class="solid" />{/each}
		{#each [112, 163, 214] as x}<path class="morse" d={`M${x} 86 h25`} />{/each}
		<text x="156" y="132" class="secondary-text">SOS</text>
	{/if}
</svg>

<style>
	svg {
		display: block;
		width: 100%;
		height: auto;
		background: radial-gradient(ellipse at center, #0f241e, #0a100f 80%);
		fill: none;
		stroke: var(--color-primary);
		stroke-width: 1.5;
	}

	text {
		fill: var(--color-primary);
		stroke: none;
		font: 14px monospace;
	}

	.big {
		font-size: 68px;
	}

	.word {
		font-size: 26px;
	}

	.secondary, .flow:nth-child(even) {
		stroke: var(--color-secondary);
	}

	.secondary-text {
		fill: var(--color-secondary);
	}

	.grid {
		stroke: var(--color-border-strong);
	}

	.solid {
		fill: var(--color-primary);
	}

	.muted {
		fill: var(--color-text-soft);
	}

	.screen {
		fill: #0a1513;
		stroke: var(--color-secondary);
	}

	.morse {
		stroke-width: 10;
		stroke-linecap: round;
	}

	.removed {
		stroke: #f5a3aa;
		fill: #35191e;
	}

	.removed-text {
		fill: #f5a3aa;
	}

	.added {
		fill: #103526;
	}
</style>
