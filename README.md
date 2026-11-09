# pki.fun

pki.fun is a free, open-source place to learn certificate technologies by building them. Short explanations pair with hands-on labs that use open-source tools: the step CLI and step-ca, OpenSSL, nginx, FreeRADIUS and curl.

The Learning Path has six modules:

1. PKI Foundations
2. Build your own CA with step-ca
3. Issue and inspect certificates with step CLI
4. mTLS: secure a service with nginx
5. EAP-TLS with FreeRADIUS
6. Operations: renewal, rotation and troubleshooting

## Run locally

Use the Node.js version in `.nvmrc`, then install dependencies and start Astro:

```sh
npm ci
npm run dev
```

Build the static site with:

```sh
npm run build
```

The build also checks internal Markdown and MDX links.

## Project status

Modules 1, 2 and 4 have full lessons. Modules 3, 5 and 6 are outlines. The site is built with [Astro Starlight](https://starlight.astro.build) and deploys to `https://pki.fun`.

## Licenses

Code and lab files are licensed under Apache-2.0. Lesson text is licensed under CC BY 4.0. See [LICENSE](LICENSE) and [LICENSE-CONTENT](LICENSE-CONTENT).

## Disclaimer

pki.fun is an independent project. It is not affiliated with or endorsed by Smallstep, FreeRADIUS or nginx.
