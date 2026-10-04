import { dispose as disposeAudio } from './browser/audio.js';
import { dispose as disposeFalling } from './browser/falling.js';
import { dispose as disposeFlow } from './browser/flow.js';
import { dispose as disposePreview } from './browser/preview.js';
import { dispose as disposeRobot } from './browser/robot-loader.js';
import { dispose as disposeTools } from './browser/tools.js';

let navigate;
let revision = 0;
let currentEntry;
let targetPosition = [0, 0];
const positions = new Map();

function rememberScroll() {
	if (currentEntry) positions.set(currentEntry, [window.scrollX, window.scrollY]);
}
function historyEntry() {
	const key = history.state?.ulikScrollKey || crypto.randomUUID();
	history.replaceState({ ...history.state, ulikScrollKey: key }, '', location.href);
	return key;
}
function disposePage() {
	disposeAudio();
	disposeTools();
	disposePreview();
	disposeFlow();
	disposeFalling();
	disposeRobot();
}
function changePage(url, push) {
	if (push && url.href === location.href) return;
	rememberScroll();
	disposePage();
	if (push) history.pushState({}, '', url.href);
	currentEntry = historyEntry();
	targetPosition = push ? [0, 0] : positions.get(currentEntry) || [0, 0];
	revision++;
	navigate(url.href);
}
export function listen(onNavigate) {
	navigate = onNavigate;
	history.scrollRestoration = 'manual';
	currentEntry = historyEntry();
	targetPosition = [window.scrollX, window.scrollY];
	// Capture the tall page before a render can clamp its scroll position.
	document.addEventListener(
		'click',
		(event) => {
			const anchor = event.target.closest?.('a[href]');
			if (
				!anchor ||
				event.defaultPrevented ||
				event.button !== 0 ||
				event.ctrlKey ||
				event.metaKey ||
				event.shiftKey ||
				event.altKey ||
				anchor.hasAttribute('download') ||
				(anchor.target && anchor.target !== '_self')
			)
				return;
			const url = new URL(anchor.href, location.href);
			if (url.origin !== location.origin || !['http:', 'https:'].includes(url.protocol)) return;
			if (url.pathname === location.pathname && url.search === location.search && url.hash) return;
			event.preventDefault();
			changePage(url, true);
		},
		true,
	);
	window.addEventListener('popstate', () => changePage(new URL(location.href), false));
	window.addEventListener('ulik:navigate', (event) => {
		const url = new URL(event.detail, location.href);
		if (url.origin === location.origin) changePage(url, true);
	});
	window.addEventListener(
		'scroll',
		() => {
			if (history.state?.ulikScrollKey === currentEntry) rememberScroll();
		},
		{ passive: true },
	);
}
export function afterRender(title, onReady) {
	document.title = title;
	const expected = revision;
	const position = [...targetPosition];
	requestAnimationFrame(() => {
		if (expected !== revision) return;
		onReady();
		requestAnimationFrame(() => {
			if (expected === revision) window.scrollTo(...position);
		});
	});
}
