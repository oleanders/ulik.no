export type Project = {
	id: string;
	title: string;
	description: string;
	tags: string[];
	href: string;
	status: 'active' | 'wip' | 'idea';
};
