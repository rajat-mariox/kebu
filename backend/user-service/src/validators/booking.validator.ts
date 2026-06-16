import { Request, Response, NextFunction } from "express";
import { Validator } from "node-input-validator";

const BookingValidator = () => {
  const validateFareEstimate = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      pickupLat: "required|numeric",
      pickupLng: "required|numeric",
      dropLat: "required|numeric",
      dropLng: "required|numeric",
      vehicleTypeId: "required|string",
    });

    const matched = await v.check();

    if (!matched) {
      return res.status(400).json({
        code: 0,
        message: "Validation failed",
        errors: v.errors,
      });
    }

    next();
  };

  const validateFareEstimateAll = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      pickupLat: "required|numeric",
      pickupLng: "required|numeric",
      dropLat: "required|numeric",
      dropLng: "required|numeric",
    });

    const matched = await v.check();

    if (!matched) {
      return res.status(400).json({
        code: 0,
        message: "Validation failed",
        errors: v.errors,
      });
    }

    next();
  };

  const validateCreateBooking = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      pickupAddress: "required|string",
      pickupLat: "required|numeric",
      pickupLng: "required|numeric",
      dropAddress: "required|string",
      dropLat: "required|numeric",
      dropLng: "required|numeric",
      vehicleTypeId: "required|string",
      paymentMethod: "in:CASH,WALLET,CARD,UPI",
    });

    const matched = await v.check();

    if (!matched) {
      return res.status(400).json({
        code: 0,
        message: "Validation failed",
        errors: v.errors,
      });
    }

    next();
  };

  const validateRating = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      rating: "required|integer|min:1|max:5",
      feedback: "string",
    });

    const matched = await v.check();

    if (!matched) {
      return res.status(400).json({
        code: 0,
        message: "Validation failed",
        errors: v.errors,
      });
    }

    next();
  };

  return {
    validateFareEstimate,
    validateFareEstimateAll,
    validateCreateBooking,
    validateRating,
  };
};

export default BookingValidator;
