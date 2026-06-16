import { Request, Response, NextFunction } from "express";
import * as auditLogService from "../services/audit-log.service";
import ExportLog from "../models/export-log.model";

export const getAuditLogs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const result = await auditLogService.getAuditLogs({
    page: Number(req.query.page) || 1,
    limit: Number(req.query.limit) || 20,
    adminId: req.query.adminId as string,
    actionType: req.query.actionType as string,
    entity: req.query.entity as string,
    startDate: req.query.startDate as string,
    endDate: req.query.endDate as string,
    search: req.query.search as string,
  });

  req.rData = result;
  next();
};

export const exportAuditLogs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const admin = (req as any).admin;
  const result = await auditLogService.getAuditLogs({
    page: 1,
    limit: 10000,
    adminId: req.query.adminId as string,
    actionType: req.query.actionType as string,
    entity: req.query.entity as string,
    startDate: req.query.startDate as string,
    endDate: req.query.endDate as string,
  });

  // Log the export event
  await ExportLog.create({
    adminId: admin._id,
    adminName: admin.name,
    exportType: "audit_logs",
    filters: req.query,
    recordCount: result.items.length,
    ipAddress: req.ip || (req.headers["x-forwarded-for"] as string | undefined),
  });

  req.rData = { items: result.items, total: result.total };
  next();
};

export const getExportLogs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 20;
  const skip = (page - 1) * limit;

  const filter: any = {};
  if (req.query.adminId) filter.adminId = req.query.adminId;
  if (req.query.exportType) filter.exportType = req.query.exportType;

  const [items, total] = await Promise.all([
    ExportLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    ExportLog.countDocuments(filter),
  ]);

  req.rData = { items, total, page, limit, totalPages: Math.ceil(total / limit) };
  next();
};
