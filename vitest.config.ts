import { defineConfig } from 'vitest/config';

export default defineConfig({
	test: {
		include: ['src/**/*.test.{ts,js}'],
		exclude: ['e2e/**', 'node_modules/**'],
	},
});
