# Learn PKI agent rules

## Brand and tone

- The brand name and site URL each live in one value in `site.config.mjs` (`SITE_NAME`, `SITE_URL`). Never hard-code them in pages, components or config. In MDX, import them. Frontmatter can't import, so keep the brand out of titles and descriptions. It is an independent community project.
- Labs carry no brand: the CA is `Lab CA`, the lab folder is `~/pki-lab`, and system folders use `pki-lab` (for example `/etc/pki-lab`).
- Keep the footer disclaimer: not affiliated with or endorsed by Smallstep, FreeRADIUS or nginx.
- No fictional company or story framing. Lessons teach the technology directly, using neutral names like `localhost`, `alice` and `example.com`.
- Use only original art. Do not use Smallstep logos, Smallstep brand colors, copied tutorial text, or references to TV shows or films.
- Keep the tone friendly, plain and direct. Do not add a backend, authentication, analytics, tracking, or cookies. Lesson progress lives only in the learner's browser (`localStorage`).

## Look and feel

- "Cloud White" palette with a blue accent, tokens in `src/styles/custom.css` (Starlight `--sl-*` variables plus site `--pf-*` tokens). Keep light and dark modes in step.
- Space Grotesk headings, DM Sans body, JetBrains Mono for code. Fonts are self-hosted via `@fontsource-variable/*`.
- Code blocks are always dark (Expressive Code `github-dark`).

## Site structure

- Lessons live in `src/content/docs/guides/` and are ordered by the `module` frontmatter field. Each lesson sets `module`, `summary`, `topic` (PKI, mTLS, EAP-TLS, ACME, SSH, Tools), `level`, `minutes`, a numbered `sidebar.label`, and optional `cards` (flip cards) and `outline: true`.
- When adding a lesson, also add its slug to the `lessons` list in `astro.config.mjs`.
- Use `.mdx` when a lesson needs `<Diagram kind="chain|mtls|eaptls" />`; otherwise `.md`.
- Glossary terms live in `src/data/glossary.ts`. Each term has an anchor ID from `termId()`, so lessons can link to `/glossary/#<id>`.
- Social preview images live in `public/og/`. Run `npm run og` after you change a lesson's title, topic, level or minutes, or `SITE_NAME` or `SITE_URL`, then commit the PNG files. `src/routeData.ts` adds the image tags and the JSON-LD data.

## Lab rules

- The default lab environment is the Multipass VM built from `public/lab/cloud-init.yaml` (Ubuntu 24.04, user `ubuntu`). Capture expected output there, so paths read `/home/ubuntu/...`. Host installs are the advanced option in Lab Setup.
- When a pinned version changes, update `labs/versions.env`, the versions and SHA-256 hashes in `public/lab/cloud-init.yaml`, and Lab Setup together. CI fails if the step versions differ.
- Learners keep the CA in the step CLI's default `$(step path)` directory and work in one folder per lesson under `~/pki-lab`. Lessons build on each other: later modules use the CA from module 2.
- Pin tool versions in `labs/versions.env` and state them in Lab Setup and lessons.
- Use real passwords in lesson instructions. Any `--no-password`, `--password-file` or `--insecure` flags in scripts must have a nearby comment that says they are for CI only.
- Verify every command and flag against the pinned tool or its official documentation. Never invent output; run commands to capture it.
- `labs/run-all.sh` runs every lab command in order and marks each output block (`<lesson>:<n>`, the n-th output block in the lesson). When you add, remove or reorder an output block, update the script to match. `labs/refresh-output.py run.log` copies a run's output into the lessons, so all output comes from one run.
- Each module that changes system files ends with a "Clean up" section. Module 6 uses port 9443, so it never meets module 4's nginx site on 8443.

## Writing rules

- Lesson shape: short explanation, diagram where useful, commands with expected output, callouts (`:::tip`, `:::caution`, `:::note`), optional flip cards, "Go deeper" links.
- Keep one action in each step and use the imperative. Keep step sentences to 20 words or fewer and explanation sentences to 25 words or fewer.
- Show each command in its own code block (`title="terminal"`) and its real output in a separate block (`title="Expected output"`).
- Define terms when they first appear and add them to the glossary.
- Link to primary sources, including relevant RFCs, official docs, and source code. Do not copy their prose.
- Add alt text to images and diagrams.

## Verification

- If a command or its output cannot be verified, mark it `{/* UNVERIFIED: reason */}` in MDX (or `<!-- UNVERIFIED -->` in Markdown) and report it.
- Explain every new dependency and its purpose in your summary.
- Do not commit unless asked.
