import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";

/**
 * Calculate haversine distance between two points in kilometers
 */
export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Convert degrees to radians
 */
function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Check if location changed significantly (>50m)
 */
export function hasLocationChangedSignificantly(loc1: GeoPoint, loc2: GeoPoint): boolean {
  const distance = haversineKm(loc1.latitude, loc1.longitude, loc2.latitude, loc2.longitude) * 1000;
  return distance > 50; // 50 meters threshold
}

/**
 * Creates a GeoJSON polygon buffer around a point
 */
export function createBufferPolygon(lat: number, lng: number, radiusMeters: number): any {
  const points = 32; // Number of points to approximate circle
  const coordinates: number[][] = [];
  
  for (let i = 0; i < points; i++) {
    const angle = (i / points) * 2 * Math.PI;
    const deltaLat = (radiusMeters / 111320) * Math.cos(angle);
    const deltaLng = (radiusMeters / (111320 * Math.cos(lat * Math.PI / 180))) * Math.sin(angle);
    
    coordinates.push([lng + deltaLng, lat + deltaLat]);
  }
  
  // Close the polygon
  coordinates.push(coordinates[0]);
  
  return {
    type: "Polygon",
    coordinates: [coordinates]
  };
}

/**
 * Generate route polyline using Mapbox Directions API
 * In MVP, returns a simple straight line encoded polyline
 */
export async function generateRoutePolyline(origin: GeoPoint, destination: GeoPoint): Promise<string> {
  // In production, call Mapbox Directions API
  // For MVP, encode a simple straight line
  const coords = [
    [origin.longitude, origin.latitude],
    [destination.longitude, destination.latitude]
  ];
  
  return encodePolyline(coords);
}

/**
 * Check if driver is on a legal curb using curbSegments collection
 */
export async function checkIfOnCurb(location: GeoPoint, db: admin.firestore.Firestore = admin.firestore()): Promise<boolean> {
  // Query nearby curb segments (within 20m)
  const nearbySegments = await db.collection("curbSegments")
    .where("allowedUses", "array-contains", "passenger-pickup")
    .limit(10)
    .get();
  
  for (const doc of nearbySegments.docs) {
    const segment = doc.data();
    if (segment.geometry && isPointNearSegment(location, segment.geometry, 20)) {
      return true;
    }
  }
  
  return false;
}

/**
 * Check if a point is within distance of a line segment
 */
function isPointNearSegment(point: GeoPoint, geometry: any, maxDistanceMeters: number): boolean {
  // Simplified check - in production use proper GIS library
  if (!geometry.coordinates || geometry.type !== "LineString") return false;
  
  const coords = geometry.coordinates;
  for (let i = 0; i < coords.length - 1; i++) {
    const distance = pointToLineDistance(
      point.latitude, point.longitude,
      coords[i][1], coords[i][0],
      coords[i + 1][1], coords[i + 1][0]
    );
    
    if (distance <= maxDistanceMeters) return true;
  }
  
  return false;
}

/**
 * Calculate distance from point to line segment
 */
function pointToLineDistance(
  pointLat: number, pointLng: number,
  line1Lat: number, line1Lng: number,
  line2Lat: number, line2Lng: number
): number {
  // Simplified calculation - in production use proper algorithm
  const d1 = haversineKm(pointLat, pointLng, line1Lat, line1Lng) * 1000;
  const d2 = haversineKm(pointLat, pointLng, line2Lat, line2Lng) * 1000;
  return Math.min(d1, d2);
}

/**
 * Encode coordinates to polyline string (Google Polyline Algorithm)
 */
export function encodePolyline(coordinates: number[][]): string {
  let encoded = "";
  let prevLat = 0;
  let prevLng = 0;
  
  for (const [lng, lat] of coordinates) {
    const latE5 = Math.round(lat * 1e5);
    const lngE5 = Math.round(lng * 1e5);
    
    encoded += encodeNumber(latE5 - prevLat);
    encoded += encodeNumber(lngE5 - prevLng);
    
    prevLat = latE5;
    prevLng = lngE5;
  }
  
  return encoded;
}

/**
 * Encode a single number for polyline
 */
function encodeNumber(num: number): string {
  let encoded = "";
  num = num < 0 ? ~(num << 1) : (num << 1);
  
  while (num >= 0x20) {
    encoded += String.fromCharCode((0x20 | (num & 0x1f)) + 63);
    num >>= 5;
  }
  
  encoded += String.fromCharCode(num + 63);
  return encoded;
}

/**
 * Create isochrone polygon (area reachable within time/distance)
 * In production, this would call Mapbox Isochrone API
 */
export function createIsochrone(lat: number, lng: number, radiusMeters: number, mode: "walk" | "drive"): any {
  // Simplified isochrone - in production use Mapbox Isochrone API
  const factor = mode === "walk" ? 1.2 : 1.5; // Irregular shape factor
  const points = 16;
  const coordinates: number[][] = [];
  
  for (let i = 0; i < points; i++) {
    const angle = (i / points) * 2 * Math.PI;
    const variation = 0.8 + Math.random() * 0.4; // Add some randomness
    const effectiveRadius = radiusMeters * factor * variation;
    
    const deltaLat = (effectiveRadius / 111320) * Math.cos(angle);
    const deltaLng = (effectiveRadius / (111320 * Math.cos(lat * Math.PI / 180))) * Math.sin(angle);
    
    coordinates.push([lng + deltaLng, lat + deltaLat]);
  }
  
  coordinates.push(coordinates[0]);
  
  return {
    type: "Polygon",
    coordinates: [coordinates]
  };
}

/**
 * Encode geohash for spatial indexing
 */
export function encodeGeohash(lat: number, lng: number, precision: number = 6): string {
  const base32 = "0123456789bcdefghjkmnpqrstuvwxyz";
  let idx = 0;
  let bit = 0;
  let evenBit = true;
  let geohash = "";
  
  let latMin = -90.0, latMax = 90.0;
  let lngMin = -180.0, lngMax = 180.0;
  
  while (geohash.length < precision) {
    if (evenBit) {
      const mid = (lngMin + lngMax) / 2;
      if (lng > mid) {
        idx |= (1 << (4 - bit));
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat > mid) {
        idx |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    
    evenBit = !evenBit;
    
    if (bit < 4) {
      bit++;
    } else {
      geohash += base32[idx];
      bit = 0;
      idx = 0;
    }
  }
  
  return geohash;
}

/**
 * Check if a point is inside a polygon (GeoJSON)
 */
export function isPointInPolygon(point: GeoPoint, polygon: any): boolean {
  if (!polygon.coordinates || polygon.type !== "Polygon") return false;
  
  const coords = polygon.coordinates[0]; // Outer ring
  const x = point.longitude;
  const y = point.latitude;
  
  let inside = false;
  for (let i = 0, j = coords.length - 1; i < coords.length; j = i++) {
    const xi = coords[i][0], yi = coords[i][1];
    const xj = coords[j][0], yj = coords[j][1];
    
    const intersect = ((yi > y) !== (yj > y)) &&
      (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    
    if (intersect) inside = !inside;
  }
  
  return inside;
}