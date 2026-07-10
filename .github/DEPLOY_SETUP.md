# GitHub Actions setup — manager approval + auto deploy

Follow these steps once in the GitHub repo settings so the pipeline behaves as:

```
Push → Open PR → CI runs → Manager approves PR → Merge → CI on main → Manager approves deploy → Auto deploy
```

---

## Step 1 — Create GitHub Environments

Go to **Settings → Environments** and create:

| Environment | Used when |
|-------------|-----------|
| `dev` | Merge/push to `dev` branch |
| `staging` | Merge/push to `staging` branch |
| `prod` | Merge/push to `main` branch |

For each environment (at minimum **prod**, recommended for staging too):

1. Enable **Required reviewers**
2. Add your **manager** as reviewer
3. (Optional) Add **Wait timer** for prod (e.g. 5 minutes)

When the Deploy workflow runs, it **pauses** and sends your manager a notification. They click **Review deployments → Approve**. Only then Ansible/Terraform runs.

---

## Step 2 — Branch protection on `main`

Go to **Settings → Branches → Add rule** for `main`:

| Setting | Value |
|---------|-------|
| Require a pull request before merging | ✅ |
| Required approvals | `1` |
| Require review from Code Owners | (optional) |
| Require status checks to pass | ✅ |
| Status checks required | Select all **CI** jobs: `Terraform validate`, `Ansible lint and syntax`, `Validate dashboard JSON`, `Validate Docker Compose` |
| Require branches to be up to date | ✅ |

Repeat similar rules for `staging` and `dev` if you use those branches.

This ensures:
- Direct push to `main` is blocked
- CI must pass before merge
- Manager must **approve the PR** before merge

---

## Step 3 — Add secrets and variables

**Settings → Secrets and variables → Actions**

### Secrets (repository level)

| Secret | Purpose |
|--------|---------|
| `ANSIBLE_SSH_PRIVATE_KEY` | SSH key for EC2 hosts |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password |
| `AWS_ACCESS_KEY_ID` | Terraform |
| `AWS_SECRET_ACCESS_KEY` | Terraform |

### Variables (per environment recommended)

Set `GRAFANA_ROOT_URL` and `AWS_REGION` under each Environment (`dev`, `staging`, `prod`) so each env can have different values.

---

## Step 4 — Full pipeline flow

```
Developer                    GitHub                         Manager
    │                           │                              │
    ├── push feature branch ───►│                              │
    ├── open PR ───────────────►│ CI workflow runs (auto)      │
    │                           │  • terraform validate        │
    │                           │  • ansible lint              │
    │                           │  • dashboard JSON            │
    │                           │  • docker compose            │
    │                           │                              │
    │                           │◄──── PR review approve ──────┤
    ├── merge PR ──────────────►│ CI runs again on main        │
    │                           │ (must pass)                  │
    │                           │                              │
    │                           │ Deploy workflow starts (auto)│
    │                           │ ⏸ PAUSED — waiting approval  │
    │                           │                              │
    │                           │◄──── Approve deployment ─────┤
    │                           │                              │
    │                           │ Terraform apply (if all)     │
    │                           │ Ansible deploy               │
    │◄── Grafana live ──────────│                              │
```

---

## Branch → environment mapping

| Branch | Deploy environment | Component deployed |
|--------|-------------------|-------------------|
| `dev` | `dev` | Full stack (`all`) |
| `staging` | `staging` | Full stack (`all`) |
| `main` | `prod` | Full stack (`all`) |

Manual **workflow_dispatch** still works from the Actions tab for single-component deploys.

---

## Terraform environments

Create matching Terraform roots before auto-deploy:

```
terraform/environments/dev/      ← exists
terraform/environments/staging/    ← copy from dev and customize
terraform/environments/prod/       ← copy from dev and customize
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Deploy never starts | CI must pass on push to `main`/`staging`/`dev` after merge |
| Deploy stuck "Waiting" | Manager must approve in Actions → Deploy run → Review deployments |
| PR can't merge | CI checks must be green + manager PR approval required |
| Terraform fails | Ensure `terraform/environments/<env>/` exists with valid `terraform.tfvars` in backend |
