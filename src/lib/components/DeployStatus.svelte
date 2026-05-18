<script lang="ts">
import { onMount } from 'svelte';

type WorkflowRun = {
	id: number;
	name: string;
	status: 'queued' | 'in_progress' | 'completed' | 'waiting' | 'requested' | 'pending';
	conclusion:
		| 'success'
		| 'failure'
		| 'cancelled'
		| 'skipped'
		| 'timed_out'
		| 'action_required'
		| 'neutral'
		| null;
	html_url: string;
	updated_at: string;
};

type ApiResponse = {
	workflow_runs: WorkflowRun[];
};

const REPO = 'oleanders/ulik.no';
const DEPLOY_NAMES = [
	'Deploy to beta on push to main',
	'Deploy to production when release is published',
];

let run = $state<WorkflowRun | null>(null);
let error = $state(false);

const isLive = $derived(
	run?.status === 'in_progress' || run?.status === 'queued' || run?.status === 'pending',
);

const label = $derived(() => {
	if (!run) return 'ingen deploy registrert';
	if (isLive) return `deploy pågår — ${run.name}`;
	if (run.conclusion === 'success') return `siste deploy ok`;
	if (run.conclusion === 'failure') return `siste deploy feilet`;
	if (run.conclusion === 'cancelled') return `siste deploy avbrutt`;
	return `siste deploy: ${run.conclusion ?? run.status}`;
});

const dotClass = $derived(() => {
	if (!run) return 'idle';
	if (isLive) return 'live';
	if (run.conclusion === 'success') return 'ok';
	if (run.conclusion === 'failure') return 'fail';
	return 'idle';
});

const fetchStatus = async () => {
	try {
		const response = await fetch(`https://api.github.com/repos/${REPO}/actions/runs?per_page=20`, {
			headers: { Accept: 'application/vnd.github+json' },
		});
		if (!response.ok) {
			error = true;
			return;
		}
		const data: ApiResponse = await response.json();
		const latest = data.workflow_runs.find((r) => DEPLOY_NAMES.includes(r.name));
		run = latest ?? null;
		error = false;
	} catch {
		error = true;
	}
};

onMount(() => {
	fetchStatus();
	let intervalMs = 60_000;
	let timer = setInterval(tick, intervalMs);

	function tick() {
		fetchStatus().then(() => {
			const next = isLive ? 15_000 : 60_000;
			if (next !== intervalMs) {
				intervalMs = next;
				clearInterval(timer);
				timer = setInterval(tick, intervalMs);
			}
		});
	}

	return () => clearInterval(timer);
});
</script>

{#if error}
	<span class="status">
		<span class="dot idle" aria-hidden="true"></span>
		<span>status utilgjengelig</span>
	</span>
{:else if run}
	<a class="status" href={run.html_url} target="_blank" rel="noreferrer">
		<span class={`dot ${dotClass()}`} aria-hidden="true"></span>
		<span>{label()}</span>
	</a>
{:else}
	<span class="status">
		<span class="dot idle" aria-hidden="true"></span>
		<span>laster deploy-status…</span>
	</span>
{/if}

<style>
	.status {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		color: var(--color-text-muted);
		font-size: 0.85rem;
		text-decoration: none;
	}

	a.status:hover,
	a.status:focus-visible {
		color: var(--color-text);
	}

	.dot {
		width: 0.6rem;
		height: 0.6rem;
		border-radius: 50%;
		background: var(--color-text-muted);
		flex-shrink: 0;
	}

	.dot.live {
		background: #ffd166;
		box-shadow: 0 0 8px #ffd166;
		animation: pulse 1.2s ease-in-out infinite;
	}

	.dot.ok {
		background: var(--color-primary);
		box-shadow: 0 0 6px color-mix(in srgb, var(--color-primary) 60%, transparent);
	}

	.dot.fail {
		background: #ff6b6b;
		box-shadow: 0 0 6px rgba(255, 107, 107, 0.6);
	}

	.dot.idle {
		background: var(--color-text-muted);
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.35;
		}
	}
</style>
