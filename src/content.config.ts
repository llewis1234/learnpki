import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader, i18nLoader } from '@astrojs/starlight/loaders';
import { docsSchema, i18nSchema } from '@astrojs/starlight/schema';

/** Extra frontmatter for lessons in `src/content/docs/guides/`. Other pages leave these unset. */
const lessonFields = z.object({
	module: z.number().int().positive().optional(),
	summary: z.string().optional(),
	topic: z.enum(['PKI', 'mTLS', 'EAP-TLS', 'ACME', 'SSH', 'Tools']).optional(),
	level: z.enum(['Beginner', 'Intermediate', 'Advanced']).optional(),
	minutes: z.number().int().positive().optional(),
	/** True while a lesson is only an outline. */
	outline: z.boolean().default(false),
	/** Optional flip cards shown at the end of a lesson. Nothing is scored or saved. */
	cards: z.array(z.object({ q: z.string(), a: z.string() })).default([]),
});

export const collections = {
	docs: defineCollection({ loader: docsLoader(), schema: docsSchema({ extend: lessonFields }) }),
	i18n: defineCollection({ loader: i18nLoader(), schema: i18nSchema() }),
};
