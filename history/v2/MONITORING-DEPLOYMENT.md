# Router Monitoring Deployment

The engine now includes a durable router monitor in `core.monitoring`. It
stores application/account snapshots, normalized application transactions,
deduplicated open alerts and every webhook delivery attempt in PostgreSQL.

## Configuration

Set these values in the engine environment. Monitoring is disabled unless
`ROUTER_MONITOR_ENABLED=true`.

```text
ROUTER_MONITOR_ENABLED=true
ROUTER_MONITOR_NETWORK=mainnet
ROUTER_MONITOR_APP_ID=3671595889
ROUTER_MONITOR_ACCOUNT_ADDRESS=<router application address>
ROUTER_MONITOR_POLL_INTERVAL_SECONDS=60
ROUTER_MONITOR_FEE_BPS=10
ROUTER_MONITOR_BATCH_CEILING=<operational accrued ceiling>
ROUTER_MONITOR_PROVIDERS=tinyman2,pact,stamm,algofi
ROUTER_MONITOR_ALGOD_ADDRESS=<private algod endpoint>
ROUTER_MONITOR_ALGOD_TOKEN=<private algod token>
ROUTER_MONITOR_INDEXER_ADDRESS=<private indexer endpoint>
ROUTER_MONITOR_INDEXER_TOKEN=<private indexer token>
ROUTER_MONITOR_WEBHOOK_URL=https://alerts.example.invalid/router
ROUTER_MONITOR_WEBHOOK_SECRET=<shared HMAC secret>
ROUTER_MONITOR_WEBHOOK_TIMEOUT_SECONDS=10
```

The account address must be the application account derived from the monitored
application ID. If omitted, the worker derives it locally and refuses to reuse
an existing row whose account address differs.

The webhook payload is JSON and is signed with
`X-Router-Monitor-Signature: sha256=<hex HMAC-SHA256>` when a secret is set.
Only HTTPS webhook URLs are accepted.

## Database Setup

Run the engine migration before starting the worker:

```bash
python manage.py migrate
```

The migration creates the `engine_core` deployment table when this partial
engine export is installed from an empty database, plus the router monitoring
tables. Existing production databases must be checked against their current
deployment schema before applying the initial migration.

## Worker Modes

Run one poll for a health check or canary:

```bash
python manage.py poll_router_monitor --once
```

Run continuously under systemd, supervisord or an equivalent process manager:

```bash
python manage.py poll_router_monitor
```

Storage-only operation is explicit and should not be used for production alert
coverage:

```bash
python manage.py poll_router_monitor --allow-no-delivery
```

An example unit and environment template are in
`systemd/asastats-router-monitor.service` and
`systemd/router-monitor.env.example`. Install the environment file with mode
`600`, run the database migration, perform a one-shot canary poll, then enable
the unit:

```bash
install -m 600 systemd/router-monitor.env.example /etc/asastats/router-monitor.env
python manage.py migrate
python manage.py poll_router_monitor --once
systemctl enable --now asastats-router-monitor.service
```

Use `--monitor-id` to select a specific persisted monitor. `--dry-run` reads
algod/indexer and evaluates alerts without writing snapshots, transactions,
alerts or deliveries; it requires an existing monitor ID.

The worker uses the persisted round cursor, polls application state and the
router account from algod, and reads bounded application transactions from the
indexer. The first poll establishes a baseline and does not alert on the
existing `accrued` value. Subsequent observations correlate state changes with
transactions in the same polling range.

## Delivery Semantics

- Admin method calls are stored and delivered individually.
- Continuing incidents are deduplicated by alert fingerprint and occurrence
  count is incremented.
- A successful delivery is not repeated on every poll.
- Failed deliveries remain durable and are retried on the next poll.
- The worker refuses to start without a webhook unless
  `--allow-no-delivery` is supplied; this prevents an apparently healthy
  storage-only process from being mistaken for active alerting.
- The worker records polling exceptions on `RouterMonitor.last_error` and does
  not advance the round cursor on a failed network read.

## Operator Commands

Show cursor, freshness, open-alert and delivery health:

```bash
python manage.py router_monitor_status --json
```

List open alerts, or include resolved alerts:

```bash
python manage.py router_alerts
python manage.py router_alerts --status all --json
```

Resolve an incident after operator review:

```bash
python manage.py resolve_router_alert <alert-id>
```

Retry failed or pending webhook deliveries without waiting for the next poll:

```bash
python manage.py retry_router_alerts --json
```

All commands accept `--monitor-id` where a monitor-specific operation is useful.
Resolution is explicit and does not delete the alert, snapshots or delivery
history.

## Verification

The durable poller, route selector parsing, retry behavior and signed webhook
delivery are covered by `engine/core/tests/test_monitoring.py`. The pure alert
policy remains covered by `router/tests/test_monitor_router.py`.

Production activation still requires database credentials, private endpoint
configuration, an alert receiver, on-call ownership and a canary observation
before unrestricted routing is treated as monitored.
