let cleanup = () => {};
let syncPlayback = () => {};
let changePattern = () => {};
let paused = true;
let reducedMotion = false;
let notify = () => {};
let mountFrame = 0;
function sendState() {
	notify(reducedMotion, !paused);
}
export function dispose() {
	cancelAnimationFrame(mountFrame);
	cleanup();
	cleanup = () => {};
	notify = () => {};
}
export function mountPreview(onState) {
	dispose();
	notify = onState;
	mountFrame = requestAnimationFrame(() => {
		const canvas = document.getElementById('home-flow');
		if (canvas) cleanup = mount(canvas) || (() => {});
	});
}
export function setPlaying(playing) {
	paused = !playing;
	syncPlayback();
}
export function newPattern() {
	changePattern();
}

function mount(canvas) {
	const context = canvas.getContext('2d');
	if (!context) return;
	const ctx = context;
	const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
	let visible = false;
	let width = 0;
	let height = 0;
	let frame = 0;
	let raf = 0;
	let lastTime = 0;
	let variation = 0;
	let hue = 150;
	let pointer = null;
	let particles = [];
	function step() {
		frame++;
		ctx.fillStyle = 'rgba(10, 16, 15, 0.055)';
		ctx.fillRect(0, 0, width, height);
		for (const p of particles) {
			const angle =
				(Math.sin(p.x * 0.009 + variation) + Math.cos(p.y * 0.012 + frame * 0.002)) * Math.PI;
			let dx = Math.cos(angle) * 2;
			let dy = Math.sin(angle) * 2;
			if (pointer) {
				const distance = Math.hypot(p.x - pointer.x, p.y - pointer.y);
				if (distance > 1 && distance < 90) {
					dx += ((p.x - pointer.x) / distance) * 3;
					dy += ((p.y - pointer.y) / distance) * 3;
				}
			}
			ctx.strokeStyle = `hsla(${hue + p.x * 0.12}, 85%, 65%, 0.6)`;
			ctx.beginPath();
			ctx.moveTo(p.x, p.y);
			p.x += dx;
			p.y += dy;
			ctx.lineTo(p.x, p.y);
			ctx.stroke();
			if (--p.life < 0 || p.x < 0 || p.x > width || p.y < 0 || p.y > height) {
				p.x = Math.random() * width;
				p.y = Math.random() * height;
				p.life = 100 + Math.random() * 160;
			}
		}
	}
	function seed() {
		ctx.fillStyle = '#0a100f';
		ctx.fillRect(0, 0, width, height);
		particles = Array.from({ length: 180 }, () => ({
			x: Math.random() * width,
			y: Math.random() * height,
			life: 100 + Math.random() * 160,
		}));
		// A still composition is useful before playback and with reduced motion.
		for (let i = 0; i < 45; i++) step();
	}
	function tick(time) {
		if (time - lastTime >= 1000 / 30) {
			step();
			lastTime = time;
		}
		raf = requestAnimationFrame(tick);
	}
	syncPlayback = () => {
		cancelAnimationFrame(raf);
		if (!paused && visible && !document.hidden && width > 0) {
			lastTime = 0;
			raf = requestAnimationFrame(tick);
		}
	};
	changePattern = () => {
		variation += 0.8;
		hue = (hue + 45) % 360;
		seed();
	};
	const resize = new ResizeObserver(() => {
		const rect = canvas.getBoundingClientRect();
		if (!rect.width || !rect.height || (width === rect.width && height === rect.height)) return;
		width = rect.width;
		height = rect.height;
		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		canvas.width = Math.round(width * dpr);
		canvas.height = Math.round(height * dpr);
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		seed();
		syncPlayback();
	});
	const intersection = new IntersectionObserver(([entry]) => {
		visible = entry.isIntersecting;
		syncPlayback();
	});
	const updateMotion = () => {
		reducedMotion = motion.matches;
		paused = motion.matches;
		sendState();
		syncPlayback();
	};
	const updatePointer = (event) => {
		const rect = canvas.getBoundingClientRect();
		pointer = { x: event.clientX - rect.left, y: event.clientY - rect.top };
	};
	const clearPointer = () => {
		pointer = null;
	};
	updateMotion();
	resize.observe(canvas);
	intersection.observe(canvas);
	motion.addEventListener('change', updateMotion);
	document.addEventListener('visibilitychange', syncPlayback);
	canvas.addEventListener('pointermove', updatePointer);
	canvas.addEventListener('pointerdown', updatePointer);
	canvas.addEventListener('pointerleave', clearPointer);
	canvas.addEventListener('pointercancel', clearPointer);
	canvas.addEventListener('pointerup', clearPointer);
	sendState();
	return () => {
		cancelAnimationFrame(raf);
		resize.disconnect();
		intersection.disconnect();
		motion.removeEventListener('change', updateMotion);
		document.removeEventListener('visibilitychange', syncPlayback);
		canvas.removeEventListener('pointermove', updatePointer);
		canvas.removeEventListener('pointerdown', updatePointer);
		canvas.removeEventListener('pointerleave', clearPointer);
		canvas.removeEventListener('pointercancel', clearPointer);
		canvas.removeEventListener('pointerup', clearPointer);
		syncPlayback = () => {};
		changePattern = () => {};
	};
}
