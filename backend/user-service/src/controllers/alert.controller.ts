import { Request, Response, NextFunction } from "express";
import * as alertService from "../services/alert.service";

export const getActiveAlerts = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const alerts = await alertService.getActiveAlerts();
  req.rData = { alerts };
  next();
};

export const getAlerts = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const result = await alertService.getAlerts({
    page: Number(req.query.page) || 1,
    limit: Number(req.query.limit) || 20,
    type: req.query.type as string,
    severity: req.query.severity as string,
    isResolved: req.query.isResolved as string,
  });

  req.rData = result;
  next();
};

export const resolveAlert = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const adminId = (req as any).adminId;
  const alert = await alertService.resolveAlert(req.params.alertId, adminId);

  if (!alert) {
    req.rCode = 5;
    req.msg = "not_found";
    return next();
  }

  req.rData = { alert };
  next();
};

export const checkAlerts = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await alertService.checkAndGenerateAlerts();
  req.rData = { message: "Alert check completed" };
  next();
};
