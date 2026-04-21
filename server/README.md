# RideNow Server

Node.js + Express + Socket.IO + Prisma (SQLite) backend for the RideNow rider demo.

Uses SQLite instead of PostgreSQL+PostGIS (per spec) for zero-setup local demo. Geospatial queries done via Haversine in JS.

Since there is no driver app in this demo, the simulation engine **auto-accepts** ride requests on behalf of the nearest seeded driver and advances the ride through all states automatically.

## Setup

```bash
cd server
npm install
npx prisma migrate dev --name init
npm run seed
npm run dev
```

Server runs on `http://localhost:3000`. Health check: `GET /health`.

## Demo accounts

| Email | Password | Role |
|---|---|---|
| rider@demo.com | demo1234 | rider |
| rider2@demo.com | demo1234 | rider |
| driver@demo.com | demo1234 | driver |
| admin@demo.com | admin1234 | admin |

## API surface (rider-relevant)

- `POST /api/v1/auth/register`, `/login`, `/refresh`, `/logout`, `GET /me`
- `POST /api/v1/rides`, `GET /rides/:id`, `GET /rides/history`, `PATCH /rides/:id/cancel`, `POST /rides/:id/rate`
- `GET /api/v1/fare/estimate`
- `GET/POST/PUT/DELETE /api/v1/saved-places`
- `POST /api/v1/promo/validate`
- `GET /api/v1/notifications`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all`

## Socket.IO events (server → rider)

- `ride:accepted`, `ride:driver_arriving`, `ride:driver_arrived`
- `ride:started`, `ride:location_tick`, `ride:completed`
- `ride:cancelled`, `ride:no_drivers`, `notification:new`

Rider joins `rider:{userId}` on connect. Join `ride:{rideId}` via `socket.emit('ride:join', rideId)` after creating a ride.

## Env

See `.env.example`. Key tunables: `SIMULATION_TICK_MS`, `AUTO_ACCEPT_MIN_MS`/`MAX_MS`, `RIDE_REQUEST_TIMEOUT_S`.
