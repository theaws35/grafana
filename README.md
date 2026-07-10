# Grafana on Docker — Full Setup

A ready-to-run monitoring stack using **Docker Compose**:

| Service | Purpose | Default URL |
|---------|---------|-------------|
| **Grafana** | Dashboards and visualization | http://localhost:3000 |
| **Prometheus** | Metrics database (time-series store) | http://localhost:9090 |
| **Node Exporter** | Host metrics (CPU, memory, disk) | internal only |

---

## Quick start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (Engine 24+)
- [Docker Compose](https://docs.docker.com/compose/install/) v2 (`docker compose` command)

### 1. Clone and configure

```bash
git clone https://github.com/theaws35/grafana.git
cd grafana
cp .env.example .env
```

Edit `.env` and set a strong `GRAFANA_ADMIN_PASSWORD` before deploying.

### 2. Start the stack

```bash
docker compose up -d
```

### 3. Open Grafana

- URL: http://localhost:3000
- Username: value of `GRAFANA_ADMIN_USER` (default `admin`)
- Password: value of `GRAFANA_ADMIN_PASSWORD`

A **Host Overview** dashboard and **Prometheus** datasource are provisioned automatically.

### 4. Stop the stack

```bash
docker compose down
```

To remove stored metrics and Grafana data as well:

```bash
docker compose down -v
```

---

## Repository layout

```
.
├── docker-compose.yml          # Defines all services, networks, and volumes
├── .env.example                # Template for environment variables
├── prometheus/
│   └── prometheus.yml          # What Prometheus scrapes and how often
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasources.yml # Auto-configure Prometheus as a datasource
        └── dashboards/
            ├── dashboards.yml  # Tell Grafana where dashboard JSON files live
            └── host-overview.json
```

---

## What each file does (and why)

### `docker-compose.yml`

This is the main orchestration file. It defines three containers on a shared Docker network.

#### `grafana` service

| Setting | Why |
|---------|-----|
| `image: grafana/grafana:11.5.2` | Pinned version for reproducible deploys |
| `ports: 3000:3000` | Exposes the Grafana web UI on your machine |
| `GF_SECURITY_ADMIN_USER/PASSWORD` | Sets the initial admin login (override via `.env`) |
| `GF_USERS_ALLOW_SIGN_UP: false` | Prevents random users from self-registering |
| `GF_SERVER_ROOT_URL` | Required when Grafana sits behind a reverse proxy or custom domain |
| `grafana-data` volume | Persists dashboards, users, and settings across restarts |
| `./grafana/provisioning` mount | Loads datasources and dashboards from files at startup (Infrastructure as Code) |
| `depends_on: prometheus (healthy)` | Waits until Prometheus is ready before Grafana starts |

#### `prometheus` service

| Setting | Why |
|---------|-----|
| `image: prom/prometheus:v3.2.1` | Pinned Prometheus version |
| `ports: 9090:9090` | Prometheus UI and API (useful for debugging queries) |
| `--storage.tsdb.retention.time=15d` | Keeps 15 days of metrics; adjust for your disk budget |
| `prometheus-data` volume | Persists collected metrics across container restarts |
| `healthcheck` | Lets Compose know when Prometheus is ready to accept scrapes |

#### `node-exporter` service

| Setting | Why |
|---------|-----|
| `image: prom/node-exporter` | Standard exporter that exposes host hardware metrics |
| Host `/proc`, `/sys`, `/` mounts | Reads real CPU, memory, and disk stats from the Docker host |
| No published port | Only Prometheus needs access; keeps the attack surface smaller |

#### `monitoring` network

All services talk over a private bridge network. Grafana reaches Prometheus at `http://prometheus:9090` using the Docker DNS name — not `localhost`.

#### Named volumes

| Volume | Stores |
|--------|--------|
| `grafana-data` | Grafana database (SQLite by default), plugins, preferences |
| `prometheus-data` | Time-series metric blocks |

---

### `.env.example` → `.env`

Environment variables keep secrets and port overrides out of `docker-compose.yml`.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GRAFANA_PORT` | `3000` | Host port for Grafana UI |
| `GRAFANA_ADMIN_USER` | `admin` | Initial Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | `change-me` | Initial Grafana admin password — **change this** |
| `GRAFANA_ROOT_URL` | `http://localhost:3000` | Public URL Grafana uses for links and redirects |
| `PROMETHEUS_PORT` | `9090` | Host port for Prometheus UI |

Copy to `.env` (gitignored) so credentials are never committed.

---

### `prometheus/prometheus.yml`

Tells Prometheus **what to scrape** and **how often**.

```yaml
global:
  scrape_interval: 15s      # Pull metrics every 15 seconds
  evaluation_interval: 15s  # Re-evaluate alerting rules every 15 seconds
```

**Scrape jobs:**

| Job | Target | Why |
|-----|--------|-----|
| `prometheus` | `prometheus:9090` | Prometheus monitors itself |
| `node-exporter` | `node-exporter:9100` | Collects host CPU, memory, disk, network metrics |

To monitor your own apps, add a new `scrape_configs` entry with your app's metrics endpoint.

---

### `grafana/provisioning/datasources/datasources.yml`

**Provisioning** means Grafana configures itself from files on startup — no manual "Add datasource" clicks.

- Registers **Prometheus** as the default datasource
- Points to `http://prometheus:9090` (internal Docker hostname)
- `access: proxy` — Grafana backend queries Prometheus (browser never talks to Prometheus directly)
- `editable: false` — Prevents accidental UI changes from drifting away from Git

---

### `grafana/provisioning/dashboards/`

**`dashboards.yml`** — Tells Grafana to load every `.json` file in this folder as a dashboard.

**`host-overview.json`** — A starter dashboard with three panels:

| Panel | PromQL query (simplified) | Shows |
|-------|---------------------------|-------|
| CPU Usage | idle CPU rate inverted | How busy the host CPU is |
| Memory Usage | available vs total memory | RAM pressure |
| Disk Usage | free vs total per mount | Disk space per filesystem |

You can edit dashboards in the Grafana UI. To make changes permanent in Git, export the JSON and replace `host-overview.json`.

---

## How the data flows

```
Host machine
    │
    ▼
node-exporter (:9100)  ──scrape──▶  Prometheus (:9090)  ◀──query──  Grafana (:3000)
                                         │                              │
                                         └── stores metrics              └── you view dashboards
                                             in prometheus-data              in browser
```

1. **Node Exporter** exposes `/metrics` with host stats.
2. **Prometheus** pulls (scrapes) those metrics every 15s and stores them.
3. **Grafana** sends PromQL queries to Prometheus and renders charts.

---

## Deployment options

### Local development (this setup)

```bash
docker compose up -d
docker compose logs -f grafana   # follow Grafana logs
docker compose ps                # check service health
```

### Production on a single VM (EC2, DigitalOcean, etc.)

1. Install Docker and Docker Compose on the server.
2. Clone this repo to the server.
3. Set `.env` with a strong password and your real domain in `GRAFANA_ROOT_URL`.
4. Run `docker compose up -d`.
5. Put **Nginx** or **Caddy** in front of Grafana for HTTPS.
6. Restrict ports `3000` and `9090` with a security group / firewall — only expose 443 publicly.

Example firewall approach: remove port mappings from `docker-compose.yml` for Prometheus and only expose Grafana through a reverse proxy.

### Updating

```bash
git pull
docker compose pull      # fetch newer images (if you bump versions)
docker compose up -d     # recreate containers with new config
```

### Backups

Back up the named volumes:

```bash
docker run --rm \
  -v grafana_grafana-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/grafana-data.tar.gz -C /data .

docker run --rm \
  -v grafana_prometheus-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/prometheus-data.tar.gz -C /data .
```

Volume names are prefixed with the project folder name (usually `grafana_`). Check with `docker volume ls`.

---

## Common operations

| Task | Command |
|------|---------|
| Restart Grafana only | `docker compose restart grafana` |
| View all logs | `docker compose logs -f` |
| Validate Compose file | `docker compose config` |
| Reset everything | `docker compose down -v && docker compose up -d` |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Grafana shows "No data" | Wait 1–2 minutes for Prometheus to scrape; check http://localhost:9090/targets — all targets should be **UP** |
| Cannot log in | Verify `.env` values; reset with `docker compose down -v` (wipes data) |
| Port already in use | Change `GRAFANA_PORT` or `PROMETHEUS_PORT` in `.env` |
| Dashboard not appearing | Check `docker compose logs grafana` for provisioning errors |

---

## Next steps

- Add your application metrics endpoints to `prometheus/prometheus.yml`
- Add [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) for Slack/email alerts
- Add [Loki](https://grafana.com/docs/loki/latest/) for log aggregation
- Use [Grafana OAuth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/) for SSO

---

## License

Use and modify freely for your own projects.
