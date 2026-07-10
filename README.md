# Grafana Monitoring Platform

Observability stack for AWS: **Grafana**, **Prometheus**, **Node Exporter**, and **CloudWatch** — deployed with **Ansible** and **Terraform**.

| Service | Purpose |
|---------|---------|
| **Grafana** | Dashboards and visualization |
| **Prometheus** | Metrics database (time-series store) |
| **Node Exporter** | Host metrics (CPU, memory, disk) |
| **CloudWatch agent** | AWS-native host and custom metrics |

---

## Automation

### Ansible roles

| Role | Description |
|------|-------------|
| `grafana` | Installs Docker, deploys Grafana container with provisioning |
| `prometheus` | Installs Docker, deploys Prometheus with scrape config |
| `node_exporter` | Deploys Node Exporter container on application hosts |
| `cloudwatch` | Installs and configures the Amazon CloudWatch agent |

Roles live under `ansible/roles/`.

### Terraform modules

| Module | Description |
|--------|-------------|
| `grafana` | EC2 instance + security group for Grafana host |
| `prometheus` | EC2 instance + security group for Prometheus host |

Modules live under `terraform/modules/`.

### Alerting IaC

The **GrafanaAlerting** repository manages alert rules, contact points, and notification policies as **Terraform resources**.

See `terraform/alerting/README.md` for the expected layout and workflow. Alert changes must be made in GrafanaAlerting — not in the Grafana UI.

### Dashboard definitions

Dashboard JSON files are tracked in `grafana-dashboards/` (30+ files covering AWS infrastructure, application services, data services, search, and HCC).

---

## Playbooks

| Playbook | Description |
|----------|-------------|
| `deploy_grafana.yaml` | Grafana deployment (AWS) |
| `deploy_grafana_al23.yaml` | Grafana on Amazon Linux 2023 |
| `deploy_prometheus.yaml` | Prometheus deployment |
| `deploy_prometheus_al23.yaml` | Prometheus on AL2023 |
| `deploy_node_exporter.yaml` | Prometheus Node Exporter |
| `deploy_cloudwatch.yaml` | CloudWatch agent |

All playbooks are in `ansible/playbooks/`.

### CI/CD pipelines

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **CI** (`ci.yml`) | Every PR and push to `main` | Terraform validate, Ansible syntax/lint, dashboard JSON validation, Docker Compose check |
| **Deploy** (`deploy.yml`) | **Auto** after CI passes on merge to `main`/`staging`/`dev`; also manual | Terraform apply + Ansible deploy; **pauses for manager approval** via GitHub Environments |

#### Approval + auto-deploy flow

```
1. Push code → open PR        → CI runs automatically
2. Manager approves PR        → (branch protection)
3. Merge PR                   → CI runs on main again
4. CI passes                  → Deploy workflow starts automatically
5. Manager approves deploy    → (GitHub Environment gate)
6. Pipeline deploys           → Terraform + Ansible run
```

See **[.github/DEPLOY_SETUP.md](.github/DEPLOY_SETUP.md)** for one-time GitHub settings (environments, branch protection, secrets).

#### Required GitHub secrets (for Deploy workflow)

| Secret | Purpose |
|--------|---------|
| `ANSIBLE_SSH_PRIVATE_KEY` | SSH key to reach EC2 hosts in inventory |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password passed to Ansible |
| `AWS_ACCESS_KEY_ID` | Terraform apply (when deploying infrastructure) |
| `AWS_SECRET_ACCESS_KEY` | Terraform apply |

#### Required GitHub variables

| Variable | Purpose |
|----------|---------|
| `GRAFANA_ROOT_URL` | Public Grafana URL (e.g. `https://grafana.example.com`) |
| `AWS_REGION` | AWS region for Terraform (e.g. `us-east-1`) |

Configure GitHub **Environments** (`dev`, `staging`, `prod`) with **Required reviewers** (your manager) — see [.github/DEPLOY_SETUP.md](.github/DEPLOY_SETUP.md).

### Deploy with Ansible

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
# Edit inventory/hosts.yml with your host IPs
ansible-playbook playbooks/deploy_grafana.yaml
ansible-playbook playbooks/deploy_prometheus.yaml
ansible-playbook playbooks/deploy_node_exporter.yaml
ansible-playbook playbooks/deploy_cloudwatch.yaml
```

For **Amazon Linux 2023** hosts, use the `*_al23.yaml` playbooks instead.

### Provision infrastructure with Terraform

```bash
cd terraform/environments/dev   # create per-environment roots as needed
terraform init
terraform plan
terraform apply
# Then run Ansible playbooks against the new instance IPs
```

---

## Repository layout

```
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.yml
│   ├── group_vars/all.yml
│   ├── requirements.yml
│   ├── playbooks/
│   │   ├── deploy_grafana.yaml
│   │   ├── deploy_grafana_al23.yaml
│   │   ├── deploy_prometheus.yaml
│   │   ├── deploy_prometheus_al23.yaml
│   │   ├── deploy_node_exporter.yaml
│   │   └── deploy_cloudwatch.yaml
│   └── roles/
│       ├── grafana/
│       ├── prometheus/
│       ├── node_exporter/
│       └── cloudwatch/
├── terraform/
│   ├── modules/
│   │   ├── grafana/
│   │   └── prometheus/
│   └── alerting/              # GrafanaAlerting repo pattern (reference)
├── grafana-dashboards/        # Dashboard JSON (IaC)
│   ├── aws-infrastructure/
│   ├── application-services/
│   ├── data-services/
│   ├── search/
│   └── hcc/
├── docker-compose.yml         # Local dev / smoke test
├── prometheus/
└── grafana/provisioning/
```

---

## Local development (Docker Compose)

For quick local testing without Ansible:

```bash
cp .env.example .env   # set GRAFANA_ADMIN_PASSWORD
docker compose up -d
```

Open http://localhost:3000 (default user: `admin`).

---

## Runbook

### Grafana Unreachable

If the Grafana UI is not loading:

1. SSH to the Grafana host and check the Docker container:

```bash
docker ps -a | grep grafana
docker logs grafana --tail 50
```

2. Restart if needed:

```bash
docker restart grafana
```

3. If the container is missing, re-run the Ansible playbook:

```bash
ansible-playbook playbooks/deploy_grafana.yaml
```

### Alert Rules Not Firing

If expected alerts are not triggering:

1. Verify the alert rules are deployed: check the **GrafanaAlerting** Terraform state for the target environment.
2. In the Grafana UI, navigate to **Alerting → Alert rules** and confirm the rule exists and is in an active state.
3. Check the data source connectivity — a broken Prometheus or CloudWatch data source will silently prevent evaluation.

### Modifying Alerts

Alert changes should be made in the **GrafanaAlerting** Terraform codebase, not directly in the Grafana UI. Direct UI changes will be overwritten on the next Terraform apply.

### Modifying Dashboards

Dashboard JSON files are tracked in `grafana-dashboards/`. To update a dashboard:

1. Make changes in the Grafana UI.
2. Export the dashboard JSON (**Share → Export → Save to file**).
3. Replace the corresponding file in `grafana-dashboards/` and commit.
4. Re-run `deploy_grafana.yaml` (or restart the Grafana container) to pick up provisioning changes.

---

## Data flow

```
Application hosts                Grafana host
┌──────────────────┐            ┌─────────────────────────────┐
│ node-exporter    │──scrape──▶   │ Prometheus ◀──query── Grafana │
│ cloudwatch-agent │──metrics──▶  │                             │
└──────────────────┘   (AWS)      └─────────────────────────────┘
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Grafana shows "No data" | Check Prometheus targets at `:9090/targets`; ensure Node Exporter is running on scraped hosts |
| Ansible fails on Docker | Confirm Amazon Linux version and use the correct playbook (`*_al23.yaml` for AL2023) |
| Dashboard not appearing | Check `docker logs grafana` for provisioning errors; verify JSON is valid |
| Alerts missing | Deploy via GrafanaAlerting Terraform — not the Grafana UI |
