# GrafanaAlerting (separate repository)

Alert rules, contact points, and notification policies are managed as **Terraform resources** in the **GrafanaAlerting** repository — not in this repo.

## Why a separate repo?

- Alerting changes are reviewed independently from dashboard and host provisioning changes
- Terraform state is scoped per environment (dev / staging / prod)
- UI changes to alerts are overwritten on the next `terraform apply`

## Typical layout (GrafanaAlerting repo)

```
GrafanaAlerting/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── alert_rules/
│   ├── contact_points/
│   └── notification_policies/
└── README.md
```

## Workflow

1. Edit alert rule `.tf` files in GrafanaAlerting
2. Open a PR and get review
3. `terraform plan` / `terraform apply` for the target environment
4. Verify in Grafana UI: **Alerting → Alert rules**

Do **not** create or edit alert rules directly in the Grafana UI — they will be overwritten on the next apply.
