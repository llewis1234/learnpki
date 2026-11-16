import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

// The 404 page is served for any missing path, so it has no canonical URL of its own.
export const onRequest = defineRouteMiddleware((context) => {
	const route = context.locals.starlightRoute;
	if (route.entry.id === '404') {
		route.head = route.head.filter((tag) => !(tag.tag === 'link' && tag.attrs?.rel === 'canonical'));
	}
});
