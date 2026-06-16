import { useState, useEffect, useCallback } from "react";
import { Eye } from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Table, Pagination } from "../components";
import { Modal } from "../components/Modal";
import api from "../services/api";

interface DeliveryUser {
  _id: string;
  fullName: string;
  mobileNumber: string;
}

interface DeliveryStop {
  address: string;
  contactName: string;
  contactPhone: string;
  status: string;
  completedAt?: string;
}

interface Delivery {
  _id: string;
  userId: DeliveryUser;
  driverId?: DeliveryUser;
  deliveryType: string;
  packageDescription?: string;
  packageSize?: string;
  pickup: { address: string; contactName: string; contactPhone: string };
  drops: DeliveryStop[];
  totalDistanceKm: number;
  totalDurationMin: number;
  fare: number;
  finalFare: number;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  createdAt: string;
  deliveredAt?: string;
}

const statusColors: Record<string, "warning" | "info" | "success" | "danger"> = {
  SEARCHING: "warning",
  ASSIGNED: "info",
  PICKED_UP: "info",
  IN_TRANSIT: "warning",
  DELIVERED: "success",
  CANCELLED: "danger",
};

export default function DeliveryBookings() {
  const [deliveries, setDeliveries] = useState<Delivery[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [selected, setSelected] = useState<Delivery | null>(null);
  const limit = 10;

  const fetchDeliveries = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/deliveries", {
        params: { page, limit, status: statusFilter || undefined, sortOrder: "asc" },
      });
      const data = res.data?.data;
      setDeliveries(data?.deliveries || []);
      setTotal(data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to load deliveries");
    } finally {
      setIsLoading(false);
    }
  }, [page, statusFilter]);

  useEffect(() => { fetchDeliveries(); }, [fetchDeliveries]);

  const columns = [
    {
      key: "_id",
      label: "ID",
      render: (val: string) => <span className="text-xs font-mono text-gray-500">#{val.slice(-6)}</span>,
    },
    {
      key: "userId",
      label: "Customer",
      render: (val: DeliveryUser) => (
        <div>
          <p className="font-medium text-gray-900 text-sm">{val?.fullName || "N/A"}</p>
          <p className="text-xs text-gray-500">{val?.mobileNumber || "-"}</p>
        </div>
      ),
    },
    {
      key: "deliveryType",
      label: "Type",
      render: (val: string) => <Badge variant="info">{val}</Badge>,
    },
    {
      key: "pickup",
      label: "Pickup",
      render: (val: { address: string }) => (
        <span className="text-xs text-gray-600 max-w-[150px] truncate block">{val?.address || "-"}</span>
      ),
    },
    {
      key: "finalFare",
      label: "Fare",
      render: (val: number) => <span className="font-medium">₹{val || 0}</span>,
    },
    {
      key: "status",
      label: "Status",
      render: (val: string) => <Badge variant={statusColors[val] || "info"}>{val?.replace(/_/g, " ")}</Badge>,
    },
    {
      key: "paymentStatus",
      label: "Payment",
      render: (val: string) => (
        <Badge variant={val === "PAID" ? "success" : val === "FAILED" ? "danger" : "warning"}>
          {val}
        </Badge>
      ),
    },
    {
      key: "createdAt",
      label: "Date",
      render: (val: string) => val ? new Date(val).toLocaleDateString() : "-",
    },
    {
      key: "_id",
      label: "Action",
      render: (_: string, row: Delivery) => (
        <button onClick={() => setSelected(row)} className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600">
          <Eye className="h-4 w-4" />
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Delivery Orders</h1>
        <p className="mt-1 text-sm text-gray-500">Manage parcel and document deliveries</p>
      </div>

      <div className="flex gap-3">
        <select
          value={statusFilter}
          onChange={(e) => { setStatusFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
        >
          <option value="">All Status</option>
          <option value="SEARCHING">Searching</option>
          <option value="ASSIGNED">Assigned</option>
          <option value="PICKED_UP">Picked Up</option>
          <option value="IN_TRANSIT">In Transit</option>
          <option value="DELIVERED">Delivered</option>
          <option value="CANCELLED">Cancelled</option>
        </select>
      </div>

      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        <Table columns={columns} data={deliveries} isLoading={isLoading} emptyMessage="No delivery orders found" />
        <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
      </div>

      {selected && (
        <Modal title="Delivery Details" onClose={() => setSelected(null)} size="lg">
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <Badge variant={statusColors[selected.status] || "info"}>{selected.status?.replace(/_/g, " ")}</Badge>
              <Badge variant="info">{selected.deliveryType}</Badge>
              {selected.packageSize && <Badge variant="warning">{selected.packageSize}</Badge>}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase mb-1">Customer</p>
                <p className="text-sm font-medium">{selected.userId?.fullName || "N/A"}</p>
                <p className="text-xs text-gray-500">{selected.userId?.mobileNumber}</p>
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase mb-1">Driver</p>
                <p className="text-sm font-medium">{selected.driverId?.fullName || "Not assigned"}</p>
                <p className="text-xs text-gray-500">{selected.driverId?.mobileNumber || "-"}</p>
              </div>
            </div>

            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase mb-2">Pickup</p>
              <div className="bg-green-50 rounded-lg p-3 text-sm">
                <p className="font-medium">{selected.pickup?.address}</p>
                <p className="text-xs text-gray-600 mt-1">{selected.pickup?.contactName} - {selected.pickup?.contactPhone}</p>
              </div>
            </div>

            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase mb-2">Drop Points ({selected.drops?.length || 0})</p>
              <div className="space-y-2">
                {selected.drops?.map((drop, i) => (
                  <div key={i} className="bg-red-50 rounded-lg p-3 text-sm">
                    <div className="flex items-center justify-between">
                      <p className="font-medium">{drop.address}</p>
                      <Badge variant={drop.status === "COMPLETED" ? "success" : "warning"}>{drop.status}</Badge>
                    </div>
                    <p className="text-xs text-gray-600 mt-1">{drop.contactName} - {drop.contactPhone}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4 border-t pt-4">
              <div><p className="text-xs text-gray-500">Distance</p><p className="text-sm font-medium">{selected.totalDistanceKm} km</p></div>
              <div><p className="text-xs text-gray-500">Duration</p><p className="text-sm font-medium">{selected.totalDurationMin} min</p></div>
              <div><p className="text-xs text-gray-500">Fare</p><p className="text-sm font-medium">₹{selected.finalFare}</p></div>
              <div><p className="text-xs text-gray-500">Payment</p><p className="text-sm font-medium">{selected.paymentMethod} - {selected.paymentStatus}</p></div>
              {selected.packageDescription && (
                <div className="col-span-2"><p className="text-xs text-gray-500">Package</p><p className="text-sm">{selected.packageDescription}</p></div>
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
