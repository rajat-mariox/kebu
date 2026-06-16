import mongoose, { Schema, Types } from "mongoose";

export interface ICmsPage {
  _id?: Types.ObjectId;
  slug: string;
  title: string;
  content: string;
  metaTitle?: string;
  metaDescription?: string;
  isActive: boolean;
  lastUpdatedBy?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

const CmsPageSchema = new Schema<ICmsPage>(
  {
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    title: { type: String, required: true, trim: true },
    content: { type: String, required: true },
    metaTitle: { type: String, trim: true },
    metaDescription: { type: String, trim: true },
    isActive: { type: Boolean, default: true },
    lastUpdatedBy: { type: Schema.Types.ObjectId, ref: "Admin" },
  },
  { timestamps: true },
);

export default mongoose.model<ICmsPage>("CmsPage", CmsPageSchema);
