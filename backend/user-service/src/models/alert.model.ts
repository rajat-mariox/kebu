import mongoose, { Schema, Types } from "mongoose";

export interface IAlert {
  _id?: Types.ObjectId;
  type:
    | "unassigned_order"
    | "idle_driver"
    | "credit_exceeded"
    | "high_cod"
    | "document_expiry"
    | "cancellation_spike"
    | "sos_unacknowledged"
    | "automation_triggered";
  severity: "red" | "amber" | "info";
  title: string;
  message: string;
  entityType?: string;
  entityId?: string;
  isRead: boolean;
  isResolved: boolean;
  resolvedBy?: Types.ObjectId;
  resolvedAt?: Date;
  metadata?: Record<string, any>;
  createdAt?: Date;
  updatedAt?: Date;
}

const AlertSchema = new Schema<IAlert>(
  {
    type: {
      type: String,
      enum: [
        "unassigned_order",
        "idle_driver",
        "credit_exceeded",
        "high_cod",
        "document_expiry",
        "cancellation_spike",
        "sos_unacknowledged",
        "automation_triggered",
      ],
      required: true,
    },
    severity: {
      type: String,
      enum: ["red", "amber", "info"],
      required: true,
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    entityType: String,
    entityId: String,
    isRead: { type: Boolean, default: false },
    isResolved: { type: Boolean, default: false },
    resolvedBy: { type: Schema.Types.ObjectId, ref: "Admin" },
    resolvedAt: Date,
    metadata: { type: Schema.Types.Mixed },
  },
  { timestamps: true },
);

AlertSchema.index({ isResolved: 1, createdAt: -1 });
AlertSchema.index({ type: 1 });
AlertSchema.index({ severity: 1 });

export default mongoose.model<IAlert>("Alert", AlertSchema);
