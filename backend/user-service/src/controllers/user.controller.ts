import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import * as UserService from "../services/user.service";
import * as UserAddressService from "../services/address.service";
import fileUploadService from "../utils/s3";
import { Express } from "express";
import { SocialProvider } from "../interfaces/users";

export const updateDeviceToken = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { userId, deviceToken, deviceType } = req.body;

  await UserService.updateUsers(userId, { fcmToken: deviceToken, deviceType });

  req.msg = "success";
  req.rData = {};
  next();
};

export const getDetails = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;

  const user = await UserService.fetch(userId);

  if (!user) {
    req.msg = "user_not_found";
    req.rCode = 5;
    req.rData = {};
  } else {
    req.msg = "success";
    req.rData = user;
  }

  next();
};

export const editUser = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;

  if (Array.isArray(req.files) && req.files.length > 0) {
    const images = await fileUploadService.uploadFileToAws(
      req.files as Express.Multer.File[]
    );
    req.body.profileImage = images.images;
  }

  const userData = await UserService.updateUsers(userId, req.body);

  req.rData = {};
  req.msg = "success";
  next();
};

export const getSocialAccounts = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;
  const user = await UserService.fetch(userId);

  req.rData = {
    socialAccounts: user?.socialAccounts || {},
  };
  req.msg = "success";
  next();
};

export const linkSocialAccount = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;
  const {
    provider,
    providerUserId,
    username,
    email,
    avatar,
  }: {
    provider: SocialProvider;
    providerUserId: string;
    username?: string;
    email?: string;
    avatar?: string;
  } = req.body;

  if (!provider || !["google", "facebook", "x"].includes(provider)) {
    req.rCode = 0;
    req.msg = "invalid_provider";
    return next();
  }

  if (!providerUserId || !providerUserId.trim()) {
    req.rCode = 0;
    req.msg = "invalid_social_account";
    return next();
  }

  const updateData: any = {
    [`socialAccounts.${provider}`]: {
      providerUserId: providerUserId.trim(),
      username: username?.trim() || "",
      email: email?.trim() || "",
      avatar: avatar?.trim() || "",
      linkedAt: new Date(),
    },
  };

  const user = await UserService.updateUsers(userId, updateData);

  req.rData = {
    socialAccounts: user?.socialAccounts || {},
  };
  req.msg = "success";
  next();
};

export const unlinkSocialAccount = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;
  const { provider } = req.params as { provider: SocialProvider };

  if (!provider || !["google", "facebook", "x"].includes(provider)) {
    req.rCode = 0;
    req.msg = "invalid_provider";
    return next();
  }

  const updateData: any = {
    [`socialAccounts.${provider}`]: {
      providerUserId: "",
      username: "",
      email: "",
      avatar: "",
      linkedAt: null,
    },
  };

  const user = await UserService.updateUsers(userId, updateData);

  req.rData = {
    socialAccounts: user?.socialAccounts || {},
  };
  req.msg = "success";
  next();
};

/**
 * Address
 */

export const addUserAddress = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { houseNo, area, city, state, pinCode } = req.body;

  req.body.address = `${houseNo}, ${area}, ${city}, ${state} - ${pinCode}`;

  const userId = (req as any).userId;

  req.body.userId = userId;

  let address = await UserAddressService.addUserAddress(req.body);

  req.rData = address;
  req.msg = "success";
  next();
};

export const updateUserAddress = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { id } = req.params;
  const { houseNo, area, city, state, pinCode } = req.body;

  if (houseNo || area || city || state || pinCode) {
    req.body.address = `${houseNo}, ${area}, ${city}, ${state} - ${pinCode}`;
  }

  const updatedAddress = await UserAddressService.updateUserAddress(
    id,
    req.body
  );

  if (!updatedAddress) {
    req.rCode = 5;
    req.msg = "address_not_found";
    return next();
  }

  req.rData = updatedAddress;
  req.msg = "success";
  next();
};

export const getUserAddress = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const rawPage = req.query.page;
  const rawLimit = req.query.limit;
  const rawIsActive = req.query.isActive;

  const page =
    rawPage && rawPage !== "" && rawPage !== "null"
      ? Math.max(Number(rawPage), 1)
      : 1;

  // ✅ Normalize limit
  const limit =
    rawLimit && rawLimit !== "" && rawLimit !== "null"
      ? Math.max(Number(rawLimit), 1)
      : 10;

  const userId = (req as any).userId;

  const query: any = { userId };
  query.isActive = rawIsActive ? rawIsActive : true;

  const data = await UserAddressService.getUserAddress(
    query,
    Number(page),
    Number(limit)
  );

  const total = await UserAddressService.countUserAddress(query);

  req.rData = { page, limit, total, data };
  req.msg = "success";
  next();
};

export const deleteUserAddress = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { id } = req.params;

  await UserAddressService.deleteUserAddress(id);

  req.msg = "success";
  next();
};

export const selectAddress = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;
  const { id } = req.params;

  const query = {
    userId,
    _id: { $ne: new Types.ObjectId(id) },
  };

  const addresses = await UserAddressService.getUserAddress(query, 1, 100);

  for (const item of addresses) {
    await UserAddressService.updateUserAddress(item._id, {
      isSelected: false,
    });
  }

  await UserAddressService.updateUserAddress(id, { isSelected: true });

  req.msg = "success";
  next();
};

export const getUserAddressDetail = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { id } = req.params;

  const address = await UserAddressService.fetch(id);

  req.rData = address;
  req.msg = "success";
  next();
};

export const activateDeactivateNotification = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;

  const user = await UserService.fetch(userId);

  if (user) {
    const notificationAllowed = !user.notificationAllowed;
    await UserService.updateUsers(userId, { notificationAllowed });
  }

  req.msg = "status_changed";
  next();
};

export const updateFcmToken = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = (req as any).userId;
  const { fcmToken, deviceType, deviceId, appVersion } = req.body;

  await UserService.updateUsers(userId, {
    fcmToken,
    deviceType,
    deviceId,
    appVersion,
  });

  req.msg = "token_updated";
  req.rData = {};
  next();
};
