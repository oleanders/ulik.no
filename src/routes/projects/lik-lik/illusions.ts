export type IllusionId = 'farge' | 'sirkler' | 'linjer';

export const TARGET_COLOR = '#82978b';
export const TARGET_RADIUS = 28;
export const TARGET_LENGTH = 280;
export const INITIAL_STRENGTH = 100;

export const illusions: {
	id: IllusionId;
	title: string;
	question: string;
	explanation: string;
	source: string;
	sourceLabel: string;
}[] = [
	{
		id: 'farge',
		title: 'Samme farge',
		question: 'Ser A og B ut som samme farge?',
		explanation:
			'Begge feltene har nøyaktig samme fargekode. En lys bakgrunn kan få et felt til å se mørkere ut, og en mørk bakgrunn kan få det til å se lysere ut. Dette kalles simultankontrast.',
		source: 'https://annex.exploratorium.edu/exhibits/mix_n_match/',
		sourceLabel: 'Exploratorium om farge og kontrast',
	},
	{
		id: 'sirkler',
		title: 'Samme sirkel',
		question: 'Hvilken midtsirkel ser størst ut, A eller B?',
		explanation:
			'Midtsirklene har samme radius. Størrelsen og plasseringen på sirklene rundt kan påvirke hvor store de ser ut. Dette er Ebbinghaus-illusjonen. Fjern omgivelsene og sammenlign igjen.',
		source: 'https://michaelbach.de/ot/cog-Ebbinghaus/index.html',
		sourceLabel: 'Michael Bach om Ebbinghaus-illusjonen',
	},
	{
		id: 'linjer',
		title: 'Samme linje',
		question: 'Ser den vannrette linjen A eller B lengst ut?',
		explanation:
			'De vannrette strekene har samme lengde. Vinklene ved endene kan påvirke hvordan vi bedømmer lengden. Dette er Müller-Lyer-illusjonen. Målelinjene viser hvor strekene begynner og slutter.',
		source: 'https://michaelbach.de/ot/sze-muelue/index.html',
		sourceLabel: 'Michael Bach om Müller-Lyer-illusjonen',
	},
];

/** Only the surroundings change. The target color and dimensions stay fixed. */
export function contextOpacity(strength: number, revealed: boolean): number {
	return revealed ? 0 : Math.max(0, Math.min(100, strength)) / 100;
}

export function surroundingCircles(
	x: number,
	radius: number,
	distance: number,
): { x: number; y: number; radius: number }[] {
	return Array.from({ length: 6 }, (_, index) => {
		const angle = (index / 6) * Math.PI * 2;
		return { x: x + Math.cos(angle) * distance, y: 135 + Math.sin(angle) * distance, radius };
	});
}

export function lineEndpoints(): { x1: number; x2: number } {
	return { x1: 220, x2: 220 + TARGET_LENGTH };
}
