# EventStoreDB config

This directory contains EventStoreDB configuration used for testing.

## Certificates

Certificates may be generated on-demand with the gen-certs.sh script:

```
./eventstoredb/gen-certs.sh
```

This writes a throwaway CA and node certificate into `eventstoredb/certs/`
(git-ignored) with a 10 year expiry.

You can inspect a generated certificate with `openssl`:

```
openssl x509 -in eventstoredb/certs/node.crt -text
```

## EventStoreDB version

We pin the test container to EventStoreDB `23.10.x`, the last release under a
true open-source license. Starting with `24.10`, EventStoreDB (now "KurrentDB")
is licensed under the non-OSS Event Store License v2.
