import { error } from '@sveltejs/kit';
import { projects } from '$lib/projects';
import type { PageLoad } from './$types';

export const load: PageLoad = ({ params }) => {
	const project = projects.find((p) => p.id === params.id);
	if (!project) throw error(404, 'Prosjekt ikke funnet');
	return { project };
};
