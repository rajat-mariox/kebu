import mongoose, { Schema, Document } from "mongoose";

/**
 * Backend-driven configuration for the household (cleaning) partner onboarding
 * "Personal Details" step. Each document describes one form field that the
 * partner app renders dynamically — labels, field type, validation and (for
 * dropdowns) the selectable option list all live here so they can be edited
 * from admin without an app release.
 */
export type HouseholdFieldType =
  | "text"
  | "phone"
  | "dropdown"
  | "multiselect";

export interface IHouseholdOnboardingConfig extends Document {
  // Maps 1:1 to a Driver field (e.g. "fullName", "totalExperience").
  key: string;
  label: string;
  type: HouseholdFieldType;
  placeholder: string;
  // Keyboard hint for text fields ("default" | "email" | "phone" | "number").
  keyboard: string;
  required: boolean;
  readOnly: boolean;
  // Options for dropdown / multiselect fields.
  options: string[];
  displayOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const householdOnboardingConfigSchema = new Schema<IHouseholdOnboardingConfig>(
  {
    key: { type: String, required: true, unique: true, trim: true },
    label: { type: String, required: true },
    type: {
      type: String,
      enum: ["text", "phone", "dropdown", "multiselect"],
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

const HouseholdOnboardingConfig = mongoose.model<IHouseholdOnboardingConfig>(
  "HouseholdOnboardingConfig",
  householdOnboardingConfigSchema,
);

/**
 * Default field set seeded the first time the config is requested while the
 * collection is empty. Mirrors the Figma "Personal Details" design.
 */
export const DEFAULT_HOUSEHOLD_PERSONAL_INFO_FIELDS: Array<
  Partial<IHouseholdOnboardingConfig>
> = [
  {
    key: "fullName",
    label: "Full Name",
    type: "text",
    placeholder: "Enter driver name",
    keyboard: "default",
    required: true,
    displayOrder: 1,
  },
  {
    key: "email",
    label: "Email Address",
    type: "text",
    placeholder: "Enter email address",
    keyboard: "email",
    required: true,
    displayOrder: 2,
  },
  {
    key: "mobileNumber",
    label: "Mobile Number",
    type: "phone",
    placeholder: "+91 ",
    keyboard: "phone",
    required: false,
    readOnly: true,
    displayOrder: 3,
  },
  {
    key: "totalExperience",
    label: "Total experience",
    type: "dropdown",
    placeholder: "Select total experience",
    required: false,
    options: [
      "Less than 1 year",
      "1 - 2 years",
      "3 - 5 years",
      "5 - 10 years",
      "More than 10 years",
    ],
    displayOrder: 4,
  },
  {
    key: "pastWorkExperience",
    label: "Past work experience",
    type: "dropdown",
    placeholder: "Select past work experience",
    required: false,
    options: [
      "No prior experience",
      "Worked independently",
      "Worked with an agency",
      "Worked with another platform",
    ],
    displayOrder: 5,
  },
  {
    key: "availability",
    label: "Availability",
    type: "dropdown",
    placeholder: "Select availability",
    required: false,
    options: ["Full time", "Part time", "Weekends only", "Flexible"],
    displayOrder: 6,
  },
  {
    key: "interestedInPaidLeads",
    label: "Interested in paid leads",
    type: "dropdown",
    placeholder: "Select an option",
    required: true,
    options: ["Yes", "No"],
    displayOrder: 7,
  },
  {
    key: "spokenLanguage",
    label: "Spoken language",
    type: "multiselect",
    placeholder: "Select languages",
    required: false,
    options: [
      "Hindi",
      "English",
      "Punjabi",
      "Tamil",
      "Telugu",
      "Bengali",
      "Marathi",
      "Gujarati",
      "Kannada",
      "Malayalam",
    ],
    displayOrder: 8,
  },
];

export default HouseholdOnboardingConfig;
