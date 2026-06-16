import { useState, useEffect, useCallback } from "react";
import { Search, UserCheck, UserX, Eye, Trash2, Users as UsersIcon } from "lucide-react";
import toast from "react-hot-toast";
import { Table, Badge, Pagination, StatsCard } from "../components";
import { Modal } from "../components/Modal";
import ConfirmDialog from "../components/ConfirmDialog";
import { userService } from "../services";
import type { User } from "../types";

export default function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [userToToggle, setUserToToggle] = useState<User | null>(null);
  const [userToDelete, setUserToDelete] = useState<User | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [stats, setStats] = useState({ total: 0, active: 0, inactive: 0, newThisMonth: 0 });
  const limit = 10;

  const fetchUsers = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await userService.getAll({
        page,
        limit,
        search: search || undefined,
        isActive: statusFilter === "active" ? true : statusFilter === "inactive" ? false : undefined,
        sortBy: "createdAt",
        sortOrder: "asc",
      });
      const data = res.data as any;
      setUsers(data?.users || data?.items || []);
      setTotal(data?.total || data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to fetch users");
    } finally {
      setIsLoading(false);
    }
  }, [page, search, statusFilter]);

  const fetchStats = async () => {
    try {
      const res = await userService.getStats();
      setStats(res.data || { total: 0, active: 0, inactive: 0, newThisMonth: 0 });
    } catch { /* ignore */ }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const handleToggleStatus = async () => {
    if (!userToToggle) return;
    setActionLoading(true);
    try {
      await userService.toggleStatus(userToToggle._id, !userToToggle.isActive);
      toast.success(
        userToToggle.isActive ? "User deactivated" : "User activated",
      );
      setUserToToggle(null);
      fetchUsers();
      fetchStats();
    } catch {
      toast.error("Action failed");
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!userToDelete) return;
    setActionLoading(true);
    try {
      await userService.delete(userToDelete._id);
      toast.success("User deleted");
      setUserToDelete(null);
      fetchUsers();
      fetchStats();
    } catch {
      toast.error("Delete failed");
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: "fullName",
      label: "User",
      render: (val: string, row: User) => (
        <div className="flex items-center gap-3">
          <div className="h-8 w-8 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white text-xs font-semibold">
            {val?.charAt(0)?.toUpperCase() || "?"}
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
      render: (val: string, row: User) =>
        `${row.countryCode || "+91"} ${val || "-"}`,
    },
    { key: "gender", label: "Gender" },
    {
      key: "isActive",
      label: "Status",
      render: (val: boolean) => (
        <Badge variant={val ? "success" : "danger"}>
          {val ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "createdAt",
      label: "Joined",
      render: (val: string) =>
        val ? new Date(val).toLocaleDateString() : "-",
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: User) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => setSelectedUser(row)}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
            title="View"
          >
            <Eye className="h-4 w-4" />
          </button>
          <button
            onClick={() => setUserToToggle(row)}
            className={`rounded-lg p-1.5 transition-colors ${
              row.isActive
                ? "text-gray-400 hover:bg-red-50 hover:text-red-600"
                : "text-gray-400 hover:bg-green-50 hover:text-green-600"
            }`}
            title={row.isActive ? "Deactivate" : "Activate"}
          >
            {row.isActive ? (
              <UserX className="h-4 w-4" />
            ) : (
              <UserCheck className="h-4 w-4" />
            )}
          </button>
          <button
            onClick={() => setUserToDelete(row)}
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
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Users</h1>
        <p className="mt-1 text-sm text-gray-500">
          Manage all registered users
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatsCard title="Total Users" value={stats.total} icon={UsersIcon} color="blue" />
        <StatsCard title="Active" value={stats.active} icon={UserCheck} color="green" />
        <StatsCard title="Inactive" value={stats.inactive} icon={UserX} color="red" />
        <StatsCard title="New This Month" value={stats.newThisMonth} icon={UsersIcon} color="purple" />
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="search"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(0);
            }}
            placeholder="Search by name, email, or mobile..."
            className="w-full rounded-lg border border-gray-300 pl-10 pr-4 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(0);
          }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none"
        >
          <option value="">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      {/* Table */}
      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        <Table columns={columns} data={users} isLoading={isLoading} emptyMessage="No users found" />
        <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
      </div>

      {/* View User Modal */}
      {selectedUser && (
        <UserDetailModal user={selectedUser} onClose={() => setSelectedUser(null)} />
      )}

      {/* Toggle Status Confirm */}
      {userToToggle && (
        <ConfirmDialog
          title={userToToggle.isActive ? "Deactivate User" : "Activate User"}
          message={`Are you sure you want to ${userToToggle.isActive ? "deactivate" : "activate"} ${userToToggle.fullName}?`}
          confirmLabel={userToToggle.isActive ? "Deactivate" : "Activate"}
          variant={userToToggle.isActive ? "danger" : "warning"}
          isLoading={actionLoading}
          onConfirm={handleToggleStatus}
          onCancel={() => setUserToToggle(null)}
        />
      )}

      {/* Delete Confirm */}
      {userToDelete && (
        <ConfirmDialog
          title="Delete User"
          message={`Are you sure you want to delete ${userToDelete.fullName}? This action cannot be undone.`}
          confirmLabel="Delete"
          variant="danger"
          isLoading={actionLoading}
          onConfirm={handleDelete}
          onCancel={() => setUserToDelete(null)}
        />
      )}
    </div>
  );
}

function UserDetailModal({ user, onClose }: { user: User; onClose: () => void }) {
  return (
    <Modal title="User Details" onClose={onClose} size="lg">
      <div className="space-y-4">
        <div className="flex items-center gap-4">
          <div className="h-16 w-16 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white text-xl font-bold">
            {user.fullName?.charAt(0)?.toUpperCase() || "?"}
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">
              {user.fullName || "N/A"}
            </h3>
            <p className="text-sm text-gray-500">{user.email || "No email"}</p>
            <Badge variant={user.isActive ? "success" : "danger"}>
              {user.isActive ? "Active" : "Inactive"}
            </Badge>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 border-t pt-4">
          <InfoField label="Mobile" value={`${user.countryCode || "+91"} ${user.mobileNumber}`} />
          <InfoField label="Gender" value={user.gender || "Not specified"} />
          <InfoField label="Date of Birth" value={user.dob || "Not provided"} />
          <InfoField label="Referral Code" value={user.referralCode || "N/A"} />
          <InfoField label="Joined" value={new Date(user.createdAt).toLocaleDateString()} />
          <InfoField label="Last Updated" value={new Date(user.updatedAt).toLocaleDateString()} />
        </div>
      </div>
    </Modal>
  );
}

function InfoField({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">
        {label}
      </p>
      <p className="mt-1 text-sm text-gray-900">{value}</p>
    </div>
  );
}
