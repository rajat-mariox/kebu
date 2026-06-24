import mongoose, { Schema, Document } from "mongoose";

/**
 * Backend-driven configuration for the household (cleaning) partner onboarding
 * "Work Details" step. One document describes one form field that the partner
 * app renders dynamically.
 *
 * The business category / sub-category dropdowns are NOT hardcoded — they read
 * from the live ServiceCategory tree via `optionsSource`:
 *   - "category"     → options are the top-level service categories
 *   - "subcategory"  → options are the children of the field named in `dependsOn`
 *   - "static"       → options come from this document's `options` array
 *   - ""             → plain text input
 *
 * Mirrors the Figma "Work Details" design.
 */
export type HouseholdWorkFieldType = "text" | "dropdown";
export type HouseholdWorkOptionsSource =
  | ""
  | "category"
  | "subcategory"
  | "static";

export interface IHouseholdWorkDetailsConfig extends Document {
  // Maps 1:1 to a Driver field (e.g. "primaryCategory", "serviceCity").
  key: string;
  label: string;
  type: HouseholdWorkFieldType;
  placeholder: string;
  keyboard: string;
  required: boolean;
  readOnly: boolean;
  // Where a dropdown's options come from (see header doc).
  optionsSource: HouseholdWorkOptionsSource;
  // For "subcategory" sources — the category field this one cascades from.
  dependsOn: string;
  // Options for "static" dropdowns.
  options: string[];
  displayOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const householdWorkDetailsConfigSchema =
  new Schema<IHouseholdWorkDetailsConfig>(
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
      optionsSource: {
        type: String,
        enum: ["", "category", "subcategory", "static"],
        default: "",
      },
      dependsOn: { type: String, default: "" },
      options: { type: [String], default: [] },
      displayOrder: { type: Number, default: 0 },
      isActive: { type: Boolean, default: true },
    },
    { timestamps: true },
  );

const HouseholdWorkDetailsConfig =
  mongoose.model<IHouseholdWorkDetailsConfig>(
    "HouseholdWorkDetailsConfig",
    householdWorkDetailsConfigSchema,
  );

/**
 * Default field set seeded the first time the config is requested while the
 * collection is empty. Mirrors the Figma "Work Details" design. The category /
 * sub-category dropdown options are resolved at request time from the live
 * ServiceCategory tree (see `optionsSource`).
 */
export const DEFAULT_HOUSEHOLD_WORK_DETAILS_FIELDS: Array<
  Partial<IHouseholdWorkDetailsConfig>
> = [
  {
    key: "primaryCategory",
    label: "Primary business category",
    type: "dropdown",
    placeholder: "-- Select category --",
    required: true,
    optionsSource: "category",
    displayOrder: 1,
  },
  {
    key: "primarySubCategory",
    label: "Primary business sub-category",
    type: "dropdown",
    placeholder: "-- Select sub-category --",
    required: true,
    optionsSource: "subcategory",
    dependsOn: "primaryCategory",
    displayOrder: 2,
  },
  {
    key: "secondaryCategory",
    label: "Secondary business category",
    type: "dropdown",
    placeholder: "-- Select category --",
    required: true,
    optionsSource: "category",
    displayOrder: 3,
  },
  {
    key: "secondarySubCategory",
    label: "Secondary business sub-category",
    type: "dropdown",
    placeholder: "-- Select sub-category --",
    required: true,
    optionsSource: "subcategory",
    dependsOn: "secondaryCategory",
    displayOrder: 4,
  },
  {
    key: "serviceCity",
    label: "Select City",
    type: "text",
    placeholder: "Enter city",
    keyboard: "default",
    required: false,
    displayOrder: 5,
  },
  {
    key: "serviceArea",
    label: "Select Area",
    type: "text",
    placeholder: "Enter area",
    keyboard: "default",
    required: false,
    displayOrder: 6,
  },
  {
    key: "businessType",
    label: "Business type",
    type: "dropdown",
    placeholder: "-- Select business type --",
    required: false,
    optionsSource: "static",
    options: [
      "Individual",
      "Proprietorship",
      "Partnership",
      "Private Limited",
      "Agency",
    ],
    displayOrder: 7,
  },
];

export default HouseholdWorkDetailsConfig;
