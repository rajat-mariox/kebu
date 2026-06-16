import { Request, Response, NextFunction } from "express";
import { Validator } from "node-input-validator";

const DeliveryValidator = () => {
  const validateFareEstimate = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      "pickup.lat": "required|numeric",
      "pickup.lng": "required|numeric",
      drops: "required|array",
      "drops.*.lat": "required|numeric",
      "drops.*.lng": "required|numeric",
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

  const validateCreateDelivery = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      "pickup.address": "required|string",
      "pickup.lat": "required|numeric",
      "pickup.lng": "required|numeric",
      "pickup.contactName": "required|string",
      "pickup.contactPhone": "required|string",
      drops: "required|array",
      "drops.*.address": "required|string",
      "drops.*.lat": "required|numeric",
      "drops.*.lng": "required|numeric",
      "drops.*.contactName": "required|string",
      "drops.*.contactPhone": "required|string",
      vehicleTypeId: "required|string",
      deliveryType: "in:DOCUMENT,PARCEL,FOOD,GROCERY,OTHER",
      deliveryMode: "in:INSTANT,SCHEDULED",
      workers: "integer|min:0",
      paymentMethod: "in:CASH,WALLET,CARD,UPI",
      proofOfDelivery: "in:OTP,SIGNATURE,PHOTO",
      scheduledAt: "string",
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
    validateCreateDelivery,
    validateRating,
  };
};

export default DeliveryValidator;
