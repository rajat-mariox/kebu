import { useState, useEffect, useCallback } from "react";
import {
  Plus, Edit2, Trash2, Car, Layers, Image as ImageIcon,
} from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Table } from "../components";
import { Modal } from "../components/Modal";
import ImageUpload from "../components/ImageUpload";
import ConfirmDialog from "../components/ConfirmDialog";
import {
  vehicleService,
  type VehicleCategory,
  type VehicleType,
} from "../services";

interface LocalVehicleType {
  _id: string;
  name: string;
  description?: string;
  image?: string;
  category?: string | { _id: string; name: string };
  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
  minimumFare: number;
  commissionRate: number;
  cancellationCharge: number;
  surgeMultiplier?: number;
  cancellationFee?: number;
  maxSeats?: number;
  isActive: boolean;
  createdAt: string;
}

export default function VehicleManagement() {
  const [activeTab, setActiveTab] = useState<"types" | "categories">("types");
  const [categories, setCategories] = useState<VehicleCategory[]>([]);
  const [types, setTypes] = useState<LocalVehicleType[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [showTypeModal, setShowTypeModal] = useState(false);
  const [editItem, setEditItem] = useState<LocalVehicleType | null>(null);
  const [editCategory, setEditCategory] = useState<VehicleCategory | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ type: "category" | "vehicleType"; id: string; name: string } | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const fetchVehicleTypes = useCallback(async () => {
    const [typesRes, catsRes] = await Promise.all([
      vehicleService.getTypes(),
      vehicleService.getCategories(),
    ]);
    const td = typesRes.data as { vehicleTypes?: LocalVehicleType[] } | LocalVehicleType[];
    const cd = catsRes.data as { categories?: VehicleCategory[] } | VehicleCategory[];
    setTypes(Array.isArray(td) ? td : td?.vehicleTypes || []);
    setCategories(Array.isArray(cd) ? cd : cd?.categories || []);
  }, []);

  const fetchCategories = useCallback(async () => {
    const res = await vehicleService.getCategories();
    const d = res.data as { categories?: VehicleCategory[] } | VehicleCategory[];
    setCategories(Array.isArray(d) ? d : d?.categories || []);
  }, []);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      if (activeTab === "types") {
        await fetchVehicleTypes();
      } else {
        await fetchCategories();
      }
    } catch {
      toast.error("Failed to fetch vehicle data");
    } finally {
      setIsLoading(false);
    }
  }, [activeTab, fetchVehicleTypes, fetchCategories]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleSaveCategory = async (data: Partial<VehicleCategory>) => {
    try {
      if (editCategory) {
        await vehicleService.updateCategory(editCategory._id, data);
        toast.success("Category updated");
      } else {
        await vehicleService.createCategory(data);
        toast.success("Category created");
      }
      setShowCategoryModal(false);
      setEditCategory(null);
      fetchData();
    } catch {
      toast.error("Failed to save category");
    }
  };

  const handleSaveType = async (data: Partial<VehicleType>) => {
    try {
      if (editItem) {
        await vehicleService.updateType(editItem._id, data);
        toast.success("Vehicle type updated");
      } else {
        await vehicleService.createType(data);
        toast.success("Vehicle type created");
      }
      setShowTypeModal(false);
      setEditItem(null);
      fetchData();
    } catch {
      toast.error("Failed to save vehicle type");
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleteLoading(true);
    try {
      if (deleteTarget.type === "category") {
        await vehicleService.deleteCategory(deleteTarget.id);
      } else {
        await vehicleService.deleteType(deleteTarget.id);
      }
      toast.success(`${deleteTarget.name} deleted`);
      setDeleteTarget(null);
      fetchData();
    } catch (err: unknown) {
      const e = err as { response?: { data?: { message?: string } } };
      const msg = e?.response?.data?.message || "";
      if (msg.includes("active_bookings")) {
        toast.error("Cannot delete — vehicle type has active bookings");
      } else if (msg.includes("in_use")) {
        toast.error("Cannot delete — drivers are using this vehicle type");
      } else if (msg.includes("has_vehicle_types")) {
        toast.error("Cannot delete — category contains vehicle types");
      } else {
        toast.error("Delete failed");
      }
    } finally {
      setDeleteLoading(false);
    }
  };

  const categoryColumns = [
    {
      key: "name",
      label: "Category",
      render: (val: string, row: VehicleCategory) => (
        <div className="flex items-center gap-3">
          {row.icon ? (
            <img src={row.icon} alt="" className="h-8 w-8 rounded-lg object-cover" />
          ) : (
            <div className="h-8 w-8 rounded-lg bg-blue-50 flex items-center justify-center">
              <Layers className="h-4 w-4 text-blue-600" />
            </div>
          )}
          <div>
            <p className="font-medium text-gray-900">{val}</p>
            <p className="text-xs text-gray-500">Code: {row.code}</p>
          </div>
        </div>
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
      key: "createdAt",
      label: "Created",
      render: (val: string) => new Date(val).toLocaleDateString(),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: VehicleCategory) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => { setEditCategory(row); setShowCategoryModal(true); }}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
            title="Edit"
          >
            <Edit2 className="h-4 w-4" />
          </button>
          <button
            onClick={() => setDeleteTarget({ type: "category", id: row._id, name: row.name })}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
            title="Delete"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      ),
    },
  ];

  const typeColumns = [
    {
      key: "name",
      label: "Vehicle Type",
      render: (val: string, row: LocalVehicleType) => (
        <div className="flex items-center gap-3">
          {row.image ? (
            <img src={row.image} alt="" className="h-10 w-10 rounded-lg object-cover" />
          ) : (
            <div className="h-10 w-10 rounded-lg bg-emerald-50 flex items-center justify-center">
              <Car className="h-5 w-5 text-emerald-600" />
            </div>
          )}
          <div>
            <p className="font-medium text-gray-900">{val}</p>
            <p className="text-xs text-gray-500">{row.description || ""}</p>
          </div>
        </div>
      ),
    },
    {
      key: "category",
      label: "Category",
      render: (val: string | { name: string }) =>
        typeof val === "object" ? val?.name : val || "-",
    },
    {
      key: "baseFare",
      label: "Base Fare",
      render: (val: number) => <span className="font-medium">₹{val}</span>,
    },
    {
      key: "perKmRate",
      label: "Per Km",
      render: (val: number) => `₹${val}`,
    },
    {
      key: "perMinuteRate",
      label: "Per Min",
      render: (val: number) => `₹${val}`,
    },
    {
      key: "surgeMultiplier",
      label: "Surge",
      render: (val: number) => (
        <span className={val > 1 ? "text-orange-600 font-medium" : ""}>
          {val}x
        </span>
      ),
    },
    { key: "maxSeats", label: "Seats" },
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
      key: "_actions",
      label: "Actions",
      render: (_: unknown, row: LocalVehicleType) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => { setEditItem(row); setShowTypeModal(true); }}
            className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
            title="Edit"
          >
            <Edit2 className="h-4 w-4" />
          </button>
          <button
            onClick={() => setDeleteTarget({ type: "vehicleType", id: row._id, name: row.name })}
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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Vehicle Management</h1>
          <p className="mt-1 text-sm text-gray-500">Manage vehicle categories and pricing</p>
        </div>
        <button
          onClick={() => {
            if (activeTab === "types") { setEditItem(null); setShowTypeModal(true); }
            else { setEditCategory(null); setShowCategoryModal(true); }
          }}
          className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
        >
          <Plus className="h-4 w-4" />
          Add {activeTab === "types" ? "Vehicle Type" : "Category"}
        </button>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {(["types", "categories"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`py-3 px-1 border-b-2 font-medium text-sm transition-colors ${
                activeTab === tab
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              }`}
            >
              {tab === "types" ? "Vehicle Types" : "Categories"}
            </button>
          ))}
        </nav>
      </div>

      {/* Table */}
      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        <Table<any>
          columns={activeTab === "types" ? typeColumns : categoryColumns}
          data={activeTab === "types" ? types : categories}
          isLoading={isLoading}
          emptyMessage={`No ${activeTab === "types" ? "vehicle types" : "categories"} found`}
        />
      </div>

      {/* Category Modal */}
      {showCategoryModal && (
        <CategoryModal
          editItem={editCategory}
          onClose={() => { setShowCategoryModal(false); setEditCategory(null); }}
          onSave={handleSaveCategory}
        />
      )}

      {/* Type Modal */}
      {showTypeModal && (
        <TypeModal
          categories={categories}
          editItem={editItem}
          onClose={() => { setShowTypeModal(false); setEditItem(null); }}
          onSave={handleSaveType}
        />
      )}

      {/* Delete Confirm */}
      {deleteTarget && (
        <ConfirmDialog
          title={`Delete ${deleteTarget.type === "category" ? "Category" : "Vehicle Type"}`}
          message={`Are you sure you want to delete "${deleteTarget.name}"? This action cannot be undone.`}
          confirmLabel="Delete"
          variant="danger"
          isLoading={deleteLoading}
          onConfirm={handleDelete}
          onCancel={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}

function CategoryModal({
  editItem,
  onClose,
  onSave,
}: {
  editItem: VehicleCategory | null;
  onClose: () => void;
  onSave: (data: Partial<VehicleCategory>) => void;
}) {
  const [name, setName] = useState(editItem?.name || "");
  const [code, setCode] = useState(editItem?.code || "");
  const [icon, setIcon] = useState(editItem?.icon || "");
  const [isActive, setIsActive] = useState(editItem?.isActive ?? true);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({ name, code, icon: icon || undefined, isActive });
  };

  return (
    <Modal title={editItem ? "Edit Category" : "Add Category"} onClose={onClose}>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Code</label>
          <input
            type="text"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            placeholder="e.g. 2W, 3W, 4W"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Icon Image</label>
          <ImageUpload value={icon} onChange={setIcon} />
        </div>
        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="h-4 w-4 rounded border-gray-300 text-blue-600"
          />
          <label className="text-sm text-gray-700">Active</label>
        </div>
        <div className="flex justify-end gap-3 pt-4">
          <button type="button" onClick={onClose}
            className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50">
            Cancel
          </button>
          <button type="submit"
            className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700">
            {editItem ? "Update" : "Create"}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function TypeModal({
  categories,
  editItem,
  onClose,
  onSave,
}: {
  categories: VehicleCategory[];
  editItem: LocalVehicleType | null;
  onClose: () => void;
  onSave: (data: Partial<VehicleType>) => void;
}) {
  const [name, setName] = useState(editItem?.name || "");
  const [category, setCategory] = useState(
    editItem
      ? typeof editItem.category === "object" ? (editItem.category as { _id: string })._id : editItem.category as string
      : "",
  );
  const [image, setImage] = useState(editItem?.image || "");
  const [baseFare, setBaseFare] = useState(editItem?.baseFare ?? 30);
  const [perKmRate, setPerKmRate] = useState(editItem?.perKmRate ?? 12);
  const [perMinuteRate, setPerMinuteRate] = useState(editItem?.perMinuteRate ?? 2);
  const [minimumFare, setMinimumFare] = useState(editItem?.minimumFare ?? 50);
  const [surgeMultiplier, setSurgeMultiplier] = useState(editItem?.surgeMultiplier ?? 1);
  const [cancellationFee, setCancellationFee] = useState(editItem?.cancellationFee ?? 50);
  const [maxSeats, setMaxSeats] = useState(editItem?.maxSeats ?? 4);
  const [description, setDescription] = useState(editItem?.description || "");
  const [isActive, setIsActive] = useState(editItem?.isActive ?? true);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({
      name, 
      categoryId: category, 
      image: image || undefined,
      baseFare, perKmRate, perMinuteRate, minimumFare,
      surgeMultiplier, cancellationFee, maxSeats, description, isActive,
    });
  };

  const numField = (label: string, value: number, setter: (v: number) => void, step = 1) => (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      <input
        type="number"
        value={value}
        onChange={(e) => setter(Number(e.target.value))}
        step={step}
        min={0}
        className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        required
      />
    </div>
  );

  return (
    <Modal title={editItem ? "Edit Vehicle Type" : "Add Vehicle Type"} onClose={onClose} size="lg">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              required
            >
              <option value="">Select category</option>
              {categories.map((c) => (
                <option key={c._id} value={c._id}>
                  {c.name} ({c.code})
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Image Upload */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            <span className="inline-flex items-center gap-1">
              <ImageIcon className="h-4 w-4" /> Vehicle Image
            </span>
          </label>
          <ImageUpload value={image} onChange={setImage} />
        </div>

        <div className="grid grid-cols-3 gap-4">
          {numField("Base Fare (₹)", baseFare, setBaseFare)}
          {numField("Per Km Rate (₹)", perKmRate, setPerKmRate, 0.5)}
          {numField("Per Minute Rate (₹)", perMinuteRate, setPerMinuteRate, 0.5)}
        </div>

        <div className="grid grid-cols-3 gap-4">
          {numField("Minimum Fare (₹)", minimumFare, setMinimumFare)}
          {numField("Surge Multiplier", surgeMultiplier, setSurgeMultiplier, 0.1)}
          {numField("Cancellation Fee (₹)", cancellationFee, setCancellationFee)}
        </div>

        <div className="grid grid-cols-2 gap-4">
          {numField("Max Seats", maxSeats, setMaxSeats)}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>
        </div>

        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="h-4 w-4 rounded border-gray-300 text-blue-600"
          />
          <label className="text-sm text-gray-700">Active</label>
        </div>

        <div className="flex justify-end gap-3 pt-4">
          <button type="button" onClick={onClose}
            className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50">
            Cancel
          </button>
          <button type="submit"
            className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700">
            {editItem ? "Update" : "Create"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
