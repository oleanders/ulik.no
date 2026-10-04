import { spawnSync } from 'node:child_process';

for (const [command, args] of [
	['vitest', ['run']],
	['elm-test', []],
]) {
	const result = spawnSync(command, args, { stdio: 'inherit', shell: true });
	if (result.status !== 0) process.exit(result.status || 1);
}
