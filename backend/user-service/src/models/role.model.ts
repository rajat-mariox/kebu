import mongoose, { Schema, Types } from "mongoose";

export interface IRole {
  _id?: Types.ObjectId;
  name: string;
  description?: string;
  permissions: string[];
  isSystem?: boolean; // System roles cannot be deleted
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const RoleSchema = new Schema<IRole>(
  {
    name: { type: String, required: true, unique: true, trim: true },
    description: { type: String, trim: true },
    permissions: [{ type: String }],
    isSystem: { type: Boolean, default: false },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

export default mongoose.model<IRole>("Role", RoleSchema);
