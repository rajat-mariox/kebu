import User from "../models/Users";
import Driver from "../models/driver.model";
import Booking from "../models/booking.model";
import Delivery from "../models/delivery.model";
import { SupportTicket } from "../models/customer-features.model";

export const globalSearch = async (
  query: string,
  adminPermissions: string[],
  adminRole: string,
) => {
  if (!query || query.length < 2) return { results: [] };

  const isSuper = adminRole === "super_admin";
  const results: any[] = [];
  const searchRegex = new RegExp(query, "i");
  const limit = 5;

  const searches: Promise<void>[] = [];

  // Search Users
  if (isSuper || adminPermissions.includes("users:view")) {
    searches.push(
      User.find({
        $or: [
          { fullName: searchRegex },
          { mobileNumber: searchRegex },
          { email: searchRegex },
        ],
        isDeleted: { $ne: true },
      })
        .select("fullName mobileNumber email isActive")
        .limit(limit)
        .then((users) => {
          users.forEach((u) =>
            results.push({
              type: "user",
              id: u._id,
              title: u.fullName,
              subtitle: u.mobileNumber,
              extra: u.email,
            }),
          );
        }),
    );
  }

  // Search Drivers
  if (isSuper || adminPermissions.includes("drivers:view")) {
    searches.push(
      Driver.find({
        $or: [
          { fullName: searchRegex },
          { mobileNumber: searchRegex },
          { email: searchRegex },
        ],
        isDeleted: { $ne: true },
      })
        .select("fullName mobileNumber status")
        .limit(limit)
        .then((drivers) => {
          drivers.forEach((d) =>
            results.push({
              type: "driver",
              id: d._id,
              title: d.fullName,
              subtitle: d.mobileNumber,
              extra: d.status,
            }),
          );
        }),
    );
  }

  // Search Bookings by ID
  if (isSuper || adminPermissions.includes("bookings:view")) {
    searches.push(
      Booking.find({
        $or: [
          ...(query.match(/^[0-9a-fA-F]{24}$/) ? [{ _id: query }] : []),
          { "pickup.address": searchRegex },
          { "drop.address": searchRegex },
        ],
      })
        .select("status finalFare pickup drop createdAt")
        .limit(limit)
        .then((bookings) => {
          bookings.forEach((b) =>
            results.push({
              type: "booking",
              id: b._id,
              title: `Booking #${b._id.toString().slice(-6)}`,
              subtitle: b.status,
              extra: `₹${b.finalFare}`,
            }),
          );
        }),
    );
  }

  // Search Support Tickets
  searches.push(
    SupportTicket.find({
      $or: [{ subject: searchRegex }, { description: searchRegex }],
    })
      .select("subject status priority")
      .limit(limit)
      .then((tickets) => {
        tickets.forEach((t) =>
          results.push({
            type: "ticket",
            id: t._id,
            title: (t as any).subject,
            subtitle: (t as any).status,
            extra: (t as any).priority,
          }),
        );
      }),
  );

  await Promise.all(searches);

  return { results: results.slice(0, 20) };
};
