import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import { SITE_NAME, SITE_URL } from '../site.config.mjs';
import { getLessons } from './data/lessons';

const LICENSE_URL = 'https://creativecommons.org/licenses/by-nc-sa/4.0/';

type HeadTag = { tag: 'meta' | 'script' | 'link'; attrs?: Record<string, string>; content?: string };

const meta = (property: string, content: string): HeadTag => ({ tag: 'meta', attrs: { property, content } });
const jsonLd = (data: object): HeadTag => ({
	tag: 'script',
	attrs: { type: 'application/ld+json' },
	content: JSON.stringify(data),
});

export const onRequest = defineRouteMiddleware(async (context) => {
	const route = context.locals.starlightRoute;
	const { id, data } = route.entry;

	// The 404 page is served for any missing path, so it has no canonical URL of its own.
	if (id === '404') {
		route.head = route.head.filter((tag) => !(tag.tag === 'link' && tag.attrs?.rel === 'canonical'));
		return;
	}

	const pageUrl = new URL(context.url.pathname, SITE_URL).href;
	const isLesson = id.startsWith('guides/') && data.module !== undefined;
	const slug = id.replace(/^guides\//, '');

	// Social preview image. Lessons have their own; other pages use the site image.
	// The images are made by `npm run og` (scripts/og-images.mjs).
	const image = new URL(`/og/${isLesson ? slug : 'site'}.png`, SITE_URL).href;
	route.head.push(
		meta('og:image', image),
		meta('og:image:width', '1200'),
		meta('og:image:height', '630'),
		meta('og:image:alt', isLesson ? `Module ${data.module}: ${data.title}` : `${SITE_NAME}: ${data.title}`),
		{ tag: 'meta', attrs: { name: 'twitter:image', content: image } },
	);

	const publisher = { '@type': 'Organization', name: SITE_NAME, url: `${SITE_URL}/` };
	const courseUrl = `${SITE_URL}/path/`;

	if (isLesson) {
		route.head.push(
			jsonLd({
				'@context': 'https://schema.org',
				'@type': 'TechArticle',
				headline: data.title,
				description: data.description,
				url: pageUrl,
				image,
				inLanguage: 'en',
				isAccessibleForFree: true,
				license: LICENSE_URL,
				educationalLevel: data.level,
				timeRequired: `PT${data.minutes}M`,
				publisher,
				isPartOf: { '@type': 'Course', name: `${SITE_NAME} Learning Path`, url: courseUrl },
			}),
		);
	} else if (id === 'path') {
		const lessons = await getLessons();
		route.head.push(
			jsonLd({
				'@context': 'https://schema.org',
				'@type': 'Course',
				name: `${SITE_NAME} Learning Path`,
				description: data.description,
				url: courseUrl,
				inLanguage: 'en',
				isAccessibleForFree: true,
				license: LICENSE_URL,
				provider: publisher,
				hasPart: lessons.map((l) => ({
					'@type': 'TechArticle',
					name: l.data.title,
					url: new URL(l.href, SITE_URL).href,
				})),
			}),
		);
	}
});
