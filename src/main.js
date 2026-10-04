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

const app = window.Elm.Main.init({ flags: { version: __APP_VERSION__, prerender: false } });
const adapters = { audio, flow, falling, tools, preview };
let robot;
let routeRevision = 0;
app.ports.send.subscribe((command) => {
	if (command.domain === 'navigation') {
		const revision = ++routeRevision;
		for (const adapter of Object.values(adapters)) adapter.dispose();
		robot?.dispose();
		requestAnimationFrame(() => {
			if (revision !== routeRevision) return;
			app.ports.receive.send({ domain: 'navigation', url: command.url });
			window.scrollTo(0, 0);
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
