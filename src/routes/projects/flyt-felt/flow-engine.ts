import { configQuery, type FlowConfig, seededRandom } from './flow-config';

const WIDTH = 960;
const HEIGHT = 540;
const STEP_MS = 1000 / 60;

type Particle = { x: number; y: number; vx: number; vy: number; life: number; color: string };
export type FlowController = {
	configure: (config: FlowConfig) => void;
	resize: (width: number, height: number, pixelRatio: number) => void;
	setRunning: (running: boolean) => void;
	setVisible: (visible: boolean) => void;
	setPointer: (x: number, y: number) => void;
	clearPointer: () => void;
	restart: () => void;
	destroy: () => void;
};

/** Fixed simulation coordinates and time steps keep a seed independent of viewport and refresh rate. */
export function createFlowField(
	canvas: HTMLCanvasElement,
	initialConfig: FlowConfig,
): FlowController | null {
	const context = canvas.getContext('2d', { alpha: false });
	if (!context) return null;
	const ctx = context;
	let config = { ...initialConfig };
	let random = seededRandom(config.seed);
	let particles: Particle[] = [];
	let time = 0;
	let offset = 0;
	let raf = 0;
	let lastTime = 0;
	let elapsed = 0;
	let running = false;
	let visible = true;
	let destroyed = false;
	let pointer: { x: number; y: number } | null = null;

	function resetParticle(particle: Particle): void {
		particle.x = random() * WIDTH;
		particle.y = random() * HEIGHT;
		particle.vx = 0;
		particle.vy = 0;
		particle.life = 150 + random() * 250;
		particle.color = `hsla(${(config.hue + random() * 65) % 360}, 90%, 65%, 0.7)`;
	}

	function drawStep(): void {
		time += config.speed;
		ctx.fillStyle = 'rgba(10, 10, 10, 0.045)';
		ctx.fillRect(0, 0, WIDTH, HEIGHT);
		for (const p of particles) {
			const field =
				Math.sin(p.x * 0.0035 + time * 0.0008 + offset) +
				Math.cos(p.y * 0.0042 + time * 0.0011 + offset) +
				Math.sin((p.x + p.y) * 0.002 + time * 0.0005);
			let angle = field * Math.PI;
			if (config.preset === 'virvel') {
				angle = Math.atan2(p.y - HEIGHT / 2, p.x - WIDTH / 2) + Math.PI / 2 + field * 0.5;
			} else if (config.preset === 'glod') {
				angle += Math.sin(p.y * 0.018 + offset + time * 0.004) * 1.5;
			}
			p.vx = p.vx * 0.85 + Math.cos(angle) * 0.9;
			p.vy = p.vy * 0.85 + Math.sin(angle) * 0.9;
			if (pointer) {
				const dx = pointer.x - p.x;
				const dy = pointer.y - p.y;
				const distance = Math.hypot(dx, dy);
				if (distance > 0.5 && distance < 140) {
					const force = (1 - distance / 140) * config.attraction * 4;
					p.vx += (dx / distance) * force;
					p.vy += (dy / distance) * force;
				}
			}
			p.x += p.vx * config.speed;
			p.y += p.vy * config.speed;
			p.life -= config.speed;
			if (p.x < 0 || p.x > WIDTH || p.y < 0 || p.y > HEIGHT || p.life <= 0) resetParticle(p);
			ctx.fillStyle = p.color;
			ctx.fillRect(p.x, p.y, 1.3, 1.3);
		}
	}

	function restart(): void {
		random = seededRandom(config.seed);
		offset = random() * Math.PI * 2;
		time = 0;
		elapsed = 0;
		lastTime = 0;
		pointer = null;
		particles = Array.from({ length: config.density }, () => {
			const particle = { x: 0, y: 0, vx: 0, vy: 0, life: 0, color: '' };
			resetParticle(particle);
			return particle;
		});
		ctx.fillStyle = '#0a0a0a';
		ctx.fillRect(0, 0, WIDTH, HEIGHT);
		// A deterministic still composition is also useful with reduced motion or while paused.
		for (let i = 0; i < 70; i++) drawStep();
	}

	function tick(now: number): void {
		raf = 0;
		if (destroyed || !running || !visible) return;
		if (lastTime) elapsed += Math.min(now - lastTime, STEP_MS * 3);
		lastTime = now;
		while (elapsed >= STEP_MS) {
			drawStep();
			elapsed -= STEP_MS;
		}
		raf = requestAnimationFrame(tick);
	}

	function schedule(): void {
		cancelAnimationFrame(raf);
		raf = 0;
		lastTime = 0;
		elapsed = 0;
		if (running && visible && !destroyed) raf = requestAnimationFrame(tick);
	}

	return {
		configure(next) {
			if (configQuery(next) === configQuery(config)) return;
			config = { ...next };
			restart();
		},
		resize(width, height, pixelRatio) {
			const ratio = Math.max(1, Math.min(2, pixelRatio || 1));
			const pixelWidth = Math.max(1, Math.round(width * ratio));
			const pixelHeight = Math.max(1, Math.round(height * ratio));
			if (canvas.width === pixelWidth && canvas.height === pixelHeight) return;
			canvas.width = pixelWidth;
			canvas.height = pixelHeight;
			ctx.setTransform(pixelWidth / WIDTH, 0, 0, pixelHeight / HEIGHT, 0, 0);
			restart();
		},
		setRunning(value) {
			running = value;
			schedule();
		},
		setVisible(value) {
			visible = value;
			schedule();
		},
		setPointer(x, y) {
			pointer = { x: Math.min(1, Math.max(0, x)) * WIDTH, y: Math.min(1, Math.max(0, y)) * HEIGHT };
		},
		clearPointer() {
			pointer = null;
		},
		restart,
		destroy() {
			destroyed = true;
			cancelAnimationFrame(raf);
			particles = [];
		},
	};
}
