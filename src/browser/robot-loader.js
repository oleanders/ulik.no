// Keep Three.js out of the initial application bundle. Generation checks prevent
// a completed import from mounting a world after the user has left this route.
let generation = 0;
let adapter = null;
let loading = null;

export function dispose() {
	generation += 1;
	adapter?.dispose();
}

export function mount(callbacks) {
	dispose();
	const current = generation;
	loading ??= import('./robot.js');
	void loading
		.then((loaded) => {
			if (current !== generation) return;
			adapter = loaded;
			adapter.mount(callbacks);
		})
		.catch(() => {
			if (current === generation)
				callbacks.on_error('Nettleseren kunne ikke laste 3D-verdenen. Prøv igjen.');
		});
}

export function setInput(keys) {
	adapter?.setInput(keys);
}
export function setRunning(running) {
	adapter?.setRunning(running);
}
export function reset() {
	adapter?.reset();
}
