import { expect, test } from '@playwright/test';

async function aim(page, hit) {
	// Observe the rendered line rather than changing game state or invoking Elm.
	await page.waitForFunction((wantHit) => {
		const line = document.querySelector('.near-miss-arena line');
		if (!line) return false;
		const angle = Math.atan2(
			Number(line.getAttribute('y2')) - 330,
			Number(line.getAttribute('x2')) - 70,
		);
		const gap = Math.abs(250 * Math.sin(angle) + 120 * Math.cos(angle)) - 35;
		return wantHit ? gap < -20 : gap > 10 && gap < 30;
	}, hit);
}

test('real geometry, repeated rounds, keyboard restart and navigation', async ({ page }, info) => {
	const errors = [];
	page.on('pageerror', (error) => errors.push(error.message));
	await page.goto('/projects/bom-feil');
	await expect(page.locator('script[src^="/elm.js"]')).toHaveAttribute(
		'src',
		/^\/elm\.js\?v=[a-f0-9]{16}$/,
	);
	const game = page.locator('.near-miss-page');
	const action = page.locator('.near-miss-action');
	await expect(game).toHaveAttribute('data-phase', 'aiming');
	await page.screenshot({ path: info.outputPath('near-miss-desktop.png'), fullPage: true });
	for (let round = 0; round < 3; round++) {
		await aim(page, false);
		await action.click();
		await expect(game).toHaveAttribute('data-phase', 'missed');
		await expect(game.getByRole('status')).toContainText('klaring');
		await expect(action).toBeFocused();
		await page.keyboard.press('Enter');
		await expect(game).toHaveAttribute('data-phase', 'aiming');
	}
	await aim(page, true);
	await action.click();
	await expect(game).toHaveAttribute('data-phase', 'crashed');
	await page.screenshot({ path: info.outputPath('near-miss-result.png'), fullPage: true });
	await expect(action).toBeFocused();
	await page.keyboard.press('Space');
	await expect(game).toHaveAttribute('data-phase', 'aiming');
	await expect(game.locator('.near-miss-stats strong').first()).toHaveText('0');
	await page.getByRole('link', { name: /Alle prosjekter/ }).click();
	await page.goBack();
	await expect(game).toHaveAttribute('data-phase', 'aiming');
	expect(errors).toEqual([]);
});

test('touch and reduced motion remain playable without overflow', async ({ browser }, info) => {
	const context = await browser.newContext({
		viewport: { width: 390, height: 844 },
		isMobile: true,
		hasTouch: true,
		reducedMotion: 'reduce',
	});
	const page = await context.newPage();
	await page.goto('http://127.0.0.1:4173/projects/bom-feil');
	await expect(page.locator('.near-miss-page')).toHaveAttribute('data-phase', 'aiming');
	await page.screenshot({ path: info.outputPath('near-miss-mobile.png'), fullPage: true });
	await expect(page.locator('.near-miss-page')).toHaveAttribute('data-reduced-motion', 'true');
	await aim(page, true);
	await page.locator('.near-miss-action').tap();
	await expect(page.locator('.near-miss-page')).toHaveAttribute('data-phase', 'crashed');
	await page.locator('.near-miss-action').tap();
	await expect(page.locator('.near-miss-page')).toHaveAttribute('data-phase', 'aiming');
	expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
	await context.close();
});
