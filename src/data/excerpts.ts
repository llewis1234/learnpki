// Pulls commands and real output lines out of lesson files, so pages outside the lessons
// (such as the home page) never show made-up output. The build fails if a lesson changes
// and an excerpt no longer matches, so the excerpts can't drift.

const BLOCK = /```(\w*)(?: title="([^"]*)")?\n([\s\S]*?)```/g;

interface Block {
	title: string;
	body: string;
}

function blocks(raw: string): Block[] {
	return [...raw.matchAll(BLOCK)].map((m) => ({ title: m[2] ?? '', body: m[3].replace(/\n$/, '') }));
}

/** The first terminal command in `raw` that starts with `start`. */
export function command(raw: string, start: string): string {
	const found = blocks(raw).find((b) => b.title === 'terminal' && b.body.startsWith(start));
	if (!found) throw new Error(`excerpts: no terminal command starts with "${start}"`);
	return found.body;
}

/**
 * A terminal command and some lines of the output block right after it.
 * Each pattern in `keep` picks the first output line it matches, in order.
 */
export function excerpt(raw: string, start: string, keep: RegExp[]): { command: string; lines: string[] } {
	const all = blocks(raw);
	const i = all.findIndex((b) => b.title === 'terminal' && b.body.startsWith(start));
	if (i < 0) throw new Error(`excerpts: no terminal command starts with "${start}"`);
	const out = all[i + 1];
	if (!out || !out.title.startsWith('Expected output')) {
		throw new Error(`excerpts: no expected output right after "${start}"`);
	}
	const lines = out.body.split('\n');
	return {
		command: all[i].body,
		lines: keep.map((re) => {
			const line = lines.find((l) => re.test(l));
			if (!line) throw new Error(`excerpts: no output line matches ${re} after "${start}"`);
			return line;
		}),
	};
}
