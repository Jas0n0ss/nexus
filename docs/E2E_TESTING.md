# App / Core end-to-end testing

CI includes an **App / Core Smoke** gate before publishing a Release:

1. Parse a VLESS + REALITY URI with the same Dart parser used by the app.
2. Generate global desktop proxy and TUN configurations.
3. Validate both configurations with the pinned sing-box binary.
4. If a live URI is configured, start sing-box and request
   `https://www.gstatic.com/generate_204` through the local mixed proxy.

## Configure the live test

The node URI is an access credential and must not be committed to this public
repository. Add it as the repository Actions Secret:

```text
NEXUS_E2E_TEST_URI
```

Repository → **Settings → Secrets and variables → Actions → New repository
secret**.

Without the Secret, CI still runs parser, config-generator, TUN-schema, and
sing-box validation against a synthetic REALITY node. The live network probe is
reported as skipped.

## Run locally

Synthetic validation:

```bash
cd app
bash scripts/app_smoke_test.sh
```

Live validation:

```bash
cd app
NEXUS_E2E_TEST_URI='vless://…' bash scripts/app_smoke_test.sh
```

The script never prints the URI or writes it to an artifact. Generated configs
are under the ignored `app/build/app-smoke/` directory.
