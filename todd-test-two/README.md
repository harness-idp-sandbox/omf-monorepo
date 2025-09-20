# Todd Test Two

Testing for POC

> Owner: todd.parson@harness.io

---

## Quick links

- **Repository path:** `/todd-test-two`
- **Open PRs (search):** https://github.com/ORG/REPO/pulls?q=is%3Apr+todd-test-two
- **Backstage/IDP catalog entry:** _(add link once created)_
- **Issue tracker:** _(add link or JIRA project)_

## Environments & URLs

| Environment | URL | Notes |
|---|---|---|
| Dev | https://todd-test-two.dev.example.com | _(replace with your real dev domain)_ |
| Staging | https://todd-test-two.stg.example.com |  |
| Prod | https://todd-test-two.example.com |  |

> If you don’t have ingress yet, you can still access a running pod locally:
>
> ```bash
> # Example: adjust namespace/service as needed
> kubectl port-forward -n <namespace> svc/todd-test-two-web 5173:80
> # then open http://localhost:5173
> ```

## Getting started (local)

### Prerequisites
- Node.js ≥ 18
- Package manager: `npm` (or `pnpm`/`yarn`)
- (Optional) Docker if you run containerized locally

### Install & run

```bash
cd todd-test-two
npm install
npm run dev
# open http://localhost:5173
```

Common scripts (defined in `package.json`):

```bash
npm run dev        # start dev server
npm run build      # production build
npm run preview    # preview built app
npm test           # run unit tests
npm run lint       # lint
```

### Environment variables

Create `.env` files as needed (`.env`, `.env.development`, `.env.production`):

| Variable | Example | Description |
|---|---|---|
| VITE_API_BASE_URL | `https://api.example.com` | API endpoint |
| FEATURE_FLAG_X | `true` | toggle a feature |
| LOG_LEVEL | `info` | logging verbosity |

> Avoid committing secrets. Use your platform’s secret manager for runtime config.

## Build & deploy

- **Branching:** feature branches like `feature/todd-test-two-<run-number>`
- **PRs:** merging to `main` triggers build/deploy (configure in CI/CD).
- **Artifact:** static SPA or container image (document what you choose).
- **Runtime config:** prefer env-driven config and inject at build/deploy time.

## Observability (fill in)

- **Logs:** _link to logging solution (e.g., CloudWatch, Elasticsearch, Datadog)_
- **Metrics/Dashboards:** _link to dashboard_
- **Tracing:** _link to traces_
- **Uptime/Synthetics:** _link to monitor_

## Security (fill in)

- **Dependency scanning:** _tool & dashboard link_
- **SAST/Secrets scanning:** _tool & dashboard link_
- **Container scan:** _tool & dashboard link_
- **AuthN/Z:** _how this app authenticates; link to provider/config_

## Operations (fill in)

- **Runbooks:** _link to runbook_
- **On-call:** _rotation / contact_
- **SLOs/SLIs:** _targets and dashboards_
- **Release process:** _versioning, tagging, change management_

## Architecture

- **Stack:** React + Vite (SPA) _(adjust if different)_
- **Directory layout:**
  ```
  todd-test-two/
  ├─ src/
  │  ├─ components/
  │  ├─ pages/
  │  ├─ assets/
  │  └─ index.tsx
  ├─ public/
  ├─ package.json
  ├─ tsconfig.json
  └─ README.md
  ```
- **Key decisions:** track in lightweight ADRs under `docs/adrs/` (see template below).

## ADR template (example)

Create files like `docs/adrs/0001-title.md`:

```markdown
# ADR-0001: Title
Date: 2025-01-01
Status: Accepted

## Context
Why are we changing something?

## Decision
What did we choose and why?

## Consequences
Trade-offs, follow-ups, risks.
```

## Getting started checklist (for the team)

> These are placeholders—edit to fit your organization.

- [ ] Choose environment URL pattern and configure ingress/DNS
- [ ] Set up CI/CD pipeline for this folder path
- [ ] Add IDP catalog annotations (owner, system, links)
- [ ] Create dashboards for logs/metrics/uptime
- [ ] Add SLOs and alerts
- [ ] Configure dependency + SAST + container scanning
- [ ] Document runtime env vars and secrets locations
- [ ] Add CODEOWNERS and review rules
- [ ] Create initial ADRs (routing, state mgmt, API client)

## Troubleshooting

- **Dev server not starting**: check Node version (`node -v`), remove `node_modules`, re-install.
- **CORS errors**: set `VITE_API_BASE_URL` correctly or add a local proxy.
- **Blank screen in prod**: ensure correct `base` path in Vite config if app serves from a sub-path.

## License

_(Add your license or link here)_
