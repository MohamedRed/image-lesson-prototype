import fetch from "node-fetch";

export interface EtaResult {
  durationSeconds: number; // total duration
  distanceKm: number;
}

export async function etaCourierToRestaurantToCustomer(opts: {
  accessToken: string;
  courier: { lat: number; lng: number };
  restaurant: { lat: number; lng: number };
  customer: { lat: number; lng: number };
}): Promise<EtaResult> {
  const coords = [
    `${opts.courier.lng},${opts.courier.lat}`,
    `${opts.restaurant.lng},${opts.restaurant.lat}`,
    `${opts.customer.lng},${opts.customer.lat}`
  ].join(";");
  const sources = "sources=0"; // courier index
  const destinations = "destinations=1;2"; // restaurant, customer
  const url = `https://api.mapbox.com/directions-matrix/v1/mapbox/driving/${coords}?${sources}&${destinations}&annotations=duration,distance&access_token=${opts.accessToken}`;

  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Mapbox Matrix HTTP ${resp.status}`);
  const json: any = await resp.json();

  // durations: rows=sources, cols=destinations
  const durations = json.durations?.[0] as number[] | undefined;
  const distances = json.distances?.[0] as number[] | undefined;
  if (!durations || durations.length < 2) throw new Error("Matrix missing durations");

  const timeToPickup = durations[0];
  // For delivery leg, approximate with restaurant->customer using second query fallback
  // If distances are aligned the same, use distances[1]; otherwise fallback to timeToPickup
  const deliveryDuration = (await etaRestaurantToCustomer(opts)).durationSeconds;
  const total = Math.round(timeToPickup + deliveryDuration);
  const distanceKm = distances && distances.length > 1 ? (distances[1] / 1000) : 0;

  return { durationSeconds: total, distanceKm };
}

export async function etaRestaurantToCustomer(opts: {
  accessToken: string;
  restaurant: { lat: number; lng: number };
  customer: { lat: number; lng: number };
}): Promise<EtaResult> {
  const coords = [
    `${opts.restaurant.lng},${opts.restaurant.lat}`,
    `${opts.customer.lng},${opts.customer.lat}`
  ].join(";");
  const sources = "sources=0";
  const destinations = "destinations=1";
  const url = `https://api.mapbox.com/directions-matrix/v1/mapbox/driving/${coords}?${sources}&${destinations}&annotations=duration,distance&access_token=${opts.accessToken}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Mapbox Matrix HTTP ${resp.status}`);
  const json: any = await resp.json();
  const durations = json.durations?.[0] as number[] | undefined;
  const distances = json.distances?.[0] as number[] | undefined;
  const duration = durations?.[0] ?? 0;
  const distanceKm = distances?.[0] ? distances[0] / 1000 : 0;
  return { durationSeconds: Math.round(duration), distanceKm };
}


