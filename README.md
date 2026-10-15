# system-design-prototypes

Hands-on system design: each lab takes one classic exercise, adds a realistic twist from a travel-booking domain (hotel/seat inventory, an aggregator over external suppliers, payments), and turns it into a **running, tested and measured** system. Every lab is in Go (with Python fakes where a stand-in service helps), runs against shared local infrastructure, and reports real numbers.

## Labs

| # | Lab | Exercise | Status | What it proves |
|---|---|---|---|---|
| 00 | [setup](labs/00-setup/) | Repo, toolchain, shared infra | ✅ done | Compose stack (Postgres, MySQL, Redis, Toxiproxy, Prometheus, Grafana, Jaeger), Makefile, CI |
| 01 | airline-checkin | W2#1 Seat allocation | ⏳ next | No double booking: naive vs `FOR UPDATE` vs optimistic vs conditional `UPDATE`; `Idempotency-Key`; hold with TTL |
| 02 | bounded-blocking-pool | W1#1 Bounded blocking pool | planned | Acquire timeout, leak-proof release, p99 acquire latency vs pool size; reused as a per-supplier bulkhead |
| 03 | supplier-gateway | Composite: W1#6 + W4#1 + W8#3 | planned | Fan-out with deadline, retries with jitter, circuit breaker, partial results, cache + single-flight + SWR, Redis Lua token bucket, chaos tests |
| 04 | cursor-pagination | W8#2 + W3#10 | planned | OFFSET vs keyset `(created_at, id)` p99 across depths 1…10K |
| 05 | payment-webhooks | W7#9 | planned | Signed webhooks: raw-body HMAC, replay window, dedupe on `event_id`, enqueue-then-200, retries with backoff |
| 06 | jwt-auth | W4#6 | planned | RS256 with a pinned alg, short expiry + refresh, `jti` denylist; API key + HMAC request signing |
| 07 | brokers-three-flavours | W7#8 (SQS on SQL) | planned | Visibility timeout, ack, DLQ, `SKIP LOCKED`; transactional outbox relay with an idempotent consumer |
| 08 | distributed-2pc | W2#6 + saga | planned | 2PC blocking on coordinator death vs orchestrated saga with compensations + reconciliation |
| 09 | geohash-nearby | W8#1 | planned | GeoHash + 8 neighbours + Haversine; boundary-miss rate; vs Redis `GEOSEARCH` |
| 10 | hashtag-counter | W4#2 | planned | Hot-key counters, five write paths: DB writes, ingest p99 and drift |
| 11 | task-scheduler | W7#6 + W7#7 | planned | `SKIP LOCKED` pullers, heartbeat leases, missed-run policy, worker-death recovery |
| 12 | consistent-hashing | W5#1–3 + W1#2 | planned | Remaps under `% N` vs ring; skew vs vnodes; shard-key choice |
| 13 | kafka-demo | W1#8 + W1#7 | planned | Log vs queue: partitions, consumer groups, rebalance, replay; RabbitMQ prefetch and DLQ |
| 14 | id-snowflake-api | W3#2 + W3#8 | planned | Snowflake with clock-rollback handling; UUIDv4 vs v7 vs BIGINT insert cost |
| 15 | mysql-read-replica | W1#3 + W2#5 | planned | Replica lag, stale reads, read-your-own-writes via a primary window and LSN token |

"Exercise" refers to the week/number in the cohort exercise catalogue the labs are based on.

## Quick start

```bash
make tools                 # check toolchain versions
make up                    # start core infra (postgres, redis)
make it                    # integration tests, including the infra smoke test
make down                  # stop everything and wipe data
```

Infra profiles: `make up PROFILES="core chaos"`, `make up PROFILES=all`.

| Profile | Service | Port(s) |
|---|---|---|
| core | Postgres 17 (`lab`/`lab`, db `lab`) | 5432 |
| core | Redis 7.4 | 6379 |
| mysql | MySQL 8.4 (`lab`/`lab`, db `lab`) | 3306 |
| chaos | Toxiproxy (API / proxy listeners) | 8474 / 20000–20019 |
| obs | Prometheus | 9090 |
| obs | Grafana (anonymous admin) | 3000 |
| obs | Jaeger UI / OTLP gRPC / OTLP HTTP | 16686 / 4317 / 4318 |

Lab NN serves HTTP and `/metrics` on port `80NN`; Prometheus already scrapes those ports.

## Make targets

| Target | What it does |
|---|---|
| `make test` | Unit tests, `-short -race`, no Docker |
| `make it` | Integration tests (`-tags integration`): testcontainers, or the `make up` stack |
| `make lint` / `make fmt` | golangci-lint / gofmt + goimports |
| `make bench [LAB=..]` | Go benchmarks for all labs or one |
| `make load LAB=..` | k6 load test, `labs/<LAB>/load/load.js` |

## How every lab is built

1. **README**: exercise → twist → requirements → Mermaid diagram → decisions and trade-offs → failure-modes table (failure → detection → mitigation → test that proves it) → measured numbers → a 2-minute story.
2. **Code**: Go service (`net/http`, `context`, `errgroup`, `log/slog`, `pgx`, `go-redis`), Python/FastAPI fakes via `uv` where useful.
3. **Tests**: table-driven unit tests, integration tests (testcontainers), fault injection (Toxiproxy) wherever there is a network hop, and a load/bench test with a stated target.
4. **Observability**: RED metrics, traces (OpenTelemetry → Jaeger), structured logs carrying the trace ID.
5. **REVIEW.md**: a deliberately flawed version of the key component with planted issues, for code-review practice. The key is folded at the bottom.
6. Each exercise's **gotchas** and **verify** lists are worked through explicitly, with real measured numbers.

See [labs/_template/README.md](labs/_template/README.md) for the skeleton.

## Layout

```
deploy/compose.yml    shared infra (profiles: core, mysql, chaos, obs)
labs/NN-name/         one lab per folder
pkg/                  shared Go helpers, only once something is needed twice
PROGRESS.md           one line per session
```

## Stack

Go 1.27 · Python 3.12 + uv · Docker Compose · testcontainers-go · Toxiproxy · k6 · OpenTelemetry · Prometheus · Grafana · Jaeger · golangci-lint
