// Thin wrapper around the public OSRM demo server. For production, self-host OSRM.
// Returns polyline as an array of {lat, lng} points along real roads.

const OSRM_BASE = process.env.OSRM_BASE ?? 'https://router.project-osrm.org';

export interface OsrmRoute {
  geometry: Array<{ lat: number; lng: number }>;
  distanceKm: number;
  durationSec: number;
}

export async function fetchRoute(
  from: { lat: number; lng: number },
  to: { lat: number; lng: number },
): Promise<OsrmRoute | null> {
  const url = `${OSRM_BASE}/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=full&geometries=geojson`;
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    const data: any = await res.json();
    if (data.code !== 'Ok' || !data.routes?.[0]) return null;
    const r = data.routes[0];
    const coords: number[][] = r.geometry.coordinates;
    return {
      geometry: coords.map(([lng, lat]) => ({ lat, lng })),
      distanceKm: (r.distance as number) / 1000,
      durationSec: r.duration as number,
    };
  } catch {
    return null;
  }
}

/// Resample a polyline to evenly-spaced points of ~stepMeters for smooth simulation.
export function resample(
  pts: Array<{ lat: number; lng: number }>,
  stepMeters = 40,
): Array<{ lat: number; lng: number }> {
  if (pts.length < 2) return pts;
  const out: Array<{ lat: number; lng: number }> = [pts[0]];
  let carry = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const dMeters = haversine(a.lat, a.lng, b.lat, b.lng) * 1000;
    if (dMeters < 0.001) continue;
    const need = stepMeters - carry;
    if (dMeters < need) { carry += dMeters; continue; }
    let placed = need;
    while (placed <= dMeters) {
      const t = placed / dMeters;
      out.push({ lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t });
      placed += stepMeters;
    }
    carry = dMeters - (placed - stepMeters);
  }
  out.push(pts[pts.length - 1]);
  return out;
}

function haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1), dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
