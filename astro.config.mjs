// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

const lessons = [
	'guides/pki-foundations',
	'guides/build-your-ca',
	'guides/issue-and-inspect',
	'guides/mtls-nginx',
	'guides/eap-tls-freeradius',
	'guides/operations',
];

export default defineConfig({
	site: 'https://pki.fun',
	integrations: [
		starlight({
			title: 'pki.fun',
			disable404Route: true,
			description:
				'A free, hands-on place to learn certificate technologies. Build a real CA, secure services with mTLS and set up EAP-TLS using open-source tools.',
			logo: {
				src: './src/assets/logo.svg',
				alt: '',
			},
			favicon: '/favicon.svg',
			customCss: [
				'@fontsource-variable/dm-sans',
				'@fontsource-variable/space-grotesk',
				'@fontsource-variable/jetbrains-mono',
				'./src/styles/custom.css',
			],
			expressiveCode: {
				themes: ['github-dark'],
				useStarlightDarkModeSwitch: false,
				useStarlightUiThemeColors: false,
				// Wrap long expected-output lines (fingerprints, key IDs); keep commands on one line so they scroll.
				defaultProps: {
					wrap: true,
					overridesByLang: { 'sh,bash,shell,powershell,nginx': { wrap: false } },
				},
				styleOverrides: {
					frames: { editorActiveTabIndicatorTopColor: 'transparent' },
					borderRadius: '0.75rem',
					codeFontFamily: "'JetBrains Mono Variable', ui-monospace, monospace",
					uiFontFamily: "'DM Sans Variable', ui-sans-serif, system-ui, sans-serif",
				},
			},
			plugins: [starlightLinksValidator()],
			editLink: {
				baseUrl: 'https://github.com/llewis1234/pki-fun/edit/main/',
			},
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/llewis1234/pki-fun' }],
			components: {
				Header: './src/components/Header.astro',
				PageTitle: './src/components/PageTitle.astro',
				Footer: './src/components/Footer.astro',
			},
			sidebar: [
				{
					label: 'Start here',
					items: [
						{ label: 'Learning Path', link: '/path/' },
						{ label: 'Browse guides', link: '/guides/' },
						{ slug: 'setup' },
					],
				},
				{ label: 'Lessons', items: lessons.map((slug) => ({ slug })) },
				{ label: 'Reference', items: [{ slug: 'glossary' }, { slug: 'about' }] },
			],
		}),
	],
});
