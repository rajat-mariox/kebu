import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import messages, { MessageKey, Lang } from "./messages";
import { Response } from "express";
import config from "../config";

export default function helpers() {
  /**
   * Standard API response
   */
  const resp = (
    response: Response,
    lang: Lang,
    m: MessageKey = "success",
    data: any = {},
    code: number = 1,
  ) => {
    return response.send({
      message: messages(lang)[m],
      data,
      code,
    });
  };

  /**
   * Extract error message
   */
  const getErrorMessage = (errors: any): string => {
    try {
      for (const key in errors) {
        return errors[key]?.message;
      }
    } catch (ex: any) {
      return "Something is wrong, Please try again later !! " + ex.message;
    }
    return "Unknown error";
  };

  /**
   * Create JWT token
   */
  const createJWT = (payload: object): string => {
    return jwt.sign(payload, config.auth.jwtSecret);
  };

  /**
   * Hash password
   */
  const hashPassword = async (password: string): Promise<string> => {
    const salt = await bcrypt.genSalt();
    return await bcrypt.hash(password, salt);
  };

  /**
   * Generate OTP
   */
  const generateOTP = (length: number = 6): number => {
    return Math.floor(
      Math.pow(10, length - 1) + Math.random() * 9 * Math.pow(10, length - 1),
    );
  };

  /**
   * Check password
   */
  const checkPassword = async (
    password: string,
    hash: string,
  ): Promise<boolean> => {
    return await bcrypt.compare(password, hash);
  };

  /**
   * Calculate fare based on distance, duration, and vehicle type
   */
  const calculateFare = (
    distanceKm: number,
    durationMin: number,
    vehicleType: any,
  ) => {
    // Apply minimum distance
    const actualDistance = Math.max(distanceKm, vehicleType.minDistanceKm || 1);

    // Base fare calculation
    const baseFare = vehicleType.baseFare || 0;
    const distanceFare = actualDistance * (vehicleType.perKmRate || 0);
    const timeFare = durationMin * (vehicleType.perMinuteRate || 0);

    // Surge pricing
    const surgeMultiplier = vehicleType.surgeMultiplier || 1;
    const surgeFare =
      surgeMultiplier > 1
        ? (baseFare + distanceFare + timeFare) * (surgeMultiplier - 1)
        : 0;

    // Total fare
    const totalFare = baseFare + distanceFare + timeFare + surgeFare;

    // Round to nearest rupee
    const finalFare = Math.round(totalFare);

    return {
      baseFare: Math.round(baseFare),
      distanceFare: Math.round(distanceFare),
      timeFare: Math.round(timeFare),
      surgeFare: Math.round(surgeFare),
      surgeMultiplier,
      discount: 0,
      finalFare,
    };
  };

  /**
   * Generate referral code
   */
  const generateReferralCode = (prefix: string = "KEBU"): string => {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let code = prefix;
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  };

  return {
    resp,
    getErrorMessage,
    createJWT,
    hashPassword,
    checkPassword,
    generateOTP,
    calculateFare,
    generateReferralCode,
  };
}
