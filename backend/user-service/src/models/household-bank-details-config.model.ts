import mongoose, { Schema, Document } from "mongoose";

/**
 * Backend-driven configuration for the household (cleaning) partner onboarding
 * "Bank Details" step (the final step). One document describes one form field
 * the partner app renders dynamically — labels, type, validation and (for the
 * bank dropdown) the selectable bank list all live here so they can be edited
 * from admin without an app release. Mirrors the Figma "Bank Details" design.
 */
export type HouseholdBankFieldType = "text" | "dropdown";

export interface IHouseholdBankDetailsConfig extends Document {
  // Maps 1:1 to a Driver field (e.g. "bankName", "accountNumber", "ifscCode").
  key: string;
  label: string;
  type: HouseholdBankFieldType;
  placeholder: string;
  keyboard: string;
  required: boolean;
  readOnly: boolean;
  // Options for the bank dropdown.
  options: string[];
  displayOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const householdBankDetailsConfigSchema =
  new Schema<IHouseholdBankDetailsConfig>(
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

const HouseholdBankDetailsConfig =
  mongoose.model<IHouseholdBankDetailsConfig>(
    "HouseholdBankDetailsConfig",
    householdBankDetailsConfigSchema,
  );

/** Banks used to seed the bank dropdown (admin-editable thereafter). */
export const INDIAN_BANKS: string[] = [
  "State Bank of India",
  "HDFC Bank",
  "ICICI Bank",
  "Punjab National Bank",
  "Bank of Baroda",
  "Canara Bank",
  "Union Bank of India",
  "Bank of India",
  "Indian Bank",
  "Central Bank of India",
  "Indian Overseas Bank",
  "UCO Bank",
  "Kotak Mahindra Bank",
  "Axis Bank",
  "IDBI Bank",
  "Yes Bank",
  "Federal Bank",
  "IndusInd Bank",
  "South Indian Bank",
];

/**
 * Default field set seeded the first time the config is requested while the
 * collection is empty. Mirrors the Figma "Bank Details" design.
 */
export const DEFAULT_HOUSEHOLD_BANK_DETAILS_FIELDS: Array<
  Partial<IHouseholdBankDetailsConfig>
> = [
  {
    key: "bankName",
    label: "Bank",
    type: "dropdown",
    placeholder: "-- Select Bank --",
    required: true,
    options: INDIAN_BANKS,
    displayOrder: 1,
  },
  {
    key: "accountNumber",
    label: "Account Number",
    type: "text",
    placeholder: "Enter account number",
    keyboard: "number",
    required: true,
    displayOrder: 2,
  },
  {
    key: "ifscCode",
    label: "IFSC Code",
    type: "text",
    placeholder: "Enter ifsc code",
    keyboard: "default",
    required: true,
    displayOrder: 3,
  },
];

export default HouseholdBankDetailsConfig;
