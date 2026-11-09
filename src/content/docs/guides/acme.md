---
title: 'ACME: automate certificate issuance'
description: Let machines request and renew their own certificates with the ACME protocol and step-ca.
summary: Let machines request and renew their own certificates with the ACME protocol and step-ca.
module: 7
topic: ACME
level: Intermediate
minutes: 40
outline: true
sidebar:
  label: '7. ACME automation'
cards:
  - q: What does ACME automate?
    a: Proving control of a name, getting a certificate for it, and renewing it — with no human in the loop.
  - q: How does the HTTP-01 challenge prove control?
    a: The client serves a token at a well-known URL on port 80, and the CA fetches it.
  - q: When would you pick DNS-01 over HTTP-01?
    a: For wildcard certificates, or hosts the CA can't reach over HTTP.
---

**ACME** (Automated Certificate Management Environment) is the protocol behind Let's Encrypt. A client proves it controls a name, and the CA issues a certificate automatically. step-ca can act as your own private ACME server.

:::note[Outline]
This lesson is coming soon. Here's what it will cover.
:::

- How ACME works: accounts, orders, authorizations and challenges.
- Adding an ACME provisioner to step-ca with `step ca provisioner add`.
- Getting a certificate with the HTTP-01 challenge.
- Getting a certificate with the DNS-01 challenge.
- Using a standard ACME client, such as certbot, against your private CA.

## Go deeper

- [RFC 8555](https://datatracker.ietf.org/doc/html/rfc8555) — the ACME protocol.
- [step-ca ACME documentation](https://smallstep.com/docs/step-ca/acme-basics/)
