let pendingRequest;
let refreshTimer;
let revision = 0;

export function fetchRuns(onSuccess, onFailure) {
	if (typeof window === 'undefined') return;
	clearTimeout(refreshTimer);
	pendingRequest?.abort();
	const controller = new AbortController();
	pendingRequest = controller;
	const requestRevision = ++revision;
	// GitHub can be unavailable or rate-limited. Keep the footer non-blocking and
	// abort stalled requests so polling can recover rather than hanging forever.
	const timeout = setTimeout(() => controller.abort(), 10_000);
	fetch('https://api.github.com/repos/oleanders/ulik.no/actions/runs?per_page=20', {
		signal: controller.signal,
	})
		.then((response) => {
			if (!response.ok) throw new Error(`Deploy status request failed: ${response.status}`);
			return response.json();
		})
		.then((value) => {
			if (requestRevision === revision) onSuccess(value);
		})
		.catch(() => {
			if (requestRevision === revision) onFailure();
		})
		.finally(() => {
			clearTimeout(timeout);
			if (pendingRequest === controller) pendingRequest = undefined;
		});
}

export function scheduleRefresh(milliseconds, onRefresh) {
	clearTimeout(refreshTimer);
	refreshTimer = setTimeout(onRefresh, milliseconds);
}

export function dispose() {
	revision += 1;
	clearTimeout(refreshTimer);
	pendingRequest?.abort();
	pendingRequest = undefined;
}
