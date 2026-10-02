import { expect, test } from '@playwright/test';

test('color targets remain identical while background is removed and restored', async ({
	page,
}, testInfo) => {
	await page.goto('/projects/lik-lik');
	const targets = page.getByTestId('color-target');
	await expect(targets).toHaveCount(2);
	await expect(targets.nth(0)).toHaveAttribute('fill', '#82978b');
	await expect(targets.nth(1)).toHaveAttribute('fill', '#82978b');
	await expect(page.getByRole('button', { name: 'Avslør likheten' })).toBeEnabled();
	await page.screenshot({ path: testInfo.outputPath('lik-lik-desktop.png'), fullPage: true });
	await page.getByRole('button', { name: 'Avslør likheten' }).press('Enter');
	await expect(page.getByText('A = B. Helt likt.')).toBeVisible();
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '0');
	await expect(page.getByRole('slider', { name: 'Omgivelser' })).toHaveValue('0');
	await expect(targets.nth(0)).toHaveAttribute('fill', '#82978b');
	await expect(targets.nth(1)).toHaveAttribute('fill', '#82978b');
	await page.getByRole('button', { name: 'Vis illusjonen igjen' }).click();
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '1');
	const slider = page.getByRole('slider', { name: 'Omgivelser' });
	await slider.press('Home');
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '0');
	await slider.press('ArrowRight');
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '0.01');
	await page.getByRole('button', { name: 'Nullstill' }).click();
	await expect(slider).toHaveValue('100');
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '1');
});

test('circle and line dimensions are invariant through reveal, slider and reset', async ({
	page,
}, testInfo) => {
	await page.goto('/projects/lik-lik');
	await page.getByRole('button', { name: '02 Samme sirkel' }).click();
	const circles = page.getByTestId('circle-target');
	await expect(circles).toHaveCount(2);
	await expect(circles.nth(0)).toHaveAttribute('r', '28');
	await expect(circles.nth(1)).toHaveAttribute('r', '28');
	await page.getByRole('slider', { name: 'Omgivelser' }).press('Home');
	await expect(circles.nth(0)).toHaveAttribute('r', '28');
	await page.getByRole('button', { name: 'Avslør likheten' }).click();
	await expect(page.getByText('Begge midtsirklene: radius 28 i tegningen.')).toBeVisible();
	await page.screenshot({
		path: testInfo.outputPath('lik-lik-circles-revealed.png'),
		fullPage: true,
	});
	await page.getByRole('button', { name: '03 Samme linje' }).click();
	await expect(page.getByRole('slider', { name: 'Omgivelser' })).toHaveValue('100');
	await expect(page.getByTestId('context')).toHaveAttribute('opacity', '1');
	const lines = page.getByTestId('line-target');
	for (const line of await lines.all()) {
		await expect(line).toHaveAttribute('x1', '220');
		await expect(line).toHaveAttribute('x2', '500');
	}
	await page.getByRole('button', { name: 'Avslør likheten' }).click();
	await expect(page.getByText('Begge strekene: 280 enheter i tegningen.')).toBeVisible();
	await page.screenshot({
		path: testInfo.outputPath('lik-lik-lines-revealed.png'),
		fullPage: true,
	});
	await page.getByRole('button', { name: 'Nullstill' }).click();
	await expect(page.getByRole('button', { name: 'Avslør likheten' })).toHaveAttribute(
		'aria-pressed',
		'false',
	);
	await expect(lines.nth(1)).toHaveAttribute('x2', '500');
});

test('mobile touch, reduced motion and onward navigation remain usable', async ({
	browser,
}, testInfo) => {
	const context = await browser.newContext({
		viewport: { width: 375, height: 812 },
		hasTouch: true,
		isMobile: true,
		reducedMotion: 'reduce',
	});
	const page = await context.newPage();
	await page.goto('/projects/lik-lik');
	await page.getByRole('button', { name: 'Avslør likheten' }).tap();
	await expect(page.getByText('A = B. Helt likt.')).toBeVisible();
	await page.screenshot({ path: testInfo.outputPath('lik-lik-mobile.png'), fullPage: true });
	for (const name of ['02 Samme sirkel', '03 Samme linje', '01 Samme farge']) {
		await page.getByRole('button', { name }).tap();
		expect(
			await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
		).toBe(true);
	}
	await page
		.getByRole('navigation', { name: 'Utforsk videre' })
		.getByRole('link', { name: /I samme spor/ })
		.tap();
	await expect(page).toHaveURL(/\/projects\/flyt-felt$/);
	await page.goBack();
	await expect(page.getByRole('heading', { name: 'lik≠lik', exact: true })).toBeVisible();
	await context.close();
});

test('catalog includes the new visual project and links without JavaScript', async ({
	browser,
}) => {
	const context = await browser.newContext({ javaScriptEnabled: false });
	const page = await context.newPage();
	await page.goto('/projects');
	await page.getByRole('link', { name: /lik≠lik/ }).click();
	await expect(page.getByRole('heading', { name: 'lik≠lik', exact: true })).toBeVisible();
	await expect(page.getByTestId('color-target')).toHaveCount(2);
	await expect(
		page.getByText('Slå på JavaScript for å bruke kontrollene.', { exact: false }),
	).toBeVisible();
	await context.close();
});
