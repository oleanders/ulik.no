import './app.css';
import './styles/shell.css';
import './styles/audio.css';
import './styles/experiments.css';
import './styles/tools.css';
import * as audio from './browser/audio.js';
import * as falling from './browser/falling.js';
import * as flow from './browser/flow.js';
import * as preview from './browser/preview.js';
import * as tools from './browser/tools.js';

// Restore after Elm renders, rather than while the previous page still determines layout.
history.scrollRestoration = 'manual';
const scrollPositions = new Map();
let currentEntry;
function historyEntry() {
	const key = history.state?.ulikScrollKey || crypto.randomUUID();
	history.replaceState({ ...history.state, ulikScrollKey: key }, '', location.href);
	return key;
}

// Elm must create its own anchors to install Browser.application navigation handlers.
// The prerendered body remains available until this synchronous startup.
document.body.replaceChildren();
const app = window.Elm.Main.init({ flags: { version: __APP_VERSION__, prerender: false } });
const adapters = { audio, flow, falling, tools, preview };
let robot;
let routeRevision = 0;
app.ports.send.subscribe((command) => {
	if (command.domain === 'navigation') {
		const revision = ++routeRevision;
		if (currentEntry) scrollPositions.set(currentEntry, [window.scrollX, window.scrollY]);
		currentEntry = historyEntry();
		const position = command.scrollToTop ? [0, 0] : scrollPositions.get(currentEntry) || [0, 0];
		for (const adapter of Object.values(adapters)) adapter.dispose();
		robot?.dispose();
		requestAnimationFrame(() => {
			if (revision !== routeRevision) return;
			app.ports.receive.send({ domain: 'navigation', url: command.url });
			requestAnimationFrame(() => {
				if (revision === routeRevision) window.scrollTo(...position);
			});
		});
		return;
	}
	if (command.domain === 'robot') {
		const revision = routeRevision;
		import('./browser/robot.js').then((module) => {
			robot = module;
			if (revision === routeRevision)
				robot.handle(command, (event) => app.ports.receive.send(event));
		});
		return;
	}
	adapters[command.domain]?.handle(command, (event) => app.ports.receive.send(event));
});
