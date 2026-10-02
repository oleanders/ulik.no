import { expect, test } from '@playwright/test';

test.use({ reducedMotion: 'reduce' });

test('presets, keyboard controls, repeated resets and local PNG export', async ({ page }) => {
	const errors: string[] = [];
	page.on('pageerror', (error) => errors.push(error.message));
	await page.goto('/projects/flyt-felt?seed=123');
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeEnabled();
	await expect(page.getByText('på pause', { exact: true })).toBeVisible();
	await expect(page.getByText('Redusert bevegelse er valgt.', { exact: false })).toBeVisible();
	const canvas = page.locator('canvas');
	const original = await canvas.evaluate((element) => element.toDataURL());
	for (let i = 0; i < 3; i++) {
		await page.getByRole('button', { name: 'start på nytt', exact: true }).click();
		expect(await canvas.evaluate((element) => element.toDataURL())).toBe(original);
	}
	await page.getByRole('button', { name: /^Virvel/ }).click();
	await expect(page.getByRole('button', { name: /^Virvel/ })).toHaveAttribute(
		'aria-pressed',
		'true',
	);
	await expect(page.getByLabel('Tetthet')).toHaveValue('1200');
	await expect(page.getByTestId('flow-seed')).toHaveText('123');
	await page.getByLabel('Fart').focus();
	await page.keyboard.press('ArrowRight');
	await expect(page.getByLabel('Fart')).toHaveValue('1.05');
	await page.getByRole('button', { name: 'nullstill innstillinger' }).click();
	await expect(page.getByLabel('Fart')).toHaveValue('1');
	await canvas.focus();
	await page.keyboard.press('Space');
	await expect(page.getByRole('button', { name: 'pause', exact: true })).toBeVisible();
	await page.keyboard.press('ArrowLeft');
	await page.keyboard.press('Escape');
	await page.keyboard.press('Space');
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeVisible();
	await page.getByRole('button', { name: 'nytt univers' }).click();
	await expect(page.getByTestId('flow-seed')).not.toHaveText('123');
	const downloadPromise = page.waitForEvent('download');
	await page.getByRole('button', { name: 'lagre PNG' }).click();
	const download = await downloadPromise;
	expect(download.suggestedFilename()).toMatch(/^flyt-felt-virvel-\d+\.png$/);
	expect(await download.failure()).toBeNull();
	expect(errors).toEqual([]);
});

test('shared URLs restore only bounded configuration and survive navigation', async ({ page }) => {
	await page.goto(
		'/projects/flyt-felt?v=1&preset=glod&seed=88&speed=1.25&density=1000&attraction=0.7&hue=40&private=discard#discard',
	);
	await expect(page.getByRole('button', { name: 'del univers' })).toBeEnabled();
	await page.getByRole('button', { name: 'del univers' }).click();
	const shareUrl = await page.getByLabel('Lenke til universet').inputValue();
	const url = new URL(shareUrl);
	expect(url.hash).toBe('');
	expect([...url.searchParams.keys()]).toEqual([
		'v',
		'preset',
		'seed',
		'speed',
		'density',
		'attraction',
		'hue',
	]);
	await page.goto(shareUrl);
	await expect(page.getByRole('button', { name: /^Glød/ })).toHaveAttribute('aria-pressed', 'true');
	await expect(page.getByLabel('Fart')).toHaveValue('1.25');
	await expect(page.getByLabel('Tetthet')).toHaveValue('1000');
	await expect(page.getByLabel('Tiltrekning')).toHaveValue('0.7');
	await expect(page.getByLabel('Fargetone')).toHaveValue('40');
	await expect(page.getByTestId('flow-seed')).toHaveText('88');
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await page.goBack();
	await expect(page.getByLabel('Fart')).toHaveValue('1.25');
	await page.goForward();
	await expect(page).toHaveURL(/\/om$/);
	await page.goBack();
	await expect(page.getByTestId('flow-seed')).toHaveText('88');
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeVisible();

	await page.goto(
		'/projects/flyt-felt?v=1&preset=invalid&seed=-9&speed=Infinity&density=999999&attraction=-999&hue=NaN',
	);
	await expect(page.getByLabel('Tetthet')).toHaveValue('1500');
	await expect(page.getByLabel('Fart')).toHaveValue('0.75');
	await expect(page.getByLabel('Tiltrekning')).toHaveValue('-2');
	await expect(page.getByTestId('flow-seed')).toHaveText('20261002');
});

test('clipboard failure leaves a selectable link and repeated sharing is safe', async ({
	page,
}) => {
	await page.addInitScript(() => {
		Object.defineProperty(navigator, 'clipboard', {
			value: { writeText: () => Promise.reject(new Error('Clipboard unavailable')) },
		});
	});
	await page.goto('/projects/flyt-felt');
	await expect(page.getByRole('button', { name: 'del univers' })).toBeEnabled();
	for (let i = 0; i < 3; i++) {
		await page.getByRole('button', { name: 'del univers' }).click();
		await expect(page.getByRole('status')).toHaveText('Kopier lenken fra feltet under.');
		await expect(page.getByLabel('Lenke til universet')).toHaveValue(/preset=nordlys/);
	}
});

test('mobile touch interaction releases cleanly and controls fit the viewport', async ({
	browser,
}) => {
	const context = await browser.newContext({
		baseURL: test.info().project.use.baseURL,
		viewport: { width: 390, height: 844 },
		hasTouch: true,
		isMobile: true,
		reducedMotion: 'reduce',
	});
	const page = await context.newPage();
	await page.goto('/projects/flyt-felt');
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeEnabled();
	await page.locator('canvas').tap();
	await page.locator('canvas').dispatchEvent('pointercancel', { pointerType: 'touch' });
	await page.getByRole('button', { name: 'nytt univers' }).tap();
	await page.getByRole('button', { name: /^Glød/ }).tap();
	await expect(page.getByLabel('Tetthet')).toHaveValue('600');
	expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
		true,
	);
	await page.screenshot({ path: 'test-results/flyt-felt-mobile.png', fullPage: true });
	await context.close();
});
