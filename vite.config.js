import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { defineConfig } from 'vite';
export default defineConfig({
	publicDir: 'static',
	plugins: [
		{
			name: 'version-elm-runtime',
			apply: 'build',
			transformIndexHtml(html) {
				// elm-watch owns this public asset, so Vite cannot fingerprint it itself.
				const hash = createHash('sha256')
					.update(readFileSync('static/elm.js'))
					.digest('hex')
					.slice(0, 16);
				return html.replace('src="/elm.js"', `src="/elm.js?v=${hash}"`);
			},
		},
	],
	build: { outDir: 'build' },
	define: { __APP_VERSION__: JSON.stringify(process.env.APP_VERSION || 'dev') },
});
