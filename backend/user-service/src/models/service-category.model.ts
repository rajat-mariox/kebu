import mongoose, { Schema, Types } from "mongoose";

export interface IServiceCategory {
  _id?: Types.ObjectId;
  name: string;
  slug: string;
  description?: string;
  icon?: string;
  image?: string;
  parentId?: Types.ObjectId;
  displayOrder: number;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const ServiceCategorySchema = new Schema<IServiceCategory>(
  {
    name: { type: String, required: true },
    slug: { type: String, required: true, unique: true, lowercase: true },
    description: String,
    icon: String,
    image: String,
    parentId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      index: true,
    },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true, index: true },
  },
  { timestamps: true },
);

export default mongoose.model<IServiceCategory>(
  "ServiceCategory",
  ServiceCategorySchema,
);
