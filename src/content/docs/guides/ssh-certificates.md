---
title: SSH certificates
description: Replace scattered authorized_keys files and host-key warnings with short-lived SSH certificates.
summary: Replace scattered authorized_keys files and host-key warnings with short-lived SSH certificates.
module: 8
topic: SSH
level: Intermediate
minutes: 35
outline: true
sidebar:
  label: 8. SSH certificates
cards:
  - q: Are SSH certificates X.509 certificates?
    a: No. OpenSSH uses its own simpler certificate format, signed by an SSH CA key.
  - q: What does a user certificate replace on the server?
    a: Per-user entries in `authorized_keys`. The server trusts the CA instead.
  - q: What does a host certificate fix for clients?
    a: The "unknown host key" prompt. Clients trust hosts signed by the CA.
---

OpenSSH has its own certificate format. Instead of copying public keys into every server's `authorized_keys`, servers trust one SSH CA. Users and hosts get short-lived certificates signed by it.

:::note[Outline]
This lesson is coming soon. Here's what it will cover.
:::

- How SSH certificates differ from X.509 certificates.
- Enabling SSH in step-ca and creating user and host CA keys.
- Issuing a user certificate with `step ssh certificate`.
- Configuring `sshd` with `TrustedUserCAKeys` and a host certificate.
- Configuring clients to trust host certificates with `@cert-authority`.

## Go deeper

- [`ssh-keygen` manual, CERTIFICATES section](https://man.openbsd.org/ssh-keygen#CERTIFICATES)
- [step-ca SSH documentation](https://smallstep.com/docs/step-ca/)
