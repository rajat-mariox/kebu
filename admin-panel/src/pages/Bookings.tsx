import { useState } from "react";
import { Table, Badge, Button } from "../components";
import type { BookingStatus } from "../types";

interface MockBooking {
  _id: string;
  userId: { fullName: string };
  driverId?: { fullName: string };
  pickup: { address: string };
  drop: { address: string };
  distanceKm: number;
  fare: number;
  finalFare: number;
  status: BookingStatus;
  paymentMethod: string;
  paymentStatus: string;
  createdAt: string;
}

const mockBookings: MockBooking[] = [
  {
    _id: "1",
    userId: { fullName: "John Doe" },
    driverId: { fullName: "Mike Smith" },
    pickup: { address: "Andheri Station" },
    drop: { address: "Bandra Kurla Complex" },
    distanceKm: 8.5,
    fare: 250,
    finalFare: 250,
    status: "COMPLETED",
    paymentMethod: "CASH",
    paymentStatus: "PAID",
    createdAt: "2026-01-31T10:30:00Z",
  },
  {
    _id: "2",
    userId: { fullName: "Jane Smith" },
    driverId: { fullName: "Tom Jones" },
    pickup: { address: "Connaught Place" },
    drop: { address: "India Gate" },
    distanceKm: 3.2,
    fare: 120,
    finalFare: 120,
    status: "IN_PROGRESS",
    paymentMethod: "WALLET",
    paymentStatus: "PENDING",
    createdAt: "2026-01-31T11:00:00Z",
  },
  {
    _id: "3",
    userId: { fullName: "Bob Wilson" },
    driverId: undefined,
    pickup: { address: "MG Road" },
    drop: { address: "Electronic City" },
    distanceKm: 15.0,
    fare: 450,
    finalFare: 450,
    status: "SEARCHING",
    paymentMethod: "UPI",
    paymentStatus: "PENDING",
    createdAt: "2026-01-31T11:15:00Z",
  },
];

export default function Bookings() {
  const [bookings] = useState(mockBookings);
  const [isLoading] = useState(false);
  const [statusFilter, setStatusFilter] = useState<string>("all");

  const filteredBookings =
    statusFilter === "all"
      ? bookings
      : bookings.filter((b) => b.status === statusFilter);

  const columns = [
    { header: "ID", accessor: (b: MockBooking) => `#${b._id}` },
    {
      header: "User",
      accessor: (b: MockBooking) => b.userId.fullName,
    },
    {
      header: "Driver",
      accessor: (b: MockBooking) => b.driverId?.fullName || "-",
    },
    {
      header: "Pickup",
      accessor: (b: MockBooking) => b.pickup.address,
    },
    {
      header: "Drop",
      accessor: (b: MockBooking) => b.drop.address,
    },
    {
      header: "Distance",
      accessor: (b: MockBooking) => `${b.distanceKm} km`,
    },
    {
      header: "Fare",
      accessor: (b: MockBooking) => `₹${b.finalFare}`,
    },
    {
      header: "Status",
      accessor: (b: MockBooking) => <Badge>{b.status}</Badge>,
    },
    {
      header: "Payment",
      accessor: (b: MockBooking) => (
        <Badge>{b.paymentStatus}</Badge>
      ),
    },
    {
      header: "Actions",
      accessor: () => (
        <Button size="sm" variant="secondary">
          View Details
        </Button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Bookings</h1>
          <p className="mt-1 text-sm text-gray-500">
            View and manage all ride bookings
          </p>
        </div>
        <div className="flex gap-3">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-md border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none"
          >
            <option value="all">All Status</option>
            <option value="SEARCHING">Searching</option>
            <option value="ASSIGNED">Assigned</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="COMPLETED">Completed</option>
            <option value="CANCELLED">Cancelled</option>
          </select>
          <input
            type="date"
            className="rounded-md border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none"
          />
        </div>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <Table
          columns={columns}
          data={filteredBookings}
          keyExtractor={(booking) => booking._id}
          isLoading={isLoading}
          emptyMessage="No bookings found"
        />
      </div>
    </div>
  );
}
