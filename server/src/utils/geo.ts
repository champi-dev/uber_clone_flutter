export function toRad(d: number) { return (d * Math.PI) / 180; }
export function toDeg(r: number) { return (r * 180) / Math.PI; }

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function bearingDeg(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const φ1 = toRad(lat1), φ2 = toRad(lat2);
  const Δλ = toRad(lng2 - lng1);
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

// Interpolate a straight-line route between two points into ~stepMeters steps.
export function interpolateRoute(
  lat1: number, lng1: number, lat2: number, lng2: number, stepMeters = 100,
): Array<{ lat: number; lng: number }> {
  const distKm = haversineKm(lat1, lng1, lat2, lng2);
  const steps = Math.max(2, Math.ceil((distKm * 1000) / stepMeters));
  const pts: Array<{ lat: number; lng: number }> = [];
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    pts.push({ lat: lat1 + (lat2 - lat1) * t, lng: lng1 + (lng2 - lng1) * t });
  }
  return pts;
}

// Simple polyline encoding: JSON stringify. Not google polyline format — rider app will parse JSON.
export function encodeRoute(pts: Array<{ lat: number; lng: number }>): string {
  return JSON.stringify(pts);
}
