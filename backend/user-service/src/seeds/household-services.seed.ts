/**
 * Seed script for Household Service Details
 * Run this to populate initial service details with inclusions/exclusions
 *
 * Usage: npx ts-node src/seeds/household-services.seed.ts
 */

import mongoose from "mongoose";
import ServiceDetails from "../models/service-details.model";
import ServicePackage from "../models/service-package.model";
import ServiceCategory from "../models/service-category.model";

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";

const seedServiceDetails = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to MongoDB");

  // Top-level household service categories shown on the customer app grid
  const topLevelCategories = [
    { name: "Cleaning", slug: "cleaning", description: "Professional home cleaning services", icon: "🧹", displayOrder: 1 },
    { name: "AC Repair", slug: "ac-repair", description: "Air conditioner installation, repair and servicing", icon: "❄️", displayOrder: 2 },
    { name: "Plumber", slug: "plumber", description: "Plumbing, leaks, taps and pipe work", icon: "🔧", displayOrder: 3 },
    { name: "Electrician", slug: "electrician", description: "Wiring, switches, fans and appliance fixes", icon: "💡", displayOrder: 4 },
    { name: "Carpenter", slug: "carpenter", description: "Furniture repair, assembly and woodwork", icon: "🪚", displayOrder: 5 },
    { name: "Pest Control", slug: "pest-control", description: "General pest control and disinfection", icon: "🐜", displayOrder: 6 },
    { name: "Appliance Repair", slug: "appliance-repair", description: "Repair for TVs, washing machines, fridges and more", icon: "📺", displayOrder: 7 },
    { name: "Painter", slug: "painter", description: "Interior and exterior painting", icon: "🎨", displayOrder: 8 },
  ];

  const categoryBySlug: Record<string, any> = {};
  for (const c of topLevelCategories) {
    const doc = await ServiceCategory.findOneAndUpdate(
      { slug: c.slug },
      { ...c, isActive: true },
      { upsert: true, new: true },
    );
    categoryBySlug[c.slug] = doc;
  }
  console.log(`Upserted ${topLevelCategories.length} top-level categories`);

  // ============================================================
  // Sub-categories (parentId points to the top-level category)
  // ============================================================
  const subCategoryDefs: Array<{
    parentSlug: string;
    name: string;
    slug: string;
    description?: string;
    icon?: string;
    displayOrder: number;
  }> = [
    // Cleaning
    { parentSlug: "cleaning", name: "Home Deep Cleaning", slug: "cleaning-home-deep", description: "Top-to-bottom deep cleaning of your full home", icon: "🏠", displayOrder: 1 },
    { parentSlug: "cleaning", name: "Bathroom Cleaning", slug: "cleaning-bathroom", description: "Deep bathroom & toilet scrubbing", icon: "🚿", displayOrder: 2 },
    { parentSlug: "cleaning", name: "Kitchen Cleaning", slug: "cleaning-kitchen", description: "Degreasing, chimney & cabinet cleaning", icon: "🍳", displayOrder: 3 },
    { parentSlug: "cleaning", name: "Sofa & Carpet Cleaning", slug: "cleaning-sofa-carpet", description: "Shampoo-based upholstery & carpet wash", icon: "🛋️", displayOrder: 4 },
    { parentSlug: "cleaning", name: "Pest Control (Cockroach)", slug: "cleaning-pest-cockroach", description: "Targeted cockroach + ant control", icon: "🐜", displayOrder: 5 },

    // AC Repair
    { parentSlug: "ac-repair", name: "Window AC Service", slug: "ac-window-service", description: "Service & cleaning for window ACs", icon: "🪟", displayOrder: 1 },
    { parentSlug: "ac-repair", name: "Split AC Service", slug: "ac-split-service", description: "Indoor + outdoor unit cleaning", icon: "❄️", displayOrder: 2 },
    { parentSlug: "ac-repair", name: "AC Gas Refill", slug: "ac-gas-refill", description: "Refrigerant top-up for split/window AC", icon: "⛽", displayOrder: 3 },
    { parentSlug: "ac-repair", name: "AC Installation", slug: "ac-installation", description: "New AC installation / uninstall + reinstall", icon: "🔧", displayOrder: 4 },
    { parentSlug: "ac-repair", name: "AC Repair", slug: "ac-repair-fix", description: "Cooling issues, leakage & PCB faults", icon: "🛠️", displayOrder: 5 },

    // Plumber
    { parentSlug: "plumber", name: "Tap & Mixer", slug: "plumber-tap", description: "Tap/mixer install or repair", icon: "🚰", displayOrder: 1 },
    { parentSlug: "plumber", name: "Toilet Repair", slug: "plumber-toilet", description: "Flush tank, seat & leakage", icon: "🚽", displayOrder: 2 },
    { parentSlug: "plumber", name: "Wash Basin", slug: "plumber-basin", description: "Basin install/leak/blockage", icon: "🧼", displayOrder: 3 },
    { parentSlug: "plumber", name: "Drainage Blockage", slug: "plumber-drainage", description: "Sink / pipe / drain unclogging", icon: "🌀", displayOrder: 4 },
    { parentSlug: "plumber", name: "Water Tank Cleaning", slug: "plumber-tank-clean", description: "Overhead / underground tank cleaning", icon: "🛢️", displayOrder: 5 },

    // Electrician
    { parentSlug: "electrician", name: "Switch & Socket", slug: "elec-switch-socket", description: "Replace switches, sockets, MCBs", icon: "🔌", displayOrder: 1 },
    { parentSlug: "electrician", name: "Fan Installation/Repair", slug: "elec-fan", description: "Ceiling/wall/exhaust fan service", icon: "🪭", displayOrder: 2 },
    { parentSlug: "electrician", name: "Light & Wiring", slug: "elec-light-wiring", description: "Lights, tube lights, basic wiring", icon: "💡", displayOrder: 3 },
    { parentSlug: "electrician", name: "Inverter & Stabilizer", slug: "elec-inverter", description: "Inverter / stabilizer install & repair", icon: "🔋", displayOrder: 4 },
    { parentSlug: "electrician", name: "Doorbell & Smart Switch", slug: "elec-doorbell", description: "Doorbell, smart switch & module install", icon: "🔔", displayOrder: 5 },

    // Carpenter
    { parentSlug: "carpenter", name: "Furniture Assembly", slug: "carp-assembly", description: "Bed, wardrobe, table assembly", icon: "🛏️", displayOrder: 1 },
    { parentSlug: "carpenter", name: "Door Repair", slug: "carp-door", description: "Hinge, lock & door alignment", icon: "🚪", displayOrder: 2 },
    { parentSlug: "carpenter", name: "Wardrobe & Cabinet", slug: "carp-wardrobe", description: "Wardrobe / cabinet repair", icon: "🚪", displayOrder: 3 },
    { parentSlug: "carpenter", name: "Drilling & Hanging", slug: "carp-drilling", description: "Wall drilling, curtain rod, photo frames", icon: "🪚", displayOrder: 4 },

    // Pest Control
    { parentSlug: "pest-control", name: "General Pest Control", slug: "pest-general", description: "Cockroach, ants & spiders treatment", icon: "🐞", displayOrder: 1 },
    { parentSlug: "pest-control", name: "Termite Control", slug: "pest-termite", description: "Anti-termite treatment", icon: "🪵", displayOrder: 2 },
    { parentSlug: "pest-control", name: "Mosquito Control", slug: "pest-mosquito", description: "Mosquito fumigation & gel", icon: "🦟", displayOrder: 3 },
    { parentSlug: "pest-control", name: "Bed Bug Control", slug: "pest-bedbug", description: "Bed bug treatment for rooms", icon: "🛌", displayOrder: 4 },
    { parentSlug: "pest-control", name: "Rodent Control", slug: "pest-rodent", description: "Rat / mice control", icon: "🐭", displayOrder: 5 },

    // Appliance Repair
    { parentSlug: "appliance-repair", name: "Washing Machine", slug: "app-washing-machine", description: "Top-load / front-load washing machine", icon: "🧺", displayOrder: 1 },
    { parentSlug: "appliance-repair", name: "Refrigerator", slug: "app-refrigerator", description: "Fridge cooling, gas & defrost", icon: "🧊", displayOrder: 2 },
    { parentSlug: "appliance-repair", name: "Microwave", slug: "app-microwave", description: "Microwave heating, magnetron, fuse", icon: "🔥", displayOrder: 3 },
    { parentSlug: "appliance-repair", name: "TV Repair", slug: "app-tv", description: "LED / LCD TV repair", icon: "📺", displayOrder: 4 },
    { parentSlug: "appliance-repair", name: "Chimney", slug: "app-chimney", description: "Kitchen chimney clean & repair", icon: "🌫️", displayOrder: 5 },
    { parentSlug: "appliance-repair", name: "Geyser", slug: "app-geyser", description: "Geyser install, heating element, leak", icon: "🚿", displayOrder: 6 },
    { parentSlug: "appliance-repair", name: "Water Purifier", slug: "app-purifier", description: "RO/UV service & filter change", icon: "💧", displayOrder: 7 },

    // Painter
    { parentSlug: "painter", name: "Interior Painting", slug: "paint-interior", description: "Living room, bedroom, hall painting", icon: "🎨", displayOrder: 1 },
    { parentSlug: "painter", name: "Exterior Painting", slug: "paint-exterior", description: "Outside wall painting", icon: "🏚️", displayOrder: 2 },
    { parentSlug: "painter", name: "Wood Polish", slug: "paint-wood-polish", description: "Furniture & door polish", icon: "🪑", displayOrder: 3 },
    { parentSlug: "painter", name: "Texture / Waterproofing", slug: "paint-texture", description: "Texture paint & wall waterproofing", icon: "🧱", displayOrder: 4 },
  ];

  for (const sc of subCategoryDefs) {
    const parent = categoryBySlug[sc.parentSlug];
    if (!parent) continue;
    await ServiceCategory.findOneAndUpdate(
      { slug: sc.slug },
      {
        name: sc.name,
        slug: sc.slug,
        description: sc.description,
        icon: sc.icon,
        parentId: parent._id,
        displayOrder: sc.displayOrder,
        isActive: true,
      },
      { upsert: true, new: true },
    );
  }
  console.log(`Upserted ${subCategoryDefs.length} sub-categories`);

  const cleaningCategory = categoryBySlug["cleaning"];
  const categoryId = cleaningCategory._id;

  // Create Service Packages (1 hr, 1.5 hr, 2 hr)
  const packages = [
    {
      categoryId,
      name: "1 hr",
      durationMinutes: 60,
      originalPrice: 499,
      discountedPrice: 149,
      discountPercentage: 70,
      isPopular: false,
      isAvailable: true,
      displayOrder: 1,
    },
    {
      categoryId,
      name: "1.5 hr",
      durationMinutes: 90,
      originalPrice: 555,
      discountedPrice: 149,
      discountPercentage: 73,
      isPopular: true,
      isAvailable: true,
      displayOrder: 2,
    },
    {
      categoryId,
      name: "2 hr",
      durationMinutes: 120,
      originalPrice: 599,
      discountedPrice: 200,
      discountPercentage: 67,
      isPopular: false,
      isAvailable: true,
      displayOrder: 3,
    },
  ];

  for (const pkg of packages) {
    await ServicePackage.findOneAndUpdate(
      { categoryId: pkg.categoryId, durationMinutes: pkg.durationMinutes },
      pkg,
      { upsert: true, new: true },
    );
  }
  console.log("Created Cleaning packages");

  // Duration packages for the other top-level categories (starting rates)
  const otherCategoryPackages: Record<string, { base: number; name: string }> = {
    "ac-repair": { base: 499, name: "AC Repair" },
    plumber: { base: 199, name: "Plumber" },
    electrician: { base: 199, name: "Electrician" },
    carpenter: { base: 249, name: "Carpenter" },
    "pest-control": { base: 799, name: "Pest Control" },
    "appliance-repair": { base: 299, name: "Appliance Repair" },
    painter: { base: 1499, name: "Painter" },
  };

  for (const [slug, cfg] of Object.entries(otherCategoryPackages)) {
    const cat = categoryBySlug[slug];
    if (!cat) continue;
    const catPackages = [
      { name: "1 hr", durationMinutes: 60, originalPrice: cfg.base, discountedPrice: Math.round(cfg.base * 0.8), discountPercentage: 20, isPopular: false, displayOrder: 1 },
      { name: "1.5 hr", durationMinutes: 90, originalPrice: Math.round(cfg.base * 1.4), discountedPrice: Math.round(cfg.base * 1.1), discountPercentage: 21, isPopular: true, displayOrder: 2 },
      { name: "2 hr", durationMinutes: 120, originalPrice: Math.round(cfg.base * 1.8), discountedPrice: Math.round(cfg.base * 1.4), discountPercentage: 22, isPopular: false, displayOrder: 3 },
    ];
    for (const p of catPackages) {
      await ServicePackage.findOneAndUpdate(
        { categoryId: cat._id, durationMinutes: p.durationMinutes },
        { ...p, categoryId: cat._id, isAvailable: true },
        { upsert: true, new: true },
      );
    }
  }
  console.log("Created duration packages for non-cleaning categories");

  // Create Service Types with Inclusions/Exclusions
  const serviceTypes = [
    {
      categoryId,
      serviceType: "Everyday Cleaning",
      slug: "everyday-cleaning",
      description: "Regular daily cleaning service",
      icon: "everyday-icon",
      displayOrder: 1,
      inclusions: [
        "Sweep & Mop Accessible Areas",
        "Dry Dust/Wet Wipe Furniture, Fixtures, Wardrobes",
        "Dry Dust Walls, Fans, Ceilings, Window Grills, Curtains, Etc",
        "Change Or Rearrange The Bedding",
        "Dispose Of Wet & Dry Waste",
      ],
      exclusions: [
        "Sweeping & Mopping Inaccessible Areas",
        "Moving Heavy Furniture",
        "Cleaning Outside Windows Or Areas",
        "Washing A Ladder",
        "Washing Bed Sheets, Pillow Covers, Blankets, Etc",
      ],
      customerRequirements: [
        { name: "Mop & Bucket", icon: "mop-icon" },
        { name: "Surface Cleaner", icon: "cleaner-icon" },
        { name: "Dusting Cloth", icon: "cloth-icon" },
        { name: "Clean Broom", icon: "broom-icon" },
      ],
    },
    {
      categoryId,
      serviceType: "Weekly Cleaning",
      slug: "weekly-cleaning",
      description: "Deep weekly cleaning service",
      icon: "weekly-icon",
      displayOrder: 2,
      inclusions: [
        "Dry Dust Ceiling, Furniture, Fixtures, And Fans (If Accessible)",
        "Dry Dust/Wet Wipe Walls, Showpieces, Vases, And Frames",
        "Empty, Clean, And Replace Contents In Wardrobes/Cabinets/Drawers",
        "Dry Dust/Wet Wipe Windows (Inside Only) And Window Grills",
        "Dry Dust Curtains, Curtain Rods, Sofas, Carpets, And Door Mats",
      ],
      exclusions: [
        "Wet Wipe The Ceiling",
        "Dust Chandeliers And Electrical Fixtures",
        "Wet Wipe/Shampoo Upholstery",
        "Clean Windows From The Outside",
        "Use An Unstable Or Risky Ladder Or Stool",
      ],
      customerRequirements: [
        { name: "Tall Brush", icon: "brush-icon" },
        { name: "Surface Cleaner", icon: "cleaner-icon" },
        { name: "Dusting Cloth", icon: "cloth-icon" },
        { name: "Step Ladder", icon: "ladder-icon" },
      ],
    },
    {
      categoryId,
      serviceType: "Laundry",
      slug: "laundry",
      description: "Laundry and ironing services",
      icon: "laundry-icon",
      displayOrder: 3,
      inclusions: ["Sort, Wash, And Dry Clothes", "Fold And Iron Clothes"],
      exclusions: [
        "Ironing Clothes With Rich Zari, Embroidery, Or Expensive Fabrics",
        "Hand Wash Biohazard-Stained Clothes",
        "Clear Washing Machine",
      ],
      customerRequirements: [
        { name: "Washing Supplies", icon: "supplies-icon" },
        { name: "Drying Rack", icon: "rack-icon" },
        { name: "Machine Instruction", icon: "instruction-icon" },
      ],
    },
    {
      categoryId,
      serviceType: "Dishwashing",
      slug: "dishwashing",
      description: "Kitchen dish cleaning service",
      icon: "dishwashing-icon",
      displayOrder: 4,
      inclusions: [
        "Clean Utensils",
        "Scrub Kitchen Sink",
        "Clean Gas Stove Grills, Burner, & Wipe Stove Top",
        "Dispose Of Wet & Dry Waste",
        "Ensure Sink & Floor Are Clean & Dry",
      ],
      exclusions: [
        "Wet Wipe The Ceiling",
        "Dust Chandeliers And Electrical Fixtures",
        "Wet Wipe/Shampoo Upholstery",
        "Clean Windows From The Outside",
        "Use An Unstable Or Risky Ladder Or Stool",
      ],
      customerRequirements: [
        { name: "Dish Soap/Liquid", icon: "soap-icon" },
        { name: "Scrubber/Sponge", icon: "scrubber-icon" },
        { name: "Dishcloth", icon: "dishcloth-icon" },
        { name: "Dish Rack", icon: "rack-icon" },
      ],
    },
    {
      categoryId,
      serviceType: "Bathroom Cleaning",
      slug: "bathroom-cleaning",
      description: "Bathroom deep cleaning service",
      icon: "bathroom-icon",
      displayOrder: 5,
      inclusions: [
        "Wet Wipe The Mirror, Bathtub, & Accessible Walls",
        "Clean The WC (Rim, Seat, Lid)",
        "Scrub The Sink",
        "Mop & Dry The Bathroom Floor",
        "Clean Bathroom Fixtures & Fittings",
      ],
      exclusions: [
        "Hard Stain Removal",
        "Cleaning The Ceiling",
        "Unclogging Drains Or Disassembling The Toilet Tank",
      ],
      customerRequirements: [
        { name: "All-Purpose Cleaner", icon: "cleaner-icon" },
        { name: "Toilet Cleaner & Brush", icon: "toilet-icon" },
        { name: "Mop & Bucket", icon: "mop-icon" },
        { name: "Scrubber", icon: "scrubber-icon" },
      ],
    },
    {
      categoryId,
      serviceType: "Cooking Assistant",
      slug: "cooking-assistant",
      description: "Kitchen cooking assistance",
      icon: "cooking-icon",
      displayOrder: 6,
      inclusions: [
        "Chop Fruits & Vegetables",
        "Clean Leafy Vegetables & Herbs",
        "Sort Fruits & Vegetables",
        "Knead Dough",
        "Soak Rice & Pulses",
      ],
      exclusions: [
        "Any Tasks Related To Meat Or Seafood",
        "Cooking Or Baking",
        "Any Other Tasks That Involve Gas Or Stove",
      ],
      customerRequirements: [
        { name: "Knife", icon: "knife-icon" },
        { name: "Chopping Board", icon: "board-icon" },
        { name: "Ingredients", icon: "ingredients-icon" },
        { name: "Clean Bowls", icon: "bowl-icon" },
      ],
    },
  ];

  for (const service of serviceTypes) {
    await ServiceDetails.findOneAndUpdate(
      { categoryId: service.categoryId, slug: service.slug },
      service,
      { upsert: true, new: true },
    );
  }
  console.log("Created service types with inclusions/exclusions");

  console.log("Seed completed successfully!");
  await mongoose.disconnect();
};

// Run if executed directly
if (require.main === module) {
  seedServiceDetails()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Seed failed:", err);
      process.exit(1);
    });
}

export default seedServiceDetails;
