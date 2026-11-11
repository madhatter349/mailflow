# mailflow

MailFlow webmail for the 382972.xyz mailbox estate, deployed on the VPS by
Coolify. Upstream: <https://github.com/maathimself/mailflow> (AGPL-3.0).

Frontend + backend + Postgres + Redis, all from pinned upstream images. Nothing
publishes a host port: Traefik terminates TLS and routes to the `frontend`
service on :80. Credentials for the mail servers are entered in the UI and are
encrypted at rest with `ENCRYPTION_KEY`.

## Required environment

| Variable | Why |
|---|---|
| `APP_URL` | Public origin, e.g. `https://mail.382972.xyz` |
| `SESSION_SECRET` | Signs session cookies |
| `DB_PASSWORD` | Postgres password (app + database) |
| `ENCRYPTION_KEY` | Encrypts stored IMAP/SMTP credentials. Losing it re-locks every connected mailbox. |
| `TRUST_PROXY_HOPS` | Set to `1` behind Traefik so client IPs are read correctly |

Generated once, stored in Coolify's env store, never in this repo:

```sh
openssl rand -hex 32   # SESSION_SECRET, ENCRYPTION_KEY
openssl rand -hex 16   # DB_PASSWORD
```

## How this project is built and run

| Concern | Where it happens |
|---|---|
| Tests | `scripts/verify.sh` — run by the pre-push hook and nightly on the VPS |
| CI service | **none.** GitHub Actions is deliberately not used: no minutes, no billing dependency |
| Deploy | Coolify on the VPS, triggered by the GitHub push webhook |
| Scheduled work | a systemd timer on the VPS, not a GitHub `schedule:` cron |

## Local

```sh
./scripts/verify.sh     # the gate; must pass before pushing
```

## Deploying

The Coolify app pulls `docker-compose.yaml` from this repo, with
`docker_compose_domains` naming the `frontend` service. Redeploying is a push.
Back up the `postgres_data` volume and keep `ENCRYPTION_KEY`: together they are
the only copy of the mailbox credentials and cached mail.

## Universal login (environment-managed)

The `admin-bootstrap` service runs once per deploy, after the backend is
healthy, and makes the environment the source of truth for the single login:

| Variable | Effect |
|---|---|
| `MAILFLOW_ADMIN_USER` | The one login that owns every connected mailbox |
| `MAILFLOW_ADMIN_PASSWORD` | Its password. Re-hashed and upserted on every deploy, so rotating the env var rotates the login |
| `MAILFLOW_ADMIN_THEME` | UI theme forced for that user (default `light`) |

Nothing here is a secret in the repo: the values live in Coolify's env store.
Because the password is re-applied from the environment on boot, changing it in
the UI is temporary by design — change the env var instead.
