import { Request, Response, NextFunction } from "express";
import * as financeService from "../services/finance.service";
import ExportLog from "../models/export-log.model";

const parseDateRange = (req: Request) => {
  const { startDate, endDate, range } = req.query;

  let start: Date;
  let end: Date = new Date();

  if (startDate && endDate) {
    start = new Date(startDate as string);
    end = new Date(endDate as string);
    end.setHours(23, 59, 59, 999);
  } else {
    switch (range) {
      case "7d":
        start = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      case "30d":
        start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        break;
      case "90d":
        start = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
        break;
      default: // today
        start = new Date();
        start.setHours(0, 0, 0, 0);
    }
  }

  return { start, end };
};

export const getFinanceOverview = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { start, end } = parseDateRange(req);
  const overview = await financeService.getFinanceOverview(start, end);
  req.rData = overview;
  next();
};

export const getRevenueTrend = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { start, end } = parseDateRange(req);
  const trend = await financeService.getRevenueTrend(start, end);
  req.rData = { trend };
  next();
};

export const getRevenueByVehicleType = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { start, end } = parseDateRange(req);
  const breakdown = await financeService.getRevenueByVehicleType(start, end);
  req.rData = { breakdown };
  next();
};

export const exportFinanceData = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const admin = (req as any).admin;
  const { start, end } = parseDateRange(req);

  const [overview, trend, vehicleBreakdown] = await Promise.all([
    financeService.getFinanceOverview(start, end),
    financeService.getRevenueTrend(start, end),
    financeService.getRevenueByVehicleType(start, end),
  ]);

  await ExportLog.create({
    adminId: admin._id,
    adminName: admin.name,
    exportType: "finance",
    filters: req.query,
    recordCount: trend.length,
    ipAddress: req.ip || (req.headers["x-forwarded-for"] as string | undefined),
  });

  req.rData = { overview, trend, vehicleBreakdown };
  next();
};
