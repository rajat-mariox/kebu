import mongoose, { Schema, Document } from "mongoose";

/**
 * Backend-driven configuration for the household (cleaning) partner onboarding
 * "Address" step. One document describes one form field. The same field set is
 * rendered twice by the partner app — once for the current address and once for
 * the permanent address — so labels, types, validation and dropdown options
 * (e.g. the state list) can be edited from admin without an app release.
 *
 * Mirrors the Figma "Address" design (ADDRESS + PERMANENT ADDRESS sections with
 * a "Same as Current Address" toggle).
 */
export type HouseholdAddressFieldType = "text" | "dropdown";

export interface IHouseholdAddressConfig extends Document {
  // Maps 1:1 to a per-section address key (e.g. "address", "state", "zipCode").
  key: string;
  label: string;
  type: HouseholdAddressFieldType;
  placeholder: string;
  // Keyboard hint for text fields ("default" | "number").
  keyboard: string;
  required: boolean;
  readOnly: boolean;
  // Options for dropdown fields (e.g. the list of states).
  options: string[];
  displayOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const householdAddressConfigSchema = new Schema<IHouseholdAddressConfig>(
  {
    key: { type: String, required: true, unique: true, trim: true },
    label: { type: String, required: true },
    type: {
      type: String,
      enum: ["text", "dropdown"],
      default: "text",
    },
    placeholder: { type: String, default: "" },
    keyboard: { type: String, default: "default" },
    required: { type: Boolean, default: false },
    readOnly: { type: Boolean, default: false },
    options: { type: [String], default: [] },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

const HouseholdAddressConfig = mongoose.model<IHouseholdAddressConfig>(
  "HouseholdAddressConfig",
  householdAddressConfigSchema,
);

/** Indian states + union territories used to seed the state dropdown. */
export const INDIAN_STATES: string[] = [
  "Andhra Pradesh",
  "Arunachal Pradesh",
  "Assam",
  "Bihar",
  "Chhattisgarh",
  "Goa",
  "Gujarat",
  "Haryana",
  "Himachal Pradesh",
  "Jharkhand",
  "Karnataka",
  "Kerala",
  "Madhya Pradesh",
  "Maharashtra",
  "Manipur",
  "Meghalaya",
  "Mizoram",
  "Nagaland",
  "Odisha",
  "Punjab",
  "Rajasthan",
  "Sikkim",
  "Tamil Nadu",
  "Telangana",
  "Tripura",
  "Uttar Pradesh",
  "Uttarakhand",
  "West Bengal",
  "Andaman and Nicobar Islands",
  "Chandigarh",
  "Dadra and Nagar Haveli and Daman and Diu",
  "Delhi",
  "Jammu and Kashmir",
  "Ladakh",
  "Lakshadweep",
  "Puducherry",
];

/**
 * Default field set seeded the first time the address config is requested while
 * the collection is empty. Mirrors the Figma "Address" design. The keys are
 * section-agnostic; the controller renders them under both the current and the
 * permanent address sections.
 */
export const DEFAULT_HOUSEHOLD_ADDRESS_FIELDS: Array<
  Partial<IHouseholdAddressConfig>
> = [
  {
    key: "address",
    label: "Address",
    type: "text",
    placeholder: "Enter address",
    keyboard: "default",
    required: true,
    displayOrder: 1,
  },
  {
    key: "apartment",
    label: "Apartment, Suite, Unit, Building, Floor, etc",
    type: "text",
    placeholder: "Enter apartment, suite, unit",
    keyboard: "default",
    required: true,
    displayOrder: 2,
  },
  {
    key: "state",
    label: "State/Province",
    type: "dropdown",
    placeholder: "-- Select State/Province --",
    required: true,
    options: INDIAN_STATES,
    displayOrder: 3,
  },
  {
    key: "city",
    label: "City",
    type: "text",
    placeholder: "Enter city",
    keyboard: "default",
    required: true,
    displayOrder: 4,
  },
  {
    key: "country",
    label: "Country",
    type: "text",
    placeholder: "India",
    keyboard: "default",
    required: true,
    readOnly: true,
    displayOrder: 5,
  },
  {
    key: "zipCode",
    label: "ZIP / Postal Code",
    type: "text",
    placeholder: "Enter ZIP / postal code",
    keyboard: "number",
    required: true,
    displayOrder: 6,
  },
];

export default HouseholdAddressConfig;
