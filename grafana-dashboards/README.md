# Grafana Dashboards

Dashboard JSON definitions tracked as Infrastructure as Code.

This directory mirrors the `grafana-dashboards/` layout used in **CatalystDevOps** — organized by domain so teams can own their dashboards.

## Categories

| Folder | Coverage |
|--------|----------|
| `aws-infrastructure/` | EC2, ALB, RDS, ElastiCache, VPC, S3, Lambda |
| `application-services/` | API latency, error rates, JVM, containers |
| `data-services/` | PostgreSQL, MySQL, MongoDB, Redis, Kafka |
| `search/` | OpenSearch / Elasticsearch cluster health |
| `hcc/` | HCC pipeline throughput, latency, queues |

## Updating a dashboard

1. Make changes in the Grafana UI
2. Export the dashboard JSON (**Share → Export → Save to file**)
3. Replace the corresponding file in this directory and commit
4. Redeploy Grafana (Ansible playbook) or sync provisioning volume

Do **not** rely on UI-only changes in production — they will be lost on the next provisioning deploy unless exported back to Git.
