import { useState, useEffect, useCallback } from "react";
import { Badge, Table, Pagination } from "../components";
import { Modal } from "../components/Modal";
import { bookingService } from "../services";
import {
  Eye,
  Calendar,
  Car,
  User,
  Phone,
  CreditCard,
  Clock,
  Navigation,
  X,
} from "lucide-react";
import toast from "react-hot-toast";
import type { BookingStatus } from "../types";

interface BookingUser {
  _id: string;
  fullName: string;
  mobileNumber: string;
}

interface Booking {
  _id: string;
  userId: BookingUser;
  driverId?: BookingUser;
  vehicleTypeId?: {
    _id: string;
    name: string;
  };
  pickup: {
    address: string;
    lat: number;
    lng: number;
  };
  drop: {
    address: string;
    lat: number;
    lng: number;
  };
  distanceKm: number;
  durationMin: number;
  fare: number;
  finalFare: number;
  status: BookingStatus;
  paymentMethod: string;
  paymentStatus: string;
  createdAt: string;
  completedAt?: string;
}

const statusColors: Record<
  string,
  "warning" | "info" | "success" | "danger" | "secondary"
> = {
  SEARCHING: "warning",
  ASSIGNED: "info",
  DRIVER_ARRIVED: "info",
  PICKED: "info",
  IN_PROGRESS: "info",
  COMPLETED: "success",
  CANCELLED: "danger",
};

export default function RideBookings() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [filters, setFilters] = useState<{
    status: BookingStatus | undefined;
    page: number;
    limit: number;
  }>({
    status: undefined,
    page: 0,
    limit: 10,
  });
  const [totalCount, setTotalCount] = useState(0);

  const fetchBookings = useCallback(async () => {
    setIsLoading(true);
    try {
      const response = await bookingService.getAll(filters);
      const data = response.data as { bookings?: Booking[]; items?: Booking[]; total?: number; pagination?: { total?: number } } | undefined;
      setBookings(data?.bookings || data?.items || []);
      setTotalCount(data?.total || data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to load bookings");
    } finally {
      setIsLoading(false);
    }
  }, [filters]);

  useEffect(() => {
    fetchBookings();
  }, [fetchBookings]);

  const columns = [
    {
      key: "_id",
      label: "Booking ID",
      render: (val: string) => (
        <span className="font-mono text-xs font-semibold text-blue-600 bg-blue-50 px-2 py-1 rounded-md">
          #{val.slice(-6).toUpperCase()}
        </span>
      ),
    },
    {
      key: "userId",
      label: "Customer",
      render: (user: Booking["userId"]) => (
        <div className="flex items-center gap-2.5">
          <div className="h-8 w-8 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-xs font-semibold">
            {user?.fullName?.charAt(0)?.toUpperCase() || "?"}
          </div>
          <div>
            <div className="font-medium text-gray-900 text-sm">{user?.fullName || "N/A"}</div>
            <div className="text-xs text-gray-500">{user?.mobileNumber}</div>
          </div>
        </div>
      ),
    },
    {
      key: "driverId",
      label: "Driver",
      render: (driver: Booking["driverId"]) =>
        driver ? (
          <div className="flex items-center gap-2.5">
            <div className="h-8 w-8 rounded-full bg-gradient-to-br from-green-500 to-emerald-600 flex items-center justify-center text-white text-xs font-semibold">
              {driver.fullName?.charAt(0)?.toUpperCase() || "D"}
            </div>
            <div>
              <div className="font-medium text-gray-900 text-sm">{driver.fullName}</div>
              <div className="text-xs text-gray-500">{driver.mobileNumber}</div>
            </div>
          </div>
        ) : (
          <span className="text-xs text-gray-400 italic">Not Assigned</span>
        ),
    },
    {
      key: "pickup",
      label: "Route",
      render: (pickup: Booking["pickup"], row: Booking) => (
        <div className="max-w-xs space-y-1">
          <div className="flex items-center gap-1.5 text-xs">
            <div className="h-1.5 w-1.5 rounded-full bg-green-500 flex-shrink-0" />
            <span className="text-gray-700 truncate">{pickup?.address?.slice(0, 35)}...</span>
          </div>
          <div className="flex items-center gap-1.5 text-xs">
            <div className="h-1.5 w-1.5 rounded-full bg-red-500 flex-shrink-0" />
            <span className="text-gray-500 truncate">{row.drop?.address?.slice(0, 35)}...</span>
          </div>
        </div>
      ),
    },
    {
      key: "distanceKm",
      label: "Distance",
      render: (val: number) => (
        <span className="text-sm font-medium text-gray-700">{val?.toFixed(1)} km</span>
      ),
    },
    {
      key: "finalFare",
      label: "Fare",
      render: (val: number) => (
        <span className="text-sm font-semibold text-gray-900">₹{val}</span>
      ),
    },
    {
      key: "status",
      label: "Status",
      render: (val: string) => (
        <Badge variant={statusColors[val] || "secondary"}>{val}</Badge>
      ),
    },
    {
      key: "paymentStatus",
      label: "Payment",
      render: (val: string) => (
        <Badge variant={val === "PAID" ? "success" : "warning"}>{val}</Badge>
      ),
    },
    {
      key: "createdAt",
      label: "Date",
      render: (val: string) => (
        <div className="flex items-center gap-1.5 text-sm text-gray-500">
          <Calendar className="h-3.5 w-3.5" />
          {new Date(val).toLocaleDateString()}
        </div>
      ),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: Booking) => (
        <button
          onClick={() => setSelectedBooking(row)}
          className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
          title="View Details"
        >
          <Eye className="h-4 w-4" />
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Ride Bookings</h1>
          <p className="mt-1 text-sm text-gray-500">Manage all ride bookings</p>
        </div>
        <div className="flex items-center gap-3 text-sm text-gray-500">
          <Car className="h-4 w-4" />
          {totalCount} total bookings
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-4 bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
        <select
          value={filters.status || ""}
          onChange={(e) =>
            setFilters({ ...filters, status: (e.target.value || undefined) as BookingStatus | undefined, page: 0 })
          }
          className="rounded-xl border border-gray-200 px-3.5 py-2.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-colors"
        >
          <option value="">All Status</option>
          <option value="SEARCHING">Searching</option>
          <option value="ASSIGNED">Assigned</option>
          <option value="DRIVER_ARRIVED">Driver Arrived</option>
          <option value="PICKED">Picked</option>
          <option value="IN_PROGRESS">In Progress</option>
          <option value="COMPLETED">Completed</option>
          <option value="CANCELLED">Cancelled</option>
        </select>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center h-64">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent"></div>
          </div>
        ) : (
        <>
          <Table
            columns={columns}
            data={bookings}
            emptyMessage="No bookings found"
          />
          <Pagination
            page={filters.page}
            limit={filters.limit}
            total={totalCount}
            onPageChange={(page) => setFilters({ ...filters, page })}
          />
        </>
        )}
      </div>

      {/* Booking Details Modal */}
      {selectedBooking && (
        <RideDetailsModal
          booking={selectedBooking}
          onClose={() => setSelectedBooking(null)}
        />
      )}
    </div>
  );
}

function InfoField({ label, value, icon: Icon }: { label: string; value: React.ReactNode; icon?: any }) {
  return (
    <div>
      <label className="text-xs font-medium text-gray-400 uppercase tracking-wider">{label}</label>
      <div className="mt-1 flex items-center gap-1.5 text-sm text-gray-900">
        {Icon && <Icon className="h-3.5 w-3.5 text-gray-400" />}
        {value}
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="border-t border-gray-100 pt-5">
      <h4 className="text-sm font-semibold text-gray-900 mb-3">{title}</h4>
      {children}
    </div>
  );
}

interface RideDetailsModalProps {
  booking: Booking;
  onClose: () => void;
}

function RideDetailsModal({ booking, onClose }: RideDetailsModalProps) {
  return (
    <Modal title="Ride Details" onClose={onClose} size="lg">
      <div className="space-y-5">
        {/* Booking Info */}
        <div className="grid grid-cols-2 gap-4">
          <InfoField
            label="Booking ID"
            value={
              <span className="font-mono font-semibold text-blue-600">
                #{booking._id.slice(-6).toUpperCase()}
              </span>
            }
          />
          <InfoField
            label="Status"
            value={
              <Badge variant={statusColors[booking.status] || "secondary"}>
                {booking.status}
              </Badge>
            }
          />
        </div>

        {/* Customer Info */}
        <Section title="Customer Details">
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Name" value={booking.userId?.fullName || "N/A"} icon={User} />
            <InfoField label="Phone" value={booking.userId?.mobileNumber || "N/A"} icon={Phone} />
          </div>
        </Section>

        {/* Driver Info */}
        {booking.driverId && (
          <Section title="Driver Details">
            <div className="grid grid-cols-2 gap-4">
              <InfoField label="Name" value={booking.driverId.fullName} icon={User} />
              <InfoField label="Phone" value={booking.driverId.mobileNumber} icon={Phone} />
            </div>
          </Section>
        )}

        {/* Route Info */}
        <Section title="Route Details">
          <div className="space-y-3 mb-4">
            <div className="flex items-start gap-2.5 p-3 bg-green-50 rounded-xl">
              <div className="h-2 w-2 rounded-full bg-green-500 mt-1.5 flex-shrink-0" />
              <div>
                <span className="text-xs font-medium text-green-700">Pickup</span>
                <p className="text-sm text-gray-900 mt-0.5">{booking.pickup?.address}</p>
              </div>
            </div>
            <div className="flex items-start gap-2.5 p-3 bg-red-50 rounded-xl">
              <div className="h-2 w-2 rounded-full bg-red-500 mt-1.5 flex-shrink-0" />
              <div>
                <span className="text-xs font-medium text-red-700">Drop</span>
                <p className="text-sm text-gray-900 mt-0.5">{booking.drop?.address}</p>
              </div>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Distance" value={`${booking.distanceKm?.toFixed(1)} km`} icon={Navigation} />
            <InfoField label="Duration" value={`${booking.durationMin} min`} icon={Clock} />
          </div>
        </Section>

        {/* Payment Info */}
        <Section title="Payment Details">
          <div className="grid grid-cols-3 gap-4">
            <InfoField label="Fare" value={`₹${booking.fare}`} icon={CreditCard} />
            <InfoField
              label="Final Fare"
              value={<span className="font-semibold text-green-600">₹{booking.finalFare}</span>}
            />
            <InfoField label="Method" value={booking.paymentMethod} icon={CreditCard} />
          </div>
          <div className="mt-3">
            <InfoField
              label="Payment Status"
              value={
                <Badge variant={booking.paymentStatus === "PAID" ? "success" : "warning"}>
                  {booking.paymentStatus}
                </Badge>
              }
            />
          </div>
        </Section>

        {/* Timestamps */}
        <Section title="Timeline">
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Created At" value={new Date(booking.createdAt).toLocaleString()} icon={Calendar} />
            {booking.completedAt && (
              <InfoField label="Completed At" value={new Date(booking.completedAt).toLocaleString()} icon={Calendar} />
            )}
          </div>
        </Section>

        <div className="flex justify-end pt-4 border-t border-gray-100">
          <button
            onClick={onClose}
            className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors"
          >
            <X className="h-4 w-4" />
            Close
          </button>
        </div>
      </div>
    </Modal>
  );
}
