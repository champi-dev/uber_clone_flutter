import 'dotenv/config';

function int(v: string | undefined, d: number) { return v ? parseInt(v, 10) : d; }
function float(v: string | undefined, d: number) { return v ? parseFloat(v) : d; }

export const env = {
  PORT: int(process.env.PORT, 3000),
  DATABASE_URL: process.env.DATABASE_URL ?? 'file:./dev.db',
  JWT_SECRET: process.env.JWT_SECRET ?? 'ridenow-dev-secret',
  JWT_ACCESS_EXPIRY: process.env.JWT_ACCESS_EXPIRY ?? '15m',
  JWT_REFRESH_EXPIRY: process.env.JWT_REFRESH_EXPIRY ?? '7d',
  SIMULATION_TICK_MS: int(process.env.SIMULATION_TICK_MS, 2000),
  SIMULATION_SPEED_KMH: float(process.env.SIMULATION_SPEED_KMH, 30),
  DRIVER_SEARCH_RADIUS_KM: float(process.env.DRIVER_SEARCH_RADIUS_KM, 5),
  RIDE_REQUEST_TIMEOUT_S: int(process.env.RIDE_REQUEST_TIMEOUT_S, 30),
  PLATFORM_COMMISSION: float(process.env.PLATFORM_COMMISSION, 0.2),
  DEFAULT_CURRENCY: process.env.DEFAULT_CURRENCY ?? 'COP',
  AUTO_ACCEPT_MIN_MS: int(process.env.AUTO_ACCEPT_MIN_MS, 3000),
  AUTO_ACCEPT_MAX_MS: int(process.env.AUTO_ACCEPT_MAX_MS, 8000),
};
