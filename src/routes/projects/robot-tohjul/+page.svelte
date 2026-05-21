<script lang="ts">
import { Canvas, T } from '@threlte/core';
import { OrbitControls } from '@threlte/extras';
import { onMount } from 'svelte';

let x = $state(0);
let z = $state(0);
let yaw = $state(0);
let speed = $state(0);
let turn = $state(0);
let wheelSpin = $state(0);
let tiltX = $state(0);
let tiltZ = $state(0);
let hop = $state(0);
let crashMode = $state(false);

const wheelRadius = 0.24;
const robotHitRadius = 0.58;
const worldLimit = 8.5;
const pressed = new Set<string>();

const obstacles = [
	{ x: -4.6, z: -2.6, size: [1.1, 1.1, 1.1] },
	{ x: -2.8, z: 3.3, size: [1.2, 1.4, 1.2] },
	{ x: 0.8, z: -3.9, size: [1.5, 0.8, 1.5] },
	{ x: 3.6, z: 2.8, size: [1.1, 1.1, 1.1] },
	{ x: 5.5, z: -1.7, size: [1.6, 1.3, 1.2] },
];

const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
const getCollision = (nx: number, nz: number) =>
	obstacles.find((obstacle) => {
		const halfX = obstacle.size[0] / 2 + robotHitRadius;
		const halfZ = obstacle.size[2] / 2 + robotHitRadius;
		return Math.abs(nx - obstacle.x) <= halfX && Math.abs(nz - obstacle.z) <= halfZ;
	});

onMount(() => {
	let rafId = 0;
	let lastTime = performance.now();
	let crashRemaining = 0;
	const crashDuration = 1.08;
	let reboundRemaining = 0;
	let reboundYaw = 0;
	let reboundSpin = 0;
	let collisionLock = 0;

	const nudgeOutOfCollision = (escapeYaw: number) => {
		for (let i = 0; i < 12; i++) {
			if (!getCollision(x, z)) return;
			x = clamp(x + Math.sin(escapeYaw) * 0.28, -worldLimit, worldLimit);
			z = clamp(z + Math.cos(escapeYaw) * 0.28, -worldLimit, worldLimit);
		}
	};

	const startCrash = (hit?: (typeof obstacles)[number]) => {
		const angleAway =
			hit && (Math.abs(x - hit.x) > 0.0001 || Math.abs(z - hit.z) > 0.0001)
				? Math.atan2(x - hit.x, z - hit.z)
				: yaw + Math.PI;
		crashRemaining = crashDuration;
		reboundRemaining = 0;
		reboundSpin = 0;
		collisionLock = 1.6;
		reboundYaw = angleAway + (Math.random() - 0.5) * 0.7;
		crashMode = true;
	};

	const down = (event: KeyboardEvent) => {
		if (event.repeat) return;
		pressed.add(event.key.toLowerCase());
	};
	const up = (event: KeyboardEvent) => {
		pressed.delete(event.key.toLowerCase());
	};

	window.addEventListener('keydown', down);
	window.addEventListener('keyup', up);

	const tick = (now: number) => {
		const delta = Math.min(0.05, (now - lastTime) / 1000);
		lastTime = now;
		collisionLock = Math.max(0, collisionLock - delta);
		hop = Math.max(0, hop - delta * 2.4);

		if (crashRemaining > 0) {
			crashRemaining = Math.max(0, crashRemaining - delta);
			const t = 1 - crashRemaining / crashDuration;
			const toppleIn = Math.min(1, t / 0.35);
			const toppleOut = t > 0.82 ? Math.max(0, (1 - t) / 0.18) : 1;
			const topple = toppleIn * toppleOut;
			const shakeStrength = t > 0.16 && t < 0.78 ? Math.max(0, 1 - Math.abs(t - 0.47) / 0.31) : 0;
			tiltX = -1.02 * topple + Math.sin(now * 0.06) * 0.08 * shakeStrength;
			tiltZ = Math.cos(now * 0.082) * 0.08 * shakeStrength;
			speed *= 0.8;
			turn *= 0.62;
			wheelSpin += (speed / wheelRadius) * delta;

			if (crashRemaining === 0) {
				reboundRemaining = 0.78;
				yaw = reboundYaw;
				speed = 3.5;
				turn = 0;
				hop = 0.12;
				reboundSpin = (Math.random() < 0.5 ? -1 : 1) * (5 + Math.random() * 4);
				nudgeOutOfCollision(yaw);
				crashMode = false;
				tiltX = 0;
				tiltZ = 0;
			}

			rafId = requestAnimationFrame(tick);
			return;
		}

		if (reboundRemaining > 0) {
			reboundRemaining = Math.max(0, reboundRemaining - delta);
			const reboundStrength = reboundRemaining / 0.78;
			const reboundPhase = 1 - reboundStrength;
			yaw += reboundSpin * delta;
			reboundSpin *= Math.max(0, 1 - delta * 3.2);
			speed += (3 * reboundStrength - speed) * Math.min(1, delta * 7);
			hop = Math.max(
				hop,
				Math.sin(reboundPhase * Math.PI) * 0.14 * reboundStrength + 0.02 * reboundStrength,
			);
			const nextX = clamp(x + Math.sin(yaw) * speed * delta, -worldLimit, worldLimit);
			const nextZ = clamp(z + Math.cos(yaw) * speed * delta, -worldLimit, worldLimit);
			const hit = getCollision(nextX, nextZ);
			if (hit && collisionLock <= 0) {
				startCrash(hit);
			} else {
				x = nextX;
				z = nextZ;
			}
			wheelSpin += (speed / wheelRadius) * delta;
			rafId = requestAnimationFrame(tick);
			return;
		}

		const forward = pressed.has('w') || pressed.has('arrowup');
		const backward = pressed.has('s') || pressed.has('arrowdown');
		const left = pressed.has('a') || pressed.has('arrowleft');
		const right = pressed.has('d') || pressed.has('arrowright');

		const targetSpeed = (forward ? 2.8 : 0) + (backward ? -2 : 0);
		const targetTurn = (left ? 1.7 : 0) + (right ? -1.7 : 0);

		speed += (targetSpeed - speed) * Math.min(1, delta * 7);
		turn += (targetTurn - turn) * Math.min(1, delta * 9);

		yaw += turn * delta;
		const nextX = clamp(x + Math.sin(yaw) * speed * delta, -worldLimit, worldLimit);
		const nextZ = clamp(z + Math.cos(yaw) * speed * delta, -worldLimit, worldLimit);
		const hit = getCollision(nextX, nextZ);
		if (hit && collisionLock <= 0) {
			startCrash(hit);
		} else {
			x = nextX;
			z = nextZ;
		}
		wheelSpin += (speed / wheelRadius) * delta;

		rafId = requestAnimationFrame(tick);
	};

	rafId = requestAnimationFrame(tick);

	return () => {
		cancelAnimationFrame(rafId);
		window.removeEventListener('keydown', down);
		window.removeEventListener('keyup', up);
	};
});
</script>

<svelte:head>
	<title>robot≠tohjul — ≠ ulik.no</title>
</svelte:head>

<section class="terminal-panel head">
	<p class="prompt">$ ./robot-tohjul --simuler</p>
	<div class="head-row">
		<h1>robot≠tohjul</h1>
		<span class="status active">aktiv</span>
	</div>
	<p class="desc">
		Styr roboten med <strong>WASD</strong> eller piltaster. Den kjører på to hjul i en liten 3D-verden
		med hindringer. Treffer den en boks, krasjer den, rister, velter bakover, spretter rundt og kjører
		videre i tilfeldig retning.
	</p>
</section>

<div class="world terminal-panel">
	<Canvas>
		<T.PerspectiveCamera makeDefault position={[7, 6.2, 9]} fov={52} />
		<OrbitControls enablePan={false} maxDistance={20} minDistance={6} maxPolarAngle={1.35} />

		<T.AmbientLight intensity={0.55} />
		<T.DirectionalLight position={[6, 11, 5]} intensity={1.1} />
		<T.HemisphereLight intensity={0.35} />

		<T.Mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
			<T.PlaneGeometry args={[24, 24]} />
			<T.MeshStandardMaterial color="#0b1110" />
		</T.Mesh>

		{#each obstacles as obstacle}
			<T.Mesh position={[obstacle.x, obstacle.size[1] / 2, obstacle.z]}>
				<T.BoxGeometry args={obstacle.size} />
				<T.MeshStandardMaterial color="#1f2f2f" />
			</T.Mesh>
		{/each}

		<T.Group position={[x, hop, z]} rotation={[0, yaw, 0]}>
			<T.Group rotation={[tiltX, 0, tiltZ]}>
				<T.Mesh position={[0, 0.55, 0]}>
					<T.BoxGeometry args={[1.2, 0.45, 0.8]} />
					<T.MeshStandardMaterial color={crashMode ? '#ffd166' : '#00ccff'} />
				</T.Mesh>

				<T.Mesh position={[0, 0.9, 0]}>
					<T.BoxGeometry args={[0.7, 0.25, 0.6]} />
					<T.MeshStandardMaterial color="#00ff88" />
				</T.Mesh>

				<T.Mesh position={[0, 1.1, 0.22]}>
					<T.SphereGeometry args={[0.09, 16, 16]} />
					<T.MeshStandardMaterial color="#ffd166" emissive="#ad7e00" emissiveIntensity={0.35} />
				</T.Mesh>

				<T.Mesh position={[-0.56, 0.32, 0]} rotation={[wheelSpin, 0, Math.PI / 2]}>
					<T.CylinderGeometry args={[wheelRadius, wheelRadius, 0.2, 28]} />
					<T.MeshStandardMaterial color="#0f1616" />
				</T.Mesh>
				<T.Mesh position={[0.56, 0.32, 0]} rotation={[wheelSpin, 0, Math.PI / 2]}>
					<T.CylinderGeometry args={[wheelRadius, wheelRadius, 0.2, 28]} />
					<T.MeshStandardMaterial color="#0f1616" />
				</T.Mesh>

				<T.Mesh position={[0, 0.14, -0.24]}>
					<T.SphereGeometry args={[0.1, 12, 12]} />
					<T.MeshStandardMaterial color="#2a3232" />
				</T.Mesh>
			</T.Group>
		</T.Group>
	</Canvas>
</div>

<style>
	.head {
		display: grid;
		gap: 0.75rem;
		margin-bottom: 1.25rem;
	}

	.head-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	h1,
	p {
		margin: 0;
	}

	.desc {
		max-width: 65ch;
		color: var(--color-text-soft);
	}

	.status {
		padding: 0.25rem 0.55rem;
		border-radius: 999px;
		border: 1px solid currentColor;
		font-size: 0.8rem;
	}

	.status.active {
		color: var(--color-primary);
	}

	.world {
		padding: 0;
		overflow: hidden;
		aspect-ratio: 16 / 10;
		min-height: 430px;
	}

	.world :global(canvas) {
		display: block;
		width: 100%;
		height: 100%;
		cursor: grab;
	}

	@media (max-width: 780px) {
		.world {
			aspect-ratio: 4 / 3;
			min-height: 360px;
		}
	}
</style>
