import { Request, Response, NextFunction } from "express";
import AutomationRule from "../models/automation-rule.model";

export const getRules = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const filter: any = {};
  if (req.query.category) filter.category = req.query.category;
  if (req.query.isActive !== undefined) filter.isActive = req.query.isActive === "true";

  const rules = await AutomationRule.find(filter)
    .populate("createdBy", "name email")
    .sort({ category: 1, priority: -1, createdAt: -1 });
  req.rData = { rules };
  next();
};

export const createRule = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const adminId = (req as any).adminId;
  const rule = await AutomationRule.create({
    ...req.body,
    createdBy: adminId,
  });
  req.rData = { rule };
  next();
};

export const updateRule = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const rule = await AutomationRule.findByIdAndUpdate(
    req.params.ruleId,
    req.body,
    { new: true },
  );

  if (!rule) {
    req.rCode = 5;
    req.msg = "not_found";
    return next();
  }

  req.rData = { rule };
  next();
};

export const deleteRule = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const rule = await AutomationRule.findByIdAndDelete(req.params.ruleId);

  if (!rule) {
    req.rCode = 5;
    req.msg = "not_found";
    return next();
  }

  req.rData = { message: "Rule deleted" };
  next();
};

export const toggleRule = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const rule = await AutomationRule.findById(req.params.ruleId);

  if (!rule) {
    req.rCode = 5;
    req.msg = "not_found";
    return next();
  }

  rule.isActive = !rule.isActive;
  await rule.save();

  req.rData = { rule };
  next();
};
