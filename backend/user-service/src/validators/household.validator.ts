import { Request, Response, NextFunction } from "express";
import { Validator } from "node-input-validator";

const HouseholdValidator = () => {
  const validateNearbySearch = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const v = new Validator(req.body, {
      categoryId: "required|string",
      lat: "required|numeric",
      lng: "required|numeric",
      maxDistanceKm: "numeric",
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
    // The app sends a flat address ({ address|fullAddress, lat, lng }); city /
    // pincode aren't always resolvable from a GPS pin, so only the coordinates
    // + a readable address are required. The controller normalises the rest.
    const v = new Validator(req.body, {
      categoryId: "required|string",
      serviceType: "required|string",
      preferredDate: "required|dateFormat:YYYY-MM-DD",
      preferredTimeSlot: "required|string",
      "address.lat": "required|numeric",
      "address.lng": "required|numeric",
      "address.fullAddress": "string",
      "address.address": "string",
      "address.city": "string",
      "address.pincode": "string",
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
    validateNearbySearch,
    validateCreateBooking,
    validateRating,
  };
};

export default HouseholdValidator;
