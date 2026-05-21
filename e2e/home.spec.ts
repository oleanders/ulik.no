import { expect, test } from '@playwright/test';

test('homepage shows terminal hero and projects', async ({ page }) => {
	await page.goto('/');

	await expect(page.getByRole('heading', { name: 'ulik.no' })).toBeVisible();
	await expect(page.getByText('ulik alt annet.')).toBeVisible();
	await expect(page.getByText('prompt≠lab')).toBeVisible();
	await expect(page.getByText('tekst≠diff')).toBeVisible();
});

test('project placeholder page renders', async ({ page }) => {
	await page.goto('/projects/prompt-lab');

	await expect(page.getByRole('heading', { name: 'prompt≠lab' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Under konstruksjon' })).toBeVisible();
});
