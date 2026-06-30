/**
 * Import the "Our Services" tiles exactly as they appear in the Figma design
 * (kebu-one, node 687-40632) into the Cleaning category.
 *
 * Unlike the full household seed, this script ONLY touches the 6 service tiles
 * — it does not re-seed categories or packages, so admin-edited package prices
 * are left untouched. It is safe to re-run (upsert by slug) and preserves each
 * service's existing inclusions/exclusions.
 *
 * Usage: npm run seed:figma-services   (or: npx ts-node src/seeds/import-figma-services.ts)
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceDetails from "../models/service-details.model";
import ServiceCategory from "../models/service-category.model";

// Load DB_URL from .env so this script targets the SAME database the backend
// uses (the other seeds skip this and silently fall back to localhost).
dotenv.config({ quiet: true } as any);

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";

// Names + display order are taken verbatim from the Figma "Our Services" grid.
// The emoji is the admin-panel-editable icon; the customer app pairs each name
// with its bundled illustration, so these match the design out of the box.
const FIGMA_SERVICES = [
  { slug: "everyday-cleaning", name: "Everyday Cleaning", icon: "🧹", order: 1 },
  { slug: "weekly-cleaning", name: "Weekly Cleaning", icon: "🧽", order: 2 },
  { slug: "laundry", name: "Laundry", icon: "👕", order: 3 },
  { slug: "dishwashing", name: "Dishwashing", icon: "🍽️", order: 4 },
  { slug: "bathroom-cleaning", name: "Bathroom Cleaning", icon: "🚿", order: 5 },
  { slug: "kitchen-prep", name: "Kitchen Prep", icon: "🔪", order: 6 },
];

const importFigmaServices = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to MongoDB");

  const cleaning = await ServiceCategory.findOne({ slug: "cleaning" });
  if (!cleaning) {
    console.error(
      'Cleaning category not found. Run "npm run seed:household" first.',
    );
    await mongoose.disconnect();
    process.exit(1);
  }
  const categoryId = cleaning._id;

  // The Figma renamed the legacy "Cooking Assistant" tile to "Kitchen Prep".
  // Migrate the existing doc in place so its inclusions/exclusions survive.
  try {
    const renamed = await ServiceDetails.findOneAndUpdate(
      { categoryId, slug: "cooking-assistant" },
      {
        $set: {
          serviceType: "Kitchen Prep",
          slug: "kitchen-prep",
          description: "Kitchen prep & chopping assistance",
        },
      },
    );
    if (renamed) console.log('Renamed "Cooking Assistant" -> "Kitchen Prep"');
  } catch (err) {
    console.warn("Skipped Cooking Assistant rename:", (err as Error).message);
  }

  for (const s of FIGMA_SERVICES) {
    await ServiceDetails.findOneAndUpdate(
      { categoryId, slug: s.slug },
      {
        $set: {
          serviceType: s.name,
          slug: s.slug,
          icon: s.icon,
          displayOrder: s.order,
          isActive: true,
        },
        $setOnInsert: { categoryId },
      },
      { upsert: true, new: true },
    );
    console.log(`Imported ${s.name} (${s.icon})`);
  }

  console.log(`Done — imported ${FIGMA_SERVICES.length} Figma services.`);
  await mongoose.disconnect();
};

if (require.main === module) {
  importFigmaServices()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Import failed:", err);
      process.exit(1);
    });
}

export default importFigmaServices;
