import mongoose, { Schema, Document } from "mongoose";

export interface IAppSettings extends Document {
  key: string;
  value: string;
  label: string;
  category: string;
  isPublic: boolean;
  updatedBy?: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const appSettingsSchema = new Schema<IAppSettings>(
  {
    key: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    value: {
      type: String,
      default: "",
    },
    label: {
      type: String,
      required: true,
    },
    category: {
      type: String,
      required: true,
      default: "general",
    },
    isPublic: {
      type: Boolean,
      default: false,
    },
    updatedBy: {
      type: Schema.Types.ObjectId,
      ref: "Admin",
    },
  },
  {
    timestamps: true,
  },
);

const AppSettings = mongoose.model<IAppSettings>(
  "AppSettings",
  appSettingsSchema,
);

export default AppSettings;
