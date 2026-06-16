import { Request } from "express";
import AuditLog, { IAuditLog } from "../models/audit-log.model";

export const createAuditLog = async (
  req: Request,
  data: Partial<IAuditLog>,
) => {
  const admin = (req as any).admin;
  return AuditLog.create({
    adminId: admin._id,
    adminName: admin.name,
    adminRole: admin.role,
    ipAddress: req.ip || (req.headers?.["x-forwarded-for"] as string | undefined) || undefined,
    userAgent: req.headers?.["user-agent"] || undefined,
    ...data,
  });
};

export const getAuditLogs = async (query: {
  page?: number;
  limit?: number;
  adminId?: string;
  actionType?: string;
  entity?: string;
  startDate?: string;
  endDate?: string;
  search?: string;
}) => {
  const {
    page = 1,
    limit = 20,
    adminId,
    actionType,
    entity,
    startDate,
    endDate,
    search,
  } = query;

  const filter: any = {};

  if (adminId) filter.adminId = adminId;
  if (actionType) filter.actionType = actionType;
  if (entity) filter.entity = entity;

  if (startDate || endDate) {
    filter.createdAt = {};
    if (startDate) filter.createdAt.$gte = new Date(startDate);
    if (endDate) filter.createdAt.$lte = new Date(endDate);
  }

  if (search) {
    filter.$or = [
      { adminName: { $regex: search, $options: "i" } },
      { description: { $regex: search, $options: "i" } },
      { entityId: { $regex: search, $options: "i" } },
    ];
  }

  const skip = (page - 1) * limit;
  const [items, total] = await Promise.all([
    AuditLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    AuditLog.countDocuments(filter),
  ]);

  return {
    items,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
};
