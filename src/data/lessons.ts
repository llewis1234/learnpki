import { getCollection, type CollectionEntry } from 'astro:content';

export type Lesson = CollectionEntry<'docs'> & {
	slug: string;
	href: string;
	data: Required<Pick<CollectionEntry<'docs'>['data'], 'module' | 'summary' | 'topic' | 'level' | 'minutes' | 'track' | 'requires'>>;
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

export const topics = ['PKI', 'mTLS', 'EAP-TLS', 'ACME', 'SSH', 'Tools'] as const;
export const levels = ['Beginner', 'Intermediate', 'Advanced'] as const;

/**
 * Learning Path tracks, in order. Each lesson names its track in frontmatter.
 * `color` is the track's accent (see `--pf-t-*` in custom.css). `tags` name the tools it uses.
 */
export const tracks = [
	{
		name: 'Core',
		color: 'var(--pf-t-core)',
		tags: ['X.509', 'step-ca', 'OpenSSL'],
		icon: 'key',
		text: 'PKI (public key infrastructure) is how keys, certificates and CAs decide who to trust. Learn how it works, then build your own CA.',
	},
	{
		name: 'mTLS',
		color: 'var(--pf-t-mtls)',
		tags: ['nginx', 'curl', 'Client certificates'],
		icon: 'network',
		text: 'In mutual TLS (mTLS), the client shows a certificate too, not only the server. Lock down a service with nginx.',
	},
	{
		name: 'EAP-TLS',
		color: 'var(--pf-t-eap)',
		tags: ['FreeRADIUS', 'eapol_test', '802.1X'],
		icon: 'wifi',
		text: 'EAP-TLS lets a device join Wi-Fi or a wired network (802.1X) with a certificate instead of a password. Build it with FreeRADIUS.',
	},
	{
		name: 'Operate',
		color: 'var(--pf-t-ops)',
		tags: ['Renewal', 'CRL', 'ACME'],
		icon: 'rotate',
		text: 'Renew, revoke and replace certificates. Then use ACME, the protocol behind Let\'s Encrypt, so machines get their own.',
	},
	{
		name: 'SSH',
		color: 'var(--pf-t-ssh)',
		tags: ['OpenSSH', 'User certs', 'Host certs'],
		icon: 'terminal',
		text: 'Short-lived SSH certificates replace the authorized_keys lists and "unknown host" prompts of plain SSH keys.',
	},
] as const;
