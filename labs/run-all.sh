#!/usr/bin/env bash
# Runs every lab command in modules 1 to 8, in order, on one machine.
#
# Use it on a disposable Ubuntu 24.04 machine only: the lab VM, or a CI runner.
# It changes system files, starts servers, and adds user accounts.
#
#   bash labs/run-all.sh > run.log
#
# The output has one section for each "Expected output" block in the lessons:
#   @@@ <lesson>:<n>    output for the n-th output block in that lesson
# labs/refresh-output.py copies the sections into the lessons.
#
# The script stops with an error when a result differs from what the lesson
# teaches, so CI catches a tool update that changes behaviour.
#
# Requirements: the tools from public/lab/cloud-init.yaml, passwordless sudo,
# a fresh ~/.step and ~/pki-lab, and nginx running without its default site.

set -uo pipefail
export LC_ALL=C.UTF-8
# The lab VM runs in UTC. Times in the lessons use it too.
export TZ=UTC

LAB=~/pki-lab
CI_DIR=$LAB/.ci
CA_LOG=$CI_DIR/step-ca.log
RADIUS_LOG=$CI_DIR/freeradius.log

mkdir -p "$CI_DIR"
# CI only: lessons ask for passwords at prompts. The script reads them from files.
printf 'lab-ca-password\n' > "$CI_DIR/ca-pass"
printf 'lab-wifi-server-password\n' > "$CI_DIR/wifi-server-pass"
printf 'lab-wifi-client-password\n' > "$CI_DIR/wifi-client-pass"
printf 'wrong-password\n' > "$CI_DIR/wrong-pass"
PW=$CI_DIR/ca-pass
ADMIN=(--provisioner admin@example.com --provisioner-password-file "$PW")

fail=0
section() { printf '\n@@@ %s\n' "$1"; }
# Prints a command's output (stdout and stderr) into the current section.
run() { "$@" 2>&1; }
# Checks that the last captured text contains a string the lesson relies on.
expect() {
	# step colours its output. Compare the text without colour codes.
	if ! sed 's/\x1b\[[0-9;]*m//g' <<<"$1" | grep -qF -- "$2"; then
		echo "@@x FAIL: expected '$2'" >&2
		echo "@@x FAIL: expected '$2'"
		fail=1
	fi
}
cap() { # cap <id> <expected text> -- command...
	local id=$1 want=$2; shift 3
	section "$id"
	local out
	out=$(run "$@")
	printf '%s\n' "$out"
	[ -n "$want" ] && expect "$out" "$want"
	return 0
}

start_ca() {
	# CI only: --password-file replaces the password prompt.
	step-ca "$(step path)/config/ca.json" --password-file "$PW" >>"$CA_LOG" 2>&1 &
	CA_PID=$!
	for _ in $(seq 50); do
		curl -sf --cacert "$(step path)/certs/root_ca.crt" https://localhost:9000/health >/dev/null && return 0
		sleep 0.2
	done
	echo "@@x FAIL: step-ca did not start"; tail -20 "$CA_LOG"; exit 1
}
stop_ca() { kill "$CA_PID" 2>/dev/null; wait "$CA_PID" 2>/dev/null; }
restart_ca() { stop_ca; start_ca; }
# Lines that a server log gained while a command ran.
log_mark() { wc -l <"$1"; }
log_since() { tail -n +"$(($2 + 1))" "$1"; }

############################################################ Module 1
mkdir -p $LAB/foundations && cd $LAB/foundations || exit 1
echo "Meet at the usual place at 9." > message.txt
cap pki-foundations:1 "message.txt" -- shasum -a 256 message.txt
cap pki-foundations:2 "Your private key has been saved" -- step crypto keypair alice.pub alice.key --password-file "$PW"
cap pki-foundations:3 "BEGIN PUBLIC KEY" -- cat alice.pub
openssl dgst -sha256 -sign alice.key -passin file:"$PW" -out message.sig message.txt
cap pki-foundations:4 "Verified OK" -- openssl dgst -sha256 -verify alice.pub -signature message.sig message.txt
echo "Meet at the usual place at 8." > message.txt
cap pki-foundations:5 "message.txt" -- shasum -a 256 message.txt
cap pki-foundations:6 "Verification failure" -- openssl dgst -sha256 -verify alice.pub -signature message.sig message.txt

############################################################ Module 2
cd ~ || exit 1
cap build-your-ca:1 "Root fingerprint" -- step ca init \
	--deployment-type standalone --name "Lab CA" --dns localhost \
	--address 127.0.0.1:9000 --provisioner admin@example.com --password-file "$PW"
# CI only: -C prints columns, as ls does in a terminal.
cap build-your-ca:2 "secrets" -- ls -C "$(step path)"
start_ca
section build-your-ca:3; head -20 "$CA_LOG"
cap build-your-ca:4 '"status":"ok"' -- curl --cacert "$(step path)/certs/root_ca.crt" https://localhost:9000/health
cap build-your-ca:5 "Root CA Certificate" -- step certificate inspect "$(step path)/certs/root_ca.crt" --short
cap build-your-ca:6 "CA:TRUE, pathlen:1" -- step certificate inspect "$(step path)/certs/root_ca.crt"
cap build-your-ca:7 "unable to get local issuer certificate" -- curl https://localhost:9000/health
cap build-your-ca:8 "Another process is using this Badger database" -- \
	timeout 10 step-ca "$(step path)/config/ca.json" --password-file "$PW"
stop_ca
cap build-your-ca:9 "decryption password incorrect" -- \
	timeout 10 step-ca "$(step path)/config/ca.json" --password-file "$CI_DIR/wrong-pass"
start_ca

############################################################ Module 3
mkdir -p $LAB/issue && cd $LAB/issue || exit 1
cap issue-and-inspect:1 "" -- step certificate fingerprint "$(step path)/certs/root_ca.crt"
FP=$(step certificate fingerprint "$(step path)/certs/root_ca.crt")
cap issue-and-inspect:2 "root certificate has been saved" -- env STEPPATH=$LAB/laptop step ca bootstrap \
	--ca-url https://localhost:9000 --fingerprint "$FP"
cap issue-and-inspect:3 "Certificate: web.crt" -- step ca certificate web.example.com web.crt web.key \
	--san web.example.com --san localhost --san 127.0.0.1 "${ADMIN[@]}"
cap issue-and-inspect:4 "Issuer:      Lab CA Intermediate CA" -- step certificate inspect web.crt --short
cap issue-and-inspect:5 "Server Authentication, Client Authentication" -- step certificate inspect web.crt
cap issue-and-inspect:6 "2" -- grep -c "BEGIN CERTIFICATE" web.crt
cap issue-and-inspect:7 "Intermediate CA Certificate" -- step certificate inspect web.crt --bundle --short
cap issue-and-inspect:8 "DNS:web.example.com" -- openssl x509 -in web.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage
cap issue-and-inspect:9 "Certificate: alice.crt" -- step ca certificate alice@example.com alice.crt alice.key "${ADMIN[@]}"
cap issue-and-inspect:10 "email:alice@example.com" -- openssl x509 -in alice.crt -noout -ext subjectAltName
section issue-and-inspect:11
k1=$(step certificate key web.crt); k2=$(step crypto key public web.key)
printf '%s\n' "$k1"
[ "$k1" = "$k2" ] || { echo "@@x FAIL: key does not match certificate"; fail=1; }
step certificate verify web.crt --roots "$(step path)/certs/root_ca.crt" --host web.example.com
cap issue-and-inspect:12 "0" -- echo $?
cap issue-and-inspect:13 "not shop.example.com" -- step certificate verify web.crt \
	--roots "$(step path)/certs/root_ca.crt" --host shop.example.com
awk '/BEGIN/{n++} n==1' web.crt > leaf-only.crt
cap issue-and-inspect:14 "signed by unknown authority" -- step certificate verify leaf-only.crt \
	--roots "$(step path)/certs/root_ca.crt" --host web.example.com
# The lesson's "second CA you made while you experimented": a second `step ca init`
# with the same name. Same names, different keys.
STEPPATH=~/other-ca step ca init --deployment-type standalone --name "Lab CA" --dns localhost \
	--address 127.0.0.1:9001 --provisioner admin@example.com --password-file "$PW" >/dev/null 2>&1
cp ~/other-ca/certs/root_ca.crt ~/other-ca/root_ca.crt
# A client certificate from the other CA, bundled with its intermediate, as step-ca would issue it.
other_cert() {
	step certificate create "$1" other.crt other.key --bundle \
		--ca ~/other-ca/certs/intermediate_ca.crt --ca-key ~/other-ca/secrets/intermediate_ca_key \
		--ca-password-file "$PW" --not-after 24h --no-password --insecure >/dev/null 2>&1
}
cap issue-and-inspect:15 "candidate authority certificate" -- step certificate verify web.crt \
	--roots ~/other-ca/root_ca.crt --host web.example.com
cap issue-and-inspect:16 "authorized maximum certificate duration" -- step ca certificate api.example.com api.crt api.key \
	--not-after 48h "${ADMIN[@]}"

############################################################ Module 4
mkdir -p $LAB/mtls && cd $LAB/mtls || exit 1
cap mtls-nginx:1 "Certificate: server.crt" -- step ca certificate localhost server.crt server.key "${ADMIN[@]}"
cap mtls-nginx:2 "Certificate: client.crt" -- step ca certificate alice client.crt client.key "${ADMIN[@]}"
cp "$(step path)/certs/root_ca.crt" .
sudo mkdir -p /etc/pki-lab
sudo cp server.crt server.key root_ca.crt /etc/pki-lab/
write_mtls_conf() {
	sudo tee /etc/nginx/conf.d/mtls.conf >/dev/null <<-EOF
	server {
	    listen 8443 ssl;
	    server_name localhost;
	$1
	    ssl_certificate         /etc/pki-lab/server.crt;
	    ssl_certificate_key     /etc/pki-lab/server.key;

	    # Trust only client certs from our CA
	    ssl_client_certificate  /etc/pki-lab/root_ca.crt;
	    ssl_verify_client       on;
	    ssl_verify_depth        2;

	    location / {
	        return 200 "Hello, \$ssl_client_s_dn\n";
	    }
	}
	EOF
}
write_mtls_conf ""
cap mtls-nginx:3 "test is successful" -- sudo nginx -t
sudo nginx -s reload; sleep 1
cap mtls-nginx:4 "No required SSL certificate was sent" -- curl -sS --cacert root_ca.crt https://localhost:8443
cap mtls-nginx:5 "Hello, CN=alice" -- curl -sS --cacert root_ca.crt --cert client.crt --key client.key https://localhost:8443
awk '/BEGIN/{n++} n==1' client.crt > client-leaf.crt
other_cert alice
cap mtls-nginx:6 "The SSL certificate error" -- curl -sS --cacert root_ca.crt --cert client-leaf.crt --key client.key https://localhost:8443
cap mtls-nginx:7 "The SSL certificate error" -- curl -sS --cacert root_ca.crt --cert other.crt --key other.key https://localhost:8443
write_mtls_conf "    error_log /var/log/nginx/error.log info;"
sudo nginx -s reload; sleep 1
curl -sS --cacert root_ca.crt --cert client-leaf.crt --key client.key https://localhost:8443 >/dev/null 2>&1
curl -sS --cacert root_ca.crt --cert other.crt --key other.key https://localhost:8443 >/dev/null 2>&1
cap mtls-nginx:8 "client SSL certificate verify error" -- sudo grep "client SSL certificate verify" /var/log/nginx/error.log
# Clean up
sudo rm /etc/nginx/conf.d/mtls.conf && sudo nginx -s reload && sudo rm -r /etc/pki-lab

############################################################ Module 5
mkdir -p $LAB/eap && cd $LAB/eap || exit 1
for role in server client; do
	cat > wifi-$role.tpl <<-EOF
	{
		"subject": {{ toJson .Subject }},
		"sans": {{ toJson .SANs }},
		"keyUsage": ["digitalSignature"],
		"extKeyUsage": ["${role}Auth"]
	}
	EOF
done
cap eap-tls-freeradius:1 "Success!" -- step ca provisioner add wifi-server --type JWK --create \
	--x509-template wifi-server.tpl --x509-default-dur 168h --x509-max-dur 720h \
	--password-file "$CI_DIR/wifi-server-pass"
step ca provisioner add wifi-client --type JWK --create \
	--x509-template wifi-client.tpl --x509-default-dur 168h --x509-max-dur 720h \
	--password-file "$CI_DIR/wifi-client-pass" >/dev/null 2>&1
pkill -HUP -x step-ca; sleep 1
cap eap-tls-freeradius:2 "Certificate: radius.crt" -- step ca certificate radius.example.com radius.crt radius.key \
	--provisioner wifi-server --provisioner-password-file "$CI_DIR/wifi-server-pass"
step ca certificate alice@example.com alice.crt alice.key \
	--provisioner wifi-client --provisioner-password-file "$CI_DIR/wifi-client-pass" >/dev/null 2>&1
cap eap-tls-freeradius:3 "TLS Web Server Authentication" -- openssl x509 -in radius.crt -noout -ext extendedKeyUsage
cap eap-tls-freeradius:4 "TLS Web Client Authentication" -- openssl x509 -in alice.crt -noout -ext extendedKeyUsage
cp "$(step path)/certs/root_ca.crt" .
R=/etc/freeradius/3.0
sudo mkdir -p $R/certs/pki-lab
sudo cp radius.crt radius.key root_ca.crt $R/certs/pki-lab/
sudo chown -R freerad:freerad $R/certs/pki-lab
sudo chmod 640 $R/certs/pki-lab/radius.key
sudo cp -p $R/mods-available/eap $R/mods-available/eap.orig
# The five edits the lesson makes with sudoedit.
sudo sed -i \
	-e '0,/^\tdefault_eap_type = md5$/s//\tdefault_eap_type = tls/' \
	-e 's/^\t\tprivate_key_password = whatever$/\t\t#private_key_password = whatever/' \
	-e 's|^\t\tprivate_key_file = .*|\t\tprivate_key_file = ${certdir}/pki-lab/radius.key|' \
	-e 's|^\t\tcertificate_file = .*|\t\tcertificate_file = ${certdir}/pki-lab/radius.crt|' \
	-e 's|^\t\tca_file = .*|\t\tca_file = ${certdir}/pki-lab/root_ca.crt|' \
	$R/mods-available/eap
cap eap-tls-freeradius:5 "Configuration appears to be OK" -- bash -c 'sudo freeradius -XC | tail -1'
sudo bash -c "freeradius -X > $RADIUS_LOG 2>&1 &"
for _ in $(seq 50); do grep -q "Ready to process requests" "$RADIUS_LOG" 2>/dev/null && break; sleep 0.2; done
section eap-tls-freeradius:6; tail -2 "$RADIUS_LOG"
cat > eaptls.conf <<'EOF'
network={
    key_mgmt=WPA-EAP
    eap=TLS
    identity="alice"
    ca_cert="root_ca.crt"
    domain_match="radius.example.com"
    client_cert="alice.crt"
    private_key="alice.key"
    eapol_flags=0
}
EOF
eap() { # eap <lesson block> <radius block> <expected> <config>
	local m; m=$(log_mark "$RADIUS_LOG")
	[ -n "$1" ] && section "$1"
	local out; out=$(eapol_test -c "$4" -a 127.0.0.1 -s testing123 2>&1)
	[ -n "$1" ] && printf '%s\n' "$out"
	expect "$out" "$3"
	sleep 0.5
	[ -n "$2" ] && { section "$2"; log_since "$RADIUS_LOG" "$m"; }
	return 0
}
eap eap-tls-freeradius:7 eap-tls-freeradius:8 "SUCCESS" eaptls.conf
grep -v -e ca_cert -e domain_match eaptls.conf > noverify.conf
eap eap-tls-freeradius:9 "" "SUCCESS" noverify.conf
sed 's/radius.example.com/wifi.example.com/' eaptls.conf > mismatch.conf
eap eap-tls-freeradius:10 "" "FAILURE" mismatch.conf
other_cert alice@example.com
sed -e 's/alice.crt/other.crt/' -e 's/alice.key/other.key/' eaptls.conf > otherca.conf
eap "" eap-tls-freeradius:11 "FAILURE" otherca.conf
sed -e 's/alice.crt/radius.crt/' -e 's/alice.key/radius.key/' eaptls.conf > servercert.conf
eap "" eap-tls-freeradius:12 "FAILURE" servercert.conf
sed 's/identity="alice"/identity="alice@example.com"/' eaptls.conf > realm.conf
eap "" eap-tls-freeradius:13 "FAILURE" realm.conf
# Clean up
sudo pkill -x freeradius; sleep 1
sudo mv $R/mods-available/eap.orig $R/mods-available/eap
sudo rm -r $R/certs/pki-lab

############################################################ Module 6
mkdir -p $LAB/ops && cd $LAB/ops || exit 1
step ca certificate web.example.com web.crt web.key --san web.example.com --san localhost "${ADMIN[@]}" >/dev/null 2>&1
step certificate needs-renewal web.crt
cap operations:1 "1" -- echo $?
step certificate needs-renewal web.crt --expires-in 25h
cap operations:2 "0" -- echo $?
cap operations:3 "saved in web.crt" -- step ca renew --force web.crt web.key
cap operations:4 "first renewal in" -- timeout 3 step ca renew --daemon web.crt web.key
cap operations:5 "reload nginx here" -- timeout 12 step ca renew --daemon --renew-period 5s \
	--exec "echo reload nginx here" web.crt web.key
step ca certificate old.example.com old.crt old.key --not-after 5m "${ADMIN[@]}" >/dev/null 2>&1
sleep 370
cap operations:6 "certificate has expired" -- step certificate verify old.crt --roots "$(step path)/certs/root_ca.crt"
cap operations:7 "certificate expired on" -- step ca renew --force old.crt old.key
step ca certificate laptop42.example.com laptop42.crt laptop42.key "${ADMIN[@]}" >/dev/null 2>&1
cap operations:8 "has been revoked" -- step ca revoke --cert laptop42.crt --key laptop42.key --reason "laptop lost"
m=$(log_mark "$CA_LOG")
cap operations:9 "lacked necessary authorization" -- step ca renew --force laptop42.crt laptop42.key
section operations:10; log_since "$CA_LOG" "$m" | grep -o 'error="[^"]*revoked[^"]*"'
step certificate verify laptop42.crt --roots "$(step path)/certs/root_ca.crt"
cap operations:11 "0" -- echo $?
jq '. + {crl: {enabled: true, generateOnRevoke: true, idpURL: "https://localhost:9000/1.0/crl"}}' \
	"$(step path)/config/ca.json" > ca.json.new && mv ca.json.new "$(step path)/config/ca.json"
cat > leaf-crl.tpl <<'EOF'
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
EOF
step ca provisioner update admin@example.com --x509-template leaf-crl.tpl >/dev/null 2>&1
restart_ca
step ca certificate laptop44.example.com laptop44.crt laptop44.key "${ADMIN[@]}" >/dev/null 2>&1
cap operations:12 "URI:https://localhost:9000/1.0/crl" -- openssl x509 -in laptop44.crt -noout -ext crlDistributionPoints
SERIAL=$(step certificate inspect laptop44.crt --format json | jq -r .serial_number)
# The lesson picks a provisioner at a prompt. CI only: make the same provisioner
# token first. `step ca token` prints the same "Provisioner" line as the prompt.
section operations:13
TOKEN=$(step ca token --revoke --provisioner admin@example.com --password-file "$PW" "$SERIAL" 2>"$CI_DIR/token.err")
grep Provisioner "$CI_DIR/token.err"
out=$(step ca revoke --reasonCode KeyCompromise --token "$TOKEN" "$SERIAL" 2>&1)
printf '%s\n' "$out"; expect "$out" "has been revoked"
curl -s --cacert "$(step path)/certs/root_ca.crt" https://localhost:9000/1.0/crl -o ca.crl
cap operations:14 "Key Compromise" -- openssl crl -inform DER -in ca.crl -noout -text
cap operations:15 "marked as revoked" -- step certificate verify laptop44.crt --roots "$(step path)/certs/root_ca.crt" \
	--issuing-ca "$(step path)/certs/intermediate_ca.crt" --verify-crl
openssl crl -inform DER -in ca.crl -out ca.crl.pem
cap operations:16 "certificate revoked" -- openssl verify -crl_check -CAfile "$(step path)/certs/root_ca.crt" \
	-untrusted "$(step path)/certs/intermediate_ca.crt" -CRLfile ca.crl.pem laptop44.crt
cap operations:17 "different CRL scope" -- openssl verify -crl_check -CAfile "$(step path)/certs/root_ca.crt" \
	-untrusted "$(step path)/certs/intermediate_ca.crt" -CRLfile ca.crl.pem web.crt
openssl s_server -accept 9443 -cert web.crt -key web.key -cert_chain "$(step path)/certs/intermediate_ca.crt" -www >/dev/null 2>&1 &
S=$!; sleep 1
cap operations:18 "Verification: OK" -- openssl s_client -connect localhost:9443 -servername web.example.com \
	-CAfile "$(step path)/certs/root_ca.crt" -verify_hostname web.example.com -brief </dev/null
kill $S; wait $S 2>/dev/null
openssl s_server -accept 9443 -cert web.crt -key web.key -www >/dev/null 2>&1 &
S=$!; sleep 1
cap operations:19 "unable to verify the first certificate" -- openssl s_client -connect localhost:9443 -servername web.example.com \
	-CAfile "$(step path)/certs/root_ca.crt" -verify_hostname web.example.com -brief </dev/null
cap operations:20 "unable to get local issuer certificate" -- curl -sS --cacert "$(step path)/certs/root_ca.crt" https://localhost:9443/
kill $S; wait $S 2>/dev/null
cap operations:21 "saved in int2.crt" -- step certificate create "Lab CA Intermediate CA 2" int2.crt int2.key \
	--profile intermediate-ca --ca "$(step path)/certs/root_ca.crt" --ca-key "$(step path)/secrets/root_ca_key" \
	--ca-password-file "$PW" --password-file "$PW"
cap operations:22 "Lab CA Intermediate CA 2" -- step certificate inspect int2.crt --short
cp int2.crt "$(step path)/certs/intermediate_ca_2.crt"
cp int2.key "$(step path)/secrets/intermediate_ca_2_key"
jq --arg c "$(step path)/certs/intermediate_ca_2.crt" --arg k "$(step path)/secrets/intermediate_ca_2_key" \
	'.crt = $c | .key = $k' "$(step path)/config/ca.json" > ca.json.new && mv ca.json.new "$(step path)/config/ca.json"
restart_ca
step ca renew --force web.crt web.key >/dev/null 2>&1
cap operations:23 "Issuer:      Lab CA Intermediate CA 2" -- step certificate inspect web.crt --bundle --short

############################################################ Module 7
cd $LAB || exit 1
cap acme:1 "Success!" -- step ca provisioner add acme --type ACME
pkill -HUP -x step-ca; sleep 1
cap acme:2 "newNonce" -- curl -s --cacert "$(step path)/certs/root_ca.crt" https://localhost:9000/acme/acme/directory
m=$(log_mark "$CA_LOG")
cap acme:3 "Successfully received certificate" -- sudo REQUESTS_CA_BUNDLE="$(step path)/certs/root_ca.crt" \
	certbot certonly --standalone --server https://localhost:9000/acme/acme/directory -d localhost \
	--register-unsafely-without-email --agree-tos
section acme:4
log_since "$CA_LOG" "$m" | grep -E 'path="?/acme/acme' |
	sed -E 's/.*method="?([A-Z]+)"?.*path="?([^" ]+)"?.*/\1 \2/' | awk '{printf "%-4s %s\n", $1, $2}'
cap acme:5 "Provisioner: acme" -- sudo step certificate inspect /etc/letsencrypt/live/localhost/fullchain.pem --bundle --short
cap acme:6 "DNS:localhost" -- sudo openssl x509 -in /etc/letsencrypt/live/localhost/cert.pem -noout -subject -ext subjectAltName
cap acme:7 "not due for renewal" -- sudo REQUESTS_CA_BUNDLE="$(step path)/certs/root_ca.crt" certbot renew
cap acme:8 "were not finalized" -- sudo REQUESTS_CA_BUNDLE="$(step path)/certs/root_ca.crt" \
	certbot certonly --standalone --server https://localhost:9000/acme/acme/directory -d nothere.example.com
section acme:9; sudo grep -o '"type":"http-01","status":"pending"[^}]*}' /var/log/letsencrypt/letsencrypt.log | tail -1
cap acme:10 "CERTIFICATE_VERIFY_FAILED" -- sudo certbot certonly --standalone \
	--server https://localhost:9000/acme/acme/directory -d localhost
# Clean up. CI only: --non-interactive answers the confirmation prompt.
sudo certbot delete --cert-name localhost --non-interactive >/dev/null 2>&1 || { echo "@@x FAIL: certbot delete"; fail=1; }

############################################################ Module 8
cd ~ || exit 1
cap ssh-certificates:1 "Your private key has been saved" -- step crypto keypair \
	"$(step path)/certs/ssh_host_ca_key.pub" "$(step path)/secrets/ssh_host_ca_key" --password-file "$PW"
step crypto keypair "$(step path)/certs/ssh_user_ca_key.pub" "$(step path)/secrets/ssh_user_ca_key" --password-file "$PW" >/dev/null 2>&1
jq --arg h "$(step path)/secrets/ssh_host_ca_key" --arg u "$(step path)/secrets/ssh_user_ca_key" \
	'. + {ssh: {hostKey: $h, userKey: $u}}' "$(step path)/config/ca.json" > /tmp/ca.json.new &&
	mv /tmp/ca.json.new "$(step path)/config/ca.json"
cap ssh-certificates:2 "Success!" -- step ca provisioner update admin@example.com --ssh
restart_ca
cap ssh-certificates:3 "ecdsa-sha2-nistp256" -- step ssh config --roots
cap ssh-certificates:4 "ssh_host_ecdsa_key-cert.pub" -- sudo step ssh certificate --host --sign \
	--principal localhost --principal host.example.com \
	host.example.com /etc/ssh/ssh_host_ecdsa_key.pub \
	--ca-url https://localhost:9000 --root "$(step path)/certs/root_ca.crt" \
	"${ADMIN[@]}"
cap ssh-certificates:5 "host certificate" -- ssh-keygen -L -f /etc/ssh/ssh_host_ecdsa_key-cert.pub
step ssh config --roots | sudo tee /etc/ssh/ssh_user_ca.pub >/dev/null
sudo tee /etc/ssh/pki-lab-sshd.conf >/dev/null <<'EOF'
TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub
HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
PidFile /run/sshd-pki-lab.pid
Include /etc/ssh/sshd_config
EOF
sudo mkdir -p /run/sshd
cap ssh-certificates:6 "sshd config OK" -- bash -c 'sudo sshd -t -f /etc/ssh/pki-lab-sshd.conf && echo "sshd config OK"'
sudo /usr/sbin/sshd -f /etc/ssh/pki-lab-sshd.conf -p 2222
sudo useradd -m -s /bin/bash alice
eval "$(ssh-agent -s)" >/dev/null
# CI only: ssh asks for the key passphrase. SSH_ASKPASS answers from the password file.
printf '#!/bin/sh\ncat %s\n' "$PW" > "$CI_DIR/askpass" && chmod +x "$CI_DIR/askpass"
export SSH_ASKPASS=$CI_DIR/askpass SSH_ASKPASS_REQUIRE=force
mkdir -p $LAB/ssh && cd $LAB/ssh || exit 1
cap ssh-certificates:7 "Certificate: id_ecdsa-cert.pub" -- step ssh certificate alice@example.com id_ecdsa \
	--password-file "$PW" "${ADMIN[@]}"
cap ssh-certificates:8 "user certificate" -- ssh-keygen -L -f id_ecdsa-cert.pub
echo "@cert-authority [localhost]:2222,*.example.com $(step ssh config --host --roots)" > known_hosts
cat > config <<'EOF'
Host localhost 127.0.0.1
    Port 2222
    IdentityFile ~/pki-lab/ssh/id_ecdsa
    IdentitiesOnly yes
    UserKnownHostsFile ~/pki-lab/ssh/known_hosts
EOF
cap ssh-certificates:9 "alice" -- ssh -F config alice@localhost whoami
cap ssh-certificates:10 "Server accepts key" -- ssh -F config -v alice@localhost whoami
sudo useradd -m bob
cap ssh-certificates:11 "Permission denied" -- ssh -F config bob@localhost whoami
cap ssh-certificates:12 "Host key verification failed" -- ssh -F config -o StrictHostKeyChecking=yes alice@127.0.0.1 whoami
mv known_hosts known_hosts.off
cap ssh-certificates:13 "Host key verification failed" -- ssh -F config -o StrictHostKeyChecking=yes alice@localhost whoami
mv known_hosts.off known_hosts
ssh-agent -k >/dev/null
# Clean up
sudo kill "$(cat /run/sshd-pki-lab.pid)"
sudo rm /etc/ssh/pki-lab-sshd.conf /etc/ssh/ssh_user_ca.pub /etc/ssh/ssh_host_ecdsa_key-cert.pub
sudo userdel -r alice 2>/dev/null; sudo userdel -r bob 2>/dev/null

stop_ca
section end
if [ $fail -ne 0 ]; then echo "@@x Some results differ from the lessons."; exit 1; fi
echo "All lab steps behaved as the lessons describe."
