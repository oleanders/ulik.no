import { describe, expect, it } from 'vitest';

import { projects } from './projects';

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
