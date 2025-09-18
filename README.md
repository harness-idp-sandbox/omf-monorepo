# Monorepo (IDP Example)

This repository hosts multiple applications and libraries provisioned through **Harness IDP**. Each new app is scaffolded into its own top-level folder via the “E2E React App Provisioning” flow.

## Layout

```
/
├─ <app-1>/
├─ <app-2>/
├─ shared/            # optional shared packages or infra (if you add one later)
└─ tools/             # optional scripts, lint configs, etc.
```

> New apps are created as PRs from feature branches (e.g. `feature/<project-slug>-<run-number>`).

## Create a new app

1. Open the IDP action **E2E React App Provisioning**.
2. Fill in:
   - **Base repo**: this repo’s name
   - **Base branch**: usually `main`
   - **Project name / slug / owner / description** (used by cookiecutter)
3. The pipeline will:
   - Create a feature branch
   - Scaffold a new folder at `/<project-slug>`
   - Commit and open a Pull Request

## Local development (per app)

1. `cd <project-slug>`
2. Install deps: `npm install` (or `pnpm i` / `yarn`)
3. Run dev server: `npm run dev`
4. Build: `npm run build`
5. Test: `npm test`

> See each app’s own `README.md` for environment variables, URLs, and app-specific commands.

## Conventions

- **Branching**: `feature/<project-slug>-<run-number>`
- **PR title**: `feat(idp:<run-number>): scaffold <project-slug>`
- **App folder**: kebab-case `<project-slug>`

## CI/CD (high level)

- Clone → Branch → Scaffold → Commit → PR
- Merges to `main` trigger the deployment workflow for each app (configure per app).

## Support

- Pipeline: `E2E_React_App_Provisioning`
- Owners: @REPLACE_ME
