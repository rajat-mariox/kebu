import mongoose, { Schema, Types } from "mongoose";

export interface IAdmin {
  _id?: Types.ObjectId;
  name: string;
  email: string;
  password: string;
  mobileNumber?: string;
  role: "super_admin" | "admin" | "support" | "finance";
  roleId?: Types.ObjectId;
  permissions: string[];
  isActive: boolean;
  lastLogin?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

const AdminSchema = new Schema<IAdmin>(
  {
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: { type: String, required: true },
    mobileNumber: { type: String, trim: true },
    role: {
      type: String,
      enum: ["super_admin", "admin", "support", "finance"],
      default: "admin",
    },
    roleId: { type: Schema.Types.ObjectId, ref: "Role" },
    permissions: [{ type: String }],
    isActive: { type: Boolean, default: true },
    lastLogin: Date,
  },
  { timestamps: true },
);

export default mongoose.model<IAdmin>("Admin", AdminSchema);
