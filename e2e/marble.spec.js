import { expect, test } from '@playwright/test';

async function openTrack(page) {
	await page.route('https://api.github.com/repos/oleanders/ulik.no/actions/runs?*', (route) =>
		route.fulfill({ headers: { 'access-control-allow-origin': '*' }, json: { workflow_runs: [] } }),
	);
	await page.goto('/projects/kule-bane');
	await expect(page.getByRole('button', { name: 'Slipp kula ↗', exact: true })).toBeEnabled();
	await expect(page.locator('#marble-canvas')).toHaveAttribute('data-state', 'ready');
}

test('a real rendered track runs to the finish and can be replayed', async ({ page }, testInfo) => {
	const errors = [];
	page.on('pageerror', (error) => errors.push(error.message));
	await openTrack(page);
	const canvas = page.locator('#marble-canvas');
	const initial = await canvas.screenshot();
	expect(initial.length).toBeGreaterThan(10000);
	await page.screenshot({ path: testInfo.outputPath('marble-desktop.png'), fullPage: true });
	await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
	await expect(canvas).toHaveAttribute('data-state', 'running');
	await expect(page.getByRole('button', { name: 'Slipp kula ↗', exact: true })).toBeDisabled();
	await expect
		.poll(async () => Number(await canvas.getAttribute('data-progress')))
		.toBeGreaterThan(0);
	await page.getByRole('button', { name: 'Følg kula', exact: true }).click();
	await expect(canvas).toHaveAttribute('data-camera', 'follow');
	await page.screenshot({ path: testInfo.outputPath('marble-follow.png'), fullPage: true });
	await expect(page.getByText('I mål! En runde til?')).toBeVisible({ timeout: 25000 });
	await page.getByRole('button', { name: 'Slipp igjen ↗', exact: true }).click();
	await expect(canvas).toHaveAttribute('data-state', 'running');
	await page.getByRole('button', { name: 'Til start', exact: true }).click();
	await expect(canvas).toHaveAttribute('data-state', 'ready');
	expect(errors).toEqual([]);
});

test('slot changes are visible, compatible, and interrupt running safely', async ({ page }) => {
	await openTrack(page);
	const canvas = page.locator('#marble-canvas');
	const original = await canvas.screenshot();
	for (let slot = 1; slot <= 3; slot++) {
		for (let change = 0; change < 3; change++) {
			await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
			await page.getByRole('button', { name: new RegExp(`Bytt del ${slot}:`) }).click();
			await expect(canvas).toHaveAttribute('data-state', 'ready');
			await expect(page.getByText('Alt passer. Klar når du er.')).toBeVisible();
		}
	}
	await page.getByRole('button', { name: 'Bytt del 1: Sving', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Bytt del 1: Spiral', exact: true })).toBeVisible();
	expect((await canvas.screenshot()).equals(original)).toBe(false);
	await page.getByRole('button', { name: 'Mint', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Mint', exact: true })).toHaveAttribute(
		'aria-pressed',
		'true',
	);
	for (let repeat = 0; repeat < 3; repeat++) {
		await page.getByRole('button', { name: 'Til start', exact: true }).click();
		await expect(canvas).toHaveAttribute('data-state', 'ready');
	}
});

test('navigation disposes the old scene and restores a single fresh scene', async ({ page }) => {
	const errors = [];
	page.on('pageerror', (error) => errors.push(error.message));
	await openTrack(page);
	await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
	for (let repeat = 0; repeat < 3; repeat++) {
		await page.getByRole('link', { name: '~/om', exact: true }).click();
		await expect(page.locator('canvas')).toHaveCount(0);
		await page.goBack();
		await expect(page.locator('#marble-canvas')).toHaveAttribute('data-state', 'ready');
		await expect(page.locator('canvas')).toHaveCount(1);
	}
	await page.goForward();
	await expect(page.locator('canvas')).toHaveCount(0);
	expect(errors).toEqual([]);
});

test('touch controls fit on a phone and reduced motion starts completely still', async ({
	browser,
}, testInfo) => {
	const context = await browser.newContext({
		viewport: { width: 375, height: 812 },
		hasTouch: true,
		isMobile: true,
		reducedMotion: 'reduce',
	});
	const page = await context.newPage();
	await openTrack(page);
	const canvas = page.locator('#marble-canvas');
	const still = await canvas.screenshot();
	await page.waitForTimeout(250);
	expect((await canvas.screenshot()).equals(still)).toBe(true);
	await page.getByRole('button', { name: 'Bytt del 1: Sving', exact: true }).tap();
	await page.getByRole('button', { name: 'Fiolett', exact: true }).tap();
	await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).tap();
	await expect(canvas).toHaveAttribute('data-state', 'running');
	await page.getByRole('button', { name: 'Til start', exact: true }).tap();
	await expect(canvas).toHaveAttribute('data-state', 'ready');
	expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
	await page.screenshot({ path: testInfo.outputPath('marble-mobile.png'), fullPage: true });
	await context.close();
});

test('WebGL failure gives a useful message and disables controls', async ({ page }) => {
	await page.addInitScript(() => {
		const getContext = HTMLCanvasElement.prototype.getContext;
		HTMLCanvasElement.prototype.getContext = function (type, ...args) {
			return type.startsWith('webgl') ? null : getContext.call(this, type, ...args);
		};
	});
	await page.goto('/projects/kule-bane');
	await expect(page.locator('.marble-status')).toContainText(/WebGL|3D/);
	await expect(page.getByRole('button', { name: 'Slipp kula ↗', exact: true })).toBeDisabled();
});

test('catalog links and prerendered track content remain accessible', async ({ browser }) => {
	const context = await browser.newContext({ javaScriptEnabled: false });
	const page = await context.newPage();
	await page.goto('/');
	await page.getByRole('link', { name: /kule≠bane/ }).click();
	await expect(page.getByRole('heading', { name: 'kule≠bane', exact: true })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Bytt del 1: Sving', exact: true })).toBeVisible();
	await context.close();
});
