import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import Delivery from "../models/delivery.model";
import * as DeliveryService from "../services/delivery.service";
import * as DriverService from "../services/driver.service";
import * as DriverLocationService from "../services/driver-location.service";
import * as CommissionService from "../services/commission.service";

/**
 * Driver-facing PARCEL delivery endpoints.
 *
 * The customer side (create delivery + nearby-driver socket dispatch) already
 * exists in delivery.controller.ts. These endpoints give the parcel partner
 * app the other half: a backend-driven home dashboard, the list of available
 * requests, and accept/reject — mirroring the cab acceptRide flow.
 */

const AVAILABLE_RADIUS_KM = 15;

/** Human label for a delivery type when no package description is given. */
function prettyDeliveryType(type?: string): string {
  switch (type) {
    case "DOCUMENT":
      return "Document";
    case "PARCEL":
      return "Parcel";
    case "FOOD":
      return "Food";
    case "GROCERY":
      return "Grocery";
    default:
      return "Delivery";
  }
}

/** Haversine distance in km between two lat/lng points. */
function distanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Map a Delivery document to the compact "job card" shape the app renders. */
function toJobCard(d: any, driverLat?: number, driverLng?: number) {
  const firstDrop = Array.isArray(d.drops) && d.drops.length ? d.drops[0] : null;
  const distFromDriver =
    driverLat != null && driverLng != null && d.pickup
      ? Math.round(
          distanceKm(driverLat, driverLng, d.pickup.lat, d.pickup.lng) * 10,
        ) / 10
      : null;
  return {
    deliveryId: d._id,
    deliveryType: d.deliveryType,
    category: d.packageDescription || prettyDeliveryType(d.deliveryType),
    recipientName: firstDrop?.contactName || "",
    dropAddress: firstDrop?.address || "",
    pickupAddress: d.pickup?.address || "",
    dropCount: Array.isArray(d.drops) ? d.drops.length : 0,
    fare: d.finalFare,
    totalDistanceKm: d.totalDistanceKm,
    distanceFromDriverKm: distFromDriver,
    createdAt: d.createdAt,
  };
}

/**
 * Fetch the SEARCHING (unassigned) deliveries available to this driver,
 * nearest first when the driver's location is known.
 */
async function fetchAvailableJobs(driverId: string, limit = 30) {
  const location = await DriverLocationService.getDriverLocation(
    new Types.ObjectId(driverId),
  );

  const deliveries = await Delivery.find({
    status: "SEARCHING",
    driverId: null,
  })
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();

  const driverLat = location?.latitude;
  const driverLng = location?.longitude;

  let jobs = deliveries.map((d) => toJobCard(d, driverLat, driverLng));

  // When we know where the driver is, only surface nearby jobs (nearest first).
  if (driverLat != null && driverLng != null) {
    jobs = jobs
      .filter(
        (j) =>
          j.distanceFromDriverKm == null ||
          j.distanceFromDriverKm <= AVAILABLE_RADIUS_KM,
      )
      .sort(
        (a, b) =>
          (a.distanceFromDriverKm ?? 1e9) - (b.distanceFromDriverKm ?? 1e9),
      );
  }

  return jobs.slice(0, limit);
}

/** Title-case a payment method enum for display. */
function paymentLabel(method?: string): string {
  switch (method) {
    case "CASH":
      return "Cash";
    case "WALLET":
      return "Wallet";
    case "CARD":
      return "Card";
    case "UPI":
      return "UPI";
    default:
      return method || "";
  }
}

/**
 * GET /driver/app/delivery/:deliveryId/detail
 * Full backend-driven payload for the parcel "Delivery details" screen.
 */
export const getDeliveryDetail = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => getDeliveryDetail");

  const { deliveryId } = req.params;

  const delivery: any = await DeliveryService.getDeliveryById(deliveryId);
  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  // Sender (customer) summary — name, lifetime deliveries and rating.
  const sender = delivery.userId || {};
  const senderName = sender.fullName || "";
  const senderId = sender._id || delivery.userId;
  const senderDeliveries = senderId
    ? await DeliveryService.countDeliveries({ userId: senderId })
    : 0;
  const senderInitials =
    senderName
      .split(" ")
      .map((p: string) => p.charAt(0))
      .filter(Boolean)
      .slice(0, 2)
      .join("")
      .toUpperCase() || "";

  const firstDrop =
    Array.isArray(delivery.drops) && delivery.drops.length
      ? delivery.drops[0]
      : null;
  const vt = delivery.vehicleTypeId || {};

  // Backend-driven fare breakdown for the "Fare Calculations" modal, built from
  // the delivery's stored amounts. Items are the additive fees; adjustments
  // (discounts / rounding) are signed.
  const round2 = (n: number) => Math.round((n || 0) * 100) / 100;
  const baseFee = round2(delivery.fare);
  const surge = round2(delivery.surgeFare);
  const items: { label: string; amount: number }[] = [
    { label: "Delivery Fee", amount: baseFee },
  ];
  if (surge > 0) items.push({ label: "Surge Fee", amount: surge });
  const subTotal = round2((delivery.fare || 0) + (delivery.surgeFare || 0));
  const adjustments: { label: string; amount: number }[] = [];
  const discountAmt = round2(
    (delivery.discount || 0) + (delivery.subscriptionDiscount || 0),
  );
  if (discountAmt > 0) {
    adjustments.push({ label: "Discount", amount: -discountAmt });
  }
  const grandTotal = round2(delivery.finalFare);
  const rounding = round2(grandTotal - (subTotal - discountAmt));
  if (Math.abs(rounding) >= 0.01) {
    adjustments.push({ label: "Rounding Up", amount: rounding });
  }
  const fareBreakdown = { items, subTotal, adjustments, grandTotal };

  // Trip info for the History → details screen, with the partner's earned money
  // (final fare minus delivery commission).
  let earnedMoney = round2(delivery.finalFare);
  try {
    const config = await CommissionService.findMatchingConfig("delivery");
    if (config) {
      const commission = CommissionService.calculateCommission(
        delivery.finalFare,
        config,
      );
      earnedMoney = round2(delivery.finalFare - commission);
    }
  } catch (err) {
    console.error("earned money calc failed:", err);
  }

  const tripInfo = {
    refId: `#${String(delivery._id).slice(-8).toUpperCase()}`,
    startedLabel: dateTimeLabel(delivery.pickedUpAt || delivery.createdAt),
    endedLabel: dateTimeLabel(delivery.deliveredAt),
    pickupAddress: delivery.pickup?.address || "",
    dropAddress: firstDrop?.address || "",
    tripType: delivery.packageDescription || prettyDeliveryType(delivery.deliveryType),
    tripDistanceKm: round2(delivery.totalDistanceKm),
    tripDurationLabel: durationLabel(delivery.totalDurationMin),
    vehicleTypeName: vt.name || "",
    estimatedTotalFare: round2(delivery.finalFare),
    earnedMoney,
  };

  req.rData = {
    delivery: {
      deliveryId: delivery._id,
      status: delivery.status,
      canAcceptReject: delivery.status === "SEARCHING" && !delivery.driverId,
      sender: {
        name: senderName,
        initials: senderInitials,
        image: sender.profileImage || "",
        deliveriesCount: senderDeliveries,
        rating: sender.rating || 0,
      },
      vehicleType: {
        name: vt.name || "",
        image: vt.image || "",
      },
      pickupLocation: {
        address: delivery.pickup?.address || "",
        lat: delivery.pickup?.lat,
        lng: delivery.pickup?.lng,
        contactName: delivery.pickup?.contactName || "",
        contactPhone: delivery.pickup?.contactPhone || "",
      },
      deliveryLocation: firstDrop
        ? {
            address: firstDrop.address || "",
            lat: firstDrop.lat,
            lng: firstDrop.lng,
          }
        : null,
      drops: delivery.drops || [],
      whatYouAreSending:
        delivery.packageDescription || prettyDeliveryType(delivery.deliveryType),
      recipientName: firstDrop?.contactName || "",
      recipientContact: firstDrop?.contactPhone || "",
      paymentMethod: delivery.paymentMethod || "",
      paymentLabel: paymentLabel(delivery.paymentMethod),
      fee: delivery.finalFare,
      fareBreakdown,
      tripInfo,
      // The model has no package/pickup photos yet; surface an empty list so the
      // screen can hide the section. Wire real images here once captured.
      pickupImages: [],
    },
  };
  req.msg = "success";
  next();
};

/** Format a duration in minutes as "Xh Ymin" / "Ymin". */
function durationLabel(min?: number): string {
  const m = Math.max(0, Math.round(min || 0));
  if (m < 60) return `${m}min`;
  const h = Math.floor(m / 60);
  const rem = m % 60;
  return rem > 0 ? `${h}h ${rem}min` : `${h}h`;
}

const MONTHS = [
  "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
  "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
];

const MONTHS_TITLE = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/** "01 Jan 2024, 11:47 AM" */
function dateTimeLabel(d?: Date | string | null): string {
  if (!d) return "";
  const dt = new Date(d);
  const p = (n: number) => n.toString().padStart(2, "0");
  let h = dt.getHours();
  const ampm = h >= 12 ? "PM" : "AM";
  h = h % 12;
  if (h === 0) h = 12;
  return `${p(dt.getDate())} ${MONTHS_TITLE[dt.getMonth()]} ${dt.getFullYear()}, ${h}:${p(dt.getMinutes())} ${ampm}`;
}

/** Section header label for a date relative to today. */
function dateSectionLabel(d: Date, today: Date): string {
  const startOf = (x: Date) =>
    new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const diffDays = Math.round((startOf(today) - startOf(d)) / 86400000);
  if (diffDays === 0) return "TODAY";
  if (diffDays === 1) return "YESTERDAY";
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

/** dd/MM/yyyy */
function ddmmyyyy(d: Date): string {
  const p = (n: number) => n.toString().padStart(2, "0");
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
}

/**
 * GET /driver/app/delivery/history
 * The partner's past deliveries, grouped into date sections (TODAY / YESTERDAY
 * / "DD MMM YYYY") for the History screen.
 */
export const getDeliveryHistory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => getDeliveryHistory");

  const driverId = (req as any).driverId;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 30;

  // History = finished deliveries only. An accepted/active delivery
  // (ASSIGNED / PICKED_UP / IN_TRANSIT) must NOT appear here — it only shows
  // up once it's DELIVERED (or CANCELLED).
  const deliveries = await Delivery.find({
    driverId: new Types.ObjectId(driverId),
    status: { $in: ["DELIVERED", "CANCELLED"] },
  })
    .populate("userId", "fullName")
    .populate("vehicleTypeId")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit)
    .lean();

  const today = new Date();
  const sections: { label: string; items: any[] }[] = [];
  const indexByLabel: Record<string, number> = {};

  for (const d of deliveries as any[]) {
    const created = new Date(d.createdAt || Date.now());
    const label = dateSectionLabel(created, today);
    const firstDrop =
      Array.isArray(d.drops) && d.drops.length ? d.drops[0] : null;

    const item = {
      deliveryId: d._id,
      refId: `#${String(d._id).slice(-8).toUpperCase()}`,
      customerName: (d.userId && d.userId.fullName) || "Customer",
      date: ddmmyyyy(created),
      pickupAddress: d.pickup?.address || "",
      dropAddress: firstDrop?.address || "",
      typeLabel: d.packageDescription || prettyDeliveryType(d.deliveryType),
      distanceKm: Math.round((d.totalDistanceKm || 0) * 100) / 100,
      durationLabel: durationLabel(d.totalDurationMin),
      fare: d.finalFare,
      status: d.status,
      paid: d.paymentStatus === "PAID",
    };

    if (indexByLabel[label] === undefined) {
      indexByLabel[label] = sections.length;
      sections.push({ label, items: [item] });
    } else {
      sections[indexByLabel[label]].items.push(item);
    }
  }

  req.rData = { sections };
  req.msg = "success";
  next();
};

/**
 * GET /driver/app/delivery/dashboard
 * Backend-driven payload for the parcel partner home screen.
 */
export const getDeliveryDashboard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => getDeliveryDashboard");

  const driverId = (req as any).driverId;

  const driver = await DriverService.getDriverById(driverId);
  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Available balance = lifetime earnings from completed deliveries.
  const delivered = await Delivery.find({
    driverId: new Types.ObjectId(driverId),
    status: "DELIVERED",
  })
    .select("finalFare")
    .lean();
  const availableBalance = delivered.reduce(
    (sum, d: any) => sum + (d.finalFare || 0),
    0,
  );

  const newJobs = await fetchAvailableJobs(driverId, 10);

  const name = driver.fullName || "";
  const initials =
    name
      .split(" ")
      .map((p: string) => p.charAt(0))
      .filter(Boolean)
      .slice(0, 2)
      .join("")
      .toUpperCase() || "";

  req.rData = {
    partner: {
      _id: driver._id,
      name,
      initials,
      profileImage: (driver as any).profileImage || "",
      rating: driver.rating || 0,
      isOnline: driver.isOnline || false,
      serviceType: driver.serviceType || "",
    },
    availableBalance: Math.round(availableBalance * 100) / 100,
    hasActiveDelivery: !!driver.currentBookingId,
    newJobs,
  };
  req.msg = "success";
  next();
};

/**
 * GET /driver/app/delivery/available
 * Refreshable list of incoming/available parcel requests.
 */
export const getAvailableDeliveries = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => getAvailableDeliveries");

  const driverId = (req as any).driverId;
  const jobs = await fetchAvailableJobs(driverId, 30);

  req.rData = { deliveries: jobs };
  req.msg = "success";
  next();
};

/**
 * POST /driver/app/delivery/:deliveryId/accept
 * Assign the delivery to this parcel partner (SEARCHING → ASSIGNED) and notify
 * the customer + other nearby drivers that the job is taken.
 */
export const acceptDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => acceptDelivery");

  const driverId = (req as any).driverId;
  const { deliveryId } = req.params;

  // Only parcel vendors can accept parcel deliveries.
  const driver = await DriverService.getDriverById(driverId);
  if (!driver || driver.serviceType !== "parcel") {
    req.rCode = 0;
    req.msg = "vendor_type_mismatch";
    return next();
  }

  // One active delivery at a time.
  if (driver.currentBookingId) {
    req.rCode = 0;
    req.msg = "active_delivery_exists";
    return next();
  }

  const delivery = await DeliveryService.getDeliveryById(deliveryId);
  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  if (delivery.status !== "SEARCHING" || delivery.driverId) {
    req.rCode = 0;
    req.msg = "delivery_not_available";
    return next();
  }

  // Assign driver → ASSIGNED, and mark the driver busy.
  const updatedDelivery = await DeliveryService.assignDriverToDelivery(
    deliveryId,
    new Types.ObjectId(driverId),
  );
  await DriverService.updateDriver(driverId, {
    currentBookingId: new Types.ObjectId(deliveryId),
  });

  const io = req.app.get("io");
  if (io && updatedDelivery) {
    const driverLocation = await DriverLocationService.getDriverLocation(
      new Types.ObjectId(driverId),
    );

    // Tell the customer their delivery was accepted.
    const userId = (delivery.userId as any)?._id || delivery.userId;
    io.to(`user_${userId}`).emit("delivery_accepted", {
      delivery: updatedDelivery,
      driver: {
        _id: driver._id,
        fullName: driver.fullName,
        mobileNumber: driver.mobileNumber,
        rating: driver.rating,
      },
      driverLocation,
    });

    // Tell every other nearby parcel driver this job is gone so their card
    // disappears (mirrors the cab "ride_taken" behaviour).
    try {
      const nearby = await DriverLocationService.findNearbyDrivers(
        delivery.pickup.lat,
        delivery.pickup.lng,
        AVAILABLE_RADIUS_KM,
        undefined,
        "parcel",
      );
      nearby.forEach(({ driver: other }) => {
        if (other._id.toString() !== driverId.toString()) {
          io.to(`driver_${other._id}`).emit("delivery_taken", {
            deliveryId: delivery._id,
          });
        }
      });
    } catch (err) {
      console.error("delivery_taken broadcast failed:", err);
    }
  }

  req.rData = { delivery: updatedDelivery };
  req.msg = "delivery_accepted";
  next();
};

/**
 * PUT /driver/app/delivery/:deliveryId/status
 * Advance the delivery the partner is handling (PICKED_UP → IN_TRANSIT →
 * DELIVERED). On DELIVERED the partner is freed up for the next job.
 */
export const updateDeliveryStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => updateDeliveryStatus");

  const driverId = (req as any).driverId;
  const { deliveryId } = req.params;
  const { status } = req.body;

  const allowed = ["PICKED_UP", "IN_TRANSIT", "DELIVERED"];
  if (!allowed.includes(status)) {
    req.rCode = 0;
    req.msg = "invalid_status";
    return next();
  }

  const delivery: any = await DeliveryService.getDeliveryById(deliveryId);
  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  const deliveryDriverId = delivery.driverId?._id || delivery.driverId;
  if (!deliveryDriverId || deliveryDriverId.toString() !== driverId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  const updated = await DeliveryService.updateDeliveryStatus(deliveryId, status);

  // Free the partner once the parcel is delivered. Passing `undefined` makes
  // updateDriver `$unset` the field, which the nearby-drivers query treats as
  // available again (mirrors cab ride completion).
  if (status === "DELIVERED") {
    await DriverService.updateDriver(driverId, { currentBookingId: undefined });
  }

  const io = req.app.get("io");
  if (io) {
    const userId = delivery.userId?._id || delivery.userId;
    io.to(`user_${userId}`).emit("delivery_status_updated", {
      deliveryId: delivery._id,
      status,
    });
  }

  req.rData = { delivery: updated };
  req.msg = "delivery_status_updated";
  next();
};

/**
 * POST /driver/app/delivery/:deliveryId/reject
 * The partner dismisses a request. We don't mutate the delivery (it stays
 * available for other drivers); this just acknowledges the dismissal so the
 * client can drop the card.
 */
export const rejectDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryDriverController => rejectDelivery");

  const { deliveryId } = req.params;
  req.rData = { deliveryId };
  req.msg = "delivery_rejected";
  next();
};
