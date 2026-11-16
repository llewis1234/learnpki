---
title: 'Operations: renewal, rotation & troubleshooting'
description: Keep a PKI healthy — automate renewal, rotate keys, revoke, and debug common errors.
summary: 'Keep a PKI healthy: automate renewal, rotate keys, revoke, and debug common errors.'
module: 6
topic: PKI
level: Intermediate
minutes: 40
sidebar:
  label: 6. Operations
cards:
  - q: How does `step ca renew` prove who you are?
    a: It uses the current certificate and key over mTLS. No password is needed while the certificate is still valid.
  - q: What is passive revocation?
    a: The CA refuses to renew a revoked certificate. It stays valid until it expires, so it works best with short lifetimes.
  - q: What does OpenSSL error 20 usually mean on a server you run?
    a: The server didn't send its intermediate. The client can't link the leaf to a root it trusts.
  - q: Why can you rotate an intermediate without touching clients?
    a: Clients trust the root. A new intermediate signed by the same root is trusted automatically.
---

A certificate is not a one-time job. It is issued, renewed, sometimes revoked, and always expires. This module runs that whole cycle on your CA from [module 2](/guides/build-your-ca/), then teaches you to debug the errors you'll see in real life.

Keep the CA running. Work in a new folder:

```sh title="terminal"
mkdir -p ~/pki-lab/ops && cd ~/pki-lab/ops
```

If you did [module 5](/guides/eap-tls-freeradius/), your CA has two JWK provisioners. When step asks which one to use, pick `admin@example.com`.

Get a certificate to work with:

```sh title="terminal"
step ca certificate web.example.com web.crt web.key \
  --san web.example.com --san localhost
```

## Why lifetimes keep shrinking

Short lifetimes limit the damage of a stolen key and force teams to automate. The public web is heading the same way. The CA/Browser Forum's ballot SC-081 cut the maximum public TLS lifetime to 200 days in March 2026. It drops to 100 days in March 2027 and 47 days in March 2029. Let's Encrypt plans to [move to 64 days in 2027 and 45 days in 2028](https://letsencrypt.org/2025/12/02/from-90-to-45/).

step-ca already defaults to 24 hours. If you can renew daily, you can handle anything the public web throws at you.

## 1. Ask whether a certificate needs renewal

```sh title="terminal"
step certificate needs-renewal web.crt
```

```sh title="terminal"
echo $?
```

```text title="Expected output"
1
```

Exit code `1` means "not yet". By default, a certificate needs renewal after two thirds of its lifetime. Pretend it expires within 25 hours:

```sh title="terminal"
step certificate needs-renewal web.crt --expires-in 25h
```

```sh title="terminal"
echo $?
```

```text title="Expected output"
0
```

Exit code `0` means "renew now". Scripts use this to decide what to do.

## 2. Renew by hand

```sh title="terminal"
step ca renew --force web.crt web.key
```

```text title="Expected output"
Your certificate has been saved in web.crt.
```

No password was needed. step proved its identity with the current certificate and key, over mTLS. The CA issued a new certificate with a new serial number and new dates for the same names.

`--force` skips the overwrite prompt. Without it, step asks before it replaces `web.crt`.

:::tip[Renew or rekey?]
`step ca renew` keeps the same private key. `step ca rekey` makes a new key pair and gets a certificate for it. Rekey regularly if keys might leak, for example from backups.
:::

## 3. Renew automatically

Run renewal as a daemon:

```sh title="terminal"
step ca renew --daemon web.crt web.key
```

```text title="Expected output"
INFO: 2026/11/16 04:00:34 first renewal in 15h12m46s
```

The daemon renews at about two thirds of the lifetime, with some random jitter. The jitter stops a fleet of machines from all hitting the CA at the same second.

A renewed certificate is useless until the service loads it. `--exec` runs a command after each renewal. Stop the daemon with `Ctrl+C`, then try a fast demo:

```sh title="terminal"
step ca renew --daemon --renew-period 5s \
  --exec "echo reload nginx here" web.crt web.key
```

```text title="Expected output"
INFO: 2026/11/16 04:00:36 first renewal in 5s
INFO: 2026/11/16 04:00:41 web.example.com certificate renewed, next in 5s
reload nginx here
INFO: 2026/11/16 04:00:46 web.example.com certificate renewed, next in 5s
reload nginx here
```

Press `Ctrl+C` to stop it. In production, use `--exec "systemctl reload nginx"` or a systemd timer. The [step-ca renewal docs](https://smallstep.com/docs/step-ca/renewal/) include ready-made systemd units.

:::note[ACME clients renew too]
certbot, Caddy and Traefik renew their own certificates. You'll see that in [module 7](/guides/acme/).
:::

### Break it: let a certificate expire

Get a certificate with the shortest lifetime the CA allows:

```sh title="terminal"
step ca certificate old.example.com old.crt old.key --not-after 5m
```

Wait six minutes. Then verify it:

```sh title="terminal"
step certificate verify old.crt --roots $(step path)/certs/root_ca.crt
```

```text title="Expected output"
failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-11-16T04:05:50Z is after 2026-11-16T04:05:49Z
```

Try to renew it:

```sh title="terminal"
step ca renew --force old.crt old.key
```

```text title="Expected output"
The request lacked necessary authorization to be completed: certificate expired on 2026-11-16 04:05:49 +0000 UTC
Re-run with STEPDEBUG=1 for more info.
```

An expired certificate can't prove anything, so it can't renew itself. You must issue a new one with the provisioner password. This is why renewal runs well before expiry, never at the last minute.

step-ca can allow late renewal with the `allowRenewalAfterExpiry` claim. Leave it off unless you have a strong reason.

## 4. Revoke a certificate (passive)

Imagine a laptop is lost. Issue a certificate to play its part:

```sh title="terminal"
step ca certificate laptop42.example.com laptop42.crt laptop42.key
```

Revoke it, using the certificate itself to authorize the request:

```sh title="terminal"
step ca revoke --cert laptop42.crt --key laptop42.key --reason "laptop lost"
```

```text title="Expected output"
✔ CA: https://localhost:9000
Certificate with Serial Number 325394138822214975015869222951509457176 has been revoked.
```

When you don't have the key, revoke by serial number. step asks you to pick a provisioner and enter its password instead:

```sh title="terminal"
step ca revoke --reasonCode KeyCompromise <serial-number>
```

Find a serial number with `step certificate inspect <file> --format json`. It's the `serial_number` field.

Now try to renew the revoked certificate:

```sh title="terminal"
step ca renew --force laptop42.crt laptop42.key
```

```text title="Expected output"
The request lacked necessary authorization to be completed. Please see the certificate authority logs for more info.
Re-run with STEPDEBUG=1 for more info.
```

The CA's log is clearer:

```text title="step-ca log (excerpt)"
error="cahandler.Renew: authority.authorizeRenew: certificate has been revoked"
```

But the certificate still verifies:

```sh title="terminal"
step certificate verify laptop42.crt --roots $(step path)/certs/root_ca.crt
```

```sh title="terminal"
echo $?
```

```text title="Expected output"
0
```

This is **passive revocation**, step-ca's default. The CA won't extend the certificate, but clients don't check with the CA. The certificate dies at its expiry time, at most 24 hours later. With short lifetimes, that's often good enough.

## 5. Revoke a certificate (active, with a CRL)

Sometimes "within 24 hours" is too slow. **Active revocation** means the CA publishes a signed **Certificate Revocation List (CRL)** and clients check it.

:::caution[Experimental]
CRL support in step-ca is marked experimental. It's great for learning. Test it carefully before you rely on it.
:::

Two parts must agree:

- The CA publishes a CRL, and stamps it with its own address in the **Issuing Distribution Point**.
- Each leaf certificate carries the same address in its **CRL Distribution Points** extension, so clients know where to look.

### Turn on the CRL

Open `$(step path)/config/ca.json` in an editor. Add this block at the top level, next to `"db"`:

```json title="ca.json (excerpt)"
"crl": {
	"enabled": true,
	"generateOnRevoke": true,
	"idpURL": "https://localhost:9000/1.0/crl"
},
```

### Add the CRL address to new certificates

Create a leaf template. It's the step-ca default plus one line:

```json title="leaf-crl.tpl"
{
	"subject": {{ toJson .Subject }},
	"sans": {{ toJson .SANs }},
{{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
	"keyUsage": ["keyEncipherment", "digitalSignature"],
{{- else }}
	"keyUsage": ["digitalSignature"],
{{- end }}
	"extKeyUsage": ["serverAuth", "clientAuth"],
	"crlDistributionPoints": ["https://localhost:9000/1.0/crl"]
}
```

Attach it to your admin provisioner:

```sh title="terminal"
step ca provisioner update admin@example.com --x509-template leaf-crl.tpl
```

Restart step-ca so it picks up both changes. Then issue a new certificate:

```sh title="terminal"
step ca certificate laptop44.example.com laptop44.crt laptop44.key
```

```sh title="terminal"
openssl x509 -in laptop44.crt -noout -ext crlDistributionPoints
```

```text title="Expected output"
X509v3 CRL Distribution Points: 
    Full Name:
      URI:https://localhost:9000/1.0/crl
```

### Revoke it and read the list

```sh title="terminal"
step ca revoke --reasonCode KeyCompromise <laptop44-serial>
```

step lists your JWK provisioners. Pick any of them and enter its password: any JWK provisioner can revoke any certificate.

```text title="Expected output"
✔ Provisioner: wifi (JWK) [kid: c703dzooi6hSNFaz00eax8xRxcQuzObfwvOAbKiInGA]
✔ CA: https://localhost:9000
Certificate with Serial Number 167336704577127535296999873164195410580 has been revoked.
```

Download the CRL and read it:

```sh title="terminal"
curl -s --cacert $(step path)/certs/root_ca.crt https://localhost:9000/1.0/crl -o ca.crl
```

```sh title="terminal"
openssl crl -inform DER -in ca.crl -noout -text
```

```text title="Expected output (excerpt)"
Certificate Revocation List (CRL):
        Version 2 (0x1)
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: O = Lab CA, CN = Lab CA Intermediate CA
        Last Update: Nov 16 04:01:20 2026 GMT
        Next Update: Nov 17 04:01:20 2026 GMT
        CRL extensions:
            X509v3 Authority Key Identifier: 
                1B:7A:83:36:88:1C:E2:E6:78:50:0A:39:5F:5D:68:AC:A5:7F:9B:F0
            X509v3 CRL Number: 
                1
            X509v3 Issuing Distribution Point: critical
                Full Name:
                  URI:https://localhost:9000/1.0/crl
Revoked Certificates:
    Serial Number: 7DE3E083FD99626EB860E37FF7503294
        Revocation Date: Nov 16 04:01:20 2026 GMT
        CRL entry extensions:
            X509v3 CRL Reason Code: 
                Key Compromise
    Serial Number: F4CCA1AE7A7CB4CC115201FCFF927918
        Revocation Date: Nov 16 04:00:50 2026 GMT
```

The CRL lists every revoked serial in hexadecimal, including `laptop42`, which you revoked passively earlier. It's signed by the intermediate, so nobody can forge it.

### Check it like a client

step can fetch and check the CRL for you:

```sh title="terminal"
step certificate verify laptop44.crt \
  --roots $(step path)/certs/root_ca.crt \
  --issuing-ca $(step path)/certs/intermediate_ca.crt \
  --verify-crl
```

```text title="Expected output"
certificate marked as revoked in CRL https://localhost:9000/1.0/crl
```

OpenSSL agrees. Convert the CRL to PEM first:

```sh title="terminal"
openssl crl -inform DER -in ca.crl -out ca.crl.pem
```

```sh title="terminal"
openssl verify -crl_check \
  -CAfile $(step path)/certs/root_ca.crt \
  -untrusted $(step path)/certs/intermediate_ca.crt \
  -CRLfile ca.crl.pem laptop44.crt
```

```text title="Expected output"
CN = laptop44.example.com
error 23 at 0 depth lookup: certificate revoked
error laptop44.crt: verification failed
```

### Break it: a certificate without a CRL address

Check `web.crt` the same way. You issued it before you added the template:

```sh title="terminal"
openssl verify -crl_check \
  -CAfile $(step path)/certs/root_ca.crt \
  -untrusted $(step path)/certs/intermediate_ca.crt \
  -CRLfile ca.crl.pem web.crt
```

```text title="Expected output"
CN = web.example.com
error 44 at 0 depth lookup: different CRL scope
error web.crt: verification failed
```

The CRL says "I cover certificates that point to this URL." `web.crt` doesn't point anywhere, so OpenSSL refuses to use the list. Renew or reissue older certificates after you turn on CRLs.

:::note[CRLs in production]
Clients must reach the CRL to check it. Since a CRL is signed, many PKIs serve it over plain HTTP. step-ca's `insecureAddress` setting does that. See the [production guide](https://smallstep.com/docs/step-ca/certificate-authority-server-production/).
:::

## 6. Troubleshoot TLS like a pro

`openssl s_client` shows exactly what a server sends. Start a throwaway test server in one terminal. It serves `web.crt` with the intermediate:

```sh title="terminal"
openssl s_server -accept 8443 -cert web.crt -key web.key \
  -cert_chain $(step path)/certs/intermediate_ca.crt -www
```

In another terminal, connect and check the name:

```sh title="terminal"
openssl s_client -connect localhost:8443 -servername web.example.com \
  -CAfile $(step path)/certs/root_ca.crt \
  -verify_hostname web.example.com -brief </dev/null
```

```text title="Expected output"
CONNECTION ESTABLISHED
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: CN = web.example.com
Hash used: SHA256
Signature type: ECDSA
Verification: OK
Verified peername: web.example.com
Server Temp Key: X25519, 253 bits
DONE
```

`Verification: OK` and `Verified peername` are what you want. Drop `-brief` to see the full chain the server sent.

### Break it: read the error numbers

Stop `s_server` with `Ctrl+C`. Restart it **without** `-cert_chain`, so it sends only the leaf:

```sh title="terminal"
openssl s_server -accept 8443 -cert web.crt -key web.key -www
```

Connect again from the other terminal:

```sh title="terminal"
openssl s_client -connect localhost:8443 -servername web.example.com \
  -CAfile $(step path)/certs/root_ca.crt \
  -verify_hostname web.example.com -brief </dev/null
```

```text title="Expected output (excerpt)"
depth=0 CN = web.example.com
verify error:num=20:unable to get local issuer certificate
depth=0 CN = web.example.com
verify error:num=21:unable to verify the first certificate
CONNECTION ESTABLISHED
```

Notice the last line. `s_client` reports problems but **connects anyway**. Add `-verify_return_error` to make it stop, like a browser would. curl fails straight away:

```sh title="terminal"
curl -sS --cacert $(step path)/certs/root_ca.crt https://localhost:8443/
```

```text title="Expected output"
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

Here are the OpenSSL errors you'll meet most:

| Error | Meaning | Usual fix |
|---|---|---|
| `20: unable to get local issuer certificate` | No path to a trusted root. | Serve the intermediate. Or trust the right root. |
| `21: unable to verify the first certificate` | Same root cause as 20, seen on the leaf. | Serve the full chain. |
| `10: certificate has expired` | Outside the validity window. | Renew. Check automation and the clock. |
| `18: self-signed certificate` | The server sent a self-signed certificate. | Use a CA-issued certificate, or trust that exact one. |
| `23: certificate revoked` | Listed in the CRL. | Issue a new certificate. |
| `26: unsuitable certificate purpose` | Wrong Key Usage or EKU for the job. | Reissue with the right EKU. |
| `62: hostname mismatch` | The name isn't in the SAN. | Reissue with the name. Check the URL. |

## 7. Rotate the intermediate CA

Intermediates should change from time to time. Clients trust the root, so a new intermediate signed by the same root needs no client changes.

Create a new intermediate. You need the root key, so this is a rare, careful job:

```sh title="terminal"
step certificate create "Lab CA Intermediate CA 2" int2.crt int2.key \
  --profile intermediate-ca \
  --ca $(step path)/certs/root_ca.crt \
  --ca-key $(step path)/secrets/root_ca_key
```

Enter the root key password, then choose a password for the new key. Use the same password as your CA so step-ca can start with one password.

```text title="Expected output"
Your certificate has been saved in int2.crt.
Your private key has been saved in int2.key.
```

```sh title="terminal"
step certificate inspect int2.crt --short
```

```text title="Expected output"
X.509v3 Intermediate CA Certificate (ECDSA P-256) [Serial: 1993...5668]
  Subject:     Lab CA Intermediate CA 2
  Issuer:      Lab CA Root CA
  Valid from:  2026-11-16T04:02:18Z
          to:  2036-11-13T04:02:18Z
```

Move the files into place:

```sh title="terminal"
cp int2.crt $(step path)/certs/intermediate_ca_2.crt
```

```sh title="terminal"
cp int2.key $(step path)/secrets/intermediate_ca_2_key
```

In `ca.json`, change `"crt"` and `"key"` to the two new paths. Restart step-ca. The root fingerprint in the startup log hasn't changed.

Renew a certificate the **old** intermediate issued:

```sh title="terminal"
step ca renew --force web.crt web.key
```

```sh title="terminal"
step certificate inspect web.crt --bundle --short
```

```text title="Expected output"
X.509v3 TLS Certificate (ECDSA P-256) [Serial: 1919...3580]
  Subject:     web.example.com
               localhost
  Issuer:      Lab CA Intermediate CA 2
  Provisioner: admin@example.com [ID: Cd7t...AS_E]
  Valid from:  2026-11-16T04:01:22Z
          to:  2026-11-17T04:02:22Z
X.509v3 Intermediate CA Certificate (ECDSA P-256) [Serial: 1993...5668]
  Subject:     Lab CA Intermediate CA 2
  Issuer:      Lab CA Root CA
  Valid from:  2026-11-16T04:02:18Z
          to:  2036-11-13T04:02:18Z
```

The renewal worked, and the new certificate comes from the new intermediate. Every client keeps working because the root is the same. Keep the old intermediate's files until every certificate it signed has expired.

From now on, the new intermediate also signs the CRL. Pass `intermediate_ca_2.crt` to `--issuing-ca` and `-untrusted` when you check new certificates.

## Go deeper

- [RFC 5280, section 5](https://datatracker.ietf.org/doc/html/rfc5280#section-5) — the CRL format.
- [step-ca renewal documentation](https://smallstep.com/docs/step-ca/renewal/)
- [step-ca revocation documentation](https://smallstep.com/docs/step-ca/revocation/)
- [OpenSSL `verify` error codes](https://docs.openssl.org/3.0/man1/openssl-verification-options/)
- [Let's Encrypt: decreasing certificate lifetimes to 45 days](https://letsencrypt.org/2025/12/02/from-90-to-45/)
