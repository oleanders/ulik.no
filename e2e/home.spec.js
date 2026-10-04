import { expect, test } from '@playwright/test';

test('homepage invites discovery with an interactive preview and selected projects', async ({
	page,
}, testInfo) => {
	await page.goto('/');
	await expect(page.getByRole('heading', { name: 'ulik.no', exact: true })).toBeVisible();
	await expect(page.getByText('ulik alt annet.')).toBeVisible();
	await expect(page.getByRole('link', { name: 'Lek med flyt≠felt' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'fall≠ned' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'morse≠kode' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'tekst≠diff' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Pause bevegelse' })).toBeEnabled();
	await page.screenshot({ path: testInfo.outputPath('home-desktop.png'), fullPage: true });
	await page.getByRole('button', { name: 'Pause bevegelse' }).click();
	await expect(page.getByRole('button', { name: 'Start bevegelse' })).toHaveAttribute(
		'aria-pressed',
		'false',
	);
	await page.getByRole('button', { name: 'Nytt mønster' }).click();
	await page.getByRole('button', { name: 'Start bevegelse' }).press('Enter');
	await expect(page.getByRole('button', { name: 'Pause bevegelse' })).toHaveAttribute(
		'aria-pressed',
		'true',
	);
});
test('catalog filters and resets without losing project links', async ({ page }) => {
	await page.goto('/projects');
	await expect(page.getByRole('status')).toContainText('Viser 10 av 10');
	await page.getByRole('button', { name: 'Generativ kunst' }).click();
	await expect(page.getByRole('heading', { name: 'flyt≠felt' })).toBeVisible();
	await expect(page.getByRole('status')).toContainText('Viser 2 av 10');
	await page.getByRole('button', { name: 'Små verktøy' }).press('Enter');
	await expect(page.getByRole('heading', { name: 'prompt≠lab' })).toBeVisible();
	await expect(page.getByRole('status')).toContainText('Viser 3 av 10');
	await page.getByRole('button', { name: 'Alle', exact: true }).click();
	await expect(page.getByRole('status')).toContainText('Viser 10 av 10');
});
test('project pages offer active onward routes and catalog navigation', async ({ page }) => {
	await page.goto('/projects/prompt-lab');
	await expect(page.getByRole('heading', { name: 'Under konstruksjon' })).toBeVisible();
	const onward = page.getByRole('navigation', { name: 'Utforsk videre' });
	await expect(onward).toBeVisible();
	await onward.getByRole('link', { name: /I samme spor/ }).click();
	await expect(page).toHaveURL(/\/projects\/diff-tool$/);
	await page.goBack();
	await expect(page.getByRole('heading', { name: 'Under konstruksjon' })).toBeVisible();
	await page.goForward();
	await expect(page.getByRole('heading', { name: 'tekst≠diff' })).toBeVisible();
	await onward.getByRole('button', { name: 'Overrask meg' }).click();
	await expect(page).not.toHaveURL(/\/projects\/(diff-tool|prompt-lab)$/);
	await onward.getByRole('link', { name: 'Alle prosjekter' }).click();
	await expect(page).toHaveURL(/\/projects$/);
});
test('preview respects reduced motion and still allows explicit playback', async ({ page }) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/');
	const start = page.getByRole('button', { name: 'Start bevegelse' });
	await expect(start).toHaveAttribute('aria-pressed', 'false');
	await expect(page.getByText('Et stille mønster. Start bevegelsen hvis du vil.')).toBeVisible();
	await page.getByRole('button', { name: 'Nytt mønster' }).click();
	await expect(start).toHaveAttribute('aria-pressed', 'false');
	await start.press('Enter');
	await expect(page.getByRole('button', { name: 'Pause bevegelse' })).toBeVisible();
});
test('mobile discovery has no horizontal overflow and touch controls work', async ({
	browser,
}, testInfo) => {
	const context = await browser.newContext({
		viewport: { width: 375, height: 812 },
		hasTouch: true,
		isMobile: true,
	});
	const page = await context.newPage();
	await page.goto('/');
	await page.getByRole('button', { name: 'Nytt mønster' }).tap();
	await page.getByRole('button', { name: 'Pause bevegelse' }).tap();
	await expect(page.getByRole('button', { name: 'Start bevegelse' })).toBeVisible();
	await page.screenshot({ path: testInfo.outputPath('home-mobile.png'), fullPage: true });
	for (const path of ['/', '/projects', '/projects/prompt-lab']) {
		await page.goto(path);
		expect(
			await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
		).toBe(true);
	}
	await context.close();
});
test('essential discovery links are rendered without JavaScript', async ({ browser }) => {
	const context = await browser.newContext({ javaScriptEnabled: false });
	const page = await context.newPage();
	await page.goto('/');
	await page.getByRole('link', { name: 'Lek med flyt≠felt' }).click();
	await expect(page.getByRole('heading', { name: 'flyt≠felt', exact: true })).toBeVisible();
	await expect(page.getByRole('navigation', { name: 'Utforsk videre' })).toBeVisible();
	await context.close();
});
test('homepage preview stops drawing while paused and off screen', async ({ page }) => {
	await page.setViewportSize({ width: 1200, height: 600 });
	await page.goto('/');
	const canvas = page.locator('canvas');
	await page.getByRole('button', { name: 'Pause bevegelse' }).click();
	const still = await canvas.evaluate((element) => element.toDataURL());
	await page.waitForTimeout(150);
	expect(await canvas.evaluate((element) => element.toDataURL())).toBe(still);
	await page.getByRole('button', { name: 'Start bevegelse' }).click();
	await expect.poll(() => canvas.evaluate((element) => element.toDataURL())).not.toBe(still);
	await page.getByText('Ingen konto. Bare nysgjerrighet.').scrollIntoViewIfNeeded();
	await page.waitForTimeout(150);
	const offscreen = await canvas.evaluate((element) => element.toDataURL());
	await page.waitForTimeout(150);
	expect(await canvas.evaluate((element) => element.toDataURL())).toBe(offscreen);
	await page.getByRole('heading', { name: 'ulik.no', exact: true }).scrollIntoViewIfNeeded();
	await expect.poll(() => canvas.evaluate((element) => element.toDataURL())).not.toBe(offscreen);
});
