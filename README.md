# RideNow (uber_clone_flutter)

Ride-hailing demo: Flutter rider app (`rider_app/`) + Node.js backend
(`server/`) with live driver simulation — since there is no driver app, the
server auto-accepts rides with the nearest seeded driver and advances them
through all states, emitting realtime updates over Socket.IO.

See `server/README.md` for full API docs. Deployment details below.

## Server deployment

The API is deployed as part of the champi docker-compose stack.

| | |
|---|---|
| Compose service / container | `ridenow-server` |
| Public base URL | `https://ridenow.champi.lat` |
| Local base URL | `http://127.0.0.1:8096` (API prefix `/api/v1`) |
| Stack | Express + TypeScript (tsx), Prisma, Socket.IO |
| Database | SQLite at `/data/ridenow.db`, persisted in the `ridenow_data` volume |
| Geospatial | Haversine in JS (no PostGIS needed) |

### Deploy / redeploy

```bash
cd ~/Development/champi
docker compose up -d --build ridenow-server
```

On boot the container runs `prisma db push` and seeds once per fresh volume
(a `/data/.seeded` marker prevents duplicate seeding on restarts).

### Environment (all have dev defaults, see `server/src/config/env.ts`)

`DATABASE_URL` (set in compose), `JWT_SECRET`, simulation tuning
(`SIMULATION_TICK_MS`, `SIMULATION_SPEED_KMH`, `DRIVER_SEARCH_RADIUS_KM`,
`AUTO_ACCEPT_MIN_MS/MAX_MS`), pricing (`PLATFORM_COMMISSION`,
`DEFAULT_CURRENCY` = COP). Seeded map area: Montería, Colombia.

### Demo accounts

| Email | Password | Role |
|---|---|---|
| rider@demo.com | demo1234 | rider |
| rider2@demo.com | demo1234 | rider |
| driver@demo.com | demo1234 | driver |
| admin@demo.com | admin1234 | admin |

### API surface (prefix `/api/v1`)

- `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `GET /auth/me`
- `POST /rides`, `GET /rides/:id`, `GET /rides/history`, `PATCH /rides/:id/cancel`, `POST /rides/:id/rate`
- `GET /fare/estimate`
- `GET|POST|PUT|DELETE /saved-places`
- `POST /promo/validate`
- `GET /notifications`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all`
- `GET /health` (no prefix)

Socket.IO on the same port emits ride lifecycle + driver location updates to
the rider (see `server/README.md` for the event list).

## Pointing the Flutter rider app at this server

`rider_app/lib/core/constants/api_config.dart` builds the base URL from a host
constant (auto-uses `10.0.2.2` on Android emulator). Change the port from
`3000` to `8096`:

```dart
static String get baseUrl => 'http://$_host:8096/api/v1';
```

For a physical device, use the machine's LAN IP (requires changing the compose
mapping from `127.0.0.1:8096:3000` to `8096:3000`) or add
`ridenow.champi.lat` to `~/.cloudflared/config.yml` → `http://localhost:8096`.
Note: Socket.IO must point at the same host/port.
