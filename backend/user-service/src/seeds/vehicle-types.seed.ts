import mongoose from "mongoose";
import VehicleCategory from "../models/vehicle-category.model";
import VehicleType from "../models/vehicle-type.model";
import Driver from "../models/driver.model";
import DriverLocation from "../models/driver-location.model";
import DriverVehicle from "../models/driver-vehicle.model";
import config from "../config";

const seedVehicleData = async () => {
  try {
    await mongoose.connect(config.database.url);
    console.log("Connected to MongoDB");

    // ── Vehicle Categories ──
    const categories = [
      { name: "2 Wheeler", code: "BIKE", icon: "", isActive: true },
      { name: "3 Wheeler", code: "AUTO", icon: "", isActive: true },
      { name: "4 Wheeler", code: "CAR", icon: "", isActive: true },
      { name: "Cargo", code: "CARGO", icon: "", isActive: true },
    ];

    const savedCategories: Record<string, any> = {};
    for (const cat of categories) {
      const saved = await VehicleCategory.findOneAndUpdate(
        { code: cat.code },
        cat,
        { upsert: true, new: true },
      );
      savedCategories[cat.code] = saved;
      console.log(`Category "${cat.name}" created/updated`);
    }

    // ── Vehicle Types ──
    const vehicleTypes = [
      {
        categoryCode: "BIKE",
        name: "Bike",
        maxWeightKg: 15,
        baseFare: 20,
        perKmRate: 8,
        perMinuteRate: 1,
        minDistanceKm: 1,
        surgeMultiplier: 1,
        cancellationFee: 10,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "AUTO",
        name: "Rickshaw",
        maxWeightKg: 50,
        baseFare: 30,
        perKmRate: 12,
        perMinuteRate: 1.5,
        minDistanceKm: 1,
        surgeMultiplier: 1,
        cancellationFee: 20,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "CAR",
        name: "Economy",
        maxWeightKg: 200,
        baseFare: 50,
        perKmRate: 14,
        perMinuteRate: 2,
        minDistanceKm: 2,
        surgeMultiplier: 1,
        cancellationFee: 30,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "CAR",
        name: "Normal",
        maxWeightKg: 200,
        baseFare: 60,
        perKmRate: 16,
        perMinuteRate: 2.5,
        minDistanceKm: 2,
        surgeMultiplier: 1,
        cancellationFee: 40,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "CAR",
        name: "Comfort",
        maxWeightKg: 200,
        baseFare: 80,
        perKmRate: 20,
        perMinuteRate: 3,
        minDistanceKm: 2,
        surgeMultiplier: 1,
        cancellationFee: 50,
        image: "",
        isActive: true,
      },
      // ── Cargo / Parcel delivery vehicle types (Send Parcel screen) ──
      {
        categoryCode: "CARGO",
        name: "Cargo Bike",
        description: "10kg, 2 Feet",
        maxWeightKg: 15,
        baseFare: 30,
        perKmRate: 10,
        perMinuteRate: 1,
        minDistanceKm: 1,
        surgeMultiplier: 1,
        cancellationFee: 15,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "CARGO",
        name: "Pickup",
        description: "~ 1.2 Ton, 7 Feet",
        maxWeightKg: 1200,
        baseFare: 100,
        perKmRate: 18,
        perMinuteRate: 2,
        minDistanceKm: 1,
        surgeMultiplier: 1,
        cancellationFee: 50,
        image: "",
        isActive: true,
      },
      {
        categoryCode: "CARGO",
        name: "Large Truck",
        description: "~ 5 Ton, 14 Feet",
        maxWeightKg: 5000,
        baseFare: 250,
        perKmRate: 35,
        perMinuteRate: 3,
        minDistanceKm: 2,
        surgeMultiplier: 1,
        cancellationFee: 100,
        image: "",
        isActive: true,
      },
    ];

    for (const vt of vehicleTypes) {
      const { categoryCode, ...vehicleData } = vt;
      const category = savedCategories[categoryCode];
      await VehicleType.findOneAndUpdate(
        { name: vehicleData.name, categoryId: category._id },
        { ...vehicleData, categoryId: category._id },
        { upsert: true, new: true },
      );
      console.log(`Vehicle type "${vehicleData.name}" created/updated`);
    }

    // ── Test Drivers (near emulator default: Amphitheatre Parkway, Mountain View) ──
    // Cab vehicle types (4 Wheeler) that test drivers will own, so booking's
    // strict vehicle-type match always finds an online driver for any car option.
    const carCategoryId = savedCategories["CAR"]._id;
    const carVehicleTypes = await VehicleType.find({
      categoryId: carCategoryId,
      isActive: true,
    }).sort({ baseFare: 1 });

    const testDrivers = [
      {
        mobileNumber: "9000000001",
        fullName: "Test Driver 1",
        serviceType: "cab",
        status: "approved",
        isActive: true,
        isOnline: true,
        lat: 37.4230,
        lng: -122.0840,
        heading: 45,
        registrationNumber: "KA01AB0001",
      },
      {
        mobileNumber: "9000000002",
        fullName: "Test Driver 2",
        serviceType: "cab",
        status: "approved",
        isActive: true,
        isOnline: true,
        lat: 37.4250,
        lng: -122.0790,
        heading: 120,
        registrationNumber: "KA01AB0002",
      },
      {
        mobileNumber: "9000000003",
        fullName: "Test Driver 3",
        serviceType: "cab",
        status: "approved",
        isActive: true,
        isOnline: true,
        lat: 37.4210,
        lng: -122.0860,
        heading: 200,
        registrationNumber: "KA01AB0003",
      },
      {
        mobileNumber: "9000000004",
        fullName: "Test Driver 4",
        serviceType: "cab",
        status: "approved",
        isActive: true,
        isOnline: true,
        lat: 37.4270,
        lng: -122.0820,
        heading: 310,
        registrationNumber: "KA01AB0004",
      },
      {
        mobileNumber: "9000000005",
        fullName: "Test Driver 5",
        serviceType: "cab",
        status: "approved",
        isActive: true,
        isOnline: true,
        lat: 37.4195,
        lng: -122.0810,
        heading: 80,
        registrationNumber: "KA01AB0005",
      },
    ];

    for (let i = 0; i < testDrivers.length; i++) {
      const td = testDrivers[i];
      const { lat, lng, heading, registrationNumber, ...driverData } = td;
      const driver = await Driver.findOneAndUpdate(
        { mobileNumber: driverData.mobileNumber },
        driverData,
        { upsert: true, new: true },
      );

      await DriverLocation.findOneAndUpdate(
        { driverId: driver._id },
        {
          driverId: driver._id,
          location: {
            type: "Point",
            coordinates: [lng, lat],
          },
          latitude: lat,
          longitude: lng,
          heading,
          speed: 0,
        },
        { upsert: true, new: true },
      );

      // Give each test driver a real cab vehicle, cycling through the car
      // vehicle types so every selectable car option has a matching driver.
      if (carVehicleTypes.length > 0) {
        const vt = carVehicleTypes[i % carVehicleTypes.length];
        await DriverVehicle.findOneAndUpdate(
          { driverId: driver._id },
          {
            driverId: driver._id,
            vehicleTypeId: vt._id,
            registrationNumber,
            isActive: true,
            isOnline: true,
            isDeleted: false,
          },
          { upsert: true, new: true },
        );
        console.log(
          `Driver "${td.fullName}" + location + vehicle (${vt.name}) created/updated`,
        );
      } else {
        console.log(`Driver "${td.fullName}" + location created/updated`);
      }
    }

    console.log("\n✅ Vehicle types & test drivers seeded successfully!");
    process.exit(0);
  } catch (error) {
    console.error("Error seeding data:", error);
    process.exit(1);
  }
};

seedVehicleData();
