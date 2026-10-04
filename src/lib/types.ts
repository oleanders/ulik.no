export type ProjectCategory = 'lek' | 'kunst' | 'verktoy';

export type Project = {
	id: string;
	title: string;
	description: string;
	hook: string;
	interaction: string;
	category: ProjectCategory;
	tags: string[];
	href: string;
	status: 'active' | 'wip' | 'idea';
};
