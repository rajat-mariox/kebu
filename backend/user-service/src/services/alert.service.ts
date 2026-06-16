import Alert, { IAlert } from "../models/alert.model";
import Booking from "../models/booking.model";
import Driver from "../models/driver.model";

export const createAlert = async (data: Partial<IAlert>) => {
  return Alert.create(data);
};

export const getActiveAlerts = async () => {
  return Alert.find({ isResolved: false })
    .sort({ severity: 1, createdAt: -1 })
    .limit(50);
};

export const resolveAlert = async (alertId: string, adminId: string) => {
  return Alert.findByIdAndUpdate(
    alertId,
    { isResolved: true, resolvedBy: adminId, resolvedAt: new Date() },
    { new: true },
  );
};

export const getAlerts = async (query: {
  page?: number;
  limit?: number;
  type?: string;
  severity?: string;
  isResolved?: string;
}) => {
  const { page = 1, limit = 20, type, severity, isResolved } = query;
  const filter: any = {};

  if (type) filter.type = type;
  if (severity) filter.severity = severity;
  if (isResolved !== undefined) filter.isResolved = isResolved === "true";

  const skip = (page - 1) * limit;
  const [items, total] = await Promise.all([
    Alert.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Alert.countDocuments(filter),
  ]);

  return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
};

// Generate real-time alerts by checking system conditions
export const checkAndGenerateAlerts = async () => {
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
  const sixtyMinutesAgo = new Date(Date.now() - 60 * 60 * 1000);

  // Check unassigned orders > 10 mins
  const unassignedOrders = await Booking.countDocuments({
    status: "SEARCHING",
    createdAt: { $lte: tenMinutesAgo },
  });

  if (unassignedOrders > 0) {
    const existing = await Alert.findOne({
      type: "unassigned_order",
      isResolved: false,
      createdAt: { $gte: tenMinutesAgo },
    });
    if (!existing) {
      await createAlert({
        type: "unassigned_order",
        severity: "red",
        title: "Unassigned Orders",
        message: `${unassignedOrders} order(s) unassigned for more than 10 minutes`,
        metadata: { count: unassignedOrders },
      });
    }
  }

  // Check idle drivers > 60 mins
  const idleDrivers = await Driver.countDocuments({
    isOnline: true,
    currentBookingId: null,
    updatedAt: { $lte: sixtyMinutesAgo },
    status: "approved",
    isActive: true,
  });

  if (idleDrivers > 0) {
    const existing = await Alert.findOne({
      type: "idle_driver",
      isResolved: false,
      createdAt: { $gte: sixtyMinutesAgo },
    });
    if (!existing) {
      await createAlert({
        type: "idle_driver",
        severity: "amber",
        title: "Idle Drivers",
        message: `${idleDrivers} driver(s) idle for more than 60 minutes`,
        metadata: { count: idleDrivers },
      });
    }
  }

  // Check cancellation spike (compare last 1 hour vs previous 24 hours average)
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [recentCancellations, dayAvgCancellations] = await Promise.all([
    Booking.countDocuments({
      status: "CANCELLED",
      cancelledAt: { $gte: oneHourAgo },
    }),
    Booking.countDocuments({
      status: "CANCELLED",
      cancelledAt: { $gte: twentyFourHoursAgo, $lt: oneHourAgo },
    }),
  ]);

  const hourlyAvg = dayAvgCancellations / 23;
  if (recentCancellations > hourlyAvg * 2 && recentCancellations > 3) {
    const existing = await Alert.findOne({
      type: "cancellation_spike",
      isResolved: false,
      createdAt: { $gte: oneHourAgo },
    });
    if (!existing) {
      await createAlert({
        type: "cancellation_spike",
        severity: "red",
        title: "Cancellation Spike",
        message: `${recentCancellations} cancellations in the last hour (${Math.round(hourlyAvg * 10) / 10} avg/hr)`,
        metadata: { count: recentCancellations, average: hourlyAvg },
      });
    }
  }
};
