import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { JSDOM } from 'jsdom';
import { handle } from '../src/browser/tools.js';

const template = await readFile('build/index.html', 'utf8');
const compiledElm = await readFile('build/elm.js', 'utf8');
const routes = [
	'/',
	'/om',
	'/projects',
	...[
		'lik-lik',
		'robot-tohjul',
		'fall-haug',
		'flyt-felt',
		'fonetisk-alfabet',
		'prompt-lab',
		'diff-tool',
		'skjermdeling-lab',
		'morsekode',
		'morsekode/oversikt',
		'morsekode/motta',
		'morsekode/sende',
	].map((slug) => `/projects/${slug}`),
];
for (const route of routes) {
	const dom = new JSDOM(template, {
		url: `https://ulik.no${route}`,
		runScripts: 'outside-only',
		pretendToBeVisual: true,
	});
	const scripts = [...dom.window.document.querySelectorAll('script')]
		.map((script) => script.outerHTML)
		.join('');
	dom.window.eval(compiledElm);
	const app = dom.window.Elm.Main.init({
		flags: { version: process.env.APP_VERSION || 'dev', prerender: true },
	});
	app.ports.send.subscribe((command) => {
		if (command.domain === 'tools' && command.action === 'diff')
			handle(command, (event) => app.ports.receive.send(event));
	});
	await new Promise((resolve) => setTimeout(resolve, 30));
	// The same Elm views supply the no-JavaScript fallback. Browser.application
	// replaces this body on startup; no second copy of the UI is maintained.
	dom.window.document.body.insertAdjacentHTML('beforeend', scripts);
	const file = route === '/' ? 'build/index.html' : `build${route}.html`;
	await mkdir(dirname(file), { recursive: true });
	await writeFile(file, dom.serialize());
	dom.window.close();
}
