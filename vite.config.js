import { defineConfig } from 'vite';
export default defineConfig({
	publicDir: 'static',
	build: { outDir: 'dist' },
	define: { __APP_VERSION__: JSON.stringify(process.env.APP_VERSION || 'dev') },
});
