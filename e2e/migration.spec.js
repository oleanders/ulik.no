import { test as base, expect } from '@playwright/test';

// Keep browser/API failures visible in every regression, including navigation cleanup.
const test = base.extend({
	page: async ({ page }, use) => {
		const errors = [];
		page.on('pageerror', (error) => errors.push(error.message));
		page.on('console', (message) => {
			if (message.type() === 'error') errors.push(message.text());
		});
		// Deployment status is unrelated to these flows and must not depend on GitHub uptime.
		await page.route('https://api.github.com/repos/oleanders/ulik.no/actions/runs?*', (route) =>
			route.fulfill({
				headers: { 'access-control-allow-origin': '*' },
				json: { workflow_runs: [] },
			}),
		);
		await use(page);
		expect(errors, 'No JavaScript exceptions or console errors').toEqual([]);
	},
});

const MORSE = {
	A: '.-',
	B: '-...',
	C: '-.-.',
	D: '-..',
	E: '.',
	F: '..-.',
	G: '--.',
	H: '....',
	I: '..',
	J: '.---',
	K: '-.-',
	L: '.-..',
	M: '--',
	N: '-.',
	O: '---',
	P: '.--.',
	Q: '--.-',
	R: '.-.',
	S: '...',
	T: '-',
	U: '..-',
	V: '...-',
	W: '.--',
	X: '-..-',
	Y: '-.--',
	Z: '--..',
	0: '-----',
	1: '.----',
	2: '..---',
	3: '...--',
	4: '....-',
	5: '.....',
	6: '-....',
	7: '--...',
	8: '---..',
	9: '----.',
};
const formatMorse = (code) => code.replaceAll('.', '·').replaceAll('-', '—');

async function disableAudio(page) {
	await page.addInitScript(() => {
		Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
	});
}

// Explicit event timestamps avoid load-dependent dot/dash threshold tests on CI.
async function sendTimedEvent(locator, type, timeStamp, properties = {}) {
	await locator.evaluate(
		(element, event) => {
			const EventType = event.type.startsWith('key') ? KeyboardEvent : PointerEvent;
			const dispatched = new EventType(event.type, {
				bubbles: true,
				cancelable: true,
				...event.properties,
			});
			Object.defineProperty(dispatched, 'timeStamp', { value: event.timeStamp });
			element.dispatchEvent(dispatched);
		},
		{ type, timeStamp, properties },
	);
}

async function installSpeechMock(page) {
	await page.addInitScript(() => {
		const voices = [
			{ voiceURI: 'test-norwegian', lang: 'nb-NO' },
			{ voiceURI: 'test-british', lang: 'en-GB' },
			{ voiceURI: 'test-american', lang: 'en-US' },
		];
		const listeners = new Set();
		const speech = {
			calls: [],
			cancellations: 0,
			getVoices: () => voices,
			addEventListener: (name, listener) => {
				if (name === 'voiceschanged') listeners.add(listener);
			},
			removeEventListener: (name, listener) => {
				if (name === 'voiceschanged') listeners.delete(listener);
			},
			speak: (utterance) => speech.calls.push(utterance),
			cancel: () => {
				speech.cancellations += 1;
			},
			listenerCount: () => listeners.size,
			finish: () => speech.calls.at(-1)?.onend?.(),
			fail: () => speech.calls.at(-1)?.onerror?.(),
		};
		class Utterance {
			constructor(text) {
				this.text = text;
			}
		}
		Object.defineProperty(window, 'SpeechSynthesisUtterance', {
			configurable: true,
			value: Utterance,
		});
		Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: speech });
		window.__speech = speech;
	});
}

async function installDisplayMediaMock(page) {
	await page.addInitScript(() => {
		const capture = {
			requests: [],
			streams: [],
			resolve(index) {
				const canvas = document.createElement('canvas');
				canvas.width = 320;
				canvas.height = 180;
				const context = canvas.getContext('2d');
				context.fillStyle = '#246';
				context.fillRect(0, 0, canvas.width, canvas.height);
				const stream = canvas.captureStream(0);
				const entry = { stream, stops: 0 };
				for (const track of stream.getTracks()) {
					const stop = track.stop.bind(track);
					track.stop = () => {
						entry.stops += 1;
						stop();
					};
				}
				capture.streams.push(entry);
				capture.requests[index].resolve(stream);
			},
			reject(index, name) {
				capture.requests[index].reject(new DOMException('Test capture failure', name));
			},
		};
		const getDisplayMedia = (options) =>
			new Promise((resolve, reject) => {
				capture.requests.push({ options, resolve, reject });
			});
		if (!navigator.mediaDevices) {
			Object.defineProperty(navigator, 'mediaDevices', { configurable: true, value: {} });
		}
		Object.defineProperty(navigator.mediaDevices, 'getDisplayMedia', {
			configurable: true,
			value: getDisplayMedia,
		});
		window.__capture = capture;
	});
}

async function expectStoppedCapture(page, index) {
	await expect
		.poll(() =>
			page.evaluate((streamIndex) => {
				const entry = window.__capture.streams[streamIndex];
				return (
					entry.stops > 0 && entry.stream.getTracks().every((track) => track.readyState === 'ended')
				);
			}, index),
		)
		.toBe(true);
}

async function captureResponsiveScreenshots(page, testInfo, name) {
	const viewport = page.viewportSize();
	await page.screenshot({ path: testInfo.outputPath(`${name}-desktop.png`), fullPage: true });
	await page.setViewportSize({ width: 390, height: 844 });
	expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
	await page.screenshot({ path: testInfo.outputPath(`${name}-mobile.png`), fullPage: true });
	await page.setViewportSize(viewport);
}

test('diff preserves line/word statistics, swap, equality, empty input and literal markup', async ({
	page,
}, testInfo) => {
	await page.goto('/projects/diff-tool');
	const left = page.getByRole('textbox', { name: '~ /venstre' });
	const right = page.getByRole('textbox', { name: '~ /høyre' });
	const output = page.getByRole('region', { name: 'Diff-resultat' });
	await expect(output.locator('.stats .added')).toHaveText('+3');
	await expect(output.locator('.stats .removed')).toHaveText('-2');
	await captureResponsiveScreenshots(page, testInfo, 'diff');
	await left.fill('same\nold\n');
	await right.fill('same\nnew\nextra\n');
	await expect(output.locator('.stats .added')).toHaveText('+2');
	await expect(output.locator('.stats .removed')).toHaveText('-1');
	await expect(output.locator('pre .context')).toHaveText('same\n');
	await page.getByRole('button', { name: '↔ bytt' }).click();
	await expect(left).toHaveValue('same\nnew\nextra\n');
	await expect(right).toHaveValue('same\nold\n');
	await expect(output.locator('.stats .added')).toHaveText('+1');
	await expect(output.locator('.stats .removed')).toHaveText('-2');
	await left.fill('red cat');
	await right.fill('blue cat');
	await page.getByRole('button', { name: 'ord', exact: true }).click();
	await expect(page.getByRole('button', { name: 'ord', exact: true })).toHaveAttribute(
		'aria-pressed',
		'true',
	);
	await expect(output.locator('.stats .added')).toHaveText('+4');
	await expect(output.locator('.stats .removed')).toHaveText('-3');
	await right.fill('red cat');
	await expect(output).toContainText('tekstene er identiske.');
	await expect(output.locator('.stats .added')).toHaveText('+0');
	await page.getByRole('button', { name: 'tøm', exact: true }).click();
	await expect(left).toHaveValue('');
	await expect(right).toHaveValue('');
	await expect(output).toContainText('ingen inndata enda.');
	await expect(output.locator('.stats .removed')).toHaveText('-0');
	await right.fill('<img src=x onerror="window.unexpected = true">');
	await expect(output.locator('pre')).toHaveText('<img src=x onerror="window.unexpected = true">');
	await expect(output.locator('img')).toHaveCount(0);
	await page.getByRole('button', { name: 'linjer', exact: true }).click();
	await expect(output.locator('.stats .added')).toHaveText('+1');
});

test('Morse overview supports all letters, speed, keyboard playback and route cleanup without audio', async ({
	page,
}, testInfo) => {
	await disableAudio(page);
	await page.goto('/projects/morsekode');
	await expect(page.getByRole('link', { name: 'oversikt', exact: true })).toHaveAttribute(
		'aria-current',
		'page',
	);
	await expect(page.locator('.letter-tile')).toHaveCount(36);
	await captureResponsiveScreenshots(page, testInfo, 'morse-overview');
	for (const [letter, code] of Object.entries(MORSE)) {
		await expect(
			page.getByRole('button', { name: `${letter}: ${formatMorse(code)}`, exact: true }),
		).toBeVisible();
	}
	await page.getByRole('slider', { name: 'Hastighet (ord per minutt)' }).press('Home');
	await expect(page.getByText('5 WPM', { exact: true })).toBeVisible();
	await page.keyboard.press('t');
	await expect(page.getByRole('button', { name: 'T: —', exact: true })).toHaveClass(/playing/);
	await expect(page.getByRole('button', { name: 'T: —', exact: true })).toBeDisabled();
	await expect(page.getByRole('button', { name: 'Forhåndsvisning av blink' })).toHaveClass(
		/active/,
	);
	await expect(page.getByRole('button', { name: 'T: —', exact: true })).toBeEnabled();
	await page.getByRole('button', { name: '0: —————', exact: true }).click();
	await page.getByRole('link', { name: 'sende', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Start øving' })).toBeVisible();
	await page.goBack();
	await expect(page.locator('.letter-tile.playing')).toHaveCount(0);
	await expect(page.getByRole('button', { name: 'T: —', exact: true })).toBeEnabled();
	await expect(page.getByRole('slider', { name: 'Hastighet (ord per minutt)' })).toHaveValue('15');
});

test('Morse receive scores correct and empty answers once, resets each round and replays', async ({
	page,
}) => {
	await disableAudio(page);
	await page.goto('/projects/morsekode/motta');
	await page.getByRole('slider', { name: 'Hastighet (ord per minutt)' }).press('End');
	await page.getByRole('button', { name: 'Start øving' }).click();
	await page.getByRole('button', { name: 'vis kode', exact: true }).click();
	const shownCode = await page.locator('.morse-hint').textContent();
	const [answer] = Object.entries(MORSE).find(([, code]) => formatMorse(code) === shownCode);
	await expect(page.getByRole('button', { name: 'spill av igjen', exact: true })).toBeEnabled();
	await page.getByRole('button', { name: 'spill av igjen', exact: true }).click();
	await expect(page.getByRole('button', { name: 'spiller…', exact: true })).toBeDisabled();
	await page.getByRole('textbox', { name: 'Bokstav eller tall' }).fill(answer.toLowerCase());
	await page.getByRole('button', { name: 'Sjekk svar', exact: true }).click();
	await expect(page.locator('.feedback')).toContainText(`Riktig! ${answer} er ${shownCode}.`);
	await expect(page.getByText('riktige: 1/1', { exact: true })).toBeVisible();
	await expect(page.getByText('streak: 1', { exact: true })).toBeVisible();
	await expect(page.locator('.history-item')).toHaveCount(1);
	await expect(page.getByRole('button', { name: 'Sjekk svar', exact: true })).toHaveCount(0);
	await page.getByRole('button', { name: 'Neste runde', exact: true }).click();
	await expect(page.getByRole('textbox', { name: 'Bokstav eller tall' })).toHaveValue('');
	await page.getByRole('button', { name: 'Sjekk svar', exact: true }).click();
	await expect(page.locator('.feedback')).toContainText('Du svarte ∅.');
	await expect(page.getByText('riktige: 1/2', { exact: true })).toBeVisible();
	await expect(page.getByText('presisjon: 50%', { exact: true })).toBeVisible();
	await expect(page.getByText('streak: 0', { exact: true })).toBeVisible();
	await expect(page.locator('.history-item')).toHaveCount(2);
});

test('Morse sending supports timed keyboard input, repeat protection, editing and round history', async ({
	page,
}) => {
	await disableAudio(page);
	await page.goto('/projects/morsekode/sende');
	await page.getByRole('button', { name: 'Start øving' }).click();
	const key = page.getByRole('button', { name: 'Morsenøkkel. Hold for prikk eller strek.' });
	await expect(page.getByRole('button', { name: 'Sjekk sending' })).toBeDisabled();
	await key.focus();
	await expect(key).toBeFocused();
	await sendTimedEvent(key, 'keydown', 1000, { code: 'Space', key: ' ', repeat: false });
	await expect(key).toHaveClass(/pressed/);
	await sendTimedEvent(key, 'keydown', 1250, { code: 'Space', key: ' ', repeat: true });
	await sendTimedEvent(key, 'keyup', 1300, { code: 'Space', key: ' ' });
	await expect(key).not.toHaveClass(/pressed/);
	await expect(page.locator('.buffer-chars')).toHaveText('—');
	await sendTimedEvent(key, 'keydown', 2000, { code: 'Space', key: ' ', repeat: false });
	await sendTimedEvent(key, 'keyup', 2100, { code: 'Space', key: ' ' });
	await expect(page.locator('.buffer-chars')).toHaveText('—·');
	await page.getByRole('button', { name: 'slett', exact: true }).click();
	await expect(page.locator('.buffer-chars')).toHaveText('—');
	await page.getByRole('button', { name: 'tøm', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Sjekk sending' })).toBeDisabled();
	const target = await page.getByLabel('Målbokstav').textContent();
	for (const symbol of MORSE[target]) {
		await page
			.getByRole('button', { name: symbol === '.' ? 'Legg til prikk' : 'Legg til strek' })
			.click();
	}
	await expect(page.locator('.buffer-guess')).toHaveText(`= ${target}`);
	await page.getByRole('button', { name: 'Sjekk sending' }).click();
	await expect(page.locator('.feedback')).toHaveText(
		`Riktig! ${formatMorse(MORSE[target])} = ${target}.`,
	);
	await expect(page.locator('.history-item')).toHaveCount(1);
	await expect(page.getByText('riktige: 1/1', { exact: true })).toBeVisible();
	await expect(key).toHaveCount(0);
	await page.getByRole('button', { name: 'Neste runde', exact: true }).click();
	await expect(page.locator('.buffer-empty')).toBeVisible();
	for (let index = 0; index < 6; index++) {
		await page.getByRole('button', { name: 'Legg til prikk' }).click();
	}
	await page.getByRole('button', { name: 'Sjekk sending' }).click();
	await expect(page.locator('.feedback')).toContainText('er ikke en gyldig morsekode.');
	await expect(page.getByText('riktige: 1/2', { exact: true })).toBeVisible();
	await expect(page.locator('.history-item')).toHaveCount(2);
});

test.describe('mobile Morse', () => {
	test.use({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
	test('touch cancellation, short taps and route reentry cannot leave the key held', async ({
		page,
	}) => {
		await disableAudio(page);
		await page.goto('/projects/morsekode/sende');
		await page.getByRole('button', { name: 'Start øving' }).tap();
		const key = page.getByRole('button', { name: 'Morsenøkkel. Hold for prikk eller strek.' });
		await sendTimedEvent(key, 'pointerdown', 1000, { pointerType: 'touch', pointerId: 1 });
		await sendTimedEvent(key, 'pointerup', 1020, { pointerType: 'touch', pointerId: 1 });
		await expect(page.locator('.buffer-empty')).toBeVisible();
		await sendTimedEvent(key, 'pointerdown', 2000, { pointerType: 'touch', pointerId: 2 });
		await sendTimedEvent(key, 'pointercancel', 2100, { pointerType: 'touch', pointerId: 2 });
		await expect(key).not.toHaveClass(/pressed/);
		await expect(page.locator('.buffer-chars')).toHaveText('·');
		await sendTimedEvent(key, 'pointerup', 2400, { pointerType: 'touch', pointerId: 2 });
		await expect(page.locator('.buffer-chars')).toHaveText('·');
		await sendTimedEvent(key, 'pointerdown', 3000, { pointerType: 'touch', pointerId: 3 });
		await sendTimedEvent(key, 'pointerleave', 3300, { pointerType: 'touch', pointerId: 3 });
		await expect(page.locator('.buffer-chars')).toHaveText('·—');
		await expect(key).not.toHaveClass(/pressed/);
		await page.getByRole('link', { name: 'motta', exact: true }).tap();
		await page.goBack();
		await expect(page.getByRole('button', { name: 'Start øving' })).toBeVisible();
		await page.getByRole('button', { name: 'Start øving' }).tap();
		await expect(key).not.toHaveClass(/pressed/);
		await expect(page.locator('.buffer-empty')).toBeVisible();
		expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
			true,
		);
	});
});

test('NATO preserves setup bounds, speech language, scoring, replay and cancellation on navigation', async ({
	page,
}, testInfo) => {
	await installSpeechMock(page);
	await page.goto('/projects/fonetisk-alfabet');
	await expect(page.getByLabel('Min', { exact: true })).toHaveValue('3');
	await expect(page.getByLabel('Maks', { exact: true })).toHaveValue('5');
	await captureResponsiveScreenshots(page, testInfo, 'nato');
	await page.getByLabel('Min', { exact: true }).selectOption('1');
	await page.getByLabel('Maks', { exact: true }).selectOption('2');
	await page.getByLabel('Min', { exact: true }).selectOption('2');
	await expect(page.getByLabel('Min', { exact: true }).locator('option')).toHaveCount(2);
	await expect(page.getByLabel('Maks', { exact: true }).locator('option').first()).toHaveValue('2');
	await page.getByRole('button', { name: 'Start spill' }).click();
	await expect(page.getByRole('button', { name: 'Spiller av…' })).toBeDisabled();
	await expect(page.getByLabel('Språk for opplesning')).toBeDisabled();
	await expect(page.getByRole('button', { name: 'Neste runde' })).toBeDisabled();
	await expect.poll(() => page.evaluate(() => window.__speech.calls.length)).toBe(1);
	expect(
		await page.evaluate(() => {
			const utterance = window.__speech.calls[0];
			return {
				language: utterance.lang,
				voice: utterance.voice.voiceURI,
				rate: utterance.rate,
				pitch: utterance.pitch,
			};
		}),
	).toEqual({ language: 'nb-NO', voice: 'test-norwegian', rate: 0.85, pitch: 1 });
	await page.evaluate(() => window.__speech.finish());
	await expect(page.getByRole('button', { name: 'Spill av ord igjen' })).toBeEnabled();
	await page.getByLabel('Språk for opplesning').selectOption('en-GB');
	await page.getByRole('button', { name: 'Spill av ord igjen' }).click();
	await expect.poll(() => page.evaluate(() => window.__speech.calls.length)).toBe(2);
	expect(await page.evaluate(() => window.__speech.calls[1].voice.voiceURI)).toBe('test-british');
	await page.evaluate(() => window.__speech.finish());
	await page.getByRole('button', { name: 'Vis ord', exact: true }).click();
	const words = await page.getByLabel('Ord i runden').locator('.round-word').allTextContents();
	expect(words).toHaveLength(2);
	expect(await page.evaluate(() => window.__speech.calls[1].text)).toBe(words.join(' '));
	const answer = words.map((word) => word[0]).join('');
	await page.getByRole('button', { name: 'Skjul ord', exact: true }).click();
	await expect(page.getByLabel('Ord i runden')).toHaveCount(0);
	await page
		.getByRole('textbox', { name: 'Hvilke bokstaver hørte du?' })
		.fill(answer.toLowerCase().split('').join(' - '));
	await page.getByRole('button', { name: 'Sjekk svar', exact: true }).click();
	await expect(page.locator('.feedback')).toContainText(`= ${answer}.`);
	await expect(page.getByLabel('Rundehistorikk')).toContainText(
		'Oppsummering: 2/2 riktige bokstaver (100%)',
	);
	await expect(page.getByRole('textbox', { name: 'Hvilke bokstaver hørte du?' })).toBeDisabled();
	await expect(page.getByRole('button', { name: 'Sjekk svar', exact: true })).toBeDisabled();
	await page.getByRole('button', { name: 'Neste runde' }).click();
	await expect(page.getByText('$ play --round 2', { exact: true })).toBeVisible();
	await expect(page.getByRole('textbox', { name: 'Hvilke bokstaver hørte du?' })).toHaveValue('');
	await expect(page.getByLabel('Ord i runden')).toHaveCount(0);
	await expect.poll(() => page.evaluate(() => window.__speech.calls.length)).toBe(3);
	await page.getByRole('button', { name: 'Sjekk svar', exact: true }).click();
	await expect(page.getByLabel('Rundehistorikk')).toContainText(
		'Oppsummering: 2/4 riktige bokstaver (50%)',
	);
	await expect(page.locator('.feedback')).toContainText('0/2 riktige.');
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'Om', exact: true })).toBeVisible();
	await expect.poll(() => page.evaluate(() => window.__speech.cancellations)).toBe(1);
	expect(await page.evaluate(() => window.__speech.listenerCount())).toBe(0);
	expect(await page.evaluate(() => window.__speech.calls.at(-1).onend)).toBeNull();
	await page.goBack();
	await expect(page.getByRole('button', { name: 'Start spill' })).toBeVisible();
	await expect.poll(() => page.evaluate(() => window.__speech.listenerCount())).toBe(1);
});

test('NATO speech failure releases replay controls and absent speech still allows visual practice', async ({
	page,
}) => {
	await installSpeechMock(page);
	await page.goto('/projects/fonetisk-alfabet');
	await page.getByRole('button', { name: 'Start spill' }).click();
	await expect.poll(() => page.evaluate(() => window.__speech.calls.length)).toBe(1);
	await page.evaluate(() => window.__speech.fail());
	await expect(page.locator('.feedback')).toHaveText('Klarte ikke å spille av tale i nettleseren.');
	await expect(page.getByRole('button', { name: 'Spill av ord igjen' })).toBeEnabled();
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await page.evaluate(() => {
		Object.defineProperty(window, 'SpeechSynthesisUtterance', {
			configurable: true,
			value: undefined,
		});
	});
	await page.goBack();
	await expect(page.locator('.feedback')).toContainText('støtter ikke taleavspilling');
	await page.getByRole('button', { name: 'Start spill' }).click();
	await expect(page.getByRole('button', { name: 'Spill av ord igjen' })).toBeDisabled();
	await page.getByRole('button', { name: 'Vis ord', exact: true }).click();
	await expect(page.getByLabel('Ord i runden')).toBeVisible();
	await page.getByRole('button', { name: 'Sjekk svar', exact: true }).click();
	await expect(page.getByRole('button', { name: 'Neste runde' })).toBeEnabled();
});

test('screen capture passes options, previews a real stream, stops all tracks and handles browser stop', async ({
	page,
}, testInfo) => {
	await installDisplayMediaMock(page);
	await page.goto('/projects/skjermdeling-lab');
	const start = page.getByRole('button', { name: 'Start skjermdeling' });
	const stop = page.getByRole('button', { name: 'Stopp', exact: true });
	const audio = page.getByRole('checkbox', { name: 'Del systemlyd hvis tilgjengelig' });
	await expect(start).toBeEnabled();
	await expect(stop).toBeDisabled();
	await audio.check();
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(1);
	expect(await page.evaluate(() => window.__capture.requests[0].options)).toEqual({
		video: { frameRate: { ideal: 30, max: 60 } },
		audio: true,
	});
	await page.evaluate(() => window.__capture.resolve(0));
	await expect(page.getByRole('status')).toHaveText('Skjermdeling er aktiv.');
	await expect(start).toBeDisabled();
	await expect(audio).toBeDisabled();
	await expect(page.locator('.preview')).toHaveAttribute('data-active', 'true');
	await expect
		.poll(() => page.locator('video').evaluate((video) => Boolean(video.srcObject)))
		.toBe(true);
	expect(await page.locator('video').evaluate((video) => video.muted)).toBe(true);
	await captureResponsiveScreenshots(page, testInfo, 'screen-active');
	await stop.click();
	await expectStoppedCapture(page, 0);
	await expect(page.locator('video')).toHaveJSProperty('srcObject', null);
	await expect(start).toBeEnabled();
	await expect(audio).toBeEnabled();
	await audio.uncheck();
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(2);
	expect(await page.evaluate(() => window.__capture.requests[1].options.audio)).toBe(false);
	await page.evaluate(() => window.__capture.resolve(1));
	await expect(stop).toBeEnabled();
	await page.evaluate(() =>
		window.__capture.streams[1].stream.getVideoTracks()[0].dispatchEvent(new Event('ended')),
	);
	await expect(page.getByRole('status')).toHaveText('Skjermdeling ble stoppet fra nettleseren.');
	await expectStoppedCapture(page, 1);
	await expect(stop).toBeDisabled();
	await expect(page.locator('video')).toHaveJSProperty('srcObject', null);
});

test('screen capture recovers from permission rejection and disposes an active stream on navigation', async ({
	page,
}) => {
	await installDisplayMediaMock(page);
	await page.goto('/projects/skjermdeling-lab');
	const start = page.getByRole('button', { name: 'Start skjermdeling' });
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(1);
	await page.evaluate(() => window.__capture.reject(0, 'NotAllowedError'));
	await expect(page.getByRole('status')).toHaveText(
		'Skjermdeling ble avbrutt eller blokkert. Prøv igjen og tillat tilgang.',
	);
	await expect(start).toBeEnabled();
	await expect(page.locator('video')).toHaveJSProperty('srcObject', null);
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(2);
	await page.evaluate(() => window.__capture.resolve(1));
	await expect(page.getByRole('button', { name: 'Stopp', exact: true })).toBeEnabled();
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await expectStoppedCapture(page, 0);
	await expect(page.locator('video')).toHaveCount(0);
	await page.goBack();
	await expect(start).toBeEnabled();
	await expect(page.getByRole('button', { name: 'Stopp', exact: true })).toBeDisabled();
	await expect(page.locator('video')).toHaveJSProperty('srcObject', null);
});

test('late screen permission results cannot capture after leaving or replace a newer session', async ({
	page,
}) => {
	await installDisplayMediaMock(page);
	await page.goto('/projects/skjermdeling-lab');
	const start = page.getByRole('button', { name: 'Start skjermdeling' });
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(1);
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'Om', exact: true })).toBeVisible();
	await page.evaluate(() => window.__capture.resolve(0));
	await expectStoppedCapture(page, 0);
	await page.goBack();
	await expect(start).toBeEnabled();
	await expect(page.locator('video')).toHaveJSProperty('srcObject', null);
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(2);
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await page.goBack();
	await expect(start).toBeEnabled();
	await start.click();
	await expect.poll(() => page.evaluate(() => window.__capture.requests.length)).toBe(3);
	await page.evaluate(() => window.__capture.resolve(2));
	await expect(page.getByRole('button', { name: 'Stopp', exact: true })).toBeEnabled();
	await expect
		.poll(() =>
			page
				.locator('video')
				.evaluate((video) => video.srcObject === window.__capture.streams[1].stream),
		)
		.toBe(true);
	await page.evaluate(() => window.__capture.resolve(1));
	await expectStoppedCapture(page, 2);
	expect(await page.evaluate(() => window.__capture.streams[1].stops)).toBe(0);
	expect(
		await page
			.locator('video')
			.evaluate((video) => video.srcObject === window.__capture.streams[1].stream),
	).toBe(true);
	await page.getByRole('button', { name: 'Stopp', exact: true }).click();
	await expectStoppedCapture(page, 1);
});

test('unsupported screen capture has a safe disabled start', async ({ page }) => {
	await page.addInitScript(() => {
		if (navigator.mediaDevices)
			Object.defineProperty(navigator.mediaDevices, 'getDisplayMedia', {
				configurable: true,
				value: undefined,
			});
	});
	await page.goto('/projects/skjermdeling-lab');
	await expect(page.getByRole('button', { name: 'Start skjermdeling' })).toBeDisabled();
	await expect(page.getByRole('button', { name: 'Stopp', exact: true })).toBeDisabled();
	await expect(page.locator('.source')).toHaveText('Kilde: Ingen aktiv kilde');
});

test('robot keyboard, pointer release, pause and repeated reset survive route reentry', async ({
	page,
}, testInfo) => {
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await page.goto('/projects/robot-tohjul');
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeEnabled();
	await expect(page.locator('#robot-world canvas')).toHaveCount(1);
	await captureResponsiveScreenshots(page, testInfo, 'robot');
	const forward = page.getByRole('button', { name: 'Kjør framover (W)' });
	await expect(forward).toBeDisabled();
	await page.getByRole('button', { name: 'spill av', exact: true }).click();
	await page.getByRole('group', { name: /Robotens 3D-verden/ }).focus();
	await page.keyboard.down('w');
	await expect(forward).toHaveAttribute('aria-pressed', 'true');
	await page.keyboard.up('w');
	await expect(forward).toHaveAttribute('aria-pressed', 'false');
	const right = page.getByRole('button', { name: 'Sving til høyre (D)' });
	await right.dispatchEvent('pointerdown', { pointerType: 'touch', pointerId: 1 });
	await expect(right).toHaveAttribute('aria-pressed', 'true');
	await right.dispatchEvent('pointercancel', { pointerType: 'touch', pointerId: 1 });
	await expect(right).toHaveAttribute('aria-pressed', 'false');
	await page.keyboard.down('w');
	await page.getByRole('button', { name: 'pause', exact: true }).click();
	await expect(forward).toHaveAttribute('aria-pressed', 'false');
	await page.keyboard.up('w');
	await expect(forward).toBeDisabled();
	for (let index = 0; index < 3; index++) {
		await page.getByRole('button', { name: 'start på nytt', exact: true }).click();
		await expect(page.locator('#robot-world canvas')).toHaveCount(1);
	}
	await page.getByRole('link', { name: '~/om', exact: true }).click();
	await expect(page.locator('canvas')).toHaveCount(0);
	await page.goBack();
	await expect(page.getByRole('button', { name: 'spill av', exact: true })).toBeEnabled();
	await expect(page.locator('#robot-world canvas')).toHaveCount(1);
	await expect(forward).toHaveAttribute('aria-pressed', 'false');
});

test('falling clones reset repeatedly and navigation restores visibility, overflow and animations', async ({
	page,
}, testInfo) => {
	await page.goto('/projects');
	const originalOverflow = await page.evaluate(() => document.body.style.overflow);
	await page.getByRole('link', { name: /fall≠ned/ }).click();
	for (let index = 0; index < 3; index++) {
		await expect.poll(() => page.locator('.fall-clone').count()).toBeGreaterThan(0);
		await expect(page.getByRole('button', { name: 'reset side', exact: true })).toBeVisible();
		await page.evaluate(() => {
			window.__fallAnimations = document
				.getAnimations()
				.filter((animation) => animation.effect?.target?.closest('.falling-layer'));
		});
		await page.getByRole('button', { name: 'reset side', exact: true }).click();
		await expect(page.locator('.fall-clone')).toHaveCount(0);
		await expect(page.locator('.falling-layer')).toHaveCount(0);
		await expect(page.getByRole('heading', { name: 'fall≠ned', exact: true })).toBeVisible();
		await expect(page.getByRole('link', { name: '~/om', exact: true })).toBeVisible();
		expect(await page.evaluate(() => document.body.style.overflow)).toBe(originalOverflow);
		expect(
			await page.evaluate(() =>
				window.__fallAnimations.every((animation) => animation.playState === 'idle'),
			),
		).toBe(true);
		await page.getByRole('button', { name: 'slipp alt igjen', exact: true }).click();
	}
	await expect.poll(() => page.locator('.fall-clone').count()).toBeGreaterThan(0);
	await page.goBack();
	await expect(page).toHaveURL(/\/projects$/);
	await expect(page.locator('.fall-clone')).toHaveCount(0);
	await expect(page.locator('.falling-layer')).toHaveCount(0);
	await expect(page.getByRole('link', { name: '~/om', exact: true })).toBeVisible();
	expect(await page.evaluate(() => document.body.style.overflow)).toBe(originalOverflow);
	await page.goForward();
	await expect.poll(() => page.locator('.fall-clone').count()).toBeGreaterThan(0);
	await page.getByRole('button', { name: 'reset side', exact: true }).click();
	await expect(page.getByRole('heading', { name: 'fall≠ned', exact: true })).toBeVisible();
	await captureResponsiveScreenshots(page, testInfo, 'fall-reset');
});

test('all migrated routes survive repeated back/forward and unknown routes offer recovery', async ({
	page,
}) => {
	await disableAudio(page);
	await page.emulateMedia({ reducedMotion: 'reduce' });
	const routes = [
		['/projects/diff-tool', 'tekst≠diff'],
		['/projects/morsekode/oversikt', 'morse≠kode'],
		['/projects/morsekode/motta', 'morse≠kode'],
		['/projects/morsekode/sende', 'morse≠kode'],
		['/projects/fonetisk-alfabet', 'fonetisk≠spill'],
		['/projects/skjermdeling-lab', 'skjerm≠deling'],
		['/projects/prompt-lab', 'prompt≠lab'],
	];
	for (const [route, title] of routes) {
		await page.goto(route);
		await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible();
		const documentIdentity = await page.evaluate(() => {
			window.__migrationDocument = crypto.randomUUID();
			return window.__migrationDocument;
		});
		await page.getByRole('link', { name: '~/om', exact: true }).click();
		await expect(page.getByRole('heading', { name: 'Om', exact: true })).toBeVisible();
		expect(
			await page.evaluate(() => window.__migrationDocument),
			'Internal links must retain the Gleam application document',
		).toBe(documentIdentity);
		for (let iteration = 0; iteration < 2; iteration++) {
			await page.goBack();
			await expect(page).toHaveURL(new RegExp(`${route}$`));
			await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible();
			expect(
				await page.evaluate(() => window.__migrationDocument),
				'Back must use the existing Gleam application',
			).toBe(documentIdentity);
			await page.goForward();
			await expect(page.getByRole('heading', { name: 'Om', exact: true })).toBeVisible();
			expect(
				await page.evaluate(() => window.__migrationDocument),
				'Forward must use the existing Gleam application',
			).toBe(documentIdentity);
			await expect(page.locator('canvas, video, .fall-clone')).toHaveCount(0);
		}
	}
	for (const route of [
		'/does-not-exist',
		'/projects/missing-project',
		'/projects/morsekode/missing-mode',
	]) {
		await page.goto(route);
		await expect(page.getByRole('heading', { name: 'Fant ikke siden', exact: true })).toBeVisible();
		await page.getByRole('link', { name: 'Se alle prosjekter', exact: true }).click();
		await expect(page).toHaveURL(/\/projects$/);
		await expect(page.getByRole('status')).toContainText('Viser 9 av 9');
	}
});

test('explicit navigation starts at the top while back and forward restore both scroll positions', async ({
	page,
}, testInfo) => {
	await disableAudio(page);
	await page.addInitScript(() => {
		window.__scrollDiagnostics = [];
		const record = (event, details = {}) => {
			window.__scrollDiagnostics.push({
				event,
				time: Math.round(performance.now()),
				path: location.pathname,
				historyState: history.state,
				x: scrollX,
				y: scrollY,
				height: document.documentElement.scrollHeight,
				viewport: innerHeight,
				...details,
			});
		};
		const nativeScrollTo = window.scrollTo.bind(window);
		window.scrollTo = (...args) => {
			record('scrollTo:before', { requested: args });
			nativeScrollTo(...args);
			record('scrollTo:after');
			requestAnimationFrame(() => record('scrollTo:nextFrame'));
		};
		for (const method of ['pushState', 'replaceState']) {
			const nativeMethod = history[method].bind(history);
			history[method] = (...args) => {
				record(`${method}:before`, { destination: args[2] });
				const result = nativeMethod(...args);
				record(`${method}:after`);
				return result;
			};
		}
		window.addEventListener('popstate', () => record('popstate'), true);
		window.addEventListener('scroll', () => record('scroll'));
	});
	let catalogScroll;
	let morseScroll;
	try {
		await page.setViewportSize({ width: 800, height: 500 });
		await page.goto('/projects');
		const morseCard = page.getByRole('link', { name: /morse≠kode/ });
		await morseCard.scrollIntoViewIfNeeded();
		await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(100);
		catalogScroll = await page.evaluate(() => scrollY);
		await morseCard.click();
		await expect(page).toHaveURL(/\/projects\/morsekode$/);
		await expect(page.getByRole('heading', { name: 'morse≠kode', exact: true })).toBeVisible();
		await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
		await page.getByRole('region', { name: 'Rundehistorikk' }).scrollIntoViewIfNeeded();
		await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(100);
		morseScroll = await page.evaluate(() => scrollY);
		for (let iteration = 0; iteration < 3; iteration++) {
			await page.goBack();
			await expect(page).toHaveURL(/\/projects$/);
			await expect
				.poll(() => page.evaluate((saved) => Math.abs(scrollY - saved), catalogScroll), {
					message: `Restore catalog scroll to ${catalogScroll}px on Back ${iteration + 1}`,
				})
				.toBeLessThanOrEqual(2);
			await page.goForward();
			await expect(page).toHaveURL(/\/projects\/morsekode$/);
			await expect
				.poll(() => page.evaluate((saved) => Math.abs(scrollY - saved), morseScroll), {
					message: `Restore Morse scroll to ${morseScroll}px on Forward ${iteration + 1}`,
				})
				.toBeLessThanOrEqual(2);
		}
	} catch (error) {
		const diagnostics = {
			expected: { catalogScroll, morseScroll },
			browser: await page.evaluate(() => ({
				events: window.__scrollDiagnostics,
				current: {
					path: location.pathname,
					x: scrollX,
					y: scrollY,
					height: document.documentElement.scrollHeight,
					viewport: innerHeight,
				},
				images: [...document.images].map((image) => ({
					source: image.getAttribute('src'),
					complete: image.complete,
					width: image.width,
					height: image.height,
					naturalWidth: image.naturalWidth,
					naturalHeight: image.naturalHeight,
				})),
			})),
		};
		const details = JSON.stringify(diagnostics, null, 2);
		console.log(`Scroll restoration diagnostics:\n${details}`);
		await testInfo.attach('scroll-diagnostics.json', {
			body: Buffer.from(details),
			contentType: 'application/json',
		});
		throw error;
	}
});
