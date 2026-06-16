import mongoose, { Schema, Types } from "mongoose";

export interface IAutomationRule {
  _id?: Types.ObjectId;
  name: string;
  description?: string;
  category: "pricing" | "promotion" | "operational";

  // Pricing rules: e.g. "per_km_rate", "base_fare", "surge_multiplier"
  // Promotion rules: e.g. "ride_count_discount", "first_ride", "referral_bonus"
  // Operational rules: e.g. "driver_cancellation_rate", "idle_driver", "unassigned_order"
  ruleType: string;

  condition: {
    field: string; // e.g. "distance_km", "ride_count", "cancellation_rate"
    operator: "gt" | "lt" | "gte" | "lte" | "eq" | "between";
    value: number;
    valueMax?: number; // for "between" operator
    unit?: string; // "km", "rides", "percent", "minutes", "rupees"
  };

  action: {
    type:
      | "set_rate"
      | "flat_discount"
      | "percent_discount"
      | "cashback"
      | "free_ride"
      | "auto_warning"
      | "flag"
      | "notify"
      | "escalate"
      | "dashboard_alert"
      | "suspend";
    value?: number; // discount amount, rate value, etc.
    maxDiscount?: number; // cap for percent discounts
    target?: string; // role or specific admin for notifications
    message?: string;
  };

  applicableTo?: {
    vehicleTypes?: string[]; // specific vehicle type IDs
    userType?: "all" | "new" | "existing";
    cities?: string[];
  };

  validFrom?: Date;
  validUntil?: Date;
  usageLimit?: number; // max times this rule can be triggered per user
  totalUsageLimit?: number; // max total triggers
  currentUsage: number;

  priority: number; // higher = evaluated first
  isActive: boolean;
  lastTriggered?: Date;
  triggerCount: number;
  createdBy: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

const AutomationRuleSchema = new Schema<IAutomationRule>(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    category: {
      type: String,
      enum: ["pricing", "promotion", "operational"],
      required: true,
    },
    ruleType: { type: String, required: true },
    condition: {
      field: { type: String, required: true },
      operator: {
        type: String,
        enum: ["gt", "lt", "gte", "lte", "eq", "between"],
        required: true,
      },
      value: { type: Number, required: true },
      valueMax: Number,
      unit: String,
    },
    action: {
      type: {
        type: String,
        enum: [
          "set_rate",
          "flat_discount",
          "percent_discount",
          "cashback",
          "free_ride",
          "auto_warning",
          "flag",
          "notify",
          "escalate",
          "dashboard_alert",
          "suspend",
        ],
        required: true,
      },
      value: Number,
      maxDiscount: Number,
      target: String,
      message: String,
    },
    applicableTo: {
      vehicleTypes: [String],
      userType: {
        type: String,
        enum: ["all", "new", "existing"],
        default: "all",
      },
      cities: [String],
    },
    validFrom: Date,
    validUntil: Date,
    usageLimit: Number,
    totalUsageLimit: Number,
    currentUsage: { type: Number, default: 0 },
    priority: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    lastTriggered: Date,
    triggerCount: { type: Number, default: 0 },
    createdBy: { type: Schema.Types.ObjectId, ref: "Admin", required: true },
  },
  { timestamps: true },
);

AutomationRuleSchema.index({ category: 1, isActive: 1, priority: -1 });

export default mongoose.model<IAutomationRule>(
  "AutomationRule",
  AutomationRuleSchema,
);
