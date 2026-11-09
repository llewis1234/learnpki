import { getCollection, type CollectionEntry } from 'astro:content';

export type Lesson = CollectionEntry<'docs'> & {
	slug: string;
	href: string;
	data: Required<Pick<CollectionEntry<'docs'>['data'], 'module' | 'summary' | 'topic' | 'level' | 'minutes'>>;
};

/** Lessons are pages under `guides/` that set a `module` number, sorted by module. */
export async function getLessons(): Promise<Lesson[]> {
	const entries = await getCollection('docs', (e) => e.id.startsWith('guides/') && e.data.module !== undefined);
	return entries
		.map((e) => {
			const slug = e.id.replace(/^guides\//, '');
			return { ...e, slug, href: `/guides/${slug}/` } as Lesson;
		})
		.sort((a, b) => a.data.module - b.data.module);
}

export const topics = ['PKI', 'mTLS', 'EAP-TLS', 'Tools'] as const;
export const levels = ['Beginner', 'Intermediate', 'Advanced'] as const;
