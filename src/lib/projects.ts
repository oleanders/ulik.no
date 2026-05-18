import type { Project } from './types';

export const projects: Project[] = [
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
