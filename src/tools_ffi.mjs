import { compareTextParts } from './browser/tools.js';
import { List$Empty, List$NonEmpty } from './gleam.mjs';

export { dispose, startSharing, stopSharing, supportsDisplayMedia } from './browser/tools.js';

/** Construct Gleam values using its public FFI list API and a typed constructor. */
export function compareText(left, right, byWords, change) {
	const parts = compareTextParts(left, right, byWords);
	let result = List$Empty();
	for (let index = parts.length - 1; index >= 0; index -= 1) {
		const part = parts[index];
		result = List$NonEmpty(
			change(part.value, part.count ?? 0, Boolean(part.added), Boolean(part.removed)),
			result,
		);
	}
	return result;
}

export function characterCount(value) {
	return value.length;
}
