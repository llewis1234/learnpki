#!/usr/bin/env python3
"""Copies real command output from a labs/run-all.sh log into the lessons.

    python3 labs/refresh-output.py run.log

Each output block in a lesson is matched to the log section with the same ID
(`<lesson>:<n>`, the n-th output block in that lesson). Values such as serials,
fingerprints, key IDs and times change on every run, so each line of the old
block is matched to a new line with the same shape. Excerpts keep their
selection of lines. A line with no match is reported, and the block is left
for you to fix by hand.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUIDES = ROOT / 'src/content/docs/guides'
OUT_TITLE = re.compile(r'^(Expected output|FreeRADIUS debug output|step-ca log|letsencrypt\.log)')
BLOCK = re.compile(r'```(\w*)(?: title="([^"]*)")?\n(.*?)```', re.S)
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')
# A date and time at the start of a log line, which lessons leave out.
LOG_TIME = re.compile(r'^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}|time="[^"]*")\s+')


def shape(line: str) -> str:
    """The line with its changing values replaced by placeholders."""
    s = line.strip()
    s = re.sub(r'[A-Za-z0-9+/_-]{20,}={0,2}', 'B', s)
    s = re.sub(r'\b[0-9a-fA-F]{6,}\b', 'H', s)
    s = re.sub(r'(?:[0-9A-F]{2}:){3,}[0-9A-F]{2}', 'H', s)
    s = re.sub(r'\d+', '0', s)
    return re.sub(r'\s+', ' ', s)


def clean(text: str) -> list[str]:
    lines = []
    for line in ANSI.sub('', text).splitlines():
        if line.startswith('@@x'):
            continue
        if line.strip() == 'FEEDBACK 😍 🍻':
            break  # step prints a feedback note after `step ca init`. Lessons leave it out.
        lines.append(line)
    while lines and not lines[-1].strip():
        lines.pop()
    while lines and not lines[0].strip():
        lines.pop(0)
    return lines


def parse_log(path: Path) -> dict[str, list[str]]:
    sections, cur, buf = {}, None, []
    for line in path.read_text().splitlines():
        if line.startswith('@@@ '):
            if cur:
                sections[cur] = clean('\n'.join(buf))
            cur, buf = line[4:].strip(), []
        elif cur:
            buf.append(line)
    if cur:
        sections[cur] = clean('\n'.join(buf))
    return sections


def match(old: list[str], new: list[str]):
    """Returns the new block, and the old lines that found no match."""
    out, missed, start = [], [], 0
    candidates = [(l, LOG_TIME.sub('', l)) for l in new]

    def find(test):
        for i in range(start, len(candidates)):
            got = test(*candidates[i])
            if got is not None:
                return i, got
        return None

    for o in old:
        if o.strip() in ('...', ''):
            out.append(o)
            continue
        want = shape(o)
        # Same shape, with or without a log time in front.
        hit = find(lambda raw, untimed: raw if shape(raw) == want else (untimed if shape(untimed) == want else None))
        # A line the lesson cuts short with " ..." keeps the same number of comma-separated fields.
        if hit is None and o.rstrip().endswith(' ...'):
            head = o.rstrip()[:-4]
            n = head.count(', ') + 1

            def cut(raw, untimed):
                parts = untimed.split(', ')
                if len(parts) > n and shape(', '.join(parts[:n])) == shape(head):
                    return ', '.join(parts[:n]) + ' ...'
                return None

            hit = find(cut)
        if hit is None:
            missed.append(o)
            out.append(o)
        else:
            start = hit[0] + 1
            out.append(hit[1])
    return out, missed


def main() -> int:
    sections = parse_log(Path(sys.argv[1]))
    problems = 0
    for f in sorted(GUIDES.glob('*.md*')):
        text = f.read_text()
        if not re.search(r'^module: \d+', text, re.M):
            continue
        name = f.stem
        n = 0
        pieces, last = [], 0
        for m in BLOCK.finditer(text):
            title = m.group(2)
            if not title or not OUT_TITLE.match(title):
                continue
            n += 1
            bid = f'{name}:{n}'
            body = m.group(3)
            old = body.rstrip('\n').split('\n')
            new = sections.get(bid)
            if new is None:
                print(f'{bid}: no output in the log')
                problems += 1
                continue
            excerpt = '(' in title
            if old == ['PENDING']:
                result, missed = new, []
            else:
                result, missed = match(old, new)
                if missed and not excerpt:
                    result, missed = new, []
                    print(f'{bid}: shape changed. Took the whole new output. Check it.')
            for line in missed:
                print(f'{bid}: no match for: {line}')
                problems += 1
            pieces.append(text[last : m.start(3)])
            pieces.append('\n'.join(result) + '\n')
            last = m.end(3)
        pieces.append(text[last:])
        f.write_text(''.join(pieces))
    print(f'{problems} line(s) need a look.')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
