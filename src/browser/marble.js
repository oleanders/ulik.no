import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import {
	buildTrack,
	MARBLE_LIFT,
	MARBLE_RADIUS,
	normalizeConfig,
	RAIL_HALF_WIDTH,
	RAIL_RADIUS,
	railSpans,
	sampleRun,
	sampleTrack,
} from './marble-path.js';

const COLORS = { coral: '#f16b58', mint: '#39b79e', violet: '#9473de' };
const vec = (point) => new THREE.Vector3(point.x, point.y, point.z);
let generation = 0;
let mountFrame = 0;
let world = null;
let pendingConfig = normalizeConfig();
let pendingLaunch = false;

function releaseTree(root) {
	const geometries = new Set();
	const materials = new Set();
	const textures = new Set();
	root.traverse((object) => {
		if (object.geometry) geometries.add(object.geometry);
		for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
			if (!material) continue;
			materials.add(material);
			for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
		}
	});
	for (const geometry of geometries) geometry.dispose();
	for (const material of materials) material.dispose();
	for (const texture of textures) texture.dispose();
}

/** Rails, supports and scenery are static: batch their shared materials into a few draws. */
function batchStaticMeshes(group) {
	group.updateMatrixWorld(true);
	const batches = new Map();
	group.traverse((object) => {
		if (!object.isMesh) return;
		const key = `${object.material.id}:${object.castShadow}:${object.receiveShadow}`;
		if (!batches.has(key)) batches.set(key, []);
		batches.get(key).push(object);
	});
	for (const meshes of batches.values()) {
		if (meshes.length < 2) continue;
		const geometries = meshes.map((mesh) => {
			const geometry = mesh.geometry.clone().applyMatrix4(mesh.matrixWorld);
			// These untextured materials only need positions and normals. Canvas labels stay sprites.
			for (const name of Object.keys(geometry.attributes))
				if (name !== 'position' && name !== 'normal') geometry.deleteAttribute(name);
			return geometry;
		});
		const geometry = mergeGeometries(geometries);
		for (const item of geometries) item.dispose();
		if (!geometry) continue;
		const mesh = new THREE.Mesh(geometry, meshes[0].material);
		mesh.castShadow = meshes[0].castShadow;
		mesh.receiveShadow = meshes[0].receiveShadow;
		for (const original of meshes) {
			original.removeFromParent();
			original.geometry.dispose();
		}
		group.add(mesh);
	}
	return group;
}

function createMarbleShadow() {
	const size = 32;
	const pixels = new Uint8Array(size * size * 4);
	for (let y = 0; y < size; y += 1) {
		for (let x = 0; x < size; x += 1) {
			const radiusSquared = ((x - 15.5) / 15.5) ** 2 + ((y - 15.5) / 15.5) ** 2;
			const index = (y * size + x) * 4;
			pixels[index] = 255;
			pixels[index + 1] = 255;
			pixels[index + 2] = 255;
			pixels[index + 3] = Math.round(Math.max(0, 1 - radiusSquared) ** 2 * 255);
		}
	}
	const texture = new THREE.DataTexture(pixels, size, size);
	texture.magFilter = THREE.LinearFilter;
	texture.needsUpdate = true;
	const shadow = new THREE.Mesh(
		new THREE.PlaneGeometry(1, 1),
		new THREE.MeshBasicMaterial({
			color: '#365647',
			map: texture,
			transparent: true,
			depthWrite: false,
			opacity: 0.15,
		}),
	);
	shadow.rotation.x = -Math.PI / 2;
	return shadow;
}

/** A sampled tube preserves the authored takeoff and landing without spline overshoot. */
function railGeometry(points, side) {
	const positions = [];
	const normals = [];
	const indices = [];
	const sides = 8;
	for (let index = 0; index < points.length; index += 1) {
		const tangent = vec(points[Math.min(index + 1, points.length - 1)])
			.sub(vec(points[Math.max(0, index - 1)]))
			.normalize();
		const across = new THREE.Vector3(-tangent.z, 0, tangent.x).normalize();
		const up = new THREE.Vector3().crossVectors(tangent, across).normalize();
		const center = vec(points[index]).addScaledVector(across, side * RAIL_HALF_WIDTH);
		for (let ring = 0; ring <= sides; ring += 1) {
			const angle = (ring / sides) * Math.PI * 2;
			const normal = across
				.clone()
				.multiplyScalar(Math.cos(angle))
				.addScaledVector(up, Math.sin(angle));
			const position = center.clone().addScaledVector(normal, RAIL_RADIUS);
			positions.push(position.x, position.y, position.z);
			normals.push(normal.x, normal.y, normal.z);
			if (index < points.length - 1 && ring < sides) {
				const a = index * (sides + 1) + ring;
				const b = a + sides + 1;
				indices.push(a, a + 1, b, b, a + 1, b + 1);
			}
		}
	}
	const geometry = new THREE.BufferGeometry();
	geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
	geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
	geometry.setIndex(indices);
	geometry.computeBoundingSphere();
	return geometry;
}

function addMesh(parent, geometry, material, position = [0, 0, 0]) {
	const mesh = new THREE.Mesh(geometry, material);
	mesh.position.set(...position);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	parent.add(mesh);
	return mesh;
}

const standard = (color, extra = {}) =>
	new THREE.MeshStandardMaterial({ color, roughness: 0.45, ...extra });

function cylinderBetween(parent, a, b, radius, material) {
	const direction = b.clone().sub(a);
	const cylinder = addMesh(
		parent,
		new THREE.CylinderGeometry(radius, radius, direction.length(), 10),
		material,
	);
	cylinder.position.copy(a).add(b).multiplyScalar(0.5);
	cylinder.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
	return cylinder;
}

function numberLabel(text, color) {
	const canvas = document.createElement('canvas');
	canvas.width = 128;
	canvas.height = 128;
	const context = canvas.getContext('2d');
	context.fillStyle = color;
	context.beginPath();
	context.arc(64, 64, 56, 0, Math.PI * 2);
	context.fill();
	context.fillStyle = '#ffffff';
	context.font = '600 52px sans-serif';
	context.textAlign = 'center';
	context.textBaseline = 'middle';
	context.fillText(text, 64, 68);
	const texture = new THREE.CanvasTexture(canvas);
	texture.colorSpace = THREE.SRGBColorSpace;
	return new THREE.SpriteMaterial({ map: texture, depthWrite: false });
}

function createCourse(track) {
	const group = new THREE.Group();
	const metal = standard('#819a90', { metalness: 0.72, roughness: 0.25 });
	const underside = standard('#698f81', { metalness: 0.44, roughness: 0.4 });
	const columns = standard('#6f9683', { metalness: 0.3, roughness: 0.38 });
	const feet = standard('#d3ded3', { metalness: 0.15 });
	const brass = standard('#ddac68', { metalness: 0.65, roughness: 0.27 });
	const chalk = standard('#faf7ed');
	const dark = standard('#345d4f');
	for (const span of railSpans(track)) {
		const runupEnd = span.findIndex((point) => point.kind !== 'runup');
		for (const side of [-1, 1]) {
			if (runupEnd > 1) {
				addMesh(group, railGeometry(span.slice(0, runupEnd), side), brass);
				addMesh(group, railGeometry(span.slice(runupEnd - 1), side), metal);
			} else addMesh(group, railGeometry(span, side), metal);
		}
	}
	for (let distance = 0.1; distance < track.length; distance += 0.59) {
		const point = sampleTrack(track, distance);
		if (point.airborne) continue;
		const across = new THREE.Vector3(-point.tangent.z, 0, point.tangent.x).normalize();
		const center = vec(point).add(new THREE.Vector3(0, -0.045, 0));
		cylinderBetween(
			group,
			center.clone().addScaledVector(across, -0.27),
			center.clone().addScaledVector(across, 0.27),
			0.029,
			underside,
		);
	}
	for (let distance = 0.25; distance < track.length; distance += 2.65) {
		const point = sampleTrack(track, distance);
		if (point.airborne) continue;
		// A high support must not pass through another, lower part of the run.
		const crossesLowerTrack = track.points.some(
			(other) => other.y < point.y - 0.5 && Math.hypot(other.x - point.x, other.z - point.z) < 0.43,
		);
		if (crossesLowerTrack) continue;
		const top = vec(point).add(new THREE.Vector3(0, -0.11, 0));
		cylinderBetween(group, new THREE.Vector3(point.x, 0.07, point.z), top, 0.055, columns);
		addMesh(group, new THREE.CylinderGeometry(0.18, 0.23, 0.12, 20), feet, [
			point.x,
			0.08,
			point.z,
		]);
		const cross = new THREE.Vector3(-point.tangent.z, 0, point.tangent.x).normalize();
		for (const side of [-1, 1])
			cylinderBetween(
				group,
				top.clone().add(new THREE.Vector3(0, -0.32, 0)),
				vec(point).addScaledVector(cross, side * 0.22),
				0.035,
				columns,
			);
	}
	for (const section of track.sections) {
		const point = track.points[section.start + 18];
		const label = new THREE.Sprite(
			numberLabel(`0${section.index + 1}`, ['#4d8975', '#9a84bc', '#cc9360'][section.index]),
		);
		label.position.copy(vec(point)).add(new THREE.Vector3(0, 0.74, 0));
		label.scale.set(0.62, 0.62, 1);
		group.add(label);
	}
	const start = sampleTrack(track, 0);
	const finish = sampleTrack(track, track.length);
	for (const [point, isFinish] of [
		[start, false],
		[finish, true],
	]) {
		const across = new THREE.Vector3(-point.tangent.z, 0, point.tangent.x).normalize();
		const center = vec(point);
		const base = addMesh(
			group,
			new THREE.CylinderGeometry(0.5, 0.54, 0.13, 40),
			isFinish ? brass : dark,
		);
		base.position.copy(center).add(new THREE.Vector3(0, -0.1, 0));
		for (const side of [-1, 1]) {
			const foot = center.clone().addScaledVector(across, side * 0.43);
			cylinderBetween(
				group,
				foot,
				foot.clone().add(new THREE.Vector3(0, 0.86, 0)),
				0.037,
				isFinish ? brass : dark,
			);
		}
		const crossbar = center.clone().add(new THREE.Vector3(0, 0.86, 0));
		cylinderBetween(
			group,
			crossbar.clone().addScaledVector(across, -0.48),
			crossbar.clone().addScaledVector(across, 0.48),
			0.037,
			isFinish ? brass : dark,
		);
		if (isFinish) {
			for (let col = 0; col < 8; col += 1) {
				for (let row = 0; row < 2; row += 1) {
					const check = addMesh(
						group,
						new THREE.BoxGeometry(0.105, 0.105, 0.024),
						(col + row) % 2 === 0 ? chalk : dark,
					);
					check.position.copy(crossbar).addScaledVector(across, (col - 3.5) * 0.105);
					check.position.y += 0.16 - row * 0.105;
					check.rotation.y = -Math.atan2(across.z, across.x);
				}
			}
		}
	}
	return batchStaticMeshes(group);
}

function createScenery() {
	const group = new THREE.Group();
	const platform = standard('#edf0e3', { roughness: 0.88 });
	const edge = standard('#d7e2d4', { roughness: 0.8 });
	addMesh(group, new THREE.CylinderGeometry(7.35, 7.35, 0.16, 100), platform, [0, -0.09, -0.6]);
	addMesh(group, new THREE.CylinderGeometry(7.35, 7.12, 0.3, 100), edge, [0, -0.31, -0.6]);
	const contour = standard('#d6e2d3', { roughness: 0.9 });
	for (const [x, z, radius, levels] of [
		[-0.7, -1.3, 1.15, 3],
		[2.6, 1.5, 0.65, 2],
		[-3.9, 1.7, 0.6, 2],
	]) {
		for (let level = 0; level < levels; level += 1)
			addMesh(
				group,
				new THREE.CylinderGeometry(radius - level * 0.2, radius - level * 0.2 + 0.05, 0.065, 60),
				contour,
				[x, 0.015 + level * 0.055, z],
			);
	}
	for (let index = 0; index < 52; index += 1) {
		const angle = (index / 52) * Math.PI * 2;
		const tick = addMesh(
			group,
			new THREE.BoxGeometry(0.025, 0.007, index % 4 === 0 ? 0.23 : 0.12),
			edge,
			[6.93 * Math.sin(angle), 0.002, -0.6 + 6.93 * Math.cos(angle)],
		);
		tick.rotation.y = angle;
		tick.castShadow = false;
	}
	const floor = addMesh(
		group,
		new THREE.PlaneGeometry(200, 200),
		standard('#e7eee5', { roughness: 1 }),
		[0, -0.51, 0],
	);
	floor.rotation.x = -Math.PI / 2;
	floor.castShadow = false;
	return batchStaticMeshes(group);
}

function createWorld(container, initialConfig, emit) {
	const existingCanvas = container instanceof HTMLCanvasElement;
	const renderer = new THREE.WebGLRenderer({
		antialias: true,
		alpha: false,
		...(existingCanvas ? { canvas: container } : {}),
	});
	const canvas = renderer.domElement;
	if (!existingCanvas) container.append(canvas);
	canvas.setAttribute('aria-label', 'Tredimensjonal klinkekulebane med tre utskiftbare deler.');
	canvas.style.display = 'block';
	canvas.style.width = '100%';
	canvas.style.height = '100%';
	renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
	renderer.shadowMap.enabled = true;
	renderer.shadowMap.autoUpdate = false;
	renderer.shadowMap.needsUpdate = true;
	renderer.shadowMap.type = THREE.PCFSoftShadowMap;
	renderer.toneMapping = THREE.ACESFilmicToneMapping;
	renderer.toneMappingExposure = 0.95;
	const scene = new THREE.Scene();
	scene.background = new THREE.Color('#e7eee5');
	scene.fog = new THREE.Fog('#e7eee5', 38, 100);
	const environment = new RoomEnvironment();
	const generator = new THREE.PMREMGenerator(renderer);
	const environmentMap = generator.fromScene(environment, 0.04, 0.1, 100, { size: 128 });
	scene.environment = environmentMap.texture;
	scene.environmentIntensity = 0.75;
	environment.dispose();
	generator.dispose();
	const camera = new THREE.OrthographicCamera(-9, 9, 7, -7, 0.1, 140);
	const controls = new OrbitControls(camera, canvas);
	controls.enablePan = false;
	controls.enableDamping = false;
	controls.minZoom = 0.8;
	controls.maxZoom = 1.7;
	controls.minPolarAngle = 0.2;
	controls.maxPolarAngle = 1.38;
	const sunlight = new THREE.DirectionalLight('#fff5dc', 2.4);
	sunlight.position.set(-4, 15, 8);
	sunlight.castShadow = true;
	sunlight.shadow.mapSize.set(1024, 1024);
	sunlight.shadow.camera.left = -12;
	sunlight.shadow.camera.right = 12;
	sunlight.shadow.camera.top = 12;
	sunlight.shadow.camera.bottom = -12;
	sunlight.shadow.camera.far = 45;
	sunlight.shadow.normalBias = 0.028;
	sunlight.shadow.bias = -0.00015;
	sunlight.shadow.blurSamples = 8;
	scene.add(sunlight, new THREE.HemisphereLight('#f4fbff', '#a1b796', 0.7));
	const rim = new THREE.DirectionalLight('#d4e3ff', 0.7);
	rim.position.set(5, 7, -9);
	scene.add(rim, createScenery());
	let config = normalizeConfig(initialConfig);
	let track = buildTrack(config.segments);
	let course = createCourse(track);
	scene.add(course);
	const marble = new THREE.Group();
	const glass = new THREE.MeshPhysicalMaterial({
		color: COLORS[config.color],
		metalness: 0,
		roughness: 0.12,
		transparent: true,
		opacity: 0.8,
		depthWrite: false,
		clearcoat: 1,
		clearcoatRoughness: 0.08,
		envMapIntensity: 1.5,
	});
	addMesh(marble, new THREE.SphereGeometry(MARBLE_RADIUS, 40, 28), glass);
	const swirlMaterial = standard('#fff6d5', { metalness: 0.18, roughness: 0.2 });
	for (const angle of [0, Math.PI / 2]) {
		const swirl = addMesh(marble, new THREE.TorusGeometry(0.23, 0.032, 10, 64), swirlMaterial);
		swirl.rotation.set(0.5, angle, 0.4);
	}
	// Keep the cached course shadow static; the marble gets a cheap moving soft shadow.
	marble.traverse((object) => {
		object.castShadow = false;
	});
	const marbleShadow = createMarbleShadow();
	scene.add(marble, marbleShadow);
	const media = window.matchMedia('(prefers-reduced-motion: reduce)');
	let reducedMotion = media.matches;
	let state = 'ready';
	let elapsed = 0;
	let lastTime = 0;
	let frame = 0;
	let disposed = false;
	let currentPoint = sampleRun(track, 0);
	const target = new THREE.Vector3(0, 3.8, -0.55);
	const followTarget = new THREE.Vector3();
	const followPosition = new THREE.Vector3();
	const lastMarblePosition = new THREE.Vector3();
	const axis = new THREE.Vector3();
	const rotation = new THREE.Quaternion();
	let moved = false;
	const diagnostic = () => {
		for (const element of new Set([container, canvas])) {
			element.dataset.state = state;
			element.dataset.runState = state;
			element.dataset.camera = config.camera;
			element.dataset.progress = currentPoint.progress.toFixed(4);
			element.dataset.trackSignature = track.signature;
			element.dataset.color = config.color;
			element.dataset.duration = track.duration.toFixed(3);
			element.dataset.speed = currentPoint.speed.toFixed(3);
			element.dataset.segment = currentPoint.kind;
			element.dataset.runupDuration = track.runup.duration.toFixed(3);
			element.dataset.reducedMotion = String(reducedMotion);
			element.dataset.airborne = String(currentPoint.airborne);
		}
	};
	const render = () => {
		if (disposed) return;
		diagnostic();
		renderer.render(scene, camera);
		for (const element of new Set([container, canvas]))
			element.dataset.drawCalls = String(renderer.info?.render.calls ?? 0);
	};
	const overview = () => {
		camera.zoom = 1;
		camera.position.set(12, 13, 17);
		camera.lookAt(target);
		controls.target.copy(target);
		camera.updateProjectionMatrix();
		controls.update();
	};
	const updateCamera = (immediate = false, delta = 0) => {
		controls.enabled = config.camera === 'overview';
		if (config.camera !== 'follow') return;
		const tangent = vec(currentPoint.tangent);
		tangent.y = 0;
		tangent.normalize();
		followTarget.copy(marble.position).addScaledVector(tangent, 0.5);
		followPosition
			.copy(marble.position)
			.addScaledVector(tangent, -5.3)
			.add(new THREE.Vector3(2.6, 4, 2.6));
		const amount = immediate || reducedMotion ? 1 : 1 - Math.exp(-delta * 3.2);
		camera.position.lerp(followPosition, amount);
		controls.target.lerp(followTarget, amount);
		camera.zoom = 2.1;
		camera.lookAt(controls.target);
		camera.updateProjectionMatrix();
	};
	const placeMarble = (immediate = false, delta = 0) => {
		currentPoint = sampleRun(track, elapsed);
		marble.position.set(currentPoint.x, currentPoint.y + MARBLE_LIFT, currentPoint.z);
		marbleShadow.position.set(currentPoint.x, 0.012, currentPoint.z);
		const shadowSize = 0.55 + currentPoint.y * 0.07;
		marbleShadow.scale.set(shadowSize, shadowSize, 1);
		marbleShadow.material.opacity = 0.18 / (1 + currentPoint.y * 0.18);
		if (moved && !immediate) {
			const movement = marble.position.clone().sub(lastMarblePosition);
			axis.crossVectors(new THREE.Vector3(0, 1, 0), movement).normalize();
			if (movement.lengthSq() > 1e-12) {
				rotation.setFromAxisAngle(axis, movement.length() / MARBLE_RADIUS);
				marble.quaternion.premultiply(rotation);
			}
		} else marble.quaternion.identity();
		lastMarblePosition.copy(marble.position);
		moved = true;
		updateCamera(immediate, delta);
	};
	const tick = (now) => {
		frame = 0;
		if (disposed || state !== 'running' || document.hidden) return;
		// The path is sampled by time, so low frame rates must not slow the whole run.
		const delta = lastTime ? Math.max(0, (now - lastTime) / 1000) : 0;
		lastTime = now;
		elapsed = Math.min(track.duration, elapsed + delta);
		placeMarble(false, delta);
		if (elapsed >= track.duration) {
			state = 'finished';
			render();
			emit('finished');
		} else {
			render();
			frame = requestAnimationFrame(tick);
		}
	};
	const schedule = () => {
		cancelAnimationFrame(frame);
		frame = 0;
		lastTime = 0;
		if (!disposed && state === 'running' && !document.hidden) frame = requestAnimationFrame(tick);
	};
	const reset = () => {
		state = 'ready';
		elapsed = 0;
		schedule();
		placeMarble(true);
		render();
	};
	let lastWidth = 0;
	let lastHeight = 0;
	const resize = () => {
		const { width, height } = container.getBoundingClientRect();
		if (width === lastWidth && height === lastHeight) return;
		lastWidth = width;
		lastHeight = height;
		const aspect = Math.max(1, width) / Math.max(1, height);
		const viewHeight = Math.max(15.8, 15.5 / aspect);
		camera.left = (-viewHeight * aspect) / 2;
		camera.right = (viewHeight * aspect) / 2;
		camera.top = viewHeight / 2;
		camera.bottom = -viewHeight / 2;
		camera.updateProjectionMatrix();
		renderer.setSize(Math.max(1, width), Math.max(1, height), false);
		render();
	};
	const motionChange = () => {
		reducedMotion = media.matches;
		render();
	};
	const contextLost = (event) => {
		event.preventDefault();
		state = 'error';
		schedule();
		diagnostic();
		emit('error', '3D-visningen ble avbrutt. Last siden på nytt for å prøve igjen.');
	};
	const observer = new ResizeObserver(resize);
	observer.observe(container);
	document.addEventListener('visibilitychange', schedule);
	media.addEventListener('change', motionChange);
	canvas.addEventListener('webglcontextlost', contextLost);
	overview();
	placeMarble(true);
	resize();
	controls.addEventListener('change', render);
	return {
		launch() {
			if (state === 'running' || state === 'error') return;
			elapsed = 0;
			state = 'running';
			placeMarble(true);
			render();
			emit('started');
			schedule();
		},
		reset,
		configure(nextConfig) {
			config = normalizeConfig(nextConfig);
			state = 'ready';
			schedule();
			scene.remove(course);
			releaseTree(course);
			track = buildTrack(config.segments);
			course = createCourse(track);
			scene.add(course);
			renderer.shadowMap.needsUpdate = true;
			glass.color.set(COLORS[config.color]);
			if (config.camera === 'overview') overview();
			reset();
			emit('ready');
		},
		camera(mode) {
			config.camera = mode === 'follow' ? 'follow' : 'overview';
			if (config.camera === 'overview') overview();
			updateCamera(true);
			render();
		},
		dispose() {
			disposed = true;
			cancelAnimationFrame(frame);
			observer.disconnect();
			controls.removeEventListener('change', render);
			controls.dispose();
			document.removeEventListener('visibilitychange', schedule);
			media.removeEventListener('change', motionChange);
			canvas.removeEventListener('webglcontextlost', contextLost);
			releaseTree(scene);
			environmentMap.dispose();
			sunlight.shadow.dispose();
			renderer.dispose();
			renderer.forceContextLoss();
			if (!existingCanvas) canvas.remove();
		},
	};
}

export function dispose() {
	generation += 1;
	cancelAnimationFrame(mountFrame);
	mountFrame = 0;
	pendingLaunch = false;
	world?.dispose();
	world = null;
}

function mount(config, send) {
	dispose();
	pendingConfig = normalizeConfig(config);
	const current = generation;
	let attempts = 0;
	const emit = (action, message) => {
		if (generation === current) send({ domain: 'marble', action, ...(message ? { message } : {}) });
	};
	const start = () => {
		mountFrame = 0;
		if (generation !== current) return;
		const container = document.getElementById('marble-canvas');
		if (!container) {
			attempts += 1;
			if (attempts < 120) mountFrame = requestAnimationFrame(start);
			else emit('error', 'Fant ikke 3D-visningen. Last siden på nytt for å prøve igjen.');
			return;
		}
		try {
			world = createWorld(container, pendingConfig, emit);
			emit('ready');
			if (pendingLaunch) world.launch();
		} catch (error) {
			world?.dispose();
			world = null;
			container.dataset.state = 'error';
			console.error('Could not initialize marble track:', error);
			emit('error', 'Nettleseren kunne ikke starte 3D-banen. Prøv en nettleser med WebGL-støtte.');
		}
	};
	mountFrame = requestAnimationFrame(start);
}

export function handle(command, send) {
	if (command.domain !== 'marble') return;
	switch (command.action) {
		case 'mount':
			mount(command.config ?? command.data ?? {}, send);
			break;
		case 'configure':
			pendingConfig = normalizeConfig(command.config ?? command.data ?? {});
			pendingLaunch = false;
			world?.configure(pendingConfig);
			break;
		case 'launch':
			pendingLaunch = true;
			world?.launch();
			break;
		case 'reset':
			pendingLaunch = false;
			world?.reset();
			break;
		case 'camera': {
			const mode = command.camera ?? command.data?.camera ?? command.data;
			pendingConfig.camera = mode === 'follow' ? 'follow' : 'overview';
			world?.camera(pendingConfig.camera);
			break;
		}
		case 'dispose':
			dispose();
			break;
		default:
			break;
	}
}
