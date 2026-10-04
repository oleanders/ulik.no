import { dispose, mountPreview, newPattern, setPlaying } from './browser/preview.js';

export { dispose, mountPreview, newPattern, setPlaying };

export function randomIndex(length) {
	return Math.floor(Math.random() * length);
}

export function navigate(href) {
	window.dispatchEvent(new CustomEvent('ulik:navigate', { detail: href }));
}
