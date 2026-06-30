import mongoose, { Schema, Types } from "mongoose";

/**
 * Service Details - Detailed info about what's included/excluded
 * (As shown in screens 61-67)
 */
export interface IServiceDetails {
  _id?: Types.ObjectId;
  categoryId: Types.ObjectId;
  serviceType: string; // "Everyday Cleaning", "Weekly Cleaning", "Laundry", "Dishwashing", etc.
  slug: string;
  description?: string;
  icon?: string;
  image?: string;
  basePrice?: number;
  duration?: number; // default service duration in minutes

  // What the expert is trained to do
  inclusions: string[];

  // What service excludes
  exclusions: string[];

  // What customer needs to provide
  customerRequirements: {
    name: string;
    icon?: string;
  }[];

  // Display settings
  displayOrder: number;
  isActive: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

const ServiceDetailsSchema = new Schema<IServiceDetails>(
  {
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      required: true,
      index: true,
    },
    serviceType: { type: String, required: true },
    slug: { type: String, required: true, lowercase: true },
    description: String,
    icon: String,
    image: String,
    basePrice: { type: Number, default: 0 },
    duration: { type: Number, default: 60 },

    // The Expert Is Trained To
    inclusions: [{ type: String }],

    // Service Excludes
    exclusions: [{ type: String }],

    // What We Need From You
    customerRequirements: [
      {
        name: { type: String, required: true },
        icon: String,
      },
    ],

    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true, index: true },
  },
  {
    timestamps: true,
    // Expose `name` (alias of serviceType) so the admin panel — which speaks
    // `name` — reads/writes the same field the customer app stores it under.
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  },
);

// `name` is the admin-facing alias for `serviceType`. The getter lets list/edit
// responses carry a `name`; the setter lets `new ServiceDetails({ name })` work.
ServiceDetailsSchema.virtual("name")
  .get(function (this: IServiceDetails) {
    return this.serviceType;
  })
  .set(function (this: IServiceDetails, value: string) {
    this.serviceType = value;
  });

ServiceDetailsSchema.index({ categoryId: 1, slug: 1 }, { unique: true });

export default mongoose.model<IServiceDetails>(
  "ServiceDetails",
  ServiceDetailsSchema,
);
