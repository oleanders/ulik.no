import { spawn, spawnSync } from 'node:child_process';
import { watch } from 'node:fs';

function build() {
	return spawnSync('gleam', ['build'], { stdio: 'inherit' }).status === 0;
}
if (!build()) process.exit(1);
let timer;
watch('src', { recursive: true }, (_, file) => {
	if (file?.endsWith('.gleam') || file?.endsWith('.mjs') || file?.startsWith('browser/')) {
		clearTimeout(timer);
		timer = setTimeout(build, 100);
	}
});
const vite = spawn('vite', process.argv.slice(2), { stdio: 'inherit' });
for (const signal of ['SIGINT', 'SIGTERM'])
	process.on(signal, () => {
		vite.kill(signal);
		process.exit();
	});
