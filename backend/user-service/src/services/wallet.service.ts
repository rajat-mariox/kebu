import Wallet from "../models/wallet.model";
import WalletTransaction from "../models/wallet-transaction.model";
import { Types } from "mongoose";

export const addToWallet = async (
  userId: Types.ObjectId,
  amount: number,
  description?: string,
  referenceId?: string,
) => {
  // 1️⃣ snapshot the prior balance so the transaction row can record before/after
  const prior = await Wallet.findOne({ userId });
  const balanceBefore = prior?.balance ?? 0;

  // 2️⃣ credit the wallet (create on first use)
  const wallet = await Wallet.findOneAndUpdate(
    { userId },
    { $inc: { balance: amount } },
    { new: true, upsert: true },
  );

  // 3️⃣ store transaction. balanceBefore/balanceAfter are required by the
  //    schema; omitting them throws a validation error that previously
  //    surfaced to the client as "payment_verification_failed" even though
  //    the credit had already been applied.
  await WalletTransaction.create({
    userId,
    amount,
    type: "CREDIT",
    referenceId,
    description: description || "Wallet Recharge",
    balanceBefore,
    balanceAfter: wallet?.balance ?? balanceBefore + amount,
  });

  return wallet;
};

export const deductFromWallet = async (
  userId: Types.ObjectId,
  amount: number,
  description?: string,
  referenceId?: string,
) => {
  // Check if wallet exists and has sufficient balance
  const wallet = await Wallet.findOne({ userId });

  if (!wallet || wallet.balance < amount) {
    return null;
  }

  // Deduct from wallet
  const updatedWallet = await Wallet.findOneAndUpdate(
    { userId, balance: { $gte: amount } },
    { $inc: { balance: -amount } },
    { new: true },
  );

  if (updatedWallet) {
    // Store transaction (balanceBefore/balanceAfter are required by the schema)
    await WalletTransaction.create({
      userId,
      amount,
      type: "DEBIT",
      referenceId,
      description: description || "Wallet Deduction",
      balanceBefore: wallet.balance,
      balanceAfter: updatedWallet.balance,
    });
  }

  return updatedWallet;
};

export const getWallet = async (userId: Types.ObjectId) => {
  const wallet = await Wallet.findOne({ userId });

  const transactions = await WalletTransaction.find({ userId })
    .sort({ createdAt: -1 })
    .limit(20);

  return {
    balance: wallet?.balance || 0,
    transactions,
  };
};
