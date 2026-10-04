import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { render, route_from_url, title } from '../build/dev/javascript/ulik/ulik.mjs';

const template = await readFile('dist/index.html', 'utf8');
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
	const file = route === '/' ? 'dist/index.html' : `dist${route}.html`;
	const html = template
		.replace('<!--prerender-->', render(route, process.env.APP_VERSION || 'dev'))
		.replace(/<title>.*?<\/title>/, `<title>${title(route_from_url(route))}</title>`);
	await mkdir(dirname(file), { recursive: true });
	await writeFile(file, html);
}
