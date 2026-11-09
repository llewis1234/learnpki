# Contributing

Thanks for helping improve pki.fun. Contributions should keep the course hands-on, accurate, and accessible to learners who know basic Linux and Docker but are new to PKI.

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

For lab changes, run the lab's `solution.sh` followed by `check.sh` in order.

## Licensing

Code and lab contributions are licensed under Apache-2.0. Lesson text contributions are licensed under CC BY 4.0.