import { useState, useEffect, useCallback } from "react";
import { Badge, Table, ConfirmDialog } from "../components";
import { Modal } from "../components/Modal";
import { adminService, roleService } from "../services";
import {
  ShieldCheck,
  Users,
  UserPlus,
  KeyRound,
  Plus,
  Edit2,
  Trash2,
  ToggleLeft,
  ToggleRight,
  Shield,
  Lock,
  Save,
  X,
  Mail,
  Calendar,
  Clock,
} from "lucide-react";
import toast from "react-hot-toast";
import type { Permission } from "../types";

interface LocalAdmin {
  _id: string;
  name: string;
  email: string;
  role: string;
  permissions: string[];
  isActive: boolean;
  createdAt: string;
  lastLogin?: string;
}

interface LocalRole {
  _id: string;
  name: string;
  permissions: Permission[];
  description?: string;
}

const availablePermissions = [
  { key: "dashboard:view", label: "View Dashboard" },
  { key: "users:view", label: "View Users" },
  { key: "users:edit", label: "Edit Users" },
  { key: "users:delete", label: "Delete Users" },
  { key: "drivers:view", label: "View Drivers" },
  { key: "drivers:edit", label: "Edit Drivers" },
  { key: "drivers:delete", label: "Delete Drivers" },
  { key: "drivers:approve", label: "Approve Drivers" },
  { key: "bookings:view", label: "View Bookings" },
  { key: "bookings:edit", label: "Edit Bookings" },
  { key: "household:view", label: "View Household Services" },
  { key: "household:edit", label: "Edit Household Services" },
  { key: "cms:view", label: "View CMS" },
  { key: "cms:edit", label: "Edit CMS" },
  { key: "admins:view", label: "View Admins" },
  { key: "admins:edit", label: "Edit Admins" },
  { key: "admins:delete", label: "Delete Admins" },
  { key: "settings:view", label: "View Settings" },
  { key: "settings:edit", label: "Edit Settings" },
];

const permissionGroups = [
  { group: "Dashboard", keys: ["dashboard:view"] },
  { group: "Users", keys: ["users:view", "users:edit", "users:delete"] },
  { group: "Drivers", keys: ["drivers:view", "drivers:edit", "drivers:delete", "drivers:approve"] },
  { group: "Bookings", keys: ["bookings:view", "bookings:edit"] },
  { group: "Household", keys: ["household:view", "household:edit"] },
  { group: "CMS", keys: ["cms:view", "cms:edit"] },
  { group: "Admins", keys: ["admins:view", "admins:edit", "admins:delete"] },
  { group: "Settings", keys: ["settings:view", "settings:edit"] },
];

export default function AdminManagement() {
  const [activeTab, setActiveTab] = useState<"admins" | "roles">("admins");
  const [admins, setAdmins] = useState<LocalAdmin[]>([]);
  const [roles, setRoles] = useState<LocalRole[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showAdminModal, setShowAdminModal] = useState(false);
  const [showRoleModal, setShowRoleModal] = useState(false);
  const [editItem, setEditItem] = useState<LocalAdmin | LocalRole | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ type: "admin" | "role"; id: string; name: string } | null>(null);
  const [toggleTarget, setToggleTarget] = useState<{ id: string; name: string; isActive: boolean } | null>(null);

  const fetchAdmins = useCallback(async () => {
    try {
      const response = await adminService.getAll();
      const data = response.data as { items?: LocalAdmin[] } | LocalAdmin[];
      const list = Array.isArray(data) ? data : data?.items || [];
      setAdmins(Array.isArray(list) ? list : []);
    } catch {
      toast.error("Failed to load admins");
    }
  }, []);

  const fetchRoles = useCallback(async () => {
    try {
      const response = await roleService.getAll();
      const data = response.data as LocalRole[] | { roles?: LocalRole[] };
      if (Array.isArray(data)) {
        setRoles(data);
      } else if (data && 'roles' in data) {
        setRoles(data.roles || []);
      } else {
        setRoles([]);
      }
    } catch {
      toast.error("Failed to load roles");
    }
  }, []);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      if (activeTab === "admins") {
        await fetchAdmins();
      } else {
        await fetchRoles();
      }
    } finally {
      setIsLoading(false);
    }
  }, [activeTab, fetchAdmins, fetchRoles]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleAddAdmin = () => {
    setEditItem(null);
    setShowAdminModal(true);
  };

  const handleAddRole = () => {
    setEditItem(null);
    setShowRoleModal(true);
  };

  const handleEditAdmin = (admin: LocalAdmin) => {
    setEditItem(admin);
    setShowAdminModal(true);
  };

  const handleEditRole = (role: LocalRole) => {
    setEditItem(role);
    setShowRoleModal(true);
  };

  const handleToggleStatus = async () => {
    if (!toggleTarget) return;
    try {
      await adminService.toggleStatus(toggleTarget.id);
      toast.success(`Admin ${toggleTarget.isActive ? "disabled" : "enabled"} successfully`);
      setToggleTarget(null);
      fetchData();
    } catch {
      toast.error("Failed to update status");
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      if (deleteTarget.type === "admin") {
        await adminService.delete(deleteTarget.id);
      } else {
        await roleService.delete(deleteTarget.id);
      }
      toast.success(`${deleteTarget.type === "admin" ? "Admin" : "Role"} deleted successfully`);
      setDeleteTarget(null);
      fetchData();
    } catch (err: any) {
      const rawMsg: string =
        err?.response?.data?.message ||
        err?.response?.data?.msg ||
        err?.message ||
        "";
      let friendly = "Failed to delete";
      if (/system/i.test(rawMsg) || rawMsg === "cannot_delete_system_role") {
        friendly = "System roles cannot be deleted";
      } else if (rawMsg === "role_in_use" || /in.use/i.test(rawMsg)) {
        friendly = "This role is assigned to one or more admins — reassign them first";
      } else if (rawMsg) {
        friendly = rawMsg;
      }
      toast.error(friendly);
    }
  };

  const adminColumns = [
    {
      key: "name",
      label: "Admin",
      render: (val: string, row: LocalAdmin) => (
        <div className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-sm font-semibold">
            {val?.charAt(0)?.toUpperCase() || "A"}
          </div>
          <div>
            <div className="font-medium text-gray-900">{val}</div>
            <div className="text-xs text-gray-500 flex items-center gap-1">
              <Mail className="h-3 w-3" />
              {row.email}
            </div>
          </div>
        </div>
      ),
    },
    {
      key: "role",
      label: "Role",
      render: (val: string) => (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-indigo-50 text-indigo-700">
          <Shield className="h-3 w-3" />
          {val || "Admin"}
        </span>
      ),
    },
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
      key: "lastLogin",
      label: "Last Login",
      render: (val: string) => (
        <div className="flex items-center gap-1.5 text-sm text-gray-500">
          <Clock className="h-3.5 w-3.5" />
          {val ? new Date(val).toLocaleString() : "Never"}
        </div>
      ),
    },
    {
      key: "createdAt",
      label: "Created",
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
      render: (_: string, row: LocalAdmin) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => handleEditAdmin(row)}
            className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
            title="Edit"
          >
            <Edit2 className="h-4 w-4" />
          </button>
          <button
            onClick={() => setToggleTarget({ id: row._id, name: row.name || row.email, isActive: row.isActive })}
            className={`p-1.5 rounded-lg transition-colors ${
              row.isActive
                ? "text-gray-400 hover:text-orange-600 hover:bg-orange-50"
                : "text-gray-400 hover:text-green-600 hover:bg-green-50"
            }`}
            title={row.isActive ? "Disable" : "Enable"}
          >
            {row.isActive ? <ToggleRight className="h-4 w-4" /> : <ToggleLeft className="h-4 w-4" />}
          </button>
          <button
            onClick={() => setDeleteTarget({ type: "admin", id: row._id, name: row.name })}
            className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            title="Delete"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      ),
    },
  ];

  const roleColumns = [
    {
      key: "name",
      label: "Role Name",
      render: (val: string) => (
        <div className="flex items-center gap-2.5">
          <div className="h-8 w-8 rounded-lg bg-purple-100 flex items-center justify-center">
            <KeyRound className="h-4 w-4 text-purple-600" />
          </div>
          <span className="font-medium text-gray-900">{val}</span>
        </div>
      ),
    },
    { key: "description", label: "Description" },
    {
      key: "permissions",
      label: "Permissions",
      render: (val: Permission[]) => (
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
            <Lock className="h-3 w-3" />
            {val?.length || 0} permissions
          </span>
        </div>
      ),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: LocalRole) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => handleEditRole(row)}
            className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
            title="Edit"
          >
            <Edit2 className="h-4 w-4" />
          </button>
          <button
            onClick={() => setDeleteTarget({ type: "role", id: row._id, name: row.name })}
            className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            title="Delete"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      ),
    },
  ];

  const stats = [
    { label: "Total Admins", value: admins.length, icon: Users, color: "blue" as const },
    { label: "Active Admins", value: admins.filter((a) => a.isActive).length, icon: ShieldCheck, color: "green" as const },
    { label: "Inactive", value: admins.filter((a) => !a.isActive).length, icon: ToggleLeft, color: "orange" as const },
    { label: "Roles", value: roles.length, icon: KeyRound, color: "purple" as const },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Admin Management</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage admin users, roles, and permissions
          </p>
        </div>
        <button
          onClick={activeTab === "admins" ? handleAddAdmin : handleAddRole}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 transition-colors shadow-sm"
        >
          {activeTab === "admins" ? (
            <>
              <UserPlus className="h-4 w-4" />
              Add Admin
            </>
          ) : (
            <>
              <Plus className="h-4 w-4" />
              Add Role
            </>
          )}
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => {
          const colorMap = {
            blue: "bg-blue-50 text-blue-600",
            green: "bg-green-50 text-green-600",
            orange: "bg-orange-50 text-orange-600",
            purple: "bg-purple-50 text-purple-600",
          };
          return (
            <div key={stat.label} className="bg-white rounded-xl border border-gray-100 shadow-sm p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{stat.label}</p>
                  <p className="text-2xl font-bold text-gray-900 mt-1">{stat.value}</p>
                </div>
                <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${colorMap[stat.color]}`}>
                  <stat.icon className="h-5 w-5" />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab("admins")}
            className={`flex items-center gap-2 py-3.5 px-1 border-b-2 font-medium text-sm transition-colors ${
              activeTab === "admins"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            }`}
          >
            <Users className="h-4 w-4" />
            Admins ({admins.length})
          </button>
          <button
            onClick={() => setActiveTab("roles")}
            className={`flex items-center gap-2 py-3.5 px-1 border-b-2 font-medium text-sm transition-colors ${
              activeTab === "roles"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            }`}
          >
            <KeyRound className="h-4 w-4" />
            Roles & Permissions ({roles.length})
          </button>
        </nav>
      </div>

      {/* Content */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center h-64">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent"></div>
          </div>
        ) : activeTab === "admins" ? (
          <Table columns={adminColumns} data={admins} emptyMessage="No admins found" />
        ) : (
          <Table columns={roleColumns} data={roles} emptyMessage="No roles found" />
        )}
      </div>

      {/* Admin Modal */}
      {showAdminModal && (
        <AdminModal
          admin={editItem as LocalAdmin | null}
          roles={roles}
          onClose={() => setShowAdminModal(false)}
          onSuccess={() => {
            setShowAdminModal(false);
            fetchData();
          }}
        />
      )}

      {/* Role Modal */}
      {showRoleModal && (
        <RoleModal
          role={editItem as LocalRole | null}
          onClose={() => setShowRoleModal(false)}
          onSuccess={() => {
            setShowRoleModal(false);
            fetchData();
          }}
        />
      )}

      {/* Delete Confirmation */}
      {deleteTarget && (
        <ConfirmDialog
          title={`Delete ${deleteTarget.type === "admin" ? "Admin" : "Role"}`}
          message={`Are you sure you want to delete "${deleteTarget.name}"? This action cannot be undone.`}
          confirmLabel="Delete"
          variant="danger"
          onConfirm={handleDelete}
          onCancel={() => setDeleteTarget(null)}
        />
      )}

      {/* Toggle Status Confirmation */}
      {toggleTarget && (
        <ConfirmDialog
          title={toggleTarget.isActive ? "Disable Admin" : "Enable Admin"}
          message={`Are you sure you want to ${toggleTarget.isActive ? "disable" : "enable"} "${toggleTarget.name}"?`}
          confirmLabel={toggleTarget.isActive ? "Disable" : "Enable"}
          variant={toggleTarget.isActive ? "danger" : "warning"}
          onConfirm={handleToggleStatus}
          onCancel={() => setToggleTarget(null)}
        />
      )}
    </div>
  );
}

interface AdminModalProps {
  admin: LocalAdmin | null;
  roles: LocalRole[];
  onClose: () => void;
  onSuccess: () => void;
}

function AdminModal({ admin, roles, onClose, onSuccess }: AdminModalProps) {
  const [formData, setFormData] = useState({
    name: admin?.name || "",
    email: admin?.email || "",
    password: "",
    role: admin?.role || "",
    isActive: admin?.isActive ?? true,
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const updateData: Record<string, unknown> = { ...formData };
      if (!updateData.password) delete updateData.password;
      
      if (admin) {
        await adminService.update(admin._id, updateData);
        toast.success("Admin updated successfully");
      } else {
        if (!formData.role) {
          toast.error("Please select a role");
          setIsSubmitting(false);
          return;
        }
        await adminService.create({
          name: formData.name,
          email: formData.email,
          password: formData.password,
          roleId: formData.role,
        });
        toast.success("Admin created successfully");
      }
      onSuccess();
    } catch (err: any) {
      const msg =
        err?.response?.data?.message ||
        err?.response?.data?.msg ||
        err?.message ||
        "Failed to save admin";
      toast.error(msg);
    } finally {
      setIsSubmitting(false);
    }
  };

  const inputClass =
    "mt-1 block w-full rounded-xl border border-gray-200 px-3.5 py-2.5 text-sm shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-colors";

  return (
    <Modal title={admin ? "Edit Admin" : "Add Admin"} onClose={onClose}>
      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Full Name
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className={inputClass}
            placeholder="Enter full name"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Email Address
          </label>
          <input
            type="email"
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            className={inputClass}
            placeholder="admin@kebu.com"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Password {admin && <span className="text-gray-400 font-normal">(leave blank to keep current)</span>}
          </label>
          <input
            type="password"
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            className={inputClass}
            placeholder={admin ? "••••••••" : "Min. 6 characters"}
            {...(!admin && { required: true })}
            minLength={6}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Role
          </label>
          <select
            value={formData.role}
            onChange={(e) => setFormData({ ...formData, role: e.target.value })}
            className={inputClass}
          >
            <option value="">Select Role</option>
            {roles.map((role) => (
              <option key={role._id} value={role._id}>
                {role.name}
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
          <button
            type="button"
            onClick={() => setFormData({ ...formData, isActive: !formData.isActive })}
            className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
              formData.isActive ? "bg-blue-600" : "bg-gray-200"
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                formData.isActive ? "translate-x-5" : "translate-x-0"
              }`}
            />
          </button>
          <span className="text-sm text-gray-700 font-medium">
            {formData.isActive ? "Active" : "Inactive"}
          </span>
        </div>

        <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
          <button
            type="button"
            onClick={onClose}
            className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors"
          >
            <X className="h-4 w-4" />
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-blue-600 rounded-xl hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            <Save className="h-4 w-4" />
            {isSubmitting ? "Saving..." : "Save Admin"}
          </button>
        </div>
      </form>
    </Modal>
  );
}

interface RoleModalProps {
  role: LocalRole | null;
  onClose: () => void;
  onSuccess: () => void;
}

function RoleModal({ role, onClose, onSuccess }: RoleModalProps) {
  const [formData, setFormData] = useState({
    name: role?.name || "",
    description: role?.description || "",
    permissions: role?.permissions || [] as Permission[],
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handlePermissionToggle = (permKey: Permission) => {
    setFormData((prev) => ({
      ...prev,
      permissions: prev.permissions.includes(permKey)
        ? prev.permissions.filter((p) => p !== permKey)
        : [...prev.permissions, permKey],
    }));
  };

  const handleGroupToggle = (keys: Permission[]) => {
    const allSelected = keys.every((k) => formData.permissions.includes(k));
    setFormData((prev) => ({
      ...prev,
      permissions: allSelected
        ? prev.permissions.filter((p) => !keys.includes(p))
        : [...new Set([...prev.permissions, ...keys])],
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      if (role) {
        await roleService.update(role._id, {
          name: formData.name,
          description: formData.description,
          permissions: formData.permissions,
        });
        toast.success("Role updated successfully");
      } else {
        await roleService.create({
          name: formData.name,
          description: formData.description,
          permissions: formData.permissions,
        });
        toast.success("Role created successfully");
      }
      onSuccess();
    } catch {
      toast.error("Failed to save role");
    } finally {
      setIsSubmitting(false);
    }
  };

  const inputClass =
    "mt-1 block w-full rounded-xl border border-gray-200 px-3.5 py-2.5 text-sm shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-colors";

  return (
    <Modal title={role ? "Edit Role" : "Add Role"} onClose={onClose} size="lg">
      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Role Name
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className={inputClass}
            placeholder="e.g. Content Manager"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Description
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            rows={2}
            className={inputClass}
            placeholder="Brief description of this role"
          />
        </div>

        <div>
          <div className="flex items-center justify-between mb-3">
            <label className="block text-sm font-medium text-gray-700">
              Permissions
            </label>
            <span className="text-xs text-blue-600 font-medium">
              {formData.permissions.length} / {availablePermissions.length} selected
            </span>
          </div>
          <div className="border border-gray-200 rounded-xl overflow-hidden max-h-80 overflow-y-auto">
            {permissionGroups.map((group) => {
              const allSelected = group.keys.every((k) => formData.permissions.includes(k as Permission));
              const someSelected = group.keys.some((k) => formData.permissions.includes(k as Permission));
              return (
                <div key={group.group} className="border-b border-gray-100 last:border-b-0">
                  <button
                    type="button"
                    onClick={() => handleGroupToggle(group.keys as Permission[])}
                    className="flex items-center gap-3 w-full px-4 py-2.5 bg-gray-50 hover:bg-gray-100 transition-colors text-left"
                  >
                    <div
                      className={`h-4 w-4 rounded border-2 flex items-center justify-center transition-colors ${
                        allSelected
                          ? "bg-blue-600 border-blue-600"
                          : someSelected
                          ? "bg-blue-100 border-blue-400"
                          : "border-gray-300"
                      }`}
                    >
                      {(allSelected || someSelected) && (
                        <svg className="h-3 w-3 text-white" fill="currentColor" viewBox="0 0 12 12">
                          <path d={allSelected ? "M10 3L4.5 8.5 2 6" : "M3 6h6"} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                        </svg>
                      )}
                    </div>
                    <span className="text-sm font-semibold text-gray-700">{group.group}</span>
                    <span className="ml-auto text-xs text-gray-400">
                      {group.keys.filter((k) => formData.permissions.includes(k as Permission)).length}/{group.keys.length}
                    </span>
                  </button>
                  <div className="grid grid-cols-2 gap-1 px-4 py-2">
                    {group.keys.map((key) => {
                      const perm = availablePermissions.find((p) => p.key === key);
                      if (!perm) return null;
                      return (
                        <label
                          key={perm.key}
                          className="flex items-center gap-2 p-1.5 hover:bg-blue-50 rounded-lg cursor-pointer transition-colors"
                        >
                          <input
                            type="checkbox"
                            checked={formData.permissions.includes(perm.key as Permission)}
                            onChange={() => handlePermissionToggle(perm.key as Permission)}
                            className="h-3.5 w-3.5 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                          />
                          <span className="text-xs text-gray-600">{perm.label}</span>
                        </label>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
          <button
            type="button"
            onClick={onClose}
            className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors"
          >
            <X className="h-4 w-4" />
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-blue-600 rounded-xl hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            <Save className="h-4 w-4" />
            {isSubmitting ? "Saving..." : "Save Role"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
