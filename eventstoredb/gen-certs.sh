#!/usr/bin/env bash
#
# Generates a throwaway CA + node certificate for the EventStoreDB test
# container. This runs per CI run (and locally, on demand) so that we don't
# have to commit — and annually rotate — certificates in the repo.
#
# Usage: eventstoredb/gen-certs.sh
set -euo pipefail

cd "$(dirname "$0")"
certs="certs"
rm -rf "$certs"
mkdir -p "$certs/ca"

ca_cnf="$(mktemp)"
node_cnf="$(mktemp)"
trap 'rm -f "$ca_cnf" "$node_cnf"' EXIT

cat > "$ca_cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca
[dn]
C = UK
O = Event Store Ltd
CN = EventStoreDB CA
[v3_ca]
basicConstraints = critical, CA:TRUE, pathlen:2
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF

cat > "$node_cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
[dn]
CN = eventstoredb-node
[v3_node]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
subjectAltName = DNS:localhost, IP:127.0.0.1
EOF

# EventStoreDB (through 23.10) reads node.key with .NET's ImportRSAPrivateKey,
# which only accepts a PKCS#1 key ("BEGIN RSA PRIVATE KEY"). OpenSSL 3 writes
# PKCS#8 ("BEGIN PRIVATE KEY") by default and needs -traditional to force
# PKCS#1; OpenSSL 1.1 / LibreSSL already default to PKCS#1 and don't recognise
# that flag. Generate a key and normalise it to PKCS#1 regardless of version.
if openssl rsa -help 2>&1 | grep -q -- '-traditional'; then
  traditional="-traditional"
else
  traditional=""
fi

gen_pkcs1_key() {
  local out="$1" tmp
  tmp="$(mktemp)"
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp" 2>/dev/null
  # shellcheck disable=SC2086
  openssl rsa -in "$tmp" $traditional -out "$out" 2>/dev/null
  rm -f "$tmp"
}

# Certificate authority (self-signed)
gen_pkcs1_key "$certs/ca/ca.key"
openssl req -x509 -new -nodes -key "$certs/ca/ca.key" -sha256 -days 3650 \
  -config "$ca_cnf" -out "$certs/ca/ca.crt"

# Node certificate (signed by the CA above)
gen_pkcs1_key "$certs/node.key"
openssl req -new -key "$certs/node.key" -config "$node_cnf" -out "$certs/node.csr"
openssl x509 -req -in "$certs/node.csr" -CA "$certs/ca/ca.crt" -CAkey "$certs/ca/ca.key" \
  -CAcreateserial -sha256 -days 3650 \
  -extensions v3_node -extfile "$node_cnf" -out "$certs/node.crt"
rm -f "$certs/node.csr" "$certs/ca/ca.srl"

# The EventStoreDB container runs as a different uid and mounts these
# read-only, so make sure they are world-readable.
chmod 644 "$certs/ca/ca.key" "$certs/ca/ca.crt" "$certs/node.key" "$certs/node.crt"

echo "Generated test certificates in $(pwd)/$certs"
