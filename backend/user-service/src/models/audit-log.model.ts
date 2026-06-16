import mongoose, { Schema, Types } from "mongoose";

export interface IAuditLog {
  _id?: Types.ObjectId;
  adminId: Types.ObjectId;
  adminName: string;
  adminRole: string;
  actionType:
    | "CREATE"
    | "UPDATE"
    | "DELETE"
    | "STATUS_CHANGE"
    | "APPROVE"
    | "REJECT"
    | "SUSPEND"
    | "REFUND"
    | "LOGIN"
    | "LOGOUT"
    | "EXPORT"
    | "PRICING_EDIT"
    | "PASSWORD_RESET"
    | "SETTING_CHANGE";
  entity: string; // e.g. "User", "Driver", "Booking", "VehicleType", etc.
  entityId?: string;
  description: string;
  oldValue?: Record<string, any>;
  newValue?: Record<string, any>;
  comment?: string; // mandatory comment for sensitive actions
  ipAddress?: string;
  userAgent?: string;
  createdAt?: Date;
}

const AuditLogSchema = new Schema<IAuditLog>(
  {
    adminId: { type: Schema.Types.ObjectId, ref: "Admin", required: true },
    adminName: { type: String, required: true },
    adminRole: { type: String, required: true },
    actionType: {
      type: String,
      enum: [
        "CREATE",
        "UPDATE",
        "DELETE",
        "STATUS_CHANGE",
        "APPROVE",
        "REJECT",
        "SUSPEND",
        "REFUND",
        "LOGIN",
        "LOGOUT",
        "EXPORT",
        "PRICING_EDIT",
        "PASSWORD_RESET",
        "SETTING_CHANGE",
      ],
      required: true,
    },
    entity: { type: String, required: true },
    entityId: { type: String },
    description: { type: String, required: true },
    oldValue: { type: Schema.Types.Mixed },
    newValue: { type: Schema.Types.Mixed },
    comment: { type: String },
    ipAddress: { type: String },
    userAgent: { type: String },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

AuditLogSchema.index({ adminId: 1 });
AuditLogSchema.index({ actionType: 1 });
AuditLogSchema.index({ entity: 1 });
AuditLogSchema.index({ createdAt: -1 });

export default mongoose.model<IAuditLog>("AuditLog", AuditLogSchema);
