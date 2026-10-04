import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
	testDir: './e2e',
	fullyParallel: true,
	use: {
		baseURL: 'http://127.0.0.1:4174',
		trace: 'on-first-retry',
		launchOptions: { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE },
	},
	webServer: {
		command: 'npm run build && npm run preview -- --host 127.0.0.1 --port 4174',
		port: 4174,
		reuseExistingServer: !process.env.CI,
		timeout: 120_000,
	},
	projects: [
		{
			name: 'chromium',
			use: { ...devices['Desktop Chrome'] },
		},
	],
});
