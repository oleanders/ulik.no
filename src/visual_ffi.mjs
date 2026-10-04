// Browser primitives only. Configuration, controls and all page state live in Gleam.

export {
	dispose as disposeFalling,
	drop as dropFalling,
	reset as resetFalling,
} from './browser/falling.js';
export {
	clearPointer as clearFlowPointer,
	configure as configureFlow,
	dispose as disposeFlow,
	mount as mountFlow,
	newSeed as newFlowSeed,
	restart as restartFlow,
	savePng as saveFlowPng,
	selectShare as selectFlowShare,
	setPointer as pointFlow,
	setRunning as runFlow,
	share as shareFlow,
} from './browser/flow.js';
export {
	dispose as disposeRobot,
	mount as mountRobot,
	reset as resetRobot,
	setInput as inputRobot,
	setRunning as runRobot,
} from './browser/robot-loader.js';
export function locationHref() {
	return window.location.href;
}
