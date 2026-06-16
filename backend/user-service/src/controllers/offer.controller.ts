import { Request, Response, NextFunction } from "express";

import Offer from "../models/offer.model";

const ALLOWED_SECTIONS = ["latest", "limited", "just_for_you"] as const;
const ALLOWED_TARGET_SERVICES = [
  "booking",
  "cleaning",
  "parcel",
  "none",
] as const;

export const listOffers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { section, targetService, isActive, search } = req.query as Record<
    string,
    string | undefined
  >;

  const query: any = { isDeleted: false };
  if (section) query.section = section;
  if (targetService) query.targetService = targetService;
  if (isActive === "true") query.isActive = true;
  if (isActive === "false") query.isActive = false;
  if (search) {
    const rx = new RegExp(search.trim(), "i");
    query.$or = [{ title: rx }, { description: rx }, { code: rx }];
  }

  const offers = await Offer.find(query)
    .sort({ priority: -1, createdAt: -1 })
    .limit(200);

  req.rData = { offers };
  req.msg = "success";
  next();
};

export const getOfferById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { offerId } = req.params;
  const offer = await Offer.findById(offerId);
  if (!offer || offer.isDeleted) {
    req.rCode = 5;
    req.msg = "offer_not_found";
    return next();
  }
  req.rData = { offer };
  req.msg = "success";
  next();
};

const normalizePayload = (body: any) => {
  const payload: any = { ...body };

  if (payload.section && !ALLOWED_SECTIONS.includes(payload.section)) {
    payload.section = "latest";
  }
  if (
    payload.targetService &&
    !ALLOWED_TARGET_SERVICES.includes(payload.targetService)
  ) {
    payload.targetService = "none";
  }

  if (payload.code) {
    payload.code = String(payload.code).trim().toUpperCase();
    if (!payload.code) delete payload.code;
  } else {
    delete payload.code;
  }

  if (payload.startDate) payload.startDate = new Date(payload.startDate);
  if (payload.endDate) payload.endDate = new Date(payload.endDate);

  return payload;
};

export const createOffer = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const payload = normalizePayload(req.body);

  if (!payload.title || !payload.description) {
    req.rCode = 1;
    req.msg = "title_and_description_required";
    return next();
  }
  if (!payload.startDate || !payload.endDate) {
    req.rCode = 1;
    req.msg = "start_and_end_date_required";
    return next();
  }

  if (payload.code) {
    const existing = await Offer.findOne({ code: payload.code });
    if (existing) {
      req.rCode = 0;
      req.msg = "code_already_exists";
      return next();
    }
  }

  const offer = await Offer.create(payload);
  req.rData = { offer };
  req.msg = "offer_created";
  next();
};

export const updateOffer = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { offerId } = req.params;
  const payload = normalizePayload(req.body);

  const offer = await Offer.findById(offerId);
  if (!offer || offer.isDeleted) {
    req.rCode = 5;
    req.msg = "offer_not_found";
    return next();
  }

  if (payload.code && payload.code !== offer.code) {
    const existing = await Offer.findOne({
      code: payload.code,
      _id: { $ne: offer._id },
    });
    if (existing) {
      req.rCode = 0;
      req.msg = "code_already_exists";
      return next();
    }
  }

  Object.assign(offer, payload);
  await offer.save();

  req.rData = { offer };
  req.msg = "offer_updated";
  next();
};

export const deleteOffer = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { offerId } = req.params;
  const offer = await Offer.findById(offerId);
  if (!offer || offer.isDeleted) {
    req.rCode = 5;
    req.msg = "offer_not_found";
    return next();
  }

  offer.isDeleted = true;
  offer.isActive = false;
  await offer.save();

  req.rData = { offer };
  req.msg = "offer_deleted";
  next();
};

export const toggleOfferStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { offerId } = req.params;
  const offer = await Offer.findById(offerId);
  if (!offer || offer.isDeleted) {
    req.rCode = 5;
    req.msg = "offer_not_found";
    return next();
  }

  offer.isActive = !offer.isActive;
  await offer.save();

  req.rData = { offer };
  req.msg = "offer_status_updated";
  next();
};
