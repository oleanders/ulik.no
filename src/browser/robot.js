import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const WHEEL_RADIUS = 0.24;
const ROBOT_RADIUS = 0.58;
const WORLD_LIMIT = 8.5;
const obstacles = [
	{ x: -4.6, z: -2.6, size: [1.1, 1.1, 1.1] },
	{ x: -2.8, z: 3.3, size: [1.2, 1.4, 1.2] },
	{ x: 0.8, z: -3.9, size: [1.5, 0.8, 1.5] },
	{ x: 3.6, z: 2.8, size: [1.1, 1.1, 1.1] },
	{ x: 5.5, z: -1.7, size: [1.6, 1.3, 1.2] },
];
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const collisionAt = (x, z) =>
	obstacles.find(
		(obstacle) =>
			Math.abs(x - obstacle.x) <= obstacle.size[0] / 2 + ROBOT_RADIUS &&
			Math.abs(z - obstacle.z) <= obstacle.size[2] / 2 + ROBOT_RADIUS,
	);

let generation = 0;
let mountFrame = 0;
let world = null;

export function dispose() {
	generation += 1;
	cancelAnimationFrame(mountFrame);
	mountFrame = 0;
	world?.dispose();
	world = null;
}

/** Animation-only state stays next to WebGL; controls and page state belong to Elm. */
function createSimulation() {
	const initial = () => ({
		x: 0,
		z: 0,
		yaw: 0,
		speed: 0,
		turn: 0,
		wheelSpin: 0,
		tiltX: 0,
		tiltZ: 0,
		hop: 0,
		crashMode: false,
	});
	const state = initial();
	let crashRemaining = 0;
	let reboundRemaining = 0;
	let reboundYaw = 0;
	let reboundSpin = 0;
	let collisionLock = 0;
	const crashDuration = 1.08;

	function reset() {
		Object.assign(state, initial());
		crashRemaining = 0;
		reboundRemaining = 0;
		reboundYaw = 0;
		reboundSpin = 0;
		collisionLock = 0;
	}

	function startCrash(hit) {
		const { x, z, yaw } = state;
		const angleAway =
			hit && (Math.abs(x - hit.x) > 0.0001 || Math.abs(z - hit.z) > 0.0001)
				? Math.atan2(x - hit.x, z - hit.z)
				: yaw + Math.PI;
		crashRemaining = crashDuration;
		reboundRemaining = 0;
		reboundSpin = 0;
		collisionLock = 1.6;
		reboundYaw = angleAway + (Math.random() - 0.5) * 0.7;
		state.crashMode = true;
	}

	function move(delta) {
		const x = clamp(state.x + Math.sin(state.yaw) * state.speed * delta, -WORLD_LIMIT, WORLD_LIMIT);
		const z = clamp(state.z + Math.cos(state.yaw) * state.speed * delta, -WORLD_LIMIT, WORLD_LIMIT);
		const hit = collisionAt(x, z);
		if (hit && collisionLock <= 0) startCrash(hit);
		else {
			state.x = x;
			state.z = z;
		}
		state.wheelSpin += (state.speed / WHEEL_RADIUS) * delta;
	}

	function update(delta, now, pressed, reducedMotion) {
		collisionLock = Math.max(0, collisionLock - delta);
		state.hop = Math.max(0, state.hop - delta * 2.4);
		if (crashRemaining > 0) {
			crashRemaining = Math.max(0, crashRemaining - delta);
			const t = 1 - crashRemaining / crashDuration;
			const topple = Math.min(1, t / 0.35) * (t > 0.82 ? Math.max(0, (1 - t) / 0.18) : 1);
			const shake = t > 0.16 && t < 0.78 ? Math.max(0, 1 - Math.abs(t - 0.47) / 0.31) : 0;
			state.tiltX = reducedMotion ? 0 : -1.02 * topple + Math.sin(now * 0.06) * 0.08 * shake;
			state.tiltZ = reducedMotion ? 0 : Math.cos(now * 0.082) * 0.08 * shake;
			state.speed *= 0.8;
			state.turn *= 0.62;
			state.wheelSpin += (state.speed / WHEEL_RADIUS) * delta;
			if (crashRemaining === 0) {
				reboundRemaining = 0.78;
				state.yaw = reboundYaw;
				state.speed = 3.5;
				state.turn = 0;
				state.hop = reducedMotion ? 0 : 0.12;
				reboundSpin = (Math.random() < 0.5 ? -1 : 1) * (5 + Math.random() * 4);
				for (let i = 0; i < 12 && collisionAt(state.x, state.z); i++) {
					state.x = clamp(state.x + Math.sin(state.yaw) * 0.28, -WORLD_LIMIT, WORLD_LIMIT);
					state.z = clamp(state.z + Math.cos(state.yaw) * 0.28, -WORLD_LIMIT, WORLD_LIMIT);
				}
				state.crashMode = false;
				state.tiltX = 0;
				state.tiltZ = 0;
			}
			return;
		}
		if (reboundRemaining > 0) {
			reboundRemaining = Math.max(0, reboundRemaining - delta);
			const strength = reboundRemaining / 0.78;
			const phase = 1 - strength;
			state.yaw += reboundSpin * delta;
			reboundSpin *= Math.max(0, 1 - delta * 3.2);
			state.speed += (3 * strength - state.speed) * Math.min(1, delta * 7);
			if (!reducedMotion)
				state.hop = Math.max(
					state.hop,
					Math.sin(phase * Math.PI) * 0.14 * strength + 0.02 * strength,
				);
			move(delta);
			return;
		}
		const forward = pressed.has('w') || pressed.has('arrowup');
		const backward = pressed.has('s') || pressed.has('arrowdown');
		const left = pressed.has('a') || pressed.has('arrowleft');
		const right = pressed.has('d') || pressed.has('arrowright');
		state.speed +=
			((forward ? 2.8 : 0) + (backward ? -2 : 0) - state.speed) * Math.min(1, delta * 7);
		state.turn += ((left ? 1.7 : 0) + (right ? -1.7 : 0) - state.turn) * Math.min(1, delta * 9);
		state.yaw += state.turn * delta;
		move(delta);
	}
	return { state, update, reset };
}

function createWorld(container, emit) {
	const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
	renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
	renderer.domElement.setAttribute('aria-label', 'En robot på to hjul blant fem hindringer.');
	container.append(renderer.domElement);
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(52, 1, 0.1, 1000);
	camera.position.set(7, 6.2, 9);
	const controls = new OrbitControls(camera, renderer.domElement);
	controls.enablePan = false;
	controls.maxDistance = 20;
	controls.minDistance = 6;
	controls.maxPolarAngle = 1.35;
	controls.update();
	scene.add(new THREE.AmbientLight(0xffffff, 0.55));
	const sunlight = new THREE.DirectionalLight(0xffffff, 1.1);
	sunlight.position.set(6, 11, 5);
	scene.add(sunlight, new THREE.HemisphereLight(0xffffff, 0xffffff, 0.35));

	const mesh = (parent, geometry, color, position, extra = {}) => {
		const object = new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({ color, ...extra }));
		object.position.set(...position);
		parent.add(object);
		return object;
	};
	const floor = mesh(scene, new THREE.PlaneGeometry(24, 24), '#0b1110', [0, 0, 0]);
	floor.rotation.x = -Math.PI / 2;
	floor.receiveShadow = true;
	for (const obstacle of obstacles)
		mesh(scene, new THREE.BoxGeometry(...obstacle.size), '#1f2f2f', [
			obstacle.x,
			obstacle.size[1] / 2,
			obstacle.z,
		]);
	const robot = new THREE.Group();
	const body = new THREE.Group();
	scene.add(robot);
	robot.add(body);
	const chassis = mesh(body, new THREE.BoxGeometry(1.2, 0.45, 0.8), '#00ccff', [0, 0.55, 0]);
	mesh(body, new THREE.BoxGeometry(0.7, 0.25, 0.6), '#00ff88', [0, 0.9, 0]);
	mesh(body, new THREE.SphereGeometry(0.09, 16, 16), '#ffd166', [0, 1.1, 0.22], {
		emissive: '#ad7e00',
		emissiveIntensity: 0.35,
	});
	const wheels = [-0.56, 0.56].map((x) =>
		mesh(body, new THREE.CylinderGeometry(WHEEL_RADIUS, WHEEL_RADIUS, 0.2, 28), '#0f1616', [
			x,
			0.32,
			0,
		]),
	);
	mesh(body, new THREE.SphereGeometry(0.1, 12, 12), '#2a3232', [0, 0.14, -0.24]);

	const simulation = createSimulation();
	const media = window.matchMedia('(prefers-reduced-motion: reduce)');
	let pressed = new Set();
	let running = false;
	let frame = 0;
	let lastTime = 0;
	let disposed = false;
	const render = () => {
		if (disposed) return;
		const state = simulation.state;
		robot.position.set(state.x, state.hop, state.z);
		robot.rotation.y = state.yaw;
		body.rotation.set(state.tiltX, 0, state.tiltZ);
		chassis.material.color.set(state.crashMode ? '#ffd166' : '#00ccff');
		for (const wheel of wheels) wheel.rotation.set(state.wheelSpin, 0, Math.PI / 2);
		renderer.render(scene, camera);
	};
	const tick = (now) => {
		frame = 0;
		if (disposed || !running || document.hidden) return;
		const delta = lastTime ? Math.min(0.05, (now - lastTime) / 1000) : 0;
		lastTime = now;
		simulation.update(delta, now, pressed, media.matches);
		render();
		frame = requestAnimationFrame(tick);
	};
	const schedule = () => {
		cancelAnimationFrame(frame);
		frame = 0;
		lastTime = 0;
		if (running && !document.hidden && !disposed) frame = requestAnimationFrame(tick);
	};
	const resize = () => {
		const { width, height } = container.getBoundingClientRect();
		camera.aspect = width / Math.max(1, height);
		camera.updateProjectionMatrix();
		renderer.setSize(Math.max(1, width), Math.max(1, height), false);
		render();
	};
	const clearKeys = () => {
		pressed.clear();
		emit('clearKeys', null);
	};
	const visibility = () => {
		clearKeys();
		schedule();
	};
	const motion = () => emit('motion', media.matches);
	const releaseTouch = () => emit('releaseTouch', null);
	const preventScroll = (event) => {
		if (
			event.key.startsWith('Arrow') &&
			!event.target.closest('input, textarea, select, [contenteditable="true"]')
		)
			event.preventDefault();
	};
	const contextLost = (event) => {
		event.preventDefault();
		running = false;
		schedule();
		emit('error', '3D-visningen ble avbrutt. Last siden på nytt for å starte igjen.');
	};
	const observer = new ResizeObserver(resize);
	observer.observe(container);
	controls.addEventListener('change', render);
	window.addEventListener('blur', clearKeys);
	window.addEventListener('keydown', preventScroll);
	window.addEventListener('pointerup', releaseTouch);
	window.addEventListener('pointercancel', releaseTouch);
	document.addEventListener('visibilitychange', visibility);
	media.addEventListener('change', motion);
	renderer.domElement.addEventListener('webglcontextlost', contextLost);
	resize();

	return {
		reducedMotion: media.matches,
		input(keys) {
			pressed = new Set(keys);
		},
		running(value) {
			running = value;
			if (!value) pressed.clear();
			schedule();
		},
		reset() {
			pressed.clear();
			simulation.reset();
			render();
		},
		dispose() {
			disposed = true;
			cancelAnimationFrame(frame);
			observer.disconnect();
			controls.removeEventListener('change', render);
			controls.dispose();
			window.removeEventListener('blur', clearKeys);
			window.removeEventListener('keydown', preventScroll);
			window.removeEventListener('pointerup', releaseTouch);
			window.removeEventListener('pointercancel', releaseTouch);
			document.removeEventListener('visibilitychange', visibility);
			media.removeEventListener('change', motion);
			renderer.domElement.removeEventListener('webglcontextlost', contextLost);
			scene.traverse((object) => {
				object.geometry?.dispose();
				if (Array.isArray(object.material))
					for (const material of object.material) material.dispose();
				else object.material?.dispose();
			});
			renderer.dispose();
			renderer.forceContextLoss();
			renderer.domElement.remove();
		},
	};
}

function mount(send) {
	dispose();
	const current = generation;
	const emit = (action, data) => {
		if (generation === current) send({ domain: 'robot', action, data });
	};
	const start = () => {
		if (generation !== current) return;
		const container = document.getElementById('robot-world');
		if (!container) {
			mountFrame = requestAnimationFrame(start);
			return;
		}
		try {
			world = createWorld(container, emit);
			emit('ready', world.reducedMotion);
		} catch {
			world?.dispose();
			world = null;
			emit(
				'error',
				'Nettleseren kunne ikke starte 3D-verdenen. Prøv en nettleser med WebGL-støtte.',
			);
		}
	};
	mountFrame = requestAnimationFrame(start);
}

export function handle(command, send) {
	if (command.domain !== 'robot') return;
	switch (command.action) {
		case 'mount':
			mount(send);
			break;
		case 'input':
			world?.input(command.data);
			break;
		case 'running':
			world?.running(command.data);
			break;
		case 'reset':
			world?.reset();
			break;
		case 'dispose':
			dispose();
			break;
		default:
			break;
	}
}
