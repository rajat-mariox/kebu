import { Types } from "mongoose";
import {
  ISubscriptionPlan,
  UserSubscription,
} from "../models/subscription.model";

export interface ActiveBenefits {
  subscriptionId: Types.ObjectId;
  planId: Types.ObjectId;
  planName: string;
  discountPercentage: number;
  unlimitedDeliveries: boolean;
  freeDeliveriesPerMonth: number;
  freeDeliveriesUsed: number;
  freeDeliveriesRemaining: number;
  priceLockGuarantee: boolean;
  zeroWaitGuarantee: boolean;
  priorityRides: boolean;
  prioritySupportAccess: boolean;
}

const MS_PER_CYCLE_MONTH = 30 * 24 * 60 * 60 * 1000;

/**
 * 0-based index of the 30-day window the subscription is currently in,
 * counting from `startDate`. Month 0 covers days 0–29, month 1 covers days
 * 30–59, etc. This is how we know when to reset the free-delivery counter
 * inside a multi-month subscription (e.g., Quarterly/Annual).
 */
const cycleMonthIndexFor = (startDate: Date): number => {
  const elapsed = Date.now() - startDate.getTime();
  if (elapsed <= 0) return 0;
  return Math.floor(elapsed / MS_PER_CYCLE_MONTH);
};

/**
 * Look up the currently active subscription for a user and return a normalized
 * benefits snapshot. Returns null when no active sub exists or the sub has
 * expired. Callers should treat null as "no benefits applied".
 *
 * Monthly reset: `freeDeliveriesPerMonth` resets every 30 days since
 * `startDate`. The rollover is detected here and persisted atomically so
 * concurrent callers see a consistent counter.
 */
export const getActiveBenefits = async (
  userId: Types.ObjectId | string,
): Promise<ActiveBenefits | null> => {
  const sub = await UserSubscription.findOne({
    userId,
    status: "ACTIVE",
    endDate: { $gte: new Date() },
  }).populate<{ planId: ISubscriptionPlan }>("planId");

  // Guard against unpopulated planId (e.g., when the referenced plan was
  // deleted): populate() leaves the original ObjectId in place, which has no
  // `benefits` field. Treat that as "no active benefits".
  if (
    !sub ||
    !sub.planId ||
    typeof sub.planId !== "object" ||
    !("benefits" in sub.planId)
  ) {
    return null;
  }

  const plan = sub.planId as unknown as ISubscriptionPlan;
  const benefits = plan.benefits || ({} as ISubscriptionPlan["benefits"]);

  // Roll over the per-month counter if we've crossed into a new 30-day window
  // since the last reset. Conditional update prevents racing callers from
  // resetting twice.
  const expectedMonthIndex = cycleMonthIndexFor(sub.startDate);
  const storedMonthIndex = sub.currentCycleMonthIndex || 0;
  let used = Math.max(0, sub.deliveriesUsedThisCycle || 0);
  if (expectedMonthIndex > storedMonthIndex) {
    await UserSubscription.updateOne(
      {
        _id: sub._id,
        currentCycleMonthIndex: { $lt: expectedMonthIndex },
      },
      {
        $set: {
          deliveriesUsedThisCycle: 0,
          currentCycleMonthIndex: expectedMonthIndex,
        },
      },
    );
    used = 0;
  }

  const freePerMonth = Math.max(0, benefits.freeDeliveriesPerMonth || 0);
  const unlimited = !!benefits.unlimitedDeliveries;

  return {
    subscriptionId: sub._id as Types.ObjectId,
    planId: (plan as any)._id as Types.ObjectId,
    planName: plan.name,
    discountPercentage: Math.max(0, benefits.discountPercentage || 0),
    unlimitedDeliveries: unlimited,
    freeDeliveriesPerMonth: freePerMonth,
    freeDeliveriesUsed: used,
    freeDeliveriesRemaining: unlimited
      ? Number.POSITIVE_INFINITY
      : Math.max(0, freePerMonth - used),
    priceLockGuarantee: !!benefits.priceLockGuarantee,
    zeroWaitGuarantee: !!benefits.zeroWaitGuarantee,
    priorityRides: !!benefits.priorityRides,
    prioritySupportAccess: !!benefits.prioritySupportAccess,
  };
};

/**
 * Apply the subscription discount percentage to a remaining (post-promo)
 * amount. Returns the rupee amount to subtract. Caller is responsible for
 * applying it to the running discount total and recomputing the final fare.
 */
export const computeSubscriptionDiscount = (
  remainingAmount: number,
  benefits: ActiveBenefits | null,
): number => {
  if (!benefits || benefits.discountPercentage <= 0) return 0;
  if (remainingAmount <= 0) return 0;
  const raw = (remainingAmount * benefits.discountPercentage) / 100;
  return Math.round(raw * 100) / 100;
};

/**
 * Mark one free delivery as consumed. Atomically increments the cycle counter
 * so concurrent deliveries cannot both claim the same free slot. No-op when
 * unlimited or when no subscription is active.
 *
 * Returns true when a free delivery was successfully reserved.
 */
export const consumeFreeDelivery = async (
  benefits: ActiveBenefits | null,
): Promise<boolean> => {
  if (!benefits) return false;
  if (benefits.unlimitedDeliveries) {
    // Still increment so we have usage telemetry; failure is non-fatal.
    await UserSubscription.updateOne(
      { _id: benefits.subscriptionId, status: "ACTIVE" },
      { $inc: { deliveriesUsedThisCycle: 1 } },
    );
    return true;
  }
  if (benefits.freeDeliveriesRemaining <= 0) return false;

  // Conditional update: only consume if we are still under the cap. This
  // prevents two concurrent deliveries from both claiming the last free slot.
  const res = await UserSubscription.updateOne(
    {
      _id: benefits.subscriptionId,
      status: "ACTIVE",
      deliveriesUsedThisCycle: { $lt: benefits.freeDeliveriesPerMonth },
    },
    { $inc: { deliveriesUsedThisCycle: 1 } },
  );

  return res.modifiedCount > 0;
};
