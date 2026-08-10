# Self-Healing Deployment Pipeline

A CI/CD pipeline that deploys a service, gates the release behind an automated
health check, and rolls back to the last-known-good version on failure —
with the deployment history visualized on a dashboard. Generalizes the
rollback/validation/DR automation pattern built for production microservices
at Thomson Reuters into an open, runnable portfolio demo.

## Why this exists

Most "CI/CD demo" repos stop at build-and-deploy. This one demonstrates the
part that actually matters in production: **what happens when a deploy is
bad** — fail-fast validation, automatic rollback, event logging, and
notification, all as code.

## Architecture

```
GitHub Actions ──▶ Ansible (deploy role) ──▶ new container on active port
                          │
                          ▼
                  health check gate (healthcheck/validate.py)
                    HTTP 200 + service-state + response-time threshold
                    retries with backoff
                          │
              ┌───────────┴───────────┐
           healthy                 unhealthy
              │                       │
      discard old version      Ansible (rollback role)
      log "success" event      restore last-known-good
                                log "rollback" event
                                notify webhook (Teams/Slack-style)
                                fail the pipeline run
```

Every deploy — success or rollback — is appended to
`deployment_log/deployments.json`, which the dashboard renders as a timeline.

## Repo layout

```
app/                  Demo FastAPI service with /health endpoint and a
                       FORCE_FAIL toggle used to simulate a broken deploy
ansible/
  deploy.yml           Orchestrating playbook: deploy → health gate → rollback
  group_vars/all.yml   Centralized config (vars.yml pattern)
  group_vars/vault.yml Secrets separation pattern (placeholder values only)
  roles/deploy/         Builds image, runs new version alongside last-known-good
  roles/rollback/       Restores last-known-good on failed health check
healthcheck/validate.py Fail-fast HTTP validation framework (retry/backoff,
                         response-time threshold)
scripts/log_event.py    Appends deploy/rollback events to the JSON log
chaos/inject_bad_deploy.sh  Triggers a forced-failure deploy end-to-end
dashboard/index.html    Deployment history timeline (success/rollback events)
.github/workflows/deploy.yml  CI entrypoint — same playbook, runs in Actions
```

## Running it

Everything runs through GitHub Actions — no local Docker/Ansible needed.

- **Push to `main`** → deploys `target_version={{ github.sha }}`, `force_fail=false`.
- **Run "Self-Healing Deploy" manually** (Actions tab → Run workflow) → set
  `target_version` and `force_fail=true` to trigger the rollback path on demand.
- **Dashboard** publishes automatically to GitHub Pages after each deploy run
  (one-time setup: Settings → Pages → source: GitHub Actions).

## What the health gate actually checks

`healthcheck/validate.py` — HTTP 200 + `status: healthy` body, response time
under a configurable threshold, retried with backoff before declaring failure.
Mirrors the Apache/NLB-convergence validation pattern (service state + HTTP
check + retry) rather than a bare curl call, so it fails on slow-but-technically-
200 responses too, not just hard errors.

## Known limitations

- **Single-host demo, runs on the Actions runner itself.** Deploy/rollback
  target Docker containers on the GitHub-hosted runner
  (`ansible_connection=local` relative to the runner), not a real fleet —
  swapping the inventory for real SSH hosts is the only change needed to
  point this at actual servers.
- **Containers don't persist across separate workflow runs.** Each push
  starts a fresh runner, so "previous" only exists within one job's
  lifetime — a same-run deploy→chaos→rollback sequence works end-to-end,
  but rolling back to a version deployed in an earlier run would need
  images pushed to GHCR and pulled by tag instead of relying on a locally
  renamed container.
- **Notification webhook is a placeholder.** `vault_notify_webhook_url` points
  at a non-existent endpoint; wire in a real Slack/Teams incoming webhook URL
  via `ansible-vault encrypt` to make it live.
- **No canary/traffic-split.** Rollback is instant cutover (rename containers),
  not a gradual traffic shift — fine for a demo, a real NLB-backed setup would
  drain connections first.
- **Vault file is committed in plaintext** since it holds no real secrets —
  documents the pattern only; a real deployment must run
  `ansible-vault encrypt group_vars/vault.yml` and never commit the decrypted
  file.
