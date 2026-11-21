// Makes the social preview images (Open Graph) in public/og/.
// Run with `npm run og` after you change SITE_NAME, SITE_URL, or a lesson's title,
// topic, level, or minutes. Commit the new PNG files.
//
// The text uses the fonts installed on your machine. For the closest match to the
// site, install Inter and JetBrains Mono first. Other fonts are fallbacks.

import { readdir, readFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import sharp from 'sharp';
import { SITE_NAME, SITE_URL } from '../site.config.mjs';

const W = 1200;
const H = 630;
const guidesDir = new URL('../src/content/docs/guides/', import.meta.url);
const outDir = new URL('../public/og/', import.meta.url);
const host = new URL(SITE_URL).host;

/** Reads the simple `key: value` lines of a lesson's frontmatter. */
function frontmatter(text) {
	const block = text.match(/^---\n([\s\S]*?)\n---/);
	const data = {};
	if (!block) return data;
	for (const line of block[1].split('\n')) {
		const m = line.match(/^(\w+):\s*(.*)$/);
		if (m) data[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
	}
	return data;
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** Breaks text into lines of at most `max` characters, at spaces. */
function wrap(text, max) {
	const lines = [];
	let line = '';
	for (const word of text.split(' ')) {
		if (line && (line + ' ' + word).length > max) {
			lines.push(line);
			line = word;
		} else {
			line = line ? line + ' ' + word : word;
		}
	}
	if (line) lines.push(line);
	return lines;
}

function svg({ kicker, title, meta }) {
	const lines = wrap(title, 24).slice(0, 3);
	const size = lines.length > 2 ? 64 : 76;
	const titleY = 300 - ((lines.length - 1) * size * 1.1) / 2;
	const grid = [];
	for (let x = 0; x <= W; x += 48) grid.push(`<path d="M${x} 0V${H}"/>`);
	for (let y = 0; y <= H; y += 48) grid.push(`<path d="M0 ${y}H${W}"/>`);
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
	<defs>
		<radialGradient id="glow" cx="0.25" cy="0.3" r="0.6">
			<stop offset="0" stop-color="#10b981" stop-opacity="0.16"/>
			<stop offset="1" stop-color="#10b981" stop-opacity="0"/>
		</radialGradient>
	</defs>
	<rect width="${W}" height="${H}" fill="#070b12"/>
	<rect width="${W}" height="${H}" fill="url(#glow)"/>
	<g stroke="#38bdf8" stroke-opacity="0.06" stroke-width="1">${grid.join('')}</g>
	<rect x="0" y="0" width="12" height="${H}" fill="#10b981"/>
	<g transform="translate(80 64) scale(1.75)">
		<rect x="0.5" y="0.5" width="31" height="31" rx="7.5" fill="#10b981" fill-opacity="0.15" stroke="#10b981" stroke-opacity="0.4"/>
		<path d="M16 6.5 8.5 9.3v6.2c0 4.8 3.2 8.6 7.5 10 4.3-1.4 7.5-5.2 7.5-10V9.3L16 6.5Z" fill="none" stroke="#34d399" stroke-width="2" stroke-linejoin="round"/>
		<path d="m12.4 16 2.6 2.6 4.8-5" fill="none" stroke="#34d399" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
	</g>
	<text x="152" y="108" font-family="Inter, Helvetica Neue, DejaVu Sans, Arial, sans-serif" font-size="36" font-weight="700" fill="#f1f5f9">${esc(SITE_NAME)}</text>
	<text x="80" y="${titleY - size}" font-family="JetBrains Mono, Menlo, DejaVu Sans Mono, monospace" font-size="26" fill="#34d399">${esc(kicker)}</text>
	${lines
		.map(
			(l, i) =>
				`<text x="80" y="${titleY + i * size * 1.1 + 20}" font-family="Inter, Helvetica Neue, DejaVu Sans, Arial, sans-serif" font-size="${size}" font-weight="700" fill="#f1f5f9">${esc(l)}</text>`,
		)
		.join('\n\t')}
	<text x="80" y="560" font-family="Inter, Helvetica Neue, DejaVu Sans, Arial, sans-serif" font-size="28" fill="#94a3b8">${esc(meta)}</text>
	<text x="${W - 80}" y="560" text-anchor="end" font-family="Inter, Helvetica Neue, DejaVu Sans, Arial, sans-serif" font-size="28" font-weight="600" fill="#34d399">${esc(host)}</text>
</svg>`;
}

async function render(name, card) {
	await sharp(Buffer.from(svg(card))).png().toFile(join(outDir.pathname, `${name}.png`));
	console.log(`public/og/${name}.png`);
}

await mkdir(outDir, { recursive: true });

await render('site', {
	kicker: 'Free hands-on course',
	title: 'Learn certificates by building them.',
	meta: 'PKI · mTLS · EAP-TLS · ACME · SSH',
});

for (const file of (await readdir(guidesDir)).sort()) {
	if (!/\.mdx?$/.test(file)) continue;
	const data = frontmatter(await readFile(new URL(file, guidesDir), 'utf8'));
	if (!data.module) continue;
	await render(file.replace(/\.mdx?$/, ''), {
		kicker: `Module ${String(data.module).padStart(2, '0')}`,
		title: data.title,
		meta: `${data.topic} · ${data.level} · ${data.minutes} min`,
	});
}
