import { expect, test } from '@playwright/test';

test.setTimeout(120000);

async function openTrack(page) {
	const errors = [];
	page.on('pageerror', (error) => errors.push(error.message));
	page.on('console', (message) => {
		if (message.type() === 'error') errors.push(message.text());
	});
	await page.route('https://api.github.com/repos/oleanders/ulik.no/actions/runs?*', (route) =>
		route.fulfill({ headers: { 'access-control-allow-origin': '*' }, json: { workflow_runs: [] } }),
	);
	await page.goto('/projects/kule-bane');
	try {
		await expect(page.getByRole('button', { name: 'Slipp kula ↗', exact: true })).toBeEnabled({
			timeout: 30000,
		});
	} catch (error) {
		console.log(
			'Marble initialization diagnostics:',
			JSON.stringify({ errors, status: await page.locator('.marble-status').textContent() }),
		);
		throw error;
	}
	await expect(page.locator('#marble-canvas')).toHaveAttribute('data-state', 'ready', {
		timeout: 30000,
	});
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
		await expect(page.locator('#marble-canvas')).toHaveAttribute('data-state', 'ready', {
			timeout: 30000,
		});
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

test('a first-slot jump has a downhill run-up and visibly builds speed before takeoff', async ({
	page,
}, testInfo) => {
	await openTrack(page);
	const canvas = page.locator('#marble-canvas');
	await page.getByRole('button', { name: 'Bytt del 1: Sving', exact: true }).click();
	await page.getByRole('button', { name: 'Bytt del 1: Spiral', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Bytt del 1: Hopp', exact: true })).toBeVisible();
	await page.screenshot({
		path: testInfo.outputPath('marble-jump-first-ready.png'),
		fullPage: true,
	});
	await expect(canvas).toHaveAttribute('data-segment', 'runup');
	const releaseSpeed = Number(await canvas.getAttribute('data-speed'));
	expect(releaseSpeed).toBeLessThan(0.5);
	await canvas.evaluate((element) => {
		window.__marbleFlightSeen = false;
		const observer = new MutationObserver(() => {
			if (element.dataset.airborne === 'true') window.__marbleFlightSeen = true;
			if (element.dataset.state === 'finished') observer.disconnect();
		});
		observer.observe(element, {
			attributes: true,
			attributeFilter: ['data-airborne', 'data-state'],
		});
	});
	await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
	await expect
		.poll(async () => Number(await canvas.getAttribute('data-speed')))
		.toBeGreaterThan(releaseSpeed);
	await expect(canvas).toHaveAttribute('data-airborne', 'false');
	await page.screenshot({
		path: testInfo.outputPath('marble-jump-first-runup.png'),
		fullPage: true,
	});
	await expect
		.poll(() => page.evaluate(() => window.__marbleFlightSeen), { timeout: 25000 })
		.toBe(true);
	await expect(page.getByText('I mål! En runde til?')).toBeVisible({ timeout: 30000 });
	await expect(canvas).toHaveAttribute('data-airborne', 'false');
	await page.screenshot({
		path: testInfo.outputPath('marble-jump-first-finished.png'),
		fullPage: true,
	});
});

test.describe('natural rolling and finish exit', () => {
	test.use({
		video: { mode: 'on', size: { width: 1100, height: 900 } },
		viewport: { width: 1100, height: 900 },
	});

	test('rolling stays visible through the finish, falls away, disappears and replays', async ({
		page,
	}, testInfo) => {
		await openTrack(page);
		const canvas = page.locator('#marble-canvas');
		await page.getByRole('button', { name: 'Følg kula', exact: true }).click();
		const bounds = await canvas.boundingBox();
		const width = bounds.width * 0.88;
		const height = width / 2.25;
		await page.screenshot({
			path: testInfo.outputPath('marble-card-start.png'),
			clip: {
				x: bounds.x + (bounds.width - width) / 2,
				y: bounds.y + (bounds.height - height) / 2,
				width,
				height,
			},
		});
		await canvas.evaluate((element) => {
			window.__marbleMotionFrames = [];
			const observer = new MutationObserver(() => {
				window.__marbleMotionFrames.push({
					at: performance.now(),
					phase: element.dataset.phase,
					position: element.dataset.position,
					rotation: element.dataset.rotation,
					visible: element.dataset.visible,
					speed: Number(element.dataset.speed),
					state: element.dataset.state,
				});
				if (element.dataset.phase === 'gone') observer.disconnect();
			});
			observer.observe(element, {
				attributes: true,
				attributeFilter: ['data-position', 'data-phase'],
			});
		});
		await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
		await expect(page.getByText('I mål! En runde til?')).toBeVisible({ timeout: 45000 });
		const frames = await page.evaluate(() => window.__marbleMotionFrames);
		await testInfo.attach('marble-motion-frames.json', {
			body: JSON.stringify(frames, null, 2),
			contentType: 'application/json',
		});
		const rolling = frames.filter((frame) => frame.phase === 'track' && frame.state === 'running');
		const falling = frames.filter((frame) => frame.phase === 'falling');
		expect(rolling.length).toBeGreaterThan(5);
		expect(new Set(rolling.map((frame) => frame.rotation)).size).toBeGreaterThan(5);
		expect(falling.length).toBeGreaterThan(1);
		expect(falling.every((frame) => frame.state === 'running' && frame.visible === 'true')).toBe(
			true,
		);
		expect(falling[0].speed).toBeGreaterThan(1);
		const positions = falling.map((frame) => frame.position.split(',').map(Number));
		expect(
			Math.hypot(...positions.at(-1).map((value, index) => value - positions[0][index])),
		).toBeGreaterThan(1);
		await expect(canvas).toHaveAttribute('data-phase', 'gone');
		await expect(canvas).toHaveAttribute('data-visible', 'false');
		await page.screenshot({ path: testInfo.outputPath('marble-after-fall.png'), fullPage: true });
		await page.getByRole('button', { name: 'Slipp igjen ↗', exact: true }).click();
		await expect(canvas).toHaveAttribute('data-visible', 'true');
		await page.getByRole('button', { name: 'Til start', exact: true }).click();
		await expect(canvas).toHaveAttribute('data-phase', 'track');
		await expect(canvas).toHaveAttribute('data-state', 'ready');
	});

	test('reset during the fall restores a motionless marble and a new run works', async ({
		page,
	}) => {
		await page.emulateMedia({ reducedMotion: 'reduce' });
		await openTrack(page);
		const canvas = page.locator('#marble-canvas');
		await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
		await expect(canvas).toHaveAttribute('data-phase', 'falling', { timeout: 45000 });
		await page.getByRole('button', { name: 'Til start', exact: true }).click();
		await expect(canvas).toHaveAttribute('data-state', 'ready');
		await expect(canvas).toHaveAttribute('data-phase', 'track');
		await expect(canvas).toHaveAttribute('data-visible', 'true');
		const position = await canvas.getAttribute('data-position');
		await page.waitForTimeout(400);
		await expect(canvas).toHaveAttribute('data-position', position);
		await page.getByRole('button', { name: 'Slipp kula ↗', exact: true }).click();
		await expect(page.getByText('I mål! En runde til?')).toBeVisible({ timeout: 45000 });
		await expect(canvas).toHaveAttribute('data-visible', 'false');
	});
});
