import Booking from "../models/booking.model";
import Delivery from "../models/delivery.model";
import WalletTransaction from "../models/wallet-transaction.model";

export const getFinanceOverview = async (startDate: Date, endDate: Date) => {
  const dateFilter = { $gte: startDate, $lte: endDate };

  // Revenue from bookings
  const bookingRevenue = await Booking.aggregate([
    {
      $match: {
        status: "COMPLETED",
        completedAt: dateFilter,
      },
    },
    {
      $group: {
        _id: null,
        grossRevenue: { $sum: "$finalFare" },
        totalFare: { $sum: "$fare" },
        totalDiscount: { $sum: "$discount" },
        totalPromoDiscount: { $sum: "$promoDiscount" },
        totalTips: { $sum: "$tip" },
        count: { $sum: 1 },
      },
    },
  ]);

  // Refunds
  const refunds = await Booking.aggregate([
    {
      $match: {
        paymentStatus: "REFUNDED",
        updatedAt: dateFilter,
      },
    },
    {
      $group: {
        _id: null,
        totalRefunds: { $sum: "$finalFare" },
        refundCount: { $sum: 1 },
      },
    },
  ]);

  // Delivery revenue
  const deliveryRevenue = await Delivery.aggregate([
    {
      $match: {
        status: "DELIVERED",
        updatedAt: dateFilter,
      },
    },
    {
      $group: {
        _id: null,
        grossRevenue: { $sum: "$finalFare" },
        count: { $sum: 1 },
      },
    },
  ]);

  const bRev = bookingRevenue[0] || {
    grossRevenue: 0,
    totalDiscount: 0,
    totalPromoDiscount: 0,
    totalTips: 0,
    count: 0,
  };
  const rRef = refunds[0] || { totalRefunds: 0, refundCount: 0 };
  const dRev = deliveryRevenue[0] || { grossRevenue: 0, count: 0 };

  const grossRevenue = bRev.grossRevenue + dRev.grossRevenue;
  const netRevenue = grossRevenue - rRef.totalRefunds;
  const refundRatio =
    grossRevenue > 0
      ? Math.round((rRef.totalRefunds / grossRevenue) * 10000) / 100
      : 0;

  return {
    grossRevenue,
    netRevenue,
    refundTotal: rRef.totalRefunds,
    refundCount: rRef.refundCount,
    refundRatio,
    totalDiscount: bRev.totalDiscount + bRev.totalPromoDiscount,
    totalTips: bRev.totalTips,
    rideRevenue: bRev.grossRevenue,
    rideCount: bRev.count,
    deliveryRevenue: dRev.grossRevenue,
    deliveryCount: dRev.count,
  };
};

export const getRevenueTrend = async (startDate: Date, endDate: Date) => {
  const trend = await Booking.aggregate([
    {
      $match: {
        status: "COMPLETED",
        completedAt: { $gte: startDate, $lte: endDate },
      },
    },
    {
      $group: {
        _id: {
          $dateToString: { format: "%Y-%m-%d", date: "$completedAt" },
        },
        revenue: { $sum: "$finalFare" },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  return trend.map((t) => ({
    date: t._id,
    revenue: t.revenue,
    bookings: t.count,
  }));
};

export const getRevenueByVehicleType = async (
  startDate: Date,
  endDate: Date,
) => {
  return Booking.aggregate([
    {
      $match: {
        status: "COMPLETED",
        completedAt: { $gte: startDate, $lte: endDate },
      },
    },
    {
      $lookup: {
        from: "vehicletypes",
        localField: "vehicleTypeId",
        foreignField: "_id",
        as: "vehicleType",
      },
    },
    { $unwind: "$vehicleType" },
    {
      $group: {
        _id: "$vehicleType.name",
        revenue: { $sum: "$finalFare" },
        count: { $sum: 1 },
      },
    },
    { $sort: { revenue: -1 } },
  ]);
};

export const getWalletTransactionStats = async (
  startDate: Date,
  endDate: Date,
) => {
  return WalletTransaction.aggregate([
    {
      $match: {
        createdAt: { $gte: startDate, $lte: endDate },
      },
    },
    {
      $group: {
        _id: "$type",
        total: { $sum: "$amount" },
        count: { $sum: 1 },
      },
    },
  ]);
};
