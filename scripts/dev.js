import { spawn, spawnSync } from 'node:child_process';

const initial = spawnSync('elm-watch', ['make'], { stdio: 'inherit', shell: true });
if (initial.status !== 0) process.exit(initial.status || 1);
const children = [
	spawn('elm-watch', ['hot'], { stdio: 'inherit', shell: true }),
	spawn('vite', process.argv.slice(2), { stdio: 'inherit', shell: true }),
];
function stop() {
	for (const child of children) child.kill();
}
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
for (const child of children) {
	child.on('exit', (code) => {
		stop();
		process.exit(code || 0);
	});
}
