export type GeoCity = {
  country: string | null
  countryName: string | null
  region: string | null
  city: string | null
  lat: number | null
  lon: number | null
  timezone: string | null
  accuracyRadiusKm: number | null
}

export type GeoAsn = {
  asn: number | null
  org: string | null
}

export function normalizeCity(r: any): GeoCity | null {
  if (!r) return null

  const country = r.country?.iso_code ?? null
  const countryName = r.country?.names?.en ?? r.country?.names?.ko ?? null
  const region = r.subdivisions?.[0]?.names?.en ?? r.subdivisions?.[0]?.names?.ko ?? null
  const city = r.city?.names?.en ?? r.city?.names?.ko ?? null
  const loc = r.location ?? null

  return {
    country,
    countryName,
    region,
    city,
    lat: typeof loc?.latitude === 'number' ? loc.latitude : null,
    lon: typeof loc?.longitude === 'number' ? loc.longitude : null,
    timezone: typeof loc?.time_zone === 'string' ? loc.time_zone : null,
    accuracyRadiusKm: typeof loc?.accuracy_radius === 'number' ? loc.accuracy_radius : null,
  }
}

export function normalizeAsn(r: any): GeoAsn | null {
  if (!r) return null
  return {
    asn: r.autonomous_system_number ?? null,
    org: r.autonomous_system_organization ?? null,
  }
}
