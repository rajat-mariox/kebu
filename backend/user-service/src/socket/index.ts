import { Server as SocketIOServer, Socket } from "socket.io";
import { Server as HTTPServer } from "http";
import { createAdapter } from "@socket.io/redis-adapter";
import { createClient } from "redis";
import jwt from "jsonwebtoken";
import { Types } from "mongoose";

import config from "../config";
import * as DriverLocationService from "../services/driver-location.service";
import * as BookingService from "../services/booking.service";
import * as HouseholdService from "../services/household.service";
import * as DriverService from "../services/driver.service";
import * as DriverVehicleService from "../services/driver-vehicle.service";
import * as NotificationService from "../services/notification.service";
import * as ChatService from "../services/chat.service";
import ScratchCard from "../models/scratch-card.model";
import Offer from "../models/offer.model";
import {
  publishDriverLocation,
  publishBookingUpdate,
} from "../mqtt/broker";

interface SocketUser {
  id: string;
  type: "user" | "driver";
  socketId: string;
}

const connectedUsers = new Map<string, SocketUser>();
const connectedDrivers = new Map<string, SocketUser>();
const otpAttempts = new Map<string, number>();

// Mobile sockets drop constantly (app backgrounded, screen off, network
// handover) without the driver actually going offline. Instead of flipping a
// driver offline the instant their socket drops — which yanks their marker off
// every customer's map and can hide an idle-but-online driver — we wait out
// this grace period and cancel it if they reconnect. A genuinely-closed app is
// still marked offline once the grace expires.
const DRIVER_OFFLINE_GRACE_MS = 90 * 1000;
const pendingDriverOffline = new Map<string, NodeJS.Timeout>();
const MAX_OTP_ATTEMPTS = 5;

/**
 * Resolves the customer's socket room id from a booking's `userId` field.
 *
 * Booking queries `.populate("userId", ...)`, so `booking.userId` is a Mongoose
 * document, not an ObjectId. Interpolating it directly (`user_${booking.userId}`)
 * yields the literal "user_[object Object]" — a room nobody is in, so the event
 * is silently dropped and the customer only catches up via the 10s poll. Always
 * route through this helper so real-time events land in the right room.
 */
const userRoom = (userId: any): string => {
  const id = userId?._id ?? userId;
  return `user_${id}`;
};

export const initializeSocket = async (
  httpServer: HTTPServer,
): Promise<SocketIOServer> => {
  const io = new SocketIOServer(httpServer, {
    cors: { origin: "*", methods: ["GET", "POST"] },
    transports: ["websocket", "polling"],
    pingInterval: 30000,
    pingTimeout: 15000,
  });

  // Cross-instance fan-out: any io.emit / io.to(room).emit on one backend
  // process is mirrored to every other process via Redis pub/sub. Required
  // when customer and driver apps connect to different backend instances
  // sharing one Redis.
  try {
    const pubClient = createClient({ url: config.redis.url });
    const subClient = pubClient.duplicate();
    pubClient.on("error", (err) =>
      console.error("Socket.io Redis pub error:", err.message),
    );
    subClient.on("error", (err) =>
      console.error("Socket.io Redis sub error:", err.message),
    );
    await Promise.all([pubClient.connect(), subClient.connect()]);
    io.adapter(createAdapter(pubClient, subClient));
    console.log("🔁 Socket.io Redis adapter attached");
  } catch (err) {
    console.error(
      "⚠️ Socket.io Redis adapter failed to attach — falling back to in-memory adapter (single-instance only):",
      (err as Error).message,
    );
  }

  // Authentication middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    const userType = socket.handshake.auth.userType as "user" | "driver";

    if (!token) return next(new Error("Authentication required"));

    try {
      const decoded = jwt.verify(token, config.auth.jwtSecret) as any;
      socket.data.userId = decoded.userId || decoded.driverId;
      socket.data.userType = userType;
      next();
    } catch {
      next(new Error("Invalid token"));
    }
  });

  io.on("connection", (socket: Socket) => {
    const userId = socket.data.userId;
    const userType = socket.data.userType;

    console.log(`Socket connected: ${userType} - ${userId}`);

    const roomName = `${userType}_${userId}`;
    socket.join(roomName);

    if (userType === "driver") {
      connectedDrivers.set(userId, { id: userId, type: "driver", socketId: socket.id });
      // Reconnected within the grace window — cancel the pending offline so a
      // brief drop doesn't flip them offline after they're already back.
      const pending = pendingDriverOffline.get(userId);
      if (pending) {
        clearTimeout(pending);
        pendingDriverOffline.delete(userId);
      }
    } else {
      connectedUsers.set(userId, { id: userId, type: "user", socketId: socket.id });
      // Shared room for all customers — lets the server fan-out driver
      // availability changes (online/offline) to every booking screen so the
      // nearby-driver markers update in real time instead of on the 30s poll.
      socket.join("customers");
    }

    // ===================================================================
    //  DRIVER EVENTS
    // ===================================================================

    socket.on("driver_online", async (data) => {
      try {
        const { latitude, longitude } = data || {};
        const driverId = new Types.ObjectId(userId);

        await DriverService.updateDriver(driverId, { isOnline: true });
        // Sync vehicle availability — the booking matcher requires an active +
        // online DriverVehicle, not just Driver.isOnline (see service comment).
        await DriverVehicleService.setDriverVehiclesOnline(driverId, true);

        if (latitude != null && longitude != null) {
          await DriverLocationService.updateDriverLocation(driverId, latitude, longitude);

          // Real-time fan-out to customers so the driver's car appears on the
          // booking map instantly. Only broadcast for available cab drivers —
          // a driver who is mid-ride or pending approval shouldn't show up as
          // an available cab. We have coords here, so the marker can be placed.
          const driverDoc = await DriverService.getDriverById(driverId);
          if (
            driverDoc &&
            driverDoc.status === "approved" &&
            !driverDoc.currentBookingId
          ) {
            // Include the driver's vehicle type name so the customer map shows
            // the correct vehicle marker (bike/auto/car) the instant they come
            // online, instead of defaulting to a car until the next poll.
            const activeVehicle =
              await DriverVehicleService.getActiveDriverVehicle(driverId);
            const vt = (activeVehicle as any)?.vehicleTypeId;
            const vehicleType =
              vt && typeof vt === "object" ? vt.name ?? "" : "";

            io.to("customers").emit("driver_status_changed", {
              driverId: userId,
              isOnline: true,
              latitude,
              longitude,
              heading: 0,
              serviceType: driverDoc.serviceType,
              vehicleType,
            });
          }
        } else {
          console.warn(`[Socket] Driver ${userId} went online without coordinates — asking client to send location_update`);
          socket.emit("location_required", { reason: "no_coords_on_online" });
        }

        socket.emit("status_updated", { isOnline: true });
        console.log(`Driver ${userId} is now online`);
      } catch (error) {
        console.error("Error setting driver online:", error);
        socket.emit("error", { message: "Failed to go online" });
      }
    });

    socket.on("driver_offline", async () => {
      try {
        const driverId = new Types.ObjectId(userId);
        await DriverService.updateDriver(driverId, { isOnline: false });
        await DriverVehicleService.setDriverVehiclesOnline(driverId, false);
        // Real-time fan-out: drop this driver's marker from every customer map.
        io.to("customers").emit("driver_status_changed", {
          driverId: userId,
          isOnline: false,
        });
        socket.emit("status_updated", { isOnline: false });
        console.log(`Driver ${userId} is now offline`);
      } catch (error) {
        console.error("Error setting driver offline:", error);
      }
    });

    /**
     * Driver location update — relay to user via Socket.io + MQTT
     */
    socket.on("location_update", async (data) => {
      try {
        const { latitude, longitude, heading, speed } = data;
        const driverId = new Types.ObjectId(userId);

        await DriverLocationService.updateDriverLocation(driverId, latitude, longitude, heading, speed);

        const activeBooking = await BookingService.getActiveDriverBooking(driverId);

        if (activeBooking) {
          const locationPayload = {
            bookingId: activeBooking._id,
            latitude,
            longitude,
            heading,
            speed,
          };

          console.log(
            `[location_update] driver=${userId} → user_${activeBooking.userId} ` +
            `booking=${activeBooking._id} (${latitude},${longitude})`,
          );

          // Socket.io → user
          io.to(userRoom(activeBooking.userId)).emit("driver_location", locationPayload);

          // MQTT → anyone listening on driver/location/{driverId}
          publishDriverLocation(userId, { latitude, longitude, heading, speed, bookingId: activeBooking._id?.toString() });
        } else {
          // No assigned booking — not relayed to any user
          // (uncomment to debug spam): console.log(`[location_update] driver=${userId} no active booking, skipping`);
        }

        // Household service: relay provider location to the household customer
        const activeServiceBooking =
          await HouseholdService.getActiveProviderServiceBooking(driverId);
        if (activeServiceBooking) {
          io.to(userRoom(activeServiceBooking.userId)).emit("provider_location", {
            bookingId: activeServiceBooking._id,
            latitude,
            longitude,
            heading,
            speed,
          });
        }
      } catch (error) {
        console.error("Error updating location:", error);
      }
    });

    /**
     * Driver accepts ride
     */
    socket.on("accept_ride", async (data) => {
      try {
        const { bookingId } = data;
        const driverId = new Types.ObjectId(userId);

        const updatedBooking = await BookingService.assignDriverToBooking(bookingId, driverId);

        if (!updatedBooking) {
          socket.emit("ride_accept_failed", { message: "Ride is no longer available" });
          return;
        }

        await DriverService.updateDriver(driverId, { currentBookingId: new Types.ObjectId(bookingId) });

        const driver = await DriverService.getDriverById(driverId);
        const driverLocation = await DriverLocationService.getDriverLocation(driverId);

        // Resolve the driver's actual vehicle so the customer's live-tracking
        // card shows the real vehicle (name/number/image) instead of static
        // placeholder data — e.g. a Bike booking must not show a car.
        const activeVehicle =
          await DriverVehicleService.getActiveDriverVehicle(driverId);
        const vt = (activeVehicle as any)?.vehicleTypeId;

        const driverInfo = {
          _id: driver?._id,
          fullName: driver?.fullName,
          mobileNumber: driver?.mobileNumber,
          rating: driver?.rating,
          totalRides: (driver as any)?.totalRides ?? 0,
          profileImage: (driver as any)?.profileImage ?? "",
          vehicleName:
            vt && typeof vt === "object" ? vt.name ?? "" : "",
          vehicleImage:
            vt && typeof vt === "object" ? vt.image ?? "" : "",
          vehicleNumber: (activeVehicle as any)?.registrationNumber ?? "",
        };

        // Socket.io → user
        io.to(userRoom(updatedBooking.userId)).emit("ride_accepted", {
          booking: updatedBooking,
          driver: driverInfo,
          driverLocation,
        });

        // MQTT → booking channel
        publishBookingUpdate(bookingId, "ride_accepted", { driver: driverInfo, driverLocation });

        // FCM push → user + persist for in-app notification list
        const user = (updatedBooking as any).userId;
        const acceptedTmpl = NotificationService.NotificationTemplates.rideAccepted(driver?.fullName || "Driver");
        if (user?.fcmToken) {
          await NotificationService.sendRideStatusPush(user.fcmToken, acceptedTmpl, { bookingId });
        }
        await NotificationService.createNotification({
          userId: (updatedBooking as any).userId?._id ?? (updatedBooking as any).userId,
          title: acceptedTmpl.title,
          message: acceptedTmpl.body,
          type: "ORDER",
          data: { bookingId: new Types.ObjectId(bookingId) },
        });

        socket.emit("ride_accepted_confirmed", { booking: updatedBooking });

        // Notify other drivers ride is taken
        const fullBooking = await BookingService.getBookingById(bookingId);
        if (fullBooking?.notifiedDriverIds?.length) {
          fullBooking.notifiedDriverIds.forEach((nid: Types.ObjectId) => {
            if (!nid.equals(driverId)) {
              io.to(`driver_${nid}`).emit("ride_taken", {
                bookingId: fullBooking._id,
                message: "This ride has been accepted by another driver",
              });
            }
          });
        }

        console.log(`Driver ${userId} accepted booking ${bookingId}`);
      } catch (error) {
        console.error("Error accepting ride:", error);
        socket.emit("error", { message: "Failed to accept ride" });
      }
    });

    socket.on("reject_ride", async (data) => {
      const { bookingId, reason } = data;
      console.log(`Driver ${userId} rejected booking ${bookingId}: ${reason}`);
      socket.emit("ride_rejected_confirmed", { bookingId });
    });

    /**
     * Driver arrived at pickup
     */
    socket.on("arrived_at_pickup", async (data) => {
      try {
        const { bookingId } = data;
        const updatedBooking = await BookingService.updateBookingStatus(bookingId, "DRIVER_ARRIVED");

        if (updatedBooking) {
          io.to(userRoom(updatedBooking.userId)).emit("driver_arrived", { booking: updatedBooking });
          publishBookingUpdate(bookingId, "driver_arrived", {});

          // FCM push → user + persist
          const user = (updatedBooking as any).userId;
          const arrivedTmpl = NotificationService.NotificationTemplates.driverArrived();
          if (user?.fcmToken) {
            await NotificationService.sendRideStatusPush(user.fcmToken, arrivedTmpl, { bookingId });
          }
          await NotificationService.createNotification({
            userId: (updatedBooking as any).userId?._id ?? (updatedBooking as any).userId,
            title: arrivedTmpl.title,
            message: arrivedTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });
        }

        socket.emit("status_update_confirmed", { bookingId, status: "DRIVER_ARRIVED" });
      } catch (error) {
        console.error("Error updating arrival:", error);
      }
    });

    /**
     * Driver starts ride (OTP verification)
     */
    socket.on("start_ride", async (data) => {
      try {
        const { bookingId, otp } = data;
        const booking = await BookingService.getBookingById(bookingId);

        if (!booking) {
          socket.emit("error", { message: "Booking not found" });
          return;
        }

        const attempts = otpAttempts.get(bookingId) || 0;
        if (attempts >= MAX_OTP_ATTEMPTS) {
          socket.emit("otp_verification_failed", { message: "Too many OTP attempts. Please contact support." });
          return;
        }

        if (booking.otp !== otp) {
          otpAttempts.set(bookingId, attempts + 1);
          socket.emit("otp_verification_failed", {
            message: `Invalid OTP. ${MAX_OTP_ATTEMPTS - attempts - 1} attempts remaining.`,
          });
          return;
        }

        otpAttempts.delete(bookingId);

        const updatedBooking = await BookingService.updateBookingStatus(bookingId, "IN_PROGRESS");

        io.to(userRoom(booking.userId)).emit("ride_started", { booking: updatedBooking });
        publishBookingUpdate(bookingId, "ride_started", {});

        // FCM push → user + persist
        const user = (booking as any).userId;
        const startedTmpl = NotificationService.NotificationTemplates.rideStarted();
        if (user?.fcmToken) {
          await NotificationService.sendRideStatusPush(user.fcmToken, startedTmpl, { bookingId });
        }
        await NotificationService.createNotification({
          userId: (booking as any).userId?._id ?? (booking as any).userId,
          title: startedTmpl.title,
          message: startedTmpl.body,
          type: "ORDER",
          data: { bookingId: new Types.ObjectId(bookingId) },
        });

        // FCM push → driver + persist (the ride start matters to both parties)
        const driverField = (booking as any).driverId;
        const driverIdValue = driverField?._id ?? driverField;
        if (driverIdValue) {
          const startedDriverTmpl =
            NotificationService.NotificationTemplates.rideStartedDriver();
          // driverField may be populated (has fcmToken) or just an ObjectId.
          if (driverField?.fcmToken) {
            await NotificationService.sendRideStatusPush(
              driverField.fcmToken,
              startedDriverTmpl,
              { bookingId },
            );
          }
          await NotificationService.createNotification({
            driverId: driverIdValue,
            title: startedDriverTmpl.title,
            message: startedDriverTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });
        }

        socket.emit("ride_started_confirmed", { booking: updatedBooking });
      } catch (error) {
        console.error("Error starting ride:", error);
      }
    });

    /**
     * Driver completes ride
     */
    socket.on("complete_ride", async (data) => {
      try {
        const { bookingId } = data;
        const driverId = new Types.ObjectId(userId);

        const updatedBooking = await BookingService.updateBookingStatus(bookingId, "COMPLETED");

        // Cash rides are paid to the driver on completion — mark them PAID now.
        // (Online/UPI rides were already PAID up-front when the booking was made.)
        if (
          (updatedBooking as any)?.paymentMethod === "CASH" &&
          (updatedBooking as any)?.paymentStatus !== "PAID"
        ) {
          await BookingService.updateBooking(bookingId, { paymentStatus: "PAID" });
          (updatedBooking as any).paymentStatus = "PAID";
        }

        await DriverService.updateDriver(driverId, { currentBookingId: undefined });

        if (updatedBooking) {
          io.to(userRoom(updatedBooking.userId)).emit("ride_completed", { booking: updatedBooking });
          publishBookingUpdate(bookingId, "ride_completed", { fare: (updatedBooking as any).finalFare });

          // FCM push → user + persist
          const user = (updatedBooking as any).userId;
          const fare = (updatedBooking as any).finalFare || 0;
          const userCompletedTmpl = NotificationService.NotificationTemplates.rideCompleted(fare);
          if (user?.fcmToken) {
            await NotificationService.sendRideStatusPush(user.fcmToken, userCompletedTmpl, { bookingId });
          }
          await NotificationService.createNotification({
            userId: user?._id ?? (updatedBooking as any).userId,
            title: userCompletedTmpl.title,
            message: userCompletedTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });

          // FCM push → driver + persist
          const driver = (updatedBooking as any).driverId;
          const driverCompletedTmpl = NotificationService.NotificationTemplates.rideCompleteDriver(fare);
          if (driver?.fcmToken) {
            await NotificationService.sendRideStatusPush(driver.fcmToken, driverCompletedTmpl, { bookingId });
          }
          await NotificationService.createNotification({
            driverId: driver?._id ?? (updatedBooking as any).driverId,
            title: driverCompletedTmpl.title,
            message: driverCompletedTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });

          // Auto-issue scratch card (~30% chance)
          try {
            const userIdForCard =
              typeof user === "object" && user?._id ? user._id : (updatedBooking as any).userId;
            if (userIdForCard && Math.random() < 0.3) {
              const roll = Math.random();
              let rewardType: "WALLET_CREDIT" | "DISCOUNT_COUPON" | "BETTER_LUCK";
              let rewardValue = 0;
              let couponCode: string | undefined;
              let title = "Ride Reward";
              if (roll < 0.5) {
                rewardType = "WALLET_CREDIT";
                rewardValue = [10, 20, 30, 50][Math.floor(Math.random() * 4)];
                title = "Wallet Cashback";
              } else if (roll < 0.8) {
                rewardType = "DISCOUNT_COUPON";
                rewardValue = [10, 15, 20, 25][Math.floor(Math.random() * 4)];
                couponCode = `RIDE${Math.random().toString(36).slice(2, 7).toUpperCase()}`;
                title = "Next Ride Discount";
              } else {
                rewardType = "BETTER_LUCK";
                title = "Surprise!";
              }
              const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
              await ScratchCard.create({
                userId: userIdForCard,
                title,
                rewardType,
                rewardValue,
                couponCode,
                status: "UNSCRATCHED",
                expiresAt,
                sourceType: "RIDE_COMPLETION",
                sourceRef: bookingId,
              });
              // For a discount coupon, also create a matching (user-specific,
              // single-use) Offer so the code is redeemable via the promo flow.
              // Tagged "SCRATCH" so it stays out of the public Offers banner.
              if (rewardType === "DISCOUNT_COUPON" && couponCode) {
                await Offer.create({
                  title: "Scratch Card Discount",
                  description: `${rewardValue}% off your next ride`,
                  code: couponCode,
                  type: "PERCENTAGE",
                  value: rewardValue,
                  applicableOn: "CAB",
                  section: "just_for_you",
                  targetService: "booking",
                  startDate: new Date(),
                  endDate: expiresAt,
                  usageLimit: 1,
                  perUserLimit: 1,
                  isForAllUsers: false,
                  targetUserIds: [userIdForCard],
                  tag: "SCRATCH",
                  isActive: true,
                });
              }
              if (user?.fcmToken) {
                await NotificationService.sendRideStatusPush(
                  user.fcmToken,
                  { title: "You earned a Scratch Card!", body: "Tap to reveal your surprise reward." },
                  { bookingId, type: "SCRATCH_CARD" },
                );
              }
            }
          } catch (cardErr) {
            console.error("Error issuing scratch card:", cardErr);
          }
        }

        socket.emit("ride_completed_confirmed", { booking: updatedBooking });
      } catch (error) {
        console.error("Error completing ride:", error);
      }
    });

    /**
     * Driver cancels ride
     */
    socket.on("cancel_ride_driver", async (data) => {
      try {
        const { bookingId, reason } = data;
        const driverId = new Types.ObjectId(userId);

        const booking = await BookingService.getBookingById(bookingId);
        if (!booking || booking.driverId?.toString() !== driverId.toString()) {
          socket.emit("error", { message: "Unauthorized to cancel this ride" });
          return;
        }

        const updatedBooking = await BookingService.cancelBooking(bookingId, "DRIVER", reason);
        await DriverService.updateDriver(driverId, { currentBookingId: undefined });

        if (updatedBooking) {
          io.to(userRoom(updatedBooking.userId)).emit("ride_cancelled", {
            booking: updatedBooking,
            cancelledBy: "DRIVER",
            reason,
          });
          publishBookingUpdate(bookingId, "ride_cancelled", { cancelledBy: "DRIVER", reason });

          // FCM push → user + persist
          const user = (updatedBooking as any).userId;
          const cancelledByDriverTmpl = NotificationService.NotificationTemplates.rideCancelled("driver");
          if (user?.fcmToken) {
            await NotificationService.sendRideStatusPush(user.fcmToken, cancelledByDriverTmpl, { bookingId });
          }
          await NotificationService.createNotification({
            userId: user?._id ?? (updatedBooking as any).userId,
            title: cancelledByDriverTmpl.title,
            message: cancelledByDriverTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });
        }

        socket.emit("ride_cancelled_confirmed", { booking: updatedBooking });
      } catch (error) {
        console.error("Error cancelling ride:", error);
      }
    });

    // ===================================================================
    //  USER EVENTS
    // ===================================================================

    socket.on("cancel_ride_user", async (data) => {
      try {
        const { bookingId, reason } = data;
        const booking = await BookingService.getBookingById(bookingId);
        const updatedBooking = await BookingService.cancelBooking(bookingId, "USER", reason);

        if (booking?.driverId) {
          io.to(`driver_${booking.driverId}`).emit("ride_cancelled", {
            booking: updatedBooking,
            cancelledBy: "USER",
            reason,
          });
          await DriverService.updateDriver(booking.driverId, { currentBookingId: undefined });
          publishBookingUpdate(bookingId, "ride_cancelled", { cancelledBy: "USER", reason });

          // FCM push → driver + persist
          const driver = await DriverService.getDriverById(booking.driverId);
          const cancelledByUserTmpl = NotificationService.NotificationTemplates.rideCancelled("user");
          if ((driver as any)?.fcmToken) {
            await NotificationService.sendRideStatusPush((driver as any).fcmToken, cancelledByUserTmpl, { bookingId });
          }
          await NotificationService.createNotification({
            driverId: booking.driverId,
            title: cancelledByUserTmpl.title,
            message: cancelledByUserTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });

          // Notify the customer too — they cancelled, but a record in their list
          // helps them see the action timeline.
          await NotificationService.createNotification({
            userId: booking.userId as any,
            title: cancelledByUserTmpl.title,
            message: cancelledByUserTmpl.body,
            type: "ORDER",
            data: { bookingId: new Types.ObjectId(bookingId) },
          });
        }

        // Clear the pending request card from every driver that was offered
        // this ride while it was still SEARCHING (buzzer), so it disappears
        // from their app instantly. The assigned driver — if any — was already
        // notified above. Without this, cancelling a SEARCHING ride leaves the
        // request on each notified driver's screen until their 30s timer
        // expires (the REST cancel path does this fan-out, but the socket
        // cancel usually flips the booking to CANCELLED first, so the REST
        // handler bails out before reaching it).
        const assignedDriverId = booking?.driverId?.toString();
        if (Array.isArray(booking?.notifiedDriverIds)) {
          for (const nid of booking.notifiedDriverIds) {
            if (assignedDriverId && nid.toString() === assignedDriverId) continue;
            io.to(`driver_${nid}`).emit("ride_cancelled", {
              bookingId: booking?._id,
              cancelledBy: "USER",
              reason,
            });
          }
        }

        socket.emit("ride_cancelled_confirmed", { booking: updatedBooking });
      } catch (error) {
        console.error("Error cancelling ride:", error);
      }
    });

    // ===================================================================
    //  CHAT EVENTS
    // ===================================================================

    socket.on("send_message", async (data) => {
      try {
        const { bookingId, receiverId, message, type: msgType, attachments } = data;

        const savedMsg = ChatService.saveMessage({
          bookingId,
          senderId: userId,
          senderType: userType as "user" | "driver",
          receiverId,
          message,
          type: msgType || "text",
          attachments,
        });

        // Emit to both parties via Socket.io
        io.to(`user_${receiverId}`).emit("new_message", savedMsg);
        io.to(`driver_${receiverId}`).emit("new_message", savedMsg);
        socket.emit("message_sent", savedMsg);
      } catch (error) {
        console.error("Error sending message:", error);
      }
    });

    socket.on("typing", (data) => {
      const { bookingId, isTyping } = data;
      const receiverType = userType === "user" ? "driver" : "user";
      // Broadcast to booking room
      socket.to(`booking:${bookingId}`).emit("typing", { senderId: userId, isTyping });
    });

    // ===================================================================
    //  SOS EMERGENCY
    // ===================================================================

    socket.on("sos_emergency", async (data) => {
      try {
        const { bookingId, latitude, longitude } = data;
        const booking = await BookingService.getBookingById(bookingId);

        console.log("🚨 SOS EMERGENCY:", { userId, userType, bookingId, latitude, longitude, timestamp: new Date() });

        if (booking) {
          if (userType === "user" && booking.driverId) {
            const driverId = (booking.driverId as any)?._id ?? booking.driverId;
            io.to(`driver_${driverId}`).emit("sos_alert", { bookingId, message: "User triggered SOS" });
          } else if (userType === "driver") {
            io.to(userRoom(booking.userId)).emit("sos_alert", { bookingId, message: "Driver triggered SOS" });
          }

          publishBookingUpdate(bookingId, "sos_emergency", { userId, userType, latitude, longitude });
        }

        socket.emit("sos_confirmed", { message: "Emergency services have been notified" });
      } catch (error) {
        console.error("Error handling SOS:", error);
      }
    });

    // ===================================================================
    //  DISCONNECT
    // ===================================================================

    socket.on("disconnect", async () => {
      console.log(`Socket disconnected: ${userType} - ${userId}`);

      if (userType === "driver") {
        connectedDrivers.delete(userId);
        // Defer marking the driver offline by the grace period (see above), and
        // cancel any earlier pending timer first. If the socket comes back the
        // connect handler clears this, so a transient drop never flips them off.
        const existing = pendingDriverOffline.get(userId);
        if (existing) clearTimeout(existing);
        pendingDriverOffline.set(
          userId,
          setTimeout(async () => {
            pendingDriverOffline.delete(userId);
            // Reconnected in the meantime → still online, nothing to do.
            if (connectedDrivers.has(userId)) return;
            try {
              const driverId = new Types.ObjectId(userId);
              await DriverService.updateDriver(driverId, { isOnline: false });
              await DriverVehicleService.setDriverVehiclesOnline(driverId, false);
              // Grace expired with no reconnect → remove from customer maps.
              io.to("customers").emit("driver_status_changed", {
                driverId: userId,
                isOnline: false,
              });
            } catch (error) {
              console.error("Error setting driver offline on disconnect:", error);
            }
          }, DRIVER_OFFLINE_GRACE_MS),
        );
      } else {
        connectedUsers.delete(userId);
      }
    });
  });

  return io;
};

// Utility exports
export const getConnectedUsers = () => connectedUsers;
export const getConnectedDrivers = () => connectedDrivers;
export const isUserOnline = (userId: string): boolean => connectedUsers.has(userId);
export const isDriverOnline = (driverId: string): boolean => connectedDrivers.has(driverId);
