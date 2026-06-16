import { useState, useEffect, useCallback } from "react";
import {
  Search, Eye, Trash2, CheckCircle, XCircle, Ban, Star,
  Car, UserCheck, UserX, Clock, Wifi, FileImage, Plus,
} from "lucide-react";
import toast from "react-hot-toast";
import { Table, Badge, Pagination, StatsCard, DocumentViewer } from "../components";
import { Modal } from "../components/Modal";
import ConfirmDialog from "../components/ConfirmDialog";
import { driverService } from "../services";
import type { Driver, DriverStatus } from "../types";

const statusColors: Record<string, "success" | "warning" | "danger" | "info"> = {
  approved: "success",
  under_verification: "warning",
  documents_uploaded: "warning",
  vehicle_added: "warning",
  draft: "info",
  rejected: "danger",
  suspended: "danger",
};

export default function Drivers() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [serviceTypeFilter, setServiceTypeFilter] = useState<string>("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [stats, setStats] = useState({ total: 0, approved: 0, pending: 0, online: 0, suspended: 0 });
  const [selectedDriver, setSelectedDriver] = useState<Driver | null>(null);
  const [actionDriver, setActionDriver] = useState<{ driver: Driver; action: string } | null>(null);
  const [reason, setReason] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [driverToDelete, setDriverToDelete] = useState<Driver | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [addForm, setAddForm] = useState({
    mobileNumber: "",
    fullName: "",
    email: "",
    serviceType: "cab" as "cab" | "cleaning" | "parcel",
    city: "",
  });
  const [addLoading, setAddLoading] = useState(false);
  const limit = 10;

  const fetchDrivers = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await driverService.getAll({
        page,
        limit,
        search: search || undefined,
        status: (statusFilter as DriverStatus) || undefined,
        sortBy: "createdAt",
        sortOrder: "asc",
      });
      const data = res.data as any;
      let list: Driver[] = data?.drivers || data?.items || [];

      // Client-side filter by serviceType since backend may not support it yet
      if (serviceTypeFilter) {
        list = list.filter((d: any) => d.serviceType === serviceTypeFilter);
      }

      setDrivers(list);
      setTotal(serviceTypeFilter ? list.length : (data?.total || data?.pagination?.total || 0));
    } catch {
      toast.error("Failed to fetch vendors");
    } finally {
      setIsLoading(false);
    }
  }, [page, search, statusFilter, serviceTypeFilter]);

  const fetchStats = async () => {
    try {
      const res = await driverService.getStats();
      setStats(res.data || { total: 0, approved: 0, pending: 0, online: 0, suspended: 0 });
    } catch { /* ignore */ }
  };

  useEffect(() => { fetchStats(); }, []);
  useEffect(() => { fetchDrivers(); }, [fetchDrivers]);

  const handleAction = async () => {
    if (!actionDriver) return;
    setActionLoading(true);
    try {
      const { driver, action } = actionDriver;
      if (action === "approve") {
        await driverService.approve(driver._id);
        toast.success(`${driver.fullName} approved`);
      } else if (action === "reject") {
        if (!reason.trim()) { toast.error("Please provide a reason"); setActionLoading(false); return; }
        await driverService.reject(driver._id, reason);
        toast.success(`${driver.fullName} rejected`);
      } else if (action === "suspend") {
        if (!reason.trim()) { toast.error("Please provide a reason"); setActionLoading(false); return; }
        await driverService.suspend(driver._id, reason);
        toast.success(`${driver.fullName} suspended`);
      } else if (action === "activate") {
        await driverService.activate(driver._id);
        toast.success(`${driver.fullName} activated`);
      }
      setActionDriver(null);
      setReason("");
      fetchDrivers();
      fetchStats();
    } catch {
      toast.error("Action failed");
    } finally {
      setActionLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!/^[6-9]\d{9}$/.test(addForm.mobileNumber)) {
      toast.error("Enter a valid 10-digit mobile number");
      return;
    }
    setAddLoading(true);
    try {
      await driverService.create({
        mobileNumber: addForm.mobileNumber,
        fullName: addForm.fullName,
        email: addForm.email,
        serviceType: addForm.serviceType,
        city: addForm.city,
      });
      toast.success("Vendor created");
      setShowAdd(false);
      setAddForm({ mobileNumber: "", fullName: "", email: "", serviceType: "cab", city: "" });
      fetchDrivers();
      fetchStats();
    } catch (err: unknown) {
      const errorObj = err as { response?: { data?: { message?: string } } };
      const msg = errorObj?.response?.data?.message;
      if (msg === "driver_already_exists") toast.error("A vendor with this mobile already exists");
      else if (msg === "invalid_mobile_number") toast.error("Invalid mobile number");
      else toast.error("Failed to create vendor");
    } finally {
      setAddLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!driverToDelete) return;
    setActionLoading(true);
    try {
      await driverService.delete(driverToDelete._id);
      toast.success("Vendor deleted");
      setDriverToDelete(null);
      fetchDrivers();
      fetchStats();
    } catch {
      toast.error("Delete failed");
    } finally {
      setActionLoading(false);
    }
  };

  const serviceTypeLabel = (type: string) => {
    const labels: Record<string, string> = { cab: "Cab Driver", cleaning: "Cleaning", parcel: "Parcel" };
    return labels[type] || type || "-";
  };

  const columns = [
    {
      key: "fullName",
      label: "Vendor",
      render: (val: string, row: Driver) => (
        <div className="flex items-center gap-3">
          <div className="relative">
            <div className="h-8 w-8 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-white text-xs font-semibold">
              {val?.charAt(0)?.toUpperCase() || "?"}
            </div>
            {row.isOnline && (
              <span className="absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full bg-green-500 border-2 border-white" />
            )}
          </div>
          <div>
            <p className="font-medium text-gray-900">{val || "N/A"}</p>
            <p className="text-xs text-gray-500">{row.email || "-"}</p>
          </div>
        </div>
      ),
    },
    {
      key: "mobileNumber",
      label: "Mobile",
      render: (val: string, row: Driver) => `${row.countryCode || "+91"} ${val || "-"}`,
    },
    {
      key: "serviceType",
      label: "Service",
      render: (val: string) => (
        <Badge variant={val === "cab" ? "info" : val === "cleaning" ? "success" : val === "parcel" ? "warning" : "info"}>
          {serviceTypeLabel(val)}
        </Badge>
      ),
    },
    {
      key: "city",
      label: "City",
      render: (val: string) => val || "-",
    },
    {
      key: "rating",
      label: "Rating",
      render: (val: number) =>
        val > 0 ? (
          <span className="inline-flex items-center gap-1 text-sm text-amber-600 font-medium">
            <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" /> {val.toFixed(1)}
          </span>
        ) : (
          <span className="text-gray-400">-</span>
        ),
    },
    {
      key: "totalRides",
      label: "Jobs",
      render: (val: number) => (
        <span className="font-medium text-gray-700">{val ?? 0}</span>
      ),
    },
    {
      key: "status",
      label: "Status",
      render: (val: string) => (
        <Badge variant={statusColors[val] || "info"}>
          {val?.replace(/_/g, " ") || "Unknown"}
        </Badge>
      ),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: Driver) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => setSelectedDriver(row)}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
            title="View"
          >
            <Eye className="h-4 w-4" />
          </button>
          {(row.status === "under_verification" || row.status === "documents_uploaded" || row.status === "vehicle_added") && (
            <>
              <button
                onClick={() => setActionDriver({ driver: row, action: "approve" })}
                className="rounded-lg p-1.5 text-gray-400 hover:bg-green-50 hover:text-green-600 transition-colors"
                title="Approve"
              >
                <CheckCircle className="h-4 w-4" />
              </button>
              <button
                onClick={() => setActionDriver({ driver: row, action: "reject" })}
                className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                title="Reject"
              >
                <XCircle className="h-4 w-4" />
              </button>
            </>
          )}
          {row.status === "approved" && (
            <button
              onClick={() => setActionDriver({ driver: row, action: "suspend" })}
              className="rounded-lg p-1.5 text-gray-400 hover:bg-orange-50 hover:text-orange-600 transition-colors"
              title="Suspend"
            >
              <Ban className="h-4 w-4" />
            </button>
          )}
          {(row.status === "suspended" || row.status === "rejected") && (
            <button
              onClick={() => setActionDriver({ driver: row, action: "activate" })}
              className="rounded-lg p-1.5 text-gray-400 hover:bg-green-50 hover:text-green-600 transition-colors"
              title="Activate"
            >
              <UserCheck className="h-4 w-4" />
            </button>
          )}
          <button
            onClick={() => setDriverToDelete(row)}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
            title="Delete"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Vendors</h1>
          <p className="mt-1 text-sm text-gray-500">Manage all vendors — cab drivers, home service technicians, and parcel delivery</p>
        </div>
        <button
          onClick={() => setShowAdd(true)}
          className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-orange-500 to-rose-500 px-4 py-2 text-sm font-medium text-white shadow-sm hover:shadow-md transition-all"
        >
          <Plus className="h-4 w-4" /> Add Vendor
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <StatsCard title="Total Vendors" value={stats.total} icon={Car} color="blue" />
        <StatsCard title="Approved" value={stats.approved} icon={UserCheck} color="green" />
        <StatsCard title="Pending" value={stats.pending} icon={Clock} color="orange" />
        <StatsCard title="Online" value={stats.online} icon={Wifi} color="purple" />
        <StatsCard title="Suspended" value={stats.suspended} icon={UserX} color="red" />
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="search"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
            placeholder="Search by name, email, or mobile..."
            className="w-full rounded-lg border border-gray-300 pl-10 pr-4 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <select
          value={serviceTypeFilter}
          onChange={(e) => { setServiceTypeFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none"
        >
          <option value="">All Services</option>
          <option value="cab">Cab Drivers</option>
          <option value="cleaning">Home Services</option>
          <option value="parcel">Parcel Delivery</option>
        </select>
        <select
          value={statusFilter}
          onChange={(e) => { setStatusFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none"
        >
          <option value="">All Status</option>
          <option value="approved">Approved</option>
          <option value="under_verification">Under Verification</option>
          <option value="documents_uploaded">Documents Uploaded</option>
          <option value="vehicle_added">Vehicle Added</option>
          <option value="draft">Draft</option>
          <option value="rejected">Rejected</option>
          <option value="suspended">Suspended</option>
        </select>
      </div>

      {/* Table */}
      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        <Table columns={columns} data={drivers} isLoading={isLoading} emptyMessage="No vendors found" />
        <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
      </div>

      {/* Driver Detail Modal */}
      {selectedDriver && (
        <DriverDetailModal driver={selectedDriver} onClose={() => setSelectedDriver(null)} />
      )}

      {/* Action Modal */}
      {actionDriver && (
        <ActionModal
          driver={actionDriver.driver}
          action={actionDriver.action}
          reason={reason}
          setReason={setReason}
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => { setActionDriver(null); setReason(""); }}
        />
      )}

      {/* Delete Confirm */}
      {driverToDelete && (
        <ConfirmDialog
          title="Delete Vendor"
          message={`Are you sure you want to delete ${driverToDelete.fullName}? This action cannot be undone.`}
          confirmLabel="Delete"
          variant="danger"
          isLoading={actionLoading}
          onConfirm={handleDelete}
          onCancel={() => setDriverToDelete(null)}
        />
      )}

      {/* Add Vendor Modal */}
      {showAdd && (
        <Modal title="Add New Vendor" onClose={() => setShowAdd(false)} size="md">
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Mobile Number *</label>
              <input
                type="tel"
                maxLength={10}
                value={addForm.mobileNumber}
                onChange={(e) => setAddForm({ ...addForm, mobileNumber: e.target.value.replace(/\D/g, "") })}
                placeholder="10-digit mobile number"
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Full Name</label>
              <input
                type="text"
                value={addForm.fullName}
                onChange={(e) => setAddForm({ ...addForm, fullName: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                value={addForm.email}
                onChange={(e) => setAddForm({ ...addForm, email: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Service Type</label>
                <select
                  value={addForm.serviceType}
                  onChange={(e) => setAddForm({ ...addForm, serviceType: e.target.value as "cab" | "cleaning" | "parcel" })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none"
                >
                  <option value="cab">Cab Driver</option>
                  <option value="cleaning">Home Services</option>
                  <option value="parcel">Parcel Delivery</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">City</label>
                <input
                  type="text"
                  value={addForm.city}
                  onChange={(e) => setAddForm({ ...addForm, city: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
                />
              </div>
            </div>
            <p className="text-xs text-gray-500">
              The vendor will complete onboarding (documents, vehicle details) when they log in to the driver app with this mobile number.
            </p>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setShowAdd(false)}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={addLoading}
                onClick={handleCreate}
                className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-orange-500 to-rose-500 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
              >
                {addLoading ? "Creating..." : "Create Vendor"}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

// ==================== DOCUMENT LINK (INLINE PREVIEW) ====================

function DocLink({ url, label }: { url: string; label: string }) {
  const [showViewer, setShowViewer] = useState(false);
  if (!url) return null;
  return (
    <>
      <button
        onClick={() => setShowViewer(true)}
        className="inline-flex items-center gap-1 text-sm text-blue-600 hover:text-blue-800 hover:underline"
      >
        <FileImage className="h-3.5 w-3.5" />
        {label}
      </button>
      {showViewer && (
        <DocumentViewer url={url} title={label} onClose={() => setShowViewer(false)} />
      )}
    </>
  );
}

// ==================== DRIVER DETAIL MODAL ====================

interface KycData {
  [key: string]: any;
}

interface VehicleData {
  [key: string]: any;
}

interface PerformanceData {
  acceptanceRate: number;
  cancellationRate: number;
  weeklyEarnings: number;
  codAmount: number;
  totalRides: number;
  rating: number;
  daysSinceLastTrip: number | null;
  documents: { type: string; expiry: string; status: "valid" | "expiring_soon" | "expired" }[];
  appVersion: string;
  deviceModel: string;
}

function DriverDetailModal({ driver, onClose }: { driver: Driver; onClose: () => void }) {
  const [kyc, setKyc] = useState<KycData | null>(null);
  const [vehicle, setVehicle] = useState<VehicleData | null>(null);
  const [performance, setPerformance] = useState<PerformanceData | null>(null);
  const [tab, setTab] = useState<"info" | "kyc" | "vehicle" | "performance">("info");
  const driverAny = driver as any;

  useEffect(() => {
    driverService.getKycDocuments(driver._id)
      .then((r) => {
        const d = r.data as any;
        setKyc(d?.kyc || d || null);
      })
      .catch(() => {});
    driverService.getVehicle(driver._id)
      .then((r) => {
        const d = r.data as any;
        setVehicle(d?.vehicle || d || null);
      })
      .catch(() => {});
    driverService.getPerformance(driver._id)
      .then((r) => {
        setPerformance(r.data || null);
      })
      .catch(() => {});
  }, [driver._id]);

  const onboardingSteps = ["Not Started", "Basic Details", "Driving Licence", "Documents", "Address", "Bank Details", "Vehicle Details", "Vehicle Images"];
  const stepNum = driverAny.onboardingStep || 0;

  const serviceTypeLabel = (type: string) => {
    const labels: Record<string, string> = { cab: "Cab Driver", cleaning: "Home Service Technician", parcel: "Parcel Delivery" };
    return labels[type] || type || "N/A";
  };

  return (
    <Modal title="Vendor Details" onClose={onClose} size="lg">
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="h-16 w-16 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-white text-xl font-bold">
              {driver.fullName?.charAt(0)?.toUpperCase() || "?"}
            </div>
            {driver.isOnline && (
              <span className="absolute bottom-0 right-0 h-4 w-4 rounded-full bg-green-500 border-2 border-white" />
            )}
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{driver.fullName || "N/A"}</h3>
            <p className="text-sm text-gray-500">{driver.email || driver.mobileNumber}</p>
            <div className="flex items-center gap-2 mt-1">
              <Badge variant={statusColors[driver.status] || "info"}>
                {driver.status?.replace(/_/g, " ")}
              </Badge>
              {driverAny.serviceType && (
                <Badge variant="info">{serviceTypeLabel(driverAny.serviceType)}</Badge>
              )}
              {driver.rating > 0 && (
                <span className="inline-flex items-center gap-1 text-sm text-amber-600">
                  <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" /> {driver.rating.toFixed(1)}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Onboarding Progress */}
        {driver.status !== "approved" && stepNum > 0 && (
          <div className="bg-blue-50 rounded-lg p-3">
            <p className="text-xs font-medium text-blue-700 mb-2">Onboarding Progress: Step {stepNum}/5 — {onboardingSteps[stepNum] || "Unknown"}</p>
            <div className="flex gap-1">
              {[1,2,3,4,5].map(s => (
                <div key={s} className={`h-1.5 flex-1 rounded-full ${s <= stepNum ? 'bg-blue-500' : 'bg-blue-200'}`} />
              ))}
            </div>
          </div>
        )}

        {/* Tabs */}
        <div className="flex border-b">
          {(["info", "kyc", "vehicle", "performance"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                tab === t
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
            >
              {t === "info" ? "Info" : t === "kyc" ? "KYC Documents" : t === "vehicle" ? "Vehicle" : "Performance"}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        {tab === "info" && (
          <div className="space-y-4">
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Personal Info</p>
              <div className="grid grid-cols-2 gap-3">
                <InfoField label="Mobile" value={`${driver.countryCode || "+91"} ${driver.mobileNumber}`} />
                <InfoField label="Email" value={driver.email || "N/A"} />
                <InfoField label="Gender" value={driver.gender || "N/A"} />
                <InfoField label="Date of Birth" value={driverAny.dob || "N/A"} />
                <InfoField label="Blood Group" value={driver.bloodGroup || "N/A"} />
                <InfoField label="Emergency Contact" value={driverAny.emergencyContact || "N/A"} />
                <InfoField label="Service Type" value={serviceTypeLabel(driverAny.serviceType)} />
              </div>
            </div>

            {(driverAny.address || driverAny.city || driverAny.state) && (
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Address</p>
                <div className="grid grid-cols-2 gap-3">
                  <InfoField label="Address" value={driverAny.address || "N/A"} />
                  <InfoField label="Apartment" value={driverAny.apartment || "N/A"} />
                  <InfoField label="City" value={driver.city || "N/A"} />
                  <InfoField label="State" value={driver.state || "N/A"} />
                  <InfoField label="Country" value={driverAny.country || "India"} />
                  <InfoField label="ZIP Code" value={driverAny.zipCode || "N/A"} />
                </div>
              </div>
            )}

            {(driverAny.bankName || driverAny.accountNumber) && (
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Bank Details</p>
                <div className="grid grid-cols-2 gap-3">
                  <InfoField label="Bank" value={driverAny.bankName || "N/A"} />
                  <InfoField label="Account Number" value={driverAny.accountNumber || "N/A"} />
                  <InfoField label="IFSC Code" value={driverAny.ifscCode || "N/A"} />
                </div>
              </div>
            )}

            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Stats</p>
              <div className="grid grid-cols-2 gap-3">
                <InfoField label="Total Jobs" value={String(driver.totalRides || 0)} />
                <InfoField label="Rating" value={driver.rating > 0 ? driver.rating.toFixed(1) : "N/A"} />
                <InfoField label="Online" value={driver.isOnline ? "Yes" : "No"} />
                <InfoField label="Joined" value={new Date(driver.createdAt).toLocaleDateString()} />
              </div>
            </div>

            {driver.rejectionReason && (
              <div className="bg-red-50 rounded-lg p-3">
                <p className="text-xs font-semibold text-red-600 mb-1">Rejection Reason</p>
                <p className="text-sm text-red-700">{driver.rejectionReason}</p>
              </div>
            )}
            {driver.suspensionReason && (
              <div className="bg-orange-50 rounded-lg p-3">
                <p className="text-xs font-semibold text-orange-600 mb-1">Suspension Reason</p>
                <p className="text-sm text-orange-700">{driver.suspensionReason}</p>
              </div>
            )}
          </div>
        )}

        {tab === "kyc" && (
          <div className="space-y-4">
            {kyc ? (
              <>
                {kyc?.aadhaar && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Aadhaar Card</p>
                    <div className="grid grid-cols-2 gap-3">
                      <InfoField label="Number" value={kyc.aadhaar.number || "N/A"} />
                      <div />
                      {kyc.aadhaar.frontImage && (
                        <DocLink url={kyc.aadhaar.frontImage} label="View Front Image" />
                      )}
                      {kyc.aadhaar.backImage && (
                        <DocLink url={kyc.aadhaar.backImage} label="View Back Image" />
                      )}
                    </div>
                  </div>
                )}
                {kyc?.pan && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">PAN Card</p>
                    <div className="grid grid-cols-2 gap-3">
                      <InfoField label="Number" value={kyc.pan.number || "N/A"} />
                      {kyc.pan.frontImage && (
                        <DocLink url={kyc.pan.frontImage} label="View Front Image" />
                      )}
                    </div>
                  </div>
                )}
                {kyc?.drivingLicense && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Driving License</p>
                    <div className="grid grid-cols-2 gap-3">
                      <InfoField label="Number" value={kyc.drivingLicense.number || "N/A"} />
                      <InfoField label="Issue Date" value={kyc.drivingLicense.issueDate || "N/A"} />
                      <InfoField label="Expiry Date" value={kyc.drivingLicense.expiryDate || "N/A"} />
                      <div />
                      {kyc.drivingLicense.frontImage && (
                        <DocLink url={kyc.drivingLicense.frontImage} label="View Front Image" />
                      )}
                      {kyc.drivingLicense.backImage && (
                        <DocLink url={kyc.drivingLicense.backImage} label="View Back Image" />
                      )}
                    </div>
                  </div>
                )}
                {kyc?.selfie && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Selfie</p>
                    <DocLink url={kyc.selfie} label="View Selfie" />
                  </div>
                )}
                {kyc?.vehicleRc && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Vehicle RC</p>
                    <div className="grid grid-cols-2 gap-3">
                      <InfoField label="Vehicle Number" value={kyc.vehicleRc.vehicleNumber || "N/A"} />
                      {kyc.vehicleRc.image && (
                        <DocLink url={kyc.vehicleRc.image} label="View RC Image" />
                      )}
                    </div>
                  </div>
                )}
                <div className="flex items-center gap-2 pt-2">
                  <span className={`inline-flex items-center gap-1 text-xs font-medium px-2 py-1 rounded-full ${kyc?.isVerified ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                    {kyc?.isVerified ? 'Verified' : 'Pending Verification'}
                  </span>
                </div>
              </>
            ) : (
              <p className="text-sm text-gray-500">No KYC documents found</p>
            )}
          </div>
        )}

        {tab === "vehicle" && (
          <div className="space-y-3">
            {vehicle ? (
              <div className="grid grid-cols-2 gap-4">
                {Object.entries(vehicle).map(([key, val]) => {
                  if (["_id", "__v", "driverId", "createdAt", "updatedAt"].includes(key)) return null;
                  const value = val as any;
                  if (typeof value === "string" && (value.startsWith("http") || value.includes("s3"))) {
                    return (
                      <div key={key}>
                        <p className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-1">
                          {key.replace(/([A-Z])/g, " $1").trim()}
                        </p>
                        <DocLink url={value} label="View Image" />
                      </div>
                    );
                  }
                  return (
                    <InfoField key={key}
                      label={key.replace(/([A-Z])/g, " $1").trim()}
                      value={typeof value === "object" ? JSON.stringify(value) : String(value ?? "N/A")} />
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-gray-500">No vehicle info found</p>
            )}
          </div>
        )}

        {/* Performance & Risk Tab */}
        {tab === "performance" && (
          <div className="space-y-4">
            {performance ? (
              <>
                {/* Performance Metrics */}
                <div>
                  <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Performance Metrics</p>
                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-lg bg-green-50 p-3">
                      <p className="text-xs text-gray-500">Acceptance Rate</p>
                      <p className={`text-lg font-bold ${performance.acceptanceRate < 70 ? "text-red-600" : "text-green-700"}`}>
                        {performance.acceptanceRate}%
                      </p>
                    </div>
                    <div className="rounded-lg bg-red-50 p-3">
                      <p className="text-xs text-gray-500">Cancellation Rate</p>
                      <p className={`text-lg font-bold ${performance.cancellationRate > 20 ? "text-red-600" : "text-gray-900"}`}>
                        {performance.cancellationRate}%
                      </p>
                    </div>
                    <div className="rounded-lg bg-blue-50 p-3">
                      <p className="text-xs text-gray-500">Weekly Earnings</p>
                      <p className="text-lg font-bold text-blue-700">
                        ₹{performance.weeklyEarnings.toLocaleString()}
                      </p>
                    </div>
                    <div className={`rounded-lg p-3 ${performance.codAmount > 5000 ? "bg-red-50" : "bg-gray-50"}`}>
                      <p className="text-xs text-gray-500">COD Outstanding</p>
                      <p className={`text-lg font-bold ${performance.codAmount > 5000 ? "text-red-600" : "text-gray-900"}`}>
                        ₹{performance.codAmount.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Additional Info */}
                <div className="grid grid-cols-2 gap-3">
                  <InfoField label="Total Rides" value={String(performance.totalRides)} />
                  <InfoField label="Days Since Last Trip" value={performance.daysSinceLastTrip !== null ? String(performance.daysSinceLastTrip) : "N/A"} />
                  <InfoField label="App Version" value={performance.appVersion} />
                  <InfoField label="Device" value={performance.deviceModel} />
                </div>

                {/* Document Compliance */}
                {performance.documents.length > 0 && (
                  <div>
                    <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Document Compliance</p>
                    <div className="space-y-2">
                      {performance.documents.map((doc) => (
                        <div
                          key={doc.type}
                          className={`flex items-center justify-between rounded-lg p-3 ${
                            doc.status === "expired"
                              ? "bg-red-50 border border-red-200"
                              : doc.status === "expiring_soon"
                                ? "bg-amber-50 border border-amber-200"
                                : "bg-green-50 border border-green-200"
                          }`}
                        >
                          <div>
                            <p className="text-sm font-medium text-gray-900">{doc.type}</p>
                            <p className="text-xs text-gray-500">
                              Expires: {new Date(doc.expiry).toLocaleDateString("en-IN")}
                            </p>
                          </div>
                          <span
                            className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                              doc.status === "expired"
                                ? "bg-red-100 text-red-700"
                                : doc.status === "expiring_soon"
                                  ? "bg-amber-100 text-amber-700"
                                  : "bg-green-100 text-green-700"
                            }`}
                          >
                            {doc.status === "expired" ? "Expired" : doc.status === "expiring_soon" ? "Expiring Soon" : "Valid"}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </>
            ) : (
              <div className="flex items-center justify-center py-8">
                <div className="h-5 w-5 animate-spin rounded-full border-2 border-blue-500 border-t-transparent" />
                <span className="ml-2 text-sm text-gray-500">Loading performance data...</span>
              </div>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}

// ==================== ACTION MODAL ====================

function ActionModal({
  driver, action, reason, setReason, isLoading, onConfirm, onCancel,
}: {
  driver: Driver;
  action: string;
  reason: string;
  setReason: (v: string) => void;
  isLoading: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const needsReason = action === "reject" || action === "suspend";
  const titles: Record<string, string> = {
    approve: "Approve Vendor",
    reject: "Reject Vendor",
    suspend: "Suspend Vendor",
    activate: "Activate Vendor",
  };
  const btnColors: Record<string, string> = {
    approve: "bg-green-600 hover:bg-green-700",
    reject: "bg-red-600 hover:bg-red-700",
    suspend: "bg-orange-600 hover:bg-orange-700",
    activate: "bg-blue-600 hover:bg-blue-700",
  };

  return (
    <Modal title={titles[action] || "Action"} onClose={onCancel}>
      <div className="space-y-4">
        <p className="text-sm text-gray-600">
          Are you sure you want to {action} <strong>{driver.fullName}</strong>?
        </p>
        {needsReason && (
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Reason <span className="text-red-500">*</span>
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder={`Why are you ${action}ing this vendor?`}
            />
          </div>
        )}
        <div className="flex justify-end gap-3">
          <button
            onClick={onCancel}
            className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={`px-4 py-2 text-sm text-white rounded-lg ${btnColors[action]} disabled:opacity-50`}
          >
            {isLoading ? "Processing..." : action.charAt(0).toUpperCase() + action.slice(1)}
          </button>
        </div>
      </div>
    </Modal>
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
