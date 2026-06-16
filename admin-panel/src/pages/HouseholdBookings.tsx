import { useState, useEffect, useCallback } from "react";
import { Eye, Calendar, MapPin } from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Table, Pagination } from "../components";
import { Modal } from "../components/Modal";
import { serviceBookingService, type ServiceBookingFilters } from "../services";

interface ServiceBooking {
  _id: string;
  userId: { _id: string; fullName: string; mobileNumber: string };
  providerId?: { _id: string; name: string; phone: string };
  serviceId: { _id: string; name: string };
  address: { address: string; lat: number; lng: number };
  scheduledDate: string;
  scheduledTime: string;
  status: string;
  finalAmount?: number;
  totalAmount: number;
  paymentStatus: string;
  createdAt: string;
}

const statusColors: Record<string, "warning" | "info" | "success" | "danger" | "secondary"> = {
  PENDING: "warning", CONFIRMED: "info", PROVIDER_ASSIGNED: "info",
  IN_PROGRESS: "info", COMPLETED: "success", CANCELLED: "danger",
};

export default function HouseholdBookings() {
  const [bookings, setBookings] = useState<ServiceBooking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState<ServiceBooking | null>(null);
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(0);
  const limit = 10;
  const [total, setTotal] = useState(0);

  const fetchBookings = useCallback(async () => {
    setIsLoading(true);
    try {
      const filters: ServiceBookingFilters = { page, limit };
      if (status) filters.status = status as ServiceBookingFilters['status'];
      const res = await serviceBookingService.getAll(filters);
      const data = res.data as { items?: ServiceBooking[]; total?: number } | undefined;
      setBookings(data?.items || []);
      setTotal(data?.total || 0);
    } catch {
      toast.error("Failed to fetch bookings");
    } finally {
      setIsLoading(false);
    }
  }, [status, page]);

  useEffect(() => { fetchBookings(); }, [fetchBookings]);

  const handleStatusChange = async (bookingId: string, newStatus: string) => {
    try {
      if (newStatus === "CANCELLED") {
        await serviceBookingService.cancel(bookingId, "Cancelled by admin");
      }
      toast.success("Status updated");
      fetchBookings();
    } catch {
      toast.error("Failed to update status");
    }
  };

  const columns = [
    {
      key: "_id",
      label: "Booking ID",
      render: (val: string) => (
        <span className="font-mono text-xs text-gray-600">#{val.slice(-6).toUpperCase()}</span>
      ),
    },
    {
      key: "userId",
      label: "Customer",
      render: (user: ServiceBooking["userId"]) => (
        <div>
          <p className="font-medium text-gray-900">{user?.fullName || "N/A"}</p>
          <p className="text-xs text-gray-500">{user?.mobileNumber}</p>
        </div>
      ),
    },
    {
      key: "serviceId",
      label: "Service",
      render: (svc: ServiceBooking["serviceId"]) => svc?.name || "N/A",
    },
    {
      key: "scheduledDate",
      label: "Schedule",
      render: (val: string, row: ServiceBooking) => (
        <div className="flex items-center gap-1.5 text-sm">
          <Calendar className="h-3.5 w-3.5 text-gray-400" />
          <span>{new Date(val).toLocaleDateString()}</span>
          <span className="text-gray-400">{row.scheduledTime}</span>
        </div>
      ),
    },
    {
      key: "totalAmount",
      label: "Amount",
      render: (val: number) => <span className="font-medium">₹{val}</span>,
    },
    {
      key: "status",
      label: "Status",
      render: (val: string) => (
        <Badge variant={statusColors[val] || "secondary"}>
          {val?.replace(/_/g, " ")}
        </Badge>
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
      key: "_id",
      label: "Actions",
      render: (_: string, row: ServiceBooking) => (
        <button onClick={() => setSelectedBooking(row)}
          className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors" title="View">
          <Eye className="h-4 w-4" />
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Household Service Bookings</h1>
        <p className="mt-1 text-sm text-gray-500">Manage all household service bookings</p>
      </div>

      <div className="flex flex-wrap gap-3">
        <select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none">
          <option value="">All Status</option>
          <option value="PENDING">Pending</option>
          <option value="CONFIRMED">Confirmed</option>
          <option value="PROVIDER_ASSIGNED">Provider Assigned</option>
          <option value="IN_PROGRESS">In Progress</option>
          <option value="COMPLETED">Completed</option>
          <option value="CANCELLED">Cancelled</option>
        </select>
      </div>

      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        <Table columns={columns} data={bookings} isLoading={isLoading} emptyMessage="No bookings found" />
        <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
      </div>

      {selectedBooking && (
        <BookingDetailsModal
          booking={selectedBooking}
          onClose={() => setSelectedBooking(null)}
          onStatusChange={handleStatusChange}
        />
      )}
    </div>
  );
}

function BookingDetailsModal({
  booking, onClose, onStatusChange,
}: {
  booking: ServiceBooking;
  onClose: () => void;
  onStatusChange: (id: string, status: string) => void;
}) {
  const [newStatus, setNewStatus] = useState(booking.status);

  const handleUpdate = () => {
    if (newStatus !== booking.status) onStatusChange(booking._id, newStatus);
    onClose();
  };

  return (
    <Modal title="Booking Details" onClose={onClose} size="lg">
      <div className="space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <InfoField label="Booking ID" value={`#${booking._id.slice(-6).toUpperCase()}`} />
          <InfoField label="Created" value={new Date(booking.createdAt).toLocaleString()} />
        </div>

        <Section title="Customer">
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Name" value={booking.userId?.fullName || "N/A"} />
            <InfoField label="Phone" value={booking.userId?.mobileNumber || "N/A"} />
          </div>
        </Section>

        <Section title="Service">
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Service" value={booking.serviceId?.name || "N/A"} />
            <InfoField label="Amount" value={`₹${booking.totalAmount}`} />
          </div>
        </Section>

        <Section title="Schedule">
          <div className="grid grid-cols-2 gap-4">
            <InfoField label="Date" value={new Date(booking.scheduledDate).toLocaleDateString()} />
            <InfoField label="Time" value={booking.scheduledTime} />
          </div>
        </Section>

        <Section title="Address">
          <div className="flex items-start gap-2">
            <MapPin className="h-4 w-4 text-gray-400 mt-0.5 shrink-0" />
            <p className="text-sm text-gray-900">{booking.address?.address || "N/A"}</p>
          </div>
        </Section>

        {booking.providerId && (
          <Section title="Provider">
            <div className="grid grid-cols-2 gap-4">
              <InfoField label="Name" value={booking.providerId.name} />
              <InfoField label="Phone" value={booking.providerId.phone} />
            </div>
          </Section>
        )}

        <Section title="Update Status">
          <div className="flex gap-3">
            <select value={newStatus} onChange={(e) => setNewStatus(e.target.value)}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500">
              <option value="PENDING">Pending</option>
              <option value="CONFIRMED">Confirmed</option>
              <option value="PROVIDER_ASSIGNED">Provider Assigned</option>
              <option value="IN_PROGRESS">In Progress</option>
              <option value="COMPLETED">Completed</option>
              <option value="CANCELLED">Cancelled</option>
            </select>
            <button onClick={handleUpdate}
              className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700">
              Update
            </button>
          </div>
        </Section>

        <div className="flex justify-end pt-2">
          <button onClick={onClose}
            className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50">
            Close
          </button>
        </div>
      </div>
    </Modal>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="border-t pt-4">
      <h4 className="font-medium text-gray-900 mb-3">{title}</h4>
      {children}
    </div>
  );
}

function InfoField({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">{label}</p>
      <p className="mt-1 text-sm text-gray-900">{value}</p>
    </div>
  );
}
