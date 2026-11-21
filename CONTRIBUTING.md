# Contributing

Thanks for helping improve Learn PKI. Contributions should keep the course hands-on, accurate, and accessible to learners who know basic Linux and Docker but are new to PKI.

## Before you contribute

- Keep lessons building on each other: later modules reuse the CA from module 2.
- Verify commands and flags with the pinned tools or their official documentation.
- Show real command output and real failure messages.
- Link to primary sources and write explanations in your own words.
- Do not add analytics, tracking, cookies, or backend services.
- Do not use Smallstep logos, brand colors, or copied tutorial text.
- Follow the lesson structure and writing rules in `CLAUDE.md`.

## Check your changes

```sh
npm ci
npm run build
```

For lab changes, run every lab on a disposable Ubuntu 24.04 machine, such as the lab VM. Then copy the real output into the lessons:

```sh
bash labs/run-all.sh > run.log
python3 labs/refresh-output.py run.log
```

`run-all.sh` changes system files, starts servers and adds user accounts, so never run it on your own computer. The "Run labs" GitHub workflow runs it every week and on pull requests that change lessons or labs.

## Licensing

Code and lab contributions are licensed under Apache-2.0. Lesson text contributions are licensed under CC BY-NC-SA 4.0.