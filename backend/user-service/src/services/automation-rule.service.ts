import { Types } from "mongoose";
import AutomationRule, { IAutomationRule } from "../models/automation-rule.model";
import Booking from "../models/booking.model";

export interface FareContext {
  userId: Types.ObjectId | string;
  distanceKm: number;
  durationMin: number;
  vehicleTypeId?: Types.ObjectId | string;
  baseFare: number;
  distanceFare: number;
  timeFare: number;
  surgeFare: number;
  subtotal: number;
}

export interface RuleApplicationResult {
  discount: number;
  finalFare: number;
  appliedRules: Array<{ ruleId: string; name: string; amount: number }>;
}

const now = () => new Date();

const isRuleValidNow = (rule: IAutomationRule): boolean => {
  if (!rule.isActive) return false;
  const n = now();
  if (rule.validFrom && n < rule.validFrom) return false;
  if (rule.validUntil && n > rule.validUntil) return false;
  if (rule.totalUsageLimit != null && rule.currentUsage >= rule.totalUsageLimit) return false;
  return true;
};

const checkCondition = (condition: IAutomationRule["condition"], numericValue: number): boolean => {
  const { operator, value, valueMax } = condition;
  switch (operator) {
    case "gt": return numericValue > value;
    case "lt": return numericValue < value;
    case "gte": return numericValue >= value;
    case "lte": return numericValue <= value;
    case "eq": return numericValue === value;
    case "between": return valueMax != null && numericValue >= value && numericValue <= valueMax;
    default: return false;
  }
};

const checkUserTypeMatch = async (
  rule: IAutomationRule,
  userId: Types.ObjectId | string,
): Promise<boolean> => {
  const userType = rule.applicableTo?.userType || "all";
  if (userType === "all") return true;
  const completedCount = await Booking.countDocuments({
    userId: new Types.ObjectId(userId.toString()),
    status: "COMPLETED",
  });
  if (userType === "new") return completedCount === 0;
  if (userType === "existing") return completedCount > 0;
  return true;
};

const checkVehicleTypeMatch = (rule: IAutomationRule, vehicleTypeId?: Types.ObjectId | string): boolean => {
  const allowed = rule.applicableTo?.vehicleTypes;
  if (!allowed || allowed.length === 0) return true;
  if (!vehicleTypeId) return false;
  return allowed.includes(vehicleTypeId.toString());
};

const numericForField = (field: string, ctx: FareContext): number => {
  switch (field) {
    case "distance_km": return ctx.distanceKm;
    case "duration_min": return ctx.durationMin;
    case "fare": return ctx.subtotal;
    case "ride_count": return 0; // filled below for first_ride rules
    default: return 0;
  }
};

export const applyPromotionRulesToFare = async (ctx: FareContext): Promise<RuleApplicationResult> => {
  const rules = await AutomationRule.find({
    category: "promotion",
    isActive: true,
  }).sort({ priority: -1 });

  let discount = 0;
  const appliedRules: RuleApplicationResult["appliedRules"] = [];

  for (const rule of rules) {
    if (!isRuleValidNow(rule)) continue;
    if (!checkVehicleTypeMatch(rule, ctx.vehicleTypeId)) continue;
    if (!(await checkUserTypeMatch(rule, ctx.userId))) continue;

    let conditionValue: number;
    if (rule.condition.field === "ride_count") {
      conditionValue = await Booking.countDocuments({
        userId: new Types.ObjectId(ctx.userId.toString()),
        status: "COMPLETED",
      });
    } else {
      conditionValue = numericForField(rule.condition.field, ctx);
    }
    if (!checkCondition(rule.condition, conditionValue)) continue;

    const remainingFare = Math.max(ctx.subtotal - discount, 0);
    let ruleDiscount = 0;

    switch (rule.action.type) {
      case "flat_discount":
        ruleDiscount = Math.min(rule.action.value ?? 0, remainingFare);
        break;
      case "percent_discount": {
        const pct = rule.action.value ?? 0;
        let amt = (remainingFare * pct) / 100;
        if (rule.action.maxDiscount != null) amt = Math.min(amt, rule.action.maxDiscount);
        ruleDiscount = Math.min(amt, remainingFare);
        break;
      }
      case "free_ride":
        ruleDiscount = remainingFare;
        break;
      case "set_rate": {
        // Force the final fare to a specific value (e.g. ₹1 ride)
        const targetFare = rule.action.value ?? 0;
        ruleDiscount = Math.max(remainingFare - targetFare, 0);
        break;
      }
      default:
        continue; // non-monetary actions (notify, flag, etc.) skipped here
    }

    if (ruleDiscount <= 0) continue;

    discount += ruleDiscount;
    appliedRules.push({
      ruleId: rule._id!.toString(),
      name: rule.name,
      amount: ruleDiscount,
    });

    // Stop after first matching rule to avoid stacking unless desired
    break;
  }

  const finalFare = Math.max(Math.round((ctx.subtotal - discount) * 100) / 100, 0);

  return { discount: Math.round(discount * 100) / 100, finalFare, appliedRules };
};

export const recordRuleTrigger = async (ruleIds: string[]): Promise<void> => {
  if (ruleIds.length === 0) return;
  await AutomationRule.updateMany(
    { _id: { $in: ruleIds.map((id) => new Types.ObjectId(id)) } },
    { $inc: { currentUsage: 1, triggerCount: 1 }, $set: { lastTriggered: new Date() } },
  );
};
