import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";
import ScratchCard from "../models/scratch-card.model";
import Wallet from "../models/wallet.model";
import WalletTransaction from "../models/wallet-transaction.model";

// ========== CUSTOMER ENDPOINTS ==========

export const getMyScratchCards = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = (req as any).userId;

  // Auto-expire old unscratched cards
  await ScratchCard.updateMany(
    { userId, status: "UNSCRATCHED", expiresAt: { $lt: new Date() } },
    { status: "EXPIRED" },
  );

  const cards = await ScratchCard.find({ userId })
    .sort({ createdAt: -1 })
    .limit(50);

  req.rData = { cards };
  req.msg = "success";
  next();
};

export const scratchCard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = (req as any).userId;
  const { cardId } = req.params;

  const card = await ScratchCard.findOne({ _id: cardId, userId });
  if (!card) {
    req.rCode = 5;
    req.msg = "scratch_card_not_found";
    return next();
  }
  if (card.status !== "UNSCRATCHED") {
    req.rCode = 0;
    req.msg = "scratch_card_already_used";
    return next();
  }
  if (card.expiresAt < new Date()) {
    card.status = "EXPIRED";
    await card.save();
    req.rCode = 0;
    req.msg = "scratch_card_expired";
    return next();
  }

  card.status = "SCRATCHED";
  card.scratchedAt = new Date();
  await card.save();

  if (card.rewardType === "WALLET_CREDIT" && card.rewardValue > 0) {
    const existing = await Wallet.findOne({ userId: new Types.ObjectId(userId) });
    const balanceBefore = existing?.balance ?? 0;
    const balanceAfter = balanceBefore + card.rewardValue;
    await Wallet.findOneAndUpdate(
      { userId: new Types.ObjectId(userId) },
      { $inc: { balance: card.rewardValue } },
      { upsert: true, new: true },
    );
    await WalletTransaction.create({
      userId: new Types.ObjectId(userId),
      type: "CREDIT",
      amount: card.rewardValue,
      description: `Scratch card reward: ${card.title}`,
      balanceBefore,
      balanceAfter,
      status: "COMPLETED",
      referenceId: card._id!.toString(),
    });
  }

  req.rData = { card };
  req.msg = "scratch_card_revealed";
  next();
};

// ========== ADMIN ENDPOINTS ==========

export const adminListScratchCards = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { userId, status, page = "0", limit = "20" } = req.query;
  const query: any = {};
  if (userId) query.userId = userId;
  if (status) query.status = status;

  const pg = parseInt(page as string) || 0;
  const lim = parseInt(limit as string) || 20;

  const cards = await ScratchCard.find(query)
    .populate("userId", "name phone email")
    .sort({ createdAt: -1 })
    .skip(pg * lim)
    .limit(lim);
  const total = await ScratchCard.countDocuments(query);

  req.rData = { cards, total, page: pg, limit: lim };
  req.msg = "success";
  next();
};

export const adminCreateScratchCard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const {
    userId,
    userIds, // optional: bulk issue
    title,
    description,
    rewardType,
    rewardValue,
    couponCode,
    expiresAt,
    sourceType,
  } = req.body;

  if (!title || !rewardType || !expiresAt) {
    req.rCode = 0;
    req.msg = "missing_required_fields";
    return next();
  }

  const targets: string[] = Array.isArray(userIds) && userIds.length
    ? userIds
    : userId
      ? [userId]
      : [];

  if (targets.length === 0) {
    req.rCode = 0;
    req.msg = "no_target_users";
    return next();
  }

  const docs = targets.map((uid) => ({
    userId: new Types.ObjectId(uid),
    title,
    description,
    rewardType,
    rewardValue: rewardValue ?? 0,
    couponCode,
    expiresAt: new Date(expiresAt),
    sourceType: sourceType || "admin_gift",
    status: "UNSCRATCHED",
  }));

  const created = await ScratchCard.insertMany(docs);

  req.rData = { created: created.length };
  req.msg = "scratch_cards_created";
  next();
};

export const adminDeleteScratchCard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { cardId } = req.params;
  const card = await ScratchCard.findByIdAndDelete(cardId);
  if (!card) {
    req.rCode = 5;
    req.msg = "scratch_card_not_found";
    return next();
  }
  req.rData = {};
  req.msg = "scratch_card_deleted";
  next();
};
