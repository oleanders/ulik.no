let generation = 0;
let mountFrame = 0;
let layer = null;
let snapshots = [];
let animations = [];
let previousOverflow = null;
let removeListeners = () => {};

const selectors = [
	'header .logo',
	'header .menu-link',
	'main .terminal-panel',
	'main h1',
	'main p',
	'main button',
	'main textarea',
	'main canvas',
	'main .card',
	'footer > span',
	'footer > a',
].join(',');

/** Restore original nodes rather than replacing them: Elm keeps ownership of its DOM. */
function reset() {
	generation += 1;
	cancelAnimationFrame(mountFrame);
	mountFrame = 0;
	for (const animation of animations) animation.cancel();
	animations = [];
	layer?.remove();
	layer = null;
	for (const { element, visibility, priority } of snapshots) {
		if (visibility) element.style.setProperty('visibility', visibility, priority);
		else element.style.removeProperty('visibility');
	}
	snapshots = [];
	if (previousOverflow !== null) {
		if (previousOverflow.value)
			document.body.style.setProperty(
				'overflow',
				previousOverflow.value,
				previousOverflow.priority,
			);
		else document.body.style.removeProperty('overflow');
		previousOverflow = null;
	}
	removeListeners();
	removeListeners = () => {};
}

export function dispose() {
	reset();
}

function copyAppearance(source, clone) {
	// Clones leave their original ancestors, so preserve inherited and scoped styles.
	const computed = getComputedStyle(source);
	for (const property of Array.from(computed))
		clone.style.setProperty(property, computed.getPropertyValue(property));
	clone.removeAttribute('id');
	for (let index = 0; index < source.children.length; index++)
		copyAppearance(source.children[index], clone.children[index]);
}

function drop(send) {
	reset();
	const current = generation;
	const emit = (action, data) => {
		if (generation === current) send({ domain: 'falling', action, data });
	};
	const start = () => {
		if (generation !== current) return;
		if (!document.querySelector('.falling-page .head')) {
			mountFrame = requestAnimationFrame(start);
			return;
		}
		previousOverflow = {
			value: document.body.style.getPropertyValue('overflow'),
			priority: document.body.style.getPropertyPriority('overflow'),
		};
		document.body.style.overflow = 'hidden';
		const filtered = Array.from(document.querySelectorAll(selectors)).filter((element) => {
			if (element.closest('[data-no-fall]')) return false;
			const rect = element.getBoundingClientRect();
			return rect.width > 12 && rect.height > 12;
		});
		const targets = filtered.filter(
			(element) => !filtered.some((other) => other !== element && other.contains(element)),
		);
		layer = document.createElement('div');
		layer.className = 'falling-layer';
		layer.setAttribute('aria-hidden', 'true');
		layer.inert = true;
		document.body.append(layer);
		const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
		const floorY = window.innerHeight - 95;
		const completed = [];

		for (const [index, element] of targets.entries()) {
			const rect = element.getBoundingClientRect();
			const clone = element.cloneNode(true);
			copyAppearance(element, clone);
			clone.setAttribute('aria-hidden', 'true');
			clone.classList.add('fall-clone');
			Object.assign(clone.style, {
				position: 'fixed',
				left: `${rect.left}px`,
				top: `${rect.top}px`,
				width: `${rect.width}px`,
				height: `${rect.height}px`,
				margin: '0',
				zIndex: '9999',
				pointerEvents: 'none',
				transformOrigin: 'center',
				boxShadow: '0 8px 22px rgba(0, 0, 0, 0.36)',
			});
			layer.append(clone);
			snapshots.push({
				element,
				visibility: element.style.getPropertyValue('visibility'),
				priority: element.style.getPropertyPriority('visibility'),
			});
			element.style.visibility = 'hidden';

			const dx = (Math.random() - 0.5) * Math.min(90, rect.width * 0.45);
			const dy = floorY - Math.random() * 70 - (rect.top + rect.height / 2);
			const rotation = (Math.random() - 0.5) * 78;
			const shakeX = Math.max(3, Math.min(12, rect.width * 0.08));
			const shakeY = Math.max(2, Math.min(8, rect.height * 0.06));
			const delay = 280 + index * 28 + Math.random() * 70 + (element.closest('.head') ? 750 : 0);
			const duration = 1450 + Math.abs(dy) * 1.25 + Math.random() * 360;
			const resting = `translate3d(${dx}px, ${dy}px, 0) rotate(${rotation}deg)`;
			if (reducedMotion.matches || typeof clone.animate !== 'function') {
				clone.style.transform = resting;
				continue;
			}
			const animation = clone.animate(
				[
					{ transform: 'translate3d(0, 0, 0) rotate(0deg)' },
					{
						transform: `translate3d(${-shakeX}px, ${-shakeY}px, 0) rotate(${-3 - Math.random() * 2}deg)`,
						offset: 0.08,
					},
					{
						transform: `translate3d(${shakeX}px, ${shakeY}px, 0) rotate(${3 + Math.random() * 2}deg)`,
						offset: 0.16,
					},
					{
						transform: `translate3d(${-shakeX * 0.7}px, ${-shakeY * 0.5}px, 0) rotate(${-2 - Math.random()}deg)`,
						offset: 0.33,
					},
					{
						transform: `translate3d(${dx * 0.9}px, ${dy - 14}px, 0) rotate(${rotation * 0.58}deg)`,
						offset: 0.88,
					},
					{
						transform: `translate3d(${dx}px, ${dy + 8}px, 0) rotate(${rotation}deg)`,
						offset: 0.94,
					},
					{ transform: resting },
				],
				{ duration, delay, easing: 'cubic-bezier(0.18, 0.65, 0.2, 1)', fill: 'forwards' },
			);
			animations.push(animation);
			completed.push(animation.finished);
		}
		const handleEscape = (event) => {
			if (event.key === 'Escape') emit('reset', 0);
		};
		const motion = () => {
			if (reducedMotion.matches) for (const animation of animations) animation.finish();
		};
		window.addEventListener('keydown', handleEscape);
		reducedMotion.addEventListener('change', motion);
		removeListeners = () => {
			window.removeEventListener('keydown', handleEscape);
			reducedMotion.removeEventListener('change', motion);
		};
		emit('count', targets.length);
		Promise.allSettled(completed).then(() => emit('settled', 0));
	};
	mountFrame = requestAnimationFrame(start);
}

export function handle(command, send) {
	if (command.domain !== 'falling') return;
	switch (command.action) {
		case 'mount':
		case 'drop':
			drop(send);
			break;
		case 'reset':
		case 'dispose':
			reset();
			break;
		default:
			break;
	}
}
