import axios from "axios";
import config from "../config";
import AppSettings from "../models/app-settings.model";

let cachedApiKey: string | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

const getGoogleMapsApiKey = async (): Promise<string> => {
  // Return cached key if still fresh
  if (cachedApiKey && Date.now() - cacheTimestamp < CACHE_TTL) {
    return cachedApiKey;
  }

  // Try DB first
  try {
    const setting = await AppSettings.findOne({ key: "google_maps_api_key" });
    if (setting?.value) {
      cachedApiKey = setting.value;
      cacheTimestamp = Date.now();
      return cachedApiKey;
    }
  } catch (e) {
    // DB not ready yet, fall through
  }

  // Fallback to env config
  cachedApiKey = config.google?.mapsApiKey || "";
  cacheTimestamp = Date.now();
  return cachedApiKey;
};

interface LatLng {
  lat: number;
  lng: number;
}

interface RouteInfo {
  distanceKm: number;
  durationMin: number;
  distanceText: string;
  durationText: string;
}

interface PlacePrediction {
  placeId: string;
  description: string;
  mainText: string;
  secondaryText: string;
}

interface PlaceDetails {
  placeId: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
}

const GOOGLE_MAPS_BASE_URL = "https://maps.googleapis.com/maps/api";
const NOMINATIM_BASE_URL = "https://nominatim.openstreetmap.org";
const OSRM_BASE_URL = "https://router.project-osrm.org";

const OSM_HEADERS = {
  "User-Agent": "KebuApp/1.0",
  Accept: "application/json",
};

/**
 * Get distance and duration between two points — uses OSRM (free) when no Google API key
 */
export const getDistanceAndDuration = async (
  origin: LatLng,
  destination: LatLng,
): Promise<RouteInfo> => {
  try {
    const apiKey = await getGoogleMapsApiKey();

    if (!apiKey) {
      return await getDistanceOSRM(origin, destination);
    }

    const response = await axios.get(
      `${GOOGLE_MAPS_BASE_URL}/distancematrix/json`,
      {
        params: {
          origins: `${origin.lat},${origin.lng}`,
          destinations: `${destination.lat},${destination.lng}`,
          mode: "driving",
          key: apiKey,
        },
      },
    );

    const element = response.data.rows[0]?.elements[0];

    if (element?.status !== "OK") {
      throw new Error("Unable to calculate route");
    }

    return {
      distanceKm: element.distance.value / 1000,
      durationMin: Math.ceil(element.duration.value / 60),
      distanceText: element.distance.text,
      durationText: element.duration.text,
    };
  } catch (error) {
    console.error("Maps API Error:", error);
    try {
      return await getDistanceOSRM(origin, destination);
    } catch {
      // Final fallback: Haversine
      const distanceKm = calculateHaversineDistance(origin, destination);
      const durationMin = Math.ceil(distanceKm * 3);
      return {
        distanceKm: Math.round(distanceKm * 100) / 100,
        durationMin,
        distanceText: `${distanceKm.toFixed(1)} km`,
        durationText: `${durationMin} mins`,
      };
    }
  }
};

/**
 * OSRM-based free distance/duration calculation
 */
const getDistanceOSRM = async (
  origin: LatLng,
  destination: LatLng,
): Promise<RouteInfo> => {
  const response = await axios.get(
    `${OSRM_BASE_URL}/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}`,
    {
      params: { overview: "false" },
    },
  );

  const route = response.data?.routes?.[0];
  if (!route) {
    throw new Error("OSRM: No route found");
  }

  const distanceKm = route.distance / 1000;
  const durationMin = Math.ceil(route.duration / 60);

  return {
    distanceKm: Math.round(distanceKm * 100) / 100,
    durationMin,
    distanceText: `${distanceKm.toFixed(1)} km`,
    durationText: `${durationMin} mins`,
  };
};

/**
 * Get directions between two points — uses OSRM (free) when no Google API key
 */
export const getDirections = async (
  origin: LatLng,
  destination: LatLng,
  waypoints?: LatLng[],
) => {
  try {
    const apiKey = await getGoogleMapsApiKey();

    if (!apiKey) {
      return await getDirectionsOSRM(origin, destination, waypoints);
    }

    const waypointsParam = waypoints
      ? waypoints.map((wp) => `${wp.lat},${wp.lng}`).join("|")
      : undefined;

    const response = await axios.get(
      `${GOOGLE_MAPS_BASE_URL}/directions/json`,
      {
        params: {
          origin: `${origin.lat},${origin.lng}`,
          destination: `${destination.lat},${destination.lng}`,
          waypoints: waypointsParam,
          mode: "driving",
          // Ask Google for multiple route options so we can pick the shortest
          // by distance. (Ignored when waypoints are present.)
          alternatives: waypointsParam ? undefined : true,
          key: apiKey,
        },
      },
    );

    if (response.data.status !== "OK") {
      throw new Error("Unable to get directions");
    }

    // Pick the route with the shortest total driving distance, rather than
    // Google's default "best" (fastest) route.
    const routes = response.data.routes as any[];
    const routeDistanceMeters = (r: any) =>
      r.legs.reduce((sum: number, leg: any) => sum + leg.distance.value, 0);
    const route = routes.reduce(
      (shortest, r) =>
        routeDistanceMeters(r) < routeDistanceMeters(shortest) ? r : shortest,
      routes[0],
    );

    return {
      polyline: route.overview_polyline.points,
      legs: route.legs.map((leg: any) => ({
        distanceKm: leg.distance.value / 1000,
        durationMin: Math.ceil(leg.duration.value / 60),
        startAddress: leg.start_address,
        endAddress: leg.end_address,
        steps: leg.steps.map((step: any) => ({
          instruction: step.html_instructions,
          maneuver: step.maneuver || "",
          distanceKm: step.distance.value / 1000,
          durationMin: Math.ceil(step.duration.value / 60),
          startLocation: step.start_location,
          endLocation: step.end_location,
        })),
      })),
      totalDistanceKm: route.legs.reduce(
        (sum: number, leg: any) => sum + leg.distance.value / 1000,
        0,
      ),
      totalDurationMin: route.legs.reduce(
        (sum: number, leg: any) => sum + Math.ceil(leg.duration.value / 60),
        0,
      ),
    };
  } catch (error) {
    console.error("Directions API Error:", error);
    try {
      return await getDirectionsOSRM(origin, destination, waypoints);
    } catch {
      return null;
    }
  }
};

/**
 * OSRM-based free directions
 */
const getDirectionsOSRM = async (
  origin: LatLng,
  destination: LatLng,
  waypoints?: LatLng[],
) => {
  // Build coordinates string: origin;waypoints;destination
  let coords = `${origin.lng},${origin.lat}`;
  if (waypoints?.length) {
    coords += ";" + waypoints.map((wp) => `${wp.lng},${wp.lat}`).join(";");
  }
  coords += `;${destination.lng},${destination.lat}`;

  const response = await axios.get(
    `${OSRM_BASE_URL}/route/v1/driving/${coords}`,
    {
      params: {
        overview: "full",
        geometries: "polyline",
        steps: "true",
        // Request alternates so we can choose the shortest-distance route.
        alternatives: "true",
      },
    },
  );

  const routes = response.data?.routes as any[] | undefined;
  if (!routes?.length) return null;
  // Choose the shortest route by distance (OSRM's first route is fastest).
  const route = routes.reduce(
    (shortest, r) => (r.distance < shortest.distance ? r : shortest),
    routes[0],
  );

  return {
    polyline: route.geometry,
    legs: route.legs.map((leg: any) => ({
      distanceKm: leg.distance / 1000,
      durationMin: Math.ceil(leg.duration / 60),
      startAddress: "",
      endAddress: "",
      steps: (leg.steps || []).map((step: any) => {
        const modifier = step.maneuver?.modifier || "";
        const type = step.maneuver?.type || "";
        // OSRM has no human text; synthesise a basic one from type+modifier.
        const synthesised = [type, modifier, step.name ? `onto ${step.name}` : ""]
          .filter(Boolean)
          .join(" ");
        return {
          instruction: step.maneuver?.instruction || synthesised,
          maneuver: modifier || type,
          distanceKm: step.distance / 1000,
          durationMin: Math.ceil(step.duration / 60),
          startLocation: {
            lat: step.maneuver?.location?.[1] || 0,
            lng: step.maneuver?.location?.[0] || 0,
          },
          endLocation: {
            lat: step.maneuver?.location?.[1] || 0,
            lng: step.maneuver?.location?.[0] || 0,
          },
        };
      }),
    })),
    totalDistanceKm: route.distance / 1000,
    totalDurationMin: Math.ceil(route.duration / 60),
  };
};

/**
 * Search places (autocomplete) — uses Nominatim (free) when no Google API key
 */
export const searchPlaces = async (
  query: string,
  location?: LatLng,
): Promise<PlacePrediction[]> => {
  try {
    const apiKey = await getGoogleMapsApiKey();

    if (!apiKey) {
      // Free: Nominatim search
      return await searchPlacesNominatim(query, location);
    }

    const params: any = {
      input: query,
      key: apiKey,
      components: "country:in", // Restrict to India
    };

    if (location) {
      params.location = `${location.lat},${location.lng}`;
      params.radius = 50000; // 50km radius
    }

    const response = await axios.get(
      `${GOOGLE_MAPS_BASE_URL}/place/autocomplete/json`,
      { params },
    );

    if (
      response.data.status !== "OK" &&
      response.data.status !== "ZERO_RESULTS"
    ) {
      throw new Error("Places API error");
    }

    return (response.data.predictions || []).map((prediction: any) => ({
      placeId: prediction.place_id,
      description: prediction.description,
      mainText: prediction.structured_formatting.main_text,
      secondaryText: prediction.structured_formatting.secondary_text,
    }));
  } catch (error) {
    console.error("Places Autocomplete Error:", error);
    // Fallback to Nominatim on Google error
    try {
      return await searchPlacesNominatim(query, location);
    } catch {
      return [];
    }
  }
};

/**
 * Nominatim-based free place search
 */
const searchPlacesNominatim = async (
  query: string,
  location?: LatLng,
): Promise<PlacePrediction[]> => {
  const params: any = {
    q: query,
    format: "json",
    addressdetails: 1,
    limit: 8,
    countrycodes: "in",
  };

  if (location) {
    params.viewbox = `${location.lng - 0.5},${location.lat + 0.5},${location.lng + 0.5},${location.lat - 0.5}`;
    params.bounded = 0;
  }

  const response = await axios.get(`${NOMINATIM_BASE_URL}/search`, {
    params,
    headers: OSM_HEADERS,
  });

  return (response.data || []).map((place: any) => {
    const parts = (place.display_name || "").split(", ");
    return {
      placeId: `nominatim_${place.osm_type}_${place.osm_id}`,
      description: place.display_name || "",
      mainText: parts[0] || "",
      secondaryText: parts.slice(1).join(", "),
    };
  });
};

/**
 * Get place details by place ID — uses Nominatim (free) when no Google API key
 */
export const getPlaceDetails = async (
  placeId: string,
): Promise<PlaceDetails | null> => {
  try {
    // Handle Nominatim IDs (format: nominatim_{osmType}_{osmId})
    if (placeId.startsWith("nominatim_")) {
      return await getPlaceDetailsNominatim(placeId);
    }

    const apiKey = await getGoogleMapsApiKey();

    if (!apiKey) {
      return await getPlaceDetailsNominatim(placeId);
    }

    const response = await axios.get(
      `${GOOGLE_MAPS_BASE_URL}/place/details/json`,
      {
        params: {
          place_id: placeId,
          fields: "name,formatted_address,geometry",
          key: apiKey,
        },
      },
    );

    if (response.data.status !== "OK") {
      throw new Error("Place details API error");
    }

    const result = response.data.result;

    return {
      placeId,
      name: result.name,
      address: result.formatted_address,
      lat: result.geometry.location.lat,
      lng: result.geometry.location.lng,
    };
  } catch (error) {
    console.error("Place Details Error:", error);
    return null;
  }
};

/**
 * Nominatim-based free place details lookup
 */
const getPlaceDetailsNominatim = async (
  placeId: string,
): Promise<PlaceDetails | null> => {
  try {
    // Parse nominatim_{osmType}_{osmId}
    const parts = placeId.replace("nominatim_", "").split("_");
    const osmType = parts[0]; // node, way, relation
    const osmId = parts[1];

    if (!osmType || !osmId) return null;

    const osmTypeLetter =
      osmType === "node" ? "N" : osmType === "way" ? "W" : "R";

    const response = await axios.get(`${NOMINATIM_BASE_URL}/lookup`, {
      params: {
        osm_ids: `${osmTypeLetter}${osmId}`,
        format: "json",
        addressdetails: 1,
      },
      headers: OSM_HEADERS,
    });

    const place = response.data?.[0];
    if (!place) return null;

    return {
      placeId,
      name: place.name || place.display_name?.split(",")[0] || "",
      address: place.display_name || "",
      lat: parseFloat(place.lat),
      lng: parseFloat(place.lon),
    };
  } catch (error) {
    console.error("Nominatim Lookup Error:", error);
    return null;
  }
};

/**
 * Reverse geocode (coordinates to address) — uses Nominatim (free) when no Google API key
 */
export const reverseGeocode = async (
  lat: number,
  lng: number,
): Promise<any> => {
  try {
    const apiKey = await getGoogleMapsApiKey();

    if (!apiKey) {
      return await reverseGeocodeNominatim(lat, lng);
    }

    const response = await axios.get(`${GOOGLE_MAPS_BASE_URL}/geocode/json`, {
      params: {
        latlng: `${lat},${lng}`,
        key: apiKey,
      },
    });

    if (response.data.status !== "OK") {
      return await reverseGeocodeNominatim(lat, lng);
    }

    return parseGoogleGeocodeResult(response.data.results);
  } catch (error) {
    console.error("Reverse Geocode Error:", error);
    try {
      return await reverseGeocodeNominatim(lat, lng);
    } catch {
      return null;
    }
  }
};

/**
 * Parse Google Geocoding API results into the shape consumed by maps.controller
 * (display_name, houseNo, area, city, state, country, pinCode).
 *
 * Google returns multiple `results`, each with `address_components` tagged by
 * `types`. The most reliable city signal is `locality`; we fall back through
 * smaller-grain types so dense urban (sublocality) and rural (administrative
 * boundary) addresses both produce a usable city name.
 */
const parseGoogleGeocodeResult = (results: any[]): any => {
  const primary = results?.[0];
  if (!primary) return null;

  // Aggregate components across all results so a missing locality on the
  // primary result can still be filled from a broader-typed result.
  const components: any[] = [];
  for (const r of results) {
    if (Array.isArray(r?.address_components)) {
      components.push(...r.address_components);
    }
  }

  const findByType = (...types: string[]): string => {
    for (const type of types) {
      const c = components.find((c) => c.types?.includes(type));
      if (c?.long_name) return c.long_name;
    }
    return "";
  };

  const streetNumber = findByType("street_number");
  const route = findByType("route");
  const houseNo = [streetNumber, route].filter(Boolean).join(" ");

  return {
    display_name: primary.formatted_address || "",
    houseNo,
    area: findByType(
      "sublocality_level_1",
      "sublocality",
      "neighborhood",
      "premise",
      "route",
    ),
    city: findByType(
      "locality",
      "postal_town",
      "administrative_area_level_3",
      "administrative_area_level_2",
    ),
    state: findByType("administrative_area_level_1"),
    country: findByType("country"),
    pinCode: findByType("postal_code"),
  };
};

/**
 * Nominatim-based free reverse geocoding
 */
const reverseGeocodeNominatim = async (
  lat: number,
  lng: number,
): Promise<any> => {
  const response = await axios.get(`${NOMINATIM_BASE_URL}/reverse`, {
    params: {
      lat,
      lon: lng,
      format: "json",
      addressdetails: 1,
    },
    headers: OSM_HEADERS,
  });

  const data = response.data;
  const addr = data?.address || {};
  const displayName = data?.display_name || '';
  const firstSegment = displayName
    ? displayName
        .split(',')
        .map((part: string) => part.trim())
        .find((part: string) => part.length > 0) || ''
    : '';

  return {
    display_name: displayName || null,
    houseNo:
      addr.house_number ||
      addr.building ||
      addr.shop ||
      addr.office ||
      addr.amenity ||
      firstSegment,
    area: addr.suburb || addr.neighbourhood || addr.road || '',
    city: addr.city || addr.town || addr.village || addr.county || '',
    state: addr.state || '',
    country: addr.country || '',
    pinCode: addr.postcode || '',
  };
};

/**
 * Calculate Haversine distance (fallback when API is not available)
 */
const calculateHaversineDistance = (
  origin: LatLng,
  destination: LatLng,
): number => {
  const R = 6371; // Earth's radius in km

  const dLat = toRad(destination.lat - origin.lat);
  const dLng = toRad(destination.lng - origin.lng);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(origin.lat)) *
      Math.cos(toRad(destination.lat)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
};

const toRad = (deg: number): number => {
  return deg * (Math.PI / 180);
};
