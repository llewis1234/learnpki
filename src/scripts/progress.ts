/**
 * Lesson progress, stored only in this browser (localStorage). No accounts, nothing sent anywhere.
 *
 * Markup hooks:
 * - `[data-progress-slug]`        gets `data-done` when that lesson is complete.
 * - `nav.sidebar a[href]`         gets `data-done` when it links to a completed lesson.
 * - `[data-progress-bar]`         with `data-slugs="a b c"`: fills `[data-progress-fill]`,
 *                                 `[data-progress-count]` and `[data-progress-pct]`.
 * - `button[data-mark-complete]`  toggles the lesson named in its value.
 */

const KEY = 'pki.fun:progress';
const EVENT = 'pf-progress';

function read(): string[] {
	try {
		const parsed = JSON.parse(localStorage.getItem(KEY) ?? '[]');
		return Array.isArray(parsed) ? parsed.filter((s) => typeof s === 'string') : [];
	} catch {
		return [];
	}
}

function write(done: string[]) {
	try {
		localStorage.setItem(KEY, JSON.stringify(done));
	} catch {
		/* Storage can be unavailable (private mode, blocked site data). Progress just won't persist. */
	}
	document.dispatchEvent(new CustomEvent(EVENT));
}

function setDone(slug: string, value: boolean) {
	const done = new Set(read());
	if (value) done.add(slug);
	else done.delete(slug);
	write([...done]);
}

function lessonHref(slug: string) {
	return `/guides/${slug}/`;
}

function apply() {
	const done = new Set(read());

	document.querySelectorAll<HTMLElement>('[data-progress-slug]').forEach((el) => {
		el.toggleAttribute('data-done', done.has(el.dataset.progressSlug!));
	});

	const doneHrefs = new Set([...done].map(lessonHref));
	document.querySelectorAll<HTMLAnchorElement>('nav.sidebar a[href]').forEach((a) => {
		a.toggleAttribute('data-done', doneHrefs.has(a.getAttribute('href')!));
	});

	document.querySelectorAll<HTMLElement>('[data-progress-bar]').forEach((bar) => {
		const slugs = (bar.dataset.slugs ?? '').split(' ').filter(Boolean);
		const count = slugs.filter((s) => done.has(s)).length;
		const pct = slugs.length ? Math.round((count / slugs.length) * 100) : 0;
		const fill = bar.querySelector<HTMLElement>('[data-progress-fill]');
		if (fill) fill.style.width = `${pct}%`;
		const countEl = bar.querySelector('[data-progress-count]');
		if (countEl) countEl.textContent = String(count);
		const pctEl = bar.querySelector('[data-progress-pct]');
		if (pctEl) pctEl.textContent = `${pct}%`;
	});

	document.querySelectorAll<HTMLButtonElement>('button[data-mark-complete]').forEach((btn) => {
		const isDone = done.has(btn.dataset.markComplete!);
		btn.setAttribute('aria-pressed', String(isDone));
		const label = btn.querySelector('[data-label]');
		if (label) label.textContent = isDone ? 'Completed' : 'Mark complete';
	});
}

document.addEventListener('click', (event) => {
	const btn = (event.target as Element | null)?.closest<HTMLButtonElement>('button[data-mark-complete]');
	if (!btn) return;
	setDone(btn.dataset.markComplete!, btn.getAttribute('aria-pressed') !== 'true');
});

document.addEventListener(EVENT, apply);
window.addEventListener('storage', (e) => {
	if (e.key === KEY) apply();
});
apply();
