# deploy

Everything needed to run the ZOVA infrastructure locally or on the home server: Docker Compose files, observability config and the OSRM data task.

## Requirements

- Docker with Compose v2
- [Task](https://taskfile.dev) 3.x
- Git and curl

## Quick start

```sh
git clone https://github.com/zova-platform/deploy.git
cd deploy
task up
```

The first `task up` copies `compose/.env.example` to `compose/.env` and starts everything except OSRM. `compose/.env` is ignored by git, so edit it freely.

Other tasks:

| Task | What it does |
| --- | --- |
| `task up` | Start the infra stack |
| `task down` | Stop it and keep the data |
| `task clone-all` | Clone every ZOVA repo next to this one, skipping those already cloned |
| `task osrm:prepare` | Download map data, clip it to Bangkok and build the routing graph |
| `task osrm:up` | Start the OSRM routing service |

## What runs

All ports are bound to `127.0.0.1` unless `BIND_ADDRESS` says otherwise.

| Service | Port | Notes |
| --- | --- | --- |
| Postgres + PostGIS | 5432 | Databases `auth`, `pricing`, `dispatch`, `trip`, each with its own role |
| Redis | 6379 | |
| NATS JetStream | 4222 | Monitoring on 8222 |
| OpenTelemetry Collector | 4317 (gRPC), 4318 (HTTP) | Services send OTLP here |
| Prometheus | 9090 | Scrapes the Collector |
| Grafana | 3000 | Login `admin` with `GRAFANA_ADMIN_PASSWORD` from `compose/.env` |
| OSRM | 5000 | Only with `task osrm:up` |

Tempo (traces) and Loki (logs) are reachable only inside the compose network. Grafana already has Prometheus, Tempo and Loki as datasources, and trace IDs in logs link to traces.

## Using the infra from a service

Run services on your machine and point them at localhost:

| Setting | Value |
| --- | --- |
| Postgres | `postgres://trip:<SERVICE_DB_PASSWORD>@localhost:5432/trip` |
| Redis | `localhost:6379` |
| NATS | `nats://localhost:4222` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4317` |

The per-service databases are created only when the Postgres volume is first created. To change them, reset the volume (see below).

## OSRM

OSRM needs a routing graph built from OpenStreetMap data. ZOVA covers the Bangkok area only.

```sh
task osrm:prepare
task osrm:up
```

`osrm:prepare` downloads `thailand-latest.osm.pbf` (about 330 MB) from Geofabrik and checks its checksum. It clips the file to the Bangkok bounding box (`100.32,13.49,100.95,13.96`, west, south, east, north) with osmium and builds the graph into `osrm/data/`. This takes a few minutes and under 1 GB of RAM.

Try a route once it is running: `curl "http://localhost:5000/route/v1/driving/100.5340,13.7456;100.5370,13.7650?overview=false"`.

Requests outside the bounding box fail, so keep pickups and drop-offs inside it.

Settings (environment variables):

| Variable | Default | Meaning |
| --- | --- | --- |
| `OSRM_BBOX` | `100.32,13.49,100.95,13.96` | Area to keep. `none` skips clipping |
| `OSRM_NAME` | `bangkok` | Name of the graph in `osrm/data/` |
| `OSRM_PREPARE_MEM` | `2g` | Memory limit while building the graph |

Building all of Thailand was tried and failed: `osrm-extract` was killed for lack of memory at 7 GB. If you have far more RAM, try `OSRM_BBOX=none OSRM_NAME=thailand-latest task osrm:prepare` and then `OSRM_NAME=thailand-latest task osrm:up`.

## Configuration

Settings live in `compose/.env`. See `compose/.env.example` for every variable.

- **Port already in use:** change the matching `*_PORT` value, for example `POSTGRES_PORT=5433`.
- **Home server:** change every password in `compose/.env` before the first `task up`. The example values are for development only.
- **Reset all data:** `docker compose -f compose/infra.yml --profile osrm down -v` removes the volumes, so Postgres, Redis, NATS and Grafana start empty.

## Layout

```
Taskfile.yml           tasks
compose/infra.yml      infra services
compose/.env.example   settings template
compose/postgres/      database init script
observability/         Collector, Prometheus, Tempo, Loki and Grafana config
osrm/data/             map data and routing graph (not committed)
```
