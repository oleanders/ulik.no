import type { Project } from './types';

export const projects: Project[] = [
	{
		id: 'fall-haug',
		title: 'fall≠ned',
		description: 'Se alle elementer falle ned og lande i en haug på bunnen.',
		tags: ['animasjon', 'css', 'eksperiment'],
		href: '/projects/fall-haug',
		status: 'active',
	},
	{
		id: 'flyt-felt',
		title: 'flyt≠felt',
		description: 'Et abstrakt, bevegelig bilde generert av et flow field på canvas.',
		tags: ['canvas', 'generativ', 'animasjon'],
		href: '/projects/flyt-felt',
		status: 'active',
	},
	{
		id: 'prompt-lab',
		title: 'prompt≠lab',
		description: 'Eksperimenter med AI-prompts og se hva som skjer.',
		tags: ['ai', 'llm', 'prompting'],
		href: '/projects/prompt-lab',
		status: 'wip',
	},
	{
		id: 'diff-tool',
		title: 'tekst≠diff',
		description: 'Sammenlign to tekster og finn forskjellene.',
		tags: ['verktøy', 'tekst'],
		href: '/projects/diff-tool',
		status: 'active',
	},
];
