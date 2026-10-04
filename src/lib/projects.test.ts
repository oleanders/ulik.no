import { describe, expect, it } from 'vitest';

import { categoryLabels, getOnwardProjects, pickSurprise, projects } from './projects';

describe('projects', () => {
	it('has unique ids and matching project routes', () => {
		const ids = projects.map((project) => project.id);
		expect(new Set(ids).size).toBe(ids.length);

		for (const project of projects) {
			expect(project.href).toBe(`/projects/${project.id}`);
		}
	});

	it('exposes at least one project card', () => {
		expect(projects.length).toBeGreaterThan(0);
		expect(projects.every((project) => project.tags.length > 0)).toBe(true);
	});
});

describe('discovery', () => {
	it('gives every project an experience category and an honest hook', () => {
		for (const project of projects) {
			expect(categoryLabels[project.category]).toBeTruthy();
			expect(project.hook.length).toBeGreaterThan(5);
			expect(project.interaction.length).toBeGreaterThan(5);
		}
	});

	it('only surprises with active projects and excludes the current project', () => {
		for (const current of projects) {
			for (let i = 0; i <= 100; i++) {
				const next = pickSurprise(current.id, () => i / 100);
				expect(next.status).toBe('active');
				expect(next.id).not.toBe(current.id);
			}
		}
	});

	it('offers distinct active onward routes without recommending the current page', () => {
		for (const project of projects) {
			const { related, different } = getOnwardProjects(project.id);
			expect(different).toBeDefined();
			expect(different?.category).not.toBe(project.category);
			for (const next of [related, different].filter(Boolean)) {
				expect(next?.id).not.toBe(project.id);
				expect(next?.status).toBe('active');
			}
			if (related) expect(related.id).not.toBe(different?.id);
		}
	});

	it('does not invent onward routes for unknown ids', () => {
		expect(getOnwardProjects('unknown')).toEqual({});
	});
});
