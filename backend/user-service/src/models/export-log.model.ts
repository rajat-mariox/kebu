import mongoose, { Schema, Types } from "mongoose";

export interface IExportLog {
  _id?: Types.ObjectId;
  adminId: Types.ObjectId;
  adminName: string;
  exportType: string; // e.g. "users", "drivers", "bookings", "revenue", "audit_logs"
  filters?: Record<string, any>;
  recordCount: number;
  ipAddress?: string;
  createdAt?: Date;
}

const ExportLogSchema = new Schema<IExportLog>(
  {
    adminId: { type: Schema.Types.ObjectId, ref: "Admin", required: true },
    adminName: { type: String, required: true },
    exportType: { type: String, required: true },
    filters: { type: Schema.Types.Mixed },
    recordCount: { type: Number, required: true },
    ipAddress: { type: String },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

ExportLogSchema.index({ adminId: 1 });
ExportLogSchema.index({ createdAt: -1 });

export default mongoose.model<IExportLog>("ExportLog", ExportLogSchema);
