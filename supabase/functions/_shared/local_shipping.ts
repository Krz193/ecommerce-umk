export interface LocalRateTier {
  min_km: number;
  max_km: number;
  price: number;
}

export interface LocalStoreShippingConfig {
  latitude?: number | null;
  longitude?: number | null;
  local_ojek_enabled?: boolean | null;
  local_ojek_rates?: unknown;
  local_ekspedisi_enabled?: boolean | null;
  local_ekspedisi_rates?: unknown;
}

export interface PricingRateOption {
  courier_name: string;
  courier_code: string;
  courier_service_name: string;
  courier_service_code: string;
  service_type: string;
  price: number;
  shipment_duration_range: string;
  shipment_duration_unit: string;
  description: string;
}

export function isValidLatLng(lat: unknown, lng: unknown): lat is number {
  return (
    typeof lat === "number" &&
    typeof lng === "number" &&
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0)
  );
}

export function haversineDistanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

export function parseLocalRateTiers(raw: unknown): LocalRateTier[] {
  if (!Array.isArray(raw)) return [];

  const valid: LocalRateTier[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") continue;
    const rec = entry as Record<string, unknown>;
    const minKm = Number(rec.min_km ?? 0);
    const maxKm = Number(rec.max_km ?? 0);
    const price = Number(rec.price ?? -1);

    if (
      Number.isFinite(minKm) &&
      Number.isFinite(maxKm) &&
      Number.isFinite(price) &&
      minKm >= 0 &&
      maxKm > minKm &&
      price >= 0
    ) {
      valid.push({
        min_km: minKm,
        max_km: maxKm,
        price: Math.round(price),
      });
    }
  }

  valid.sort((a, b) => a.min_km - b.min_km || a.max_km - b.max_km);
  return valid;
}

export function findMatchingRateTier(
  tiers: LocalRateTier[],
  distanceKm: number,
): LocalRateTier | null {
  if (!Number.isFinite(distanceKm) || distanceKm < 0) return null;

  for (let i = 0; i < tiers.length; i++) {
    const tier = tiers[i];
    const matchesLower = i === 0 ? distanceKm >= tier.min_km : distanceKm > tier.min_km || distanceKm === tier.min_km;
    if (matchesLower && distanceKm <= tier.max_km) {
      return tier;
    }
  }

  return null;
}

export function resolveLocalStoreShippingOptions(
  store: LocalStoreShippingConfig | null | undefined,
  destLat: unknown,
  destLng: unknown,
): PricingRateOption[] {
  if (!store) return [];

  const originLat = store.latitude != null ? Number(store.latitude) : null;
  const originLng = store.longitude != null ? Number(store.longitude) : null;
  const targetLat = destLat != null ? Number(destLat) : null;
  const targetLng = destLng != null ? Number(destLng) : null;

  if (!isValidLatLng(originLat, originLng) || !isValidLatLng(targetLat, targetLng)) {
    return [];
  }

  const distanceKm = haversineDistanceKm(originLat!, originLng!, targetLat!, targetLng!);
  const formattedKm = distanceKm.toFixed(1);
  const options: PricingRateOption[] = [];

  if (store.local_ojek_enabled === true) {
    const ojekTiers = parseLocalRateTiers(store.local_ojek_rates);
    const matched = findMatchingRateTier(ojekTiers, distanceKm);
    if (matched) {
      options.push({
        courier_name: "Ojek Lokal Toko UMKM",
        courier_code: "ojek_lokal",
        courier_service_name: `Instan (${matched.min_km}-${matched.max_km} km)`,
        courier_service_code: "instant_lokal",
        service_type: "instant",
        price: matched.price,
        shipment_duration_range: "1 - 2",
        shipment_duration_unit: "hours",
        description: `Pengantaran langsung oleh ojek toko UMKM (~${formattedKm} km)`,
      });
    }
  }

  if (store.local_ekspedisi_enabled === true) {
    const ekspedisiTiers = parseLocalRateTiers(store.local_ekspedisi_rates);
    const matched = findMatchingRateTier(ekspedisiTiers, distanceKm);
    if (matched) {
      options.push({
        courier_name: "Ekspedisi Lokal Toko UMKM",
        courier_code: "ekspedisi_lokal",
        courier_service_name: `Reguler Lokal (${matched.min_km}-${matched.max_km} km)`,
        courier_service_code: "reg_lokal",
        service_type: "standard",
        price: matched.price,
        shipment_duration_range: "1 - 2",
        shipment_duration_unit: "days",
        description: `Pengiriman oleh armada ekspedisi toko UMKM (~${formattedKm} km)`,
      });
    }
  }

  return options;
}
