import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';

function check(directory) {
	for (const entry of readdirSync(directory, { withFileTypes: true })) {
		const path = `${directory}/${entry.name}`;
		if (entry.isDirectory()) check(path);
		else if (/\.m?js$/.test(entry.name)) {
			const result = spawnSync(process.execPath, ['--check', path], { stdio: 'inherit' });
			if (result.status !== 0) process.exit(result.status || 1);
		}
	}
}
for (const directory of ['src', 'scripts', 'e2e']) check(directory);
