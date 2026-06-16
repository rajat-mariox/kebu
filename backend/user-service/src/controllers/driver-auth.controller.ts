import { Request, Response, NextFunction } from "express";
import { v4 as uuidv4 } from "uuid";
import { Types } from "mongoose";

import * as DriverService from "../services/driver.service";
import * as DriverKycService from "../services/driver-kyc.service";
import * as DriverVehicleService from "../services/driver-vehicle.service";
import { sendOtpSms } from "../services/sms.service";
import helpers from "../utils/helpers";
import redis from "../utils/redis";
import config from "../config";
import fileUploadService from "../utils/s3";

/**
 * Driver Login - Step 1
 */
export const driverLogin = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => driverLogin");

  const { mobileNumber, countryCode = "+91" } = req.body;

  const otp = helpers().generateOTP();

  const driver = await DriverService.getDriverByMobile(
    mobileNumber,
    countryCode
  );

  const redisKey = `DRIVER_Mob_${mobileNumber}`;
  const redisKeys = await redis().GetKeys(redisKey);

  let txnId: string | undefined;

  if (redisKeys.length > 0) {
    const result = await redis().GetRedis<any>(redisKeys[0]);
    if (result?.[0]) {
      txnId = result[0].txnId;
    }
  }

  const newTxnId = uuidv4();

  const otpData = {
    txnId: newTxnId,
    mobileNumber,
    countryCode,
    otp,
    reason: "DRIVER OTP LOGIN",
    is_active: 1,
    date_created: new Date(),
    date_modified: new Date(),
  };

  await redis().SetRedis(`DRIVER|txnId:${newTxnId}`, otpData, 600);
  await redis().SetRedis(`DRIVER|Mob:${mobileNumber}`, otpData, 600);

  sendOtpSms(mobileNumber, String(otp), "vendors", countryCode).catch((e) =>
    console.error("[SMS] driver login send failed:", e),
  );

  req.rData = {
    driverRegistered: !!driver,
    txnId: txnId || newTxnId,
  };

  req.msg = "otp_sent";
  next();
};

export const getDriverDetails = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const driverId = (req as any).driverId;

  const [driver, kyc, vehicle] = await Promise.all([
    DriverService.getDriverById(driverId),
    DriverKycService.getDriverKyc(new Types.ObjectId(driverId)),
    DriverVehicleService.getActiveDriverVehicle(new Types.ObjectId(driverId)),
  ]);

  const kycComplete = await DriverKycService.isKycComplete(
    new Types.ObjectId(driverId)
  );

  req.rData = {
    driver,
    kyc,
    vehicle,
    status: driver?.status,
    currentStep: getCurrentStep(driver, kycComplete, vehicle),
    rejectionReason: driver?.rejectionReason || null,
    suspensionReason: driver?.suspensionReason || null,
  };

  req.msg = "success";
  next();
};

/**
 * Verify OTP - Step 2
 */
export const verifyDriverOtp = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => verifyDriverOtp");

  const { otp, txnId, fcmToken, deviceType, deviceModel, deviceId, appVersion } = req.body;

  const redisKey = `DRIVER|txnId:${txnId}`;
  const redisKeys = await redis().GetKeys(redisKey);

  if (!redisKeys.length) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  const result = await redis().GetRedis<any>(redisKeys[0]);

  console.log("OTP Data from Redis:", result);

  if (!result?.[0]) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  const otpData =
    typeof result[0] === "string" ? JSON.parse(result[0]) : result[0];
  const { mobileNumber, countryCode } = otpData;

  // Prepare device info update
  const deviceInfo: any = {};
  if (fcmToken) deviceInfo.fcmToken = fcmToken;
  if (deviceType) deviceInfo.deviceType = deviceType;
  if (deviceModel) deviceInfo.deviceModel = deviceModel;
  if (deviceId) deviceInfo.deviceId = deviceId;
  if (appVersion) deviceInfo.appVersion = appVersion;

  // Master OTP check
  if (otp == config.auth.masterOtp) {
    let driver = await DriverService.getDriverByMobile(
      mobileNumber,
      countryCode
    );

    if (!driver) {
      driver = await DriverService.createDriver({
        mobileNumber,
        countryCode,
      });
    }

    // Update device info
    if (Object.keys(deviceInfo).length > 0) {
      await DriverService.updateDriver(driver._id!, deviceInfo);
    }

    const token = helpers().createJWT({ driverId: driver._id });

    req.rData = {
      token,
      driverId: driver._id,
      status: driver.status,
      serviceType: driver.serviceType || "",
      onboardingStep: driver.onboardingStep || 0,
      isNewDriver: !driver.fullName,
    };
    req.msg = "otp_verified";
    return next();
  }

  // Normal OTP validation. Loose string compare so "881610" (request) and
  // 881610 (Redis number) match.
  if (String(otp) !== String(otpData.otp)) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  let driver = await DriverService.getDriverByMobile(mobileNumber, countryCode);

  if (!driver) {
    driver = await DriverService.createDriver({
      mobileNumber,
      countryCode,
      fullName: "",
      city: "",
      state: "",
    });
  }

  // Update device info
  if (Object.keys(deviceInfo).length > 0) {
    await DriverService.updateDriver(driver._id!, deviceInfo);
  }

  const token = helpers().createJWT({ driverId: driver._id });

  req.rData = {
    token,
    driverId: driver._id,
    status: driver.status,
    serviceType: driver.serviceType || "",
    onboardingStep: driver.onboardingStep || 0,
    isNewDriver: !driver.fullName,
  };
  req.msg = "otp_verified";
  next();
};

/**
 * Update Personal Info - Step 3
 */
export const updatePersonalInfo = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => updatePersonalInfo");

  const driverId = (req as any).driverId;
  const { fullName, email, gender, dob, city, state, bloodGroup } = req.body;

  const driver = await DriverService.updateDriver(driverId, {
    fullName,
    email,
    gender,
    dob,
    city,
    state,
    bloodGroup,
  });

  req.rData = driver;
  req.msg = "personal_info_updated";
  next();
};

/**
 * Upload KYC Documents - Step 4
 */
export const uploadKycDocuments = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => uploadKycDocuments");

  const driverId = (req as any).driverId;
  const kycData = req.body;

  const kyc = await DriverKycService.upsertDriverKyc(
    new Types.ObjectId(driverId),
    kycData
  );

  // Check if KYC is complete
  const isComplete = await DriverKycService.isKycComplete(
    new Types.ObjectId(driverId)
  );

  if (isComplete) {
    await DriverService.updateDriverStatus(driverId, "documents_uploaded");
  }

  req.rData = { kyc, isComplete };
  req.msg = "kyc_documents_uploaded";
  next();
};

/**
 * Upload Aadhaar Card
 */
export const uploadAadhaar = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = (req as any).driverId;
    const { aadhaarNumber } = req.body;

    const files = req.files as {
      frontImage?: Express.Multer.File[];
      backImage?: Express.Multer.File[];
    };

    if (!files?.frontImage?.length || !files?.backImage?.length) {
      req.rCode = 0;
      req.msg = "aadhaar_images_required";
      return next();
    }

    // ✅ Upload front image to S3
    const frontUpload = await fileUploadService.uploadMultipleFilesToAws(
      files.frontImage
    );

    // ✅ Upload back image to S3
    const backUpload = await fileUploadService.uploadMultipleFilesToAws(
      files.backImage
    );

    const frontImageUrl = frontUpload.images[0];
    const backImageUrl = backUpload.images[0];

    // ✅ Save S3 URLs in DB
    const kyc = await DriverKycService.upsertDriverKyc(
      new Types.ObjectId(driverId),
      {
        aadhaar: {
          number: aadhaarNumber,
          frontImage: frontImageUrl,
          backImage: backImageUrl,
        },
      }
    );

    req.rData = kyc;
    req.msg = "aadhaar_uploaded";
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Upload PAN Card
 */
export const uploadPan = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = (req as any).driverId;
    const { panNumber } = req.body;

    const files = req.files as {
      frontImage?: Express.Multer.File[];
      backImage?: Express.Multer.File[];
    };

    if (!files?.frontImage?.length) {
      req.rCode = 0;
      req.msg = "pan_front_image_required";
      return next();
    }

    const [frontUpload, backUpload] = await Promise.all([
      fileUploadService.uploadMultipleFilesToAws(files.frontImage),
      files.backImage
        ? fileUploadService.uploadMultipleFilesToAws(files.backImage)
        : Promise.resolve({ images: [] as string[] }),
    ]);

    const frontImageUrl = frontUpload.images[0];
    const backImageUrl = backUpload.images[0] || "";

    if (!frontImageUrl) {
      throw new Error("PAN front image upload failed");
    }

    const kyc = await DriverKycService.upsertDriverKyc(
      new Types.ObjectId(driverId),
      {
        pan: {
          number: panNumber,
          frontImage: frontImageUrl,
          backImage: backImageUrl,
        },
      }
    );

    req.rData = kyc;
    req.msg = "pan_uploaded";
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Upload Driving License
 */
export const uploadDrivingLicense = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = (req as any).driverId;
    const { licenseNumber, expiryDate } = req.body;

    const files = req.files as {
      frontImage?: Express.Multer.File[];
      backImage?: Express.Multer.File[];
    };

    if (!files?.frontImage?.length || !files?.backImage?.length) {
      req.rCode = 0;
      req.msg = "license_images_required";
      return next();
    }

    const [frontUpload, backUpload] = await Promise.all([
      fileUploadService.uploadMultipleFilesToAws(files.frontImage),
      fileUploadService.uploadMultipleFilesToAws(files.backImage),
    ]);

    const frontImageUrl = frontUpload.images[0];
    const backImageUrl = backUpload.images[0];

    if (!frontImageUrl || !backImageUrl) {
      throw new Error("Driving license upload failed");
    }

    const kyc = await DriverKycService.upsertDriverKyc(
      new Types.ObjectId(driverId),
      {
        drivingLicense: {
          number: licenseNumber,
          issueDate: "",
          expiryDate,
          frontImage: frontImageUrl,
          backImage: backImageUrl,
        },
        status: "documents_uploaded",
      }
    );

    req.rData = kyc;
    req.msg = "driving_license_uploaded";
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Upload Selfie
 */
export const uploadSelfie = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = (req as any).driverId;

    const files = req.files as {
      selfieImage?: Express.Multer.File[];
    };

    if (!files?.selfieImage?.length) {
      req.rCode = 0;
      req.msg = "selfie_required";
      return next();
    }

    const upload = await fileUploadService.uploadFileToAws(files.selfieImage);

    const selfieUrl = upload.images;

    if (!selfieUrl) {
      throw new Error("Selfie upload failed");
    }

    const kyc = await DriverKycService.upsertDriverKyc(
      new Types.ObjectId(driverId),
      { selfie: selfieUrl }
    );

    req.rData = kyc;
    req.msg = "selfie_uploaded";
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Upload RC (Registration Certificate)
 */
export const uploadRC = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = (req as any).driverId;

    if (!req.file) {
      req.rCode = 0;
      req.msg = "rc_image_required";
      return next();
    }

    // upload.single → req.file
    const upload = await fileUploadService.uploadFileToAws([req.file]);

    const rcImageUrl = upload.images;

    if (!rcImageUrl) {
      throw new Error("RC upload failed");
    }

    const kyc = await DriverKycService.upsertDriverKyc(
      new Types.ObjectId(driverId),
      {
        vehicleRc: {
          image: rcImageUrl,
          vehicleNumber: req.body.vehicleNumber,
        },
      }
    );

    req.rData = kyc;
    req.msg = "rc_uploaded";
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Add Vehicle - Step 5
 */
export const addVehicle = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => addVehicle");

  const driverId = (req as any).driverId;
  const {
    vehicleTypeId,
    registrationNumber,
    driverName,
    driverPhoneNumber,
    uploadDrivingLicense,
    uploadDriverPhoto,
    selectVehicleBody,
    selectVehicleModel,
  } = req.body;

  // Check if registration number already exists
  const exists = await DriverVehicleService.checkRegistrationExists(
    registrationNumber
  );

  if (exists) {
    req.rCode = 0;
    req.msg = "registration_number_exists";
    return next();
  }

  const vehicle = await DriverVehicleService.addDriverVehicle({
    driverId: new Types.ObjectId(driverId),
    vehicleTypeId: new Types.ObjectId(vehicleTypeId),
    registrationNumber,
  });

  // Update driver status to vehicle_added
  await DriverService.updateDriverStatus(driverId, "vehicle_added");

  req.rData = vehicle;
  req.msg = "vehicle_added";
  next();
};

/**
 * Submit for Verification - Final Step
 */
export const submitForVerification = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => submitForVerification");

  const driverId = (req as any).driverId;

  // Check if all requirements are met
  const driver = await DriverService.getDriverById(driverId);
  const kycComplete = await DriverKycService.isKycComplete(
    new Types.ObjectId(driverId)
  );
  const vehicle = await DriverVehicleService.getActiveDriverVehicle(
    new Types.ObjectId(driverId)
  );

  if (!driver?.fullName) {
    req.rCode = 0;
    req.msg = "personal_info_incomplete";
    return next();
  }

  if (!kycComplete) {
    req.rCode = 0;
    req.msg = "kyc_incomplete";
    return next();
  }

  if (!vehicle) {
    req.rCode = 0;
    req.msg = "vehicle_not_added";
    return next();
  }

  // Update status to under_verification
  await DriverService.updateDriverStatus(driverId, "under_verification");

  req.rData = { status: "under_verification" };
  req.msg = "submitted_for_verification";
  next();
};

/**
 * Get Driver Onboarding Status
 */
export const getOnboardingStatus = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => getOnboardingStatus");

  const driverId = (req as any).driverId;

  const driver = await DriverService.getDriverById(driverId);
  const kyc = await DriverKycService.getDriverKyc(new Types.ObjectId(driverId));
  const vehicle = await DriverVehicleService.getActiveDriverVehicle(
    new Types.ObjectId(driverId)
  );

  const kycComplete = await DriverKycService.isKycComplete(
    new Types.ObjectId(driverId)
  );

  req.rData = {
    driver,
    kyc,
    vehicle,
    kycComplete,
    currentStep: getCurrentStep(driver, kycComplete, vehicle),
  };
  req.msg = "success";
  next();
};

/**
 * Helper function to determine current onboarding step
 */
function getCurrentStep(
  driver: any,
  kycComplete: boolean,
  vehicle: any
): string {
  if (!driver?.fullName) return "personal_info";
  if (!kycComplete) return "kyc_documents";
  if (!vehicle) return "vehicle_info";
  if (driver.status === "vehicle_added") return "ready_for_verification";
  return driver.status;
}

/**
 * Resend OTP
 */
export const resendDriverOtp = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => resendDriverOtp");

  const { mobileNumber, countryCode = "+91" } = req.body;

  const otp = helpers().generateOTP();
  const newTxnId = uuidv4();

  const otpData = {
    txnId: newTxnId,
    mobileNumber,
    countryCode,
    otp,
    reason: "DRIVER OTP RESEND",
    is_active: 1,
    date_created: new Date(),
    date_modified: new Date(),
  };

  await redis().SetRedis(`DRIVER|txnId:${newTxnId}`, otpData, 600);
  await redis().SetRedis(`DRIVER|Mob:${mobileNumber}`, otpData, 600);

  const driver = await DriverService.getDriverByMobile(
    mobileNumber,
    countryCode
  );

  sendOtpSms(mobileNumber, String(otp), "vendors", countryCode).catch((e) =>
    console.error("[SMS] driver resend failed:", e),
  );

  req.rData = {
    driverRegistered: !!driver,
    txnId: newTxnId,
  };

  req.msg = "otp_sent";
  next();
};

/**
 * Driver Logout
 */
export const driverLogout = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => driverLogout");

  const driverId = (req as any).driverId;

  // Update driver to offline
  await DriverService.updateDriver(driverId, {
    isOnline: false,
  });

  req.msg = "logout_success";
  next();
};

/**
 * Update Driver FCM Token
 */
export const updateFcmToken = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.log("DriverAuthController => updateFcmToken");

  const driverId = (req as any).driverId;
  const { fcmToken, deviceType, deviceId, appVersion } = req.body;

  await DriverService.updateDriver(driverId, {
    fcmToken,
    deviceType,
    deviceId,
    appVersion,
  });

  req.msg = "token_updated";
  req.rData = {};
  next();
};
