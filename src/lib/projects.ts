import type { Project, ProjectCategory } from './types';

export const projects: Project[] = [
	{
		id: 'robot-tohjul',
		category: 'lek',
		hook: 'To hjul. Din kontroll.',
		interaction: 'Tastatur · 3D',
		title: 'robot≠tohjul',
		description: 'En to-hjuls robot som kjører rundt i en liten 3D-verden med tastaturstyring.',
		tags: ['threlte', '3d', 'robot'],
		href: '/projects/robot-tohjul',
		status: 'active',
	},
	{
		id: 'fall-haug',
		category: 'lek',
		hook: 'Hva om hele siden ga etter?',
		interaction: 'Trykk · kaos',
		title: 'fall≠ned',
		description: 'Se alle elementer falle ned og lande i en haug på bunnen.',
		tags: ['animasjon', 'css', 'eksperiment'],
		href: '/projects/fall-haug',
		status: 'active',
	},
	{
		id: 'flyt-felt',
		category: 'kunst',
		hook: 'Et lite dytt. Et helt nytt mønster.',
		interaction: 'Peker / berøring',
		title: 'flyt≠felt',
		description: 'Et abstrakt, bevegelig bilde generert av et flow field på canvas.',
		tags: ['canvas', 'generativ', 'animasjon'],
		href: '/projects/flyt-felt',
		status: 'active',
	},
	{
		id: 'fonetisk-alfabet',
		category: 'lek',
		hook: 'Hør ordet. Finn bokstaven.',
		interaction: 'Lyd · tastatur',
		title: 'fonetisk≠spill',
		description: 'Øv deg på det fonetiske alfabetet ved å høre ord og skriv riktige bokstaver.',
		tags: ['språk', 'spill', 'speech'],
		href: '/projects/fonetisk-alfabet',
		status: 'active',
	},
	{
		id: 'prompt-lab',
		category: 'verktoy',
		hook: 'Et laboratorium under bygging.',
		interaction: 'Kommer snart',
		title: 'prompt≠lab',
		description: 'Eksperimenter med AI-prompts og se hva som skjer.',
		tags: ['ai', 'llm', 'prompting'],
		href: '/projects/prompt-lab',
		status: 'wip',
	},
	{
		id: 'diff-tool',
		category: 'verktoy',
		hook: 'Finn det som ikke er likt.',
		interaction: 'Lim inn · sammenlign',
		title: 'tekst≠diff',
		description: 'Sammenlign to tekster og finn forskjellene.',
		tags: ['verktøy', 'tekst'],
		href: '/projects/diff-tool',
		status: 'active',
	},
	{
		id: 'skjermdeling-lab',
		category: 'verktoy',
		hook: 'Se hva nettleseren kan dele.',
		interaction: 'Skjerm · lokal visning',
		title: 'skjerm≠deling',
		description: 'Test skjermdeling direkte i nettleseren med getDisplayMedia.',
		tags: ['webrtc', 'media', 'eksperiment'],
		href: '/projects/skjermdeling-lab',
		status: 'active',
	},
	{
		id: 'morsekode',
		category: 'lek',
		hook: 'Prikk. Strek. Knekk koden.',
		interaction: 'Lyd · berøring / tastatur',
		title: 'morse≠kode',
		description: 'Øv deg på å sende og motta morsekode med lyd, lys og tommelen.',
		tags: ['spill', 'morse', 'lyd'],
		href: '/projects/morsekode',
		status: 'active',
	},
];

export const categoryLabels: Record<ProjectCategory, string> = {
	lek: 'Lek og lær',
	kunst: 'Generativ kunst',
	verktoy: 'Små verktøy',
};

/** Discovery always leads to something playable, never a placeholder. */
export function pickSurprise(excludeId?: string, random: () => number = Math.random): Project {
	const candidates = projects.filter(
		(project) => project.status === 'active' && project.id !== excludeId,
	);
	return candidates[
		Math.min(candidates.length - 1, Math.max(0, Math.floor(random() * candidates.length)))
	];
}

export function getOnwardProjects(id: string): { related?: Project; different?: Project } {
	const current = projects.find((project) => project.id === id);
	if (!current) return {};
	const candidates = projects.filter((project) => project.status === 'active' && project.id !== id);
	// If this is the only project in its category, shared tags give a useful next step.
	const related =
		candidates.find((project) => project.category === current.category) ??
		candidates.find((project) => project.tags.some((tag) => current.tags.includes(tag)));
	const different = candidates.find(
		(project) => project.category !== current.category && project.id !== related?.id,
	);
	return { related, different };
}
