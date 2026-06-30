import { useState, useEffect, useCallback, useMemo } from "react";
import {
  Plus, Edit2, Trash2, ToggleLeft, ToggleRight, Home, Wrench, Package,
  Search, Layers, FolderTree, Sparkles, IndianRupee, Clock,
} from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Table, StatsCard } from "../components";
import { Modal } from "../components/Modal";
import ImageUpload from "../components/ImageUpload";
import ConfirmDialog from "../components/ConfirmDialog";
import { categoryService, serviceService, packageService } from "../services";
import type { ServiceCategory, ServiceDetails, ServicePackage } from "../types";

type TabType = "categories" | "services" | "packages";

type EditableItem =
  | (ServiceCategory & { __type: "category" })
  | (ServiceDetails & { __type: "service" })
  | (ServicePackage & { __type: "package" })
  | null;

interface FormDataState {
  name: string;
  description: string;
  icon: string;
  image: string;
  isActive: boolean;
  // category
  parentId: string;
  displayOrder: number;
  // service
  categoryId: string;
  basePrice: number;
  duration: number;
  // package
  serviceId: string;
  durationMinutes: number;
  originalPrice: number;
  discountedPrice: number;
  isPopular: boolean;
}

const emptyForm: FormDataState = {
  name: "",
  description: "",
  icon: "🏠",
  image: "",
  isActive: true,
  parentId: "",
  displayOrder: 0,
  categoryId: "",
  basePrice: 0,
  duration: 60,
  serviceId: "",
  durationMinutes: 60,
  originalPrice: 0,
  discountedPrice: 0,
  isPopular: false,
};

const getCategoryId = (val: unknown): string => {
  if (!val) return "";
  if (typeof val === "string") return val;
  if (typeof val === "object" && val && "_id" in val) {
    return String((val as { _id: unknown })._id ?? "");
  }
  return "";
};

const getCategoryName = (val: unknown, lookup: Map<string, ServiceCategory>): string => {
  if (!val) return "-";
  if (typeof val === "object" && val && "name" in val) {
    return String((val as { name: unknown }).name ?? "-");
  }
  if (typeof val === "string") {
    return lookup.get(val)?.name || "-";
  }
  return "-";
};

export default function HouseholdServices() {
  const [activeTab, setActiveTab] = useState<TabType>("categories");
  const [categories, setCategories] = useState<ServiceCategory[]>([]);
  const [services, setServices] = useState<ServiceDetails[]>([]);
  const [packages, setPackages] = useState<ServicePackage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState<EditableItem>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);
  const [search, setSearch] = useState("");
  const [filterCategoryId, setFilterCategoryId] = useState<string>("");
  const [filterStatus, setFilterStatus] = useState<"" | "active" | "inactive">("");

  const categoryLookup = useMemo(
    () => new Map(categories.map((c) => [c._id, c])),
    [categories],
  );

  const parentCategories = useMemo(
    () => categories.filter((c) => !c.parentId),
    [categories],
  );

  const fetchCategories = useCallback(async () => {
    try {
      const res = await categoryService.getAll();
      const data = res.data as { categories?: ServiceCategory[] } | ServiceCategory[];
      const cats = Array.isArray(data) ? data : data?.categories || [];
      setCategories(cats);
    } catch {
      toast.error("Failed to fetch categories");
    }
  }, []);

  const fetchServices = useCallback(async () => {
    try {
      const res = await serviceService.getAll();
      const data = res.data as { services?: ServiceDetails[] } | ServiceDetails[];
      const svcs = Array.isArray(data) ? data : data?.services || [];
      setServices(svcs);
    } catch {
      toast.error("Failed to fetch services");
    }
  }, []);

  const fetchPackages = useCallback(async () => {
    try {
      const res = await packageService.getAll();
      const data = res.data as
        | { packages?: ServicePackage[]; items?: ServicePackage[] }
        | ServicePackage[];
      const pkgs = Array.isArray(data)
        ? data
        : data?.packages || data?.items || [];
      setPackages(pkgs);
    } catch {
      // packages endpoint may not return on first call; ignore silently
      setPackages([]);
    }
  }, []);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      await Promise.all([fetchCategories(), fetchServices(), fetchPackages()]);
    } finally {
      setIsLoading(false);
    }
  }, [fetchCategories, fetchServices, fetchPackages]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Reset filters when switching tabs
  useEffect(() => {
    setSearch("");
    setFilterCategoryId("");
    setFilterStatus("");
  }, [activeTab]);

  const handleToggleStatus = async (id: string) => {
    try {
      if (activeTab === "categories") await categoryService.toggleStatus(id);
      else if (activeTab === "services") await serviceService.toggleStatus(id);
      else await packageService.toggleStatus(id);
      toast.success("Status updated");
      fetchData();
    } catch {
      toast.error("Failed to toggle status");
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleteLoading(true);
    try {
      if (activeTab === "categories") await categoryService.delete(deleteTarget.id);
      else if (activeTab === "services") await serviceService.delete(deleteTarget.id);
      else await packageService.delete(deleteTarget.id);
      toast.success(`${deleteTarget.name} deleted`);
      setDeleteTarget(null);
      fetchData();
    } catch {
      toast.error("Delete failed");
    } finally {
      setDeleteLoading(false);
    }
  };

  // ========= Derived: stats =========
  const stats = useMemo(() => {
    return {
      totalCategories: categories.length,
      activeCategories: categories.filter((c) => c.isActive).length,
      totalServices: services.length,
      activeServices: services.filter((s) => s.isActive).length,
      totalPackages: packages.length,
    };
  }, [categories, services, packages]);

  // ========= Derived: filtered lists =========
  const filteredCategories = useMemo(() => {
    const q = search.trim().toLowerCase();
    return categories
      .filter((c) => !q || c.name.toLowerCase().includes(q) || c.description?.toLowerCase().includes(q))
      .filter((c) =>
        filterStatus === "active" ? c.isActive :
        filterStatus === "inactive" ? !c.isActive : true
      );
  }, [categories, search, filterStatus]);

  // Build hierarchical view: parent followed by its children (indented visually via render)
  const hierarchicalCategories = useMemo(() => {
    const parents = filteredCategories.filter((c) => !c.parentId);
    const childrenByParent = new Map<string, ServiceCategory[]>();
    filteredCategories
      .filter((c) => !!c.parentId)
      .forEach((c) => {
        const pid = typeof c.parentId === "string" ? c.parentId : (c.parentId as ServiceCategory | null | undefined)?._id;
        if (!pid) return;
        if (!childrenByParent.has(pid)) childrenByParent.set(pid, []);
        childrenByParent.get(pid)!.push(c);
      });
    const result: (ServiceCategory & { __depth?: number })[] = [];
    parents.forEach((p) => {
      result.push({ ...p, __depth: 0 });
      (childrenByParent.get(p._id) || []).forEach((child) => {
        result.push({ ...child, __depth: 1 });
      });
    });
    // Also include orphan children (whose parent was filtered out)
    const includedIds = new Set(result.map((r) => r._id));
    filteredCategories.forEach((c) => {
      if (!includedIds.has(c._id)) result.push({ ...c, __depth: 0 });
    });
    return result;
  }, [filteredCategories]);

  const filteredServices = useMemo(() => {
    const q = search.trim().toLowerCase();
    return services
      .filter((s) => !q || (s.name || "").toLowerCase().includes(q) || s.description?.toLowerCase().includes(q))
      .filter((s) => !filterCategoryId || getCategoryId(s.categoryId) === filterCategoryId)
      .filter((s) =>
        filterStatus === "active" ? s.isActive :
        filterStatus === "inactive" ? !s.isActive : true
      );
  }, [services, search, filterCategoryId, filterStatus]);

  const filteredPackages = useMemo(() => {
    const q = search.trim().toLowerCase();
    return packages
      .filter((p) => !q || p.name.toLowerCase().includes(q) || p.description?.toLowerCase().includes(q))
      .filter((p) => {
        if (!filterCategoryId) return true;
        const cid = getCategoryId(p.categoryId);
        return cid === filterCategoryId;
      });
  }, [packages, search, filterCategoryId]);

  // ========= Columns =========
  const categoryColumns = [
    {
      key: "name",
      label: "Category",
      render: (val: string, row: ServiceCategory & { __depth?: number }) => (
        <div className={`flex items-center gap-3 ${row.__depth ? "pl-6" : ""}`}>
          {row.__depth ? (
            <span className="text-gray-300 text-xs">↳</span>
          ) : null}
          {row.image ? (
            <img src={row.image} alt="" className="h-10 w-10 rounded-lg object-cover ring-1 ring-gray-100" />
          ) : (
            <div className="h-10 w-10 rounded-lg bg-gradient-to-br from-purple-50 to-pink-50 flex items-center justify-center text-xl">
              {row.icon || <Home className="h-5 w-5 text-purple-600" />}
            </div>
          )}
          <div className="min-w-0">
            <p className="font-medium text-gray-900 truncate">{val}</p>
            <p className="text-xs text-gray-500 line-clamp-1">{row.description || "—"}</p>
          </div>
        </div>
      ),
    },
    {
      key: "parentId",
      label: "Parent",
      render: (val: unknown) => {
        if (!val) return <span className="text-xs text-gray-400">Top-level</span>;
        return <span className="text-xs text-gray-600">{getCategoryName(val, categoryLookup)}</span>;
      },
    },
    {
      key: "displayOrder",
      label: "Order",
      render: (val: number | undefined) => (
        <span className="text-xs font-medium text-gray-600">{val ?? 0}</span>
      ),
    },
    {
      key: "isActive",
      label: "Status",
      render: (val: boolean) => (
        <Badge variant={val ? "success" : "danger"}>{val ? "Active" : "Inactive"}</Badge>
      ),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: ServiceCategory) => renderActions(row._id, row.name, row, "category"),
    },
  ];

  const serviceColumns = [
    {
      key: "name",
      label: "Service",
      render: (val: string, row: ServiceDetails) => (
        <div className="flex items-center gap-3">
          {row.image ? (
            <img src={row.image} alt="" className="h-10 w-10 rounded-lg object-cover ring-1 ring-gray-100" />
          ) : (
            <div className="h-10 w-10 rounded-lg bg-gradient-to-br from-blue-50 to-cyan-50 flex items-center justify-center">
              <Wrench className="h-5 w-5 text-blue-600" />
            </div>
          )}
          <div className="min-w-0">
            <p className="font-medium text-gray-900 truncate">{val || "—"}</p>
            <p className="text-xs text-gray-500 line-clamp-1">{row.description || "—"}</p>
          </div>
        </div>
      ),
    },
    {
      key: "categoryId",
      label: "Category",
      render: (val: unknown) => {
        const name = getCategoryName(val, categoryLookup);
        return (
          <Badge variant="info">
            <Layers className="h-3 w-3 mr-1 inline" />
            {name}
          </Badge>
        );
      },
    },
    {
      key: "price",
      label: "Price",
      render: (_: number, row: ServiceDetails) => {
        const price = row.price ?? row.basePrice ?? 0;
        return (
          <span className="inline-flex items-center gap-0.5 font-medium text-gray-900">
            <IndianRupee className="h-3.5 w-3.5" />
            {price}
          </span>
        );
      },
    },
    {
      key: "duration",
      label: "Duration",
      render: (val: number) => (
        <span className="inline-flex items-center gap-1 text-sm text-gray-600">
          <Clock className="h-3.5 w-3.5" />
          {val || 0} min
        </span>
      ),
    },
    {
      key: "isActive",
      label: "Status",
      render: (val: boolean) => (
        <Badge variant={val ? "success" : "danger"}>{val ? "Active" : "Inactive"}</Badge>
      ),
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: ServiceDetails) => renderActions(row._id, row.name || "service", row, "service"),
    },
  ];

  const packageColumns = [
    {
      key: "name",
      label: "Package",
      render: (val: string, row: ServicePackage) => (
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-lg bg-gradient-to-br from-amber-50 to-orange-50 flex items-center justify-center">
            <Package className="h-5 w-5 text-orange-600" />
          </div>
          <div>
            <p className="font-medium text-gray-900 flex items-center gap-1.5">
              {val}
              {row.isPopular && (
                <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700">
                  <Sparkles className="h-2.5 w-2.5" /> Popular
                </span>
              )}
            </p>
            <p className="text-xs text-gray-500 line-clamp-1">{row.description || "—"}</p>
          </div>
        </div>
      ),
    },
    {
      key: "categoryId",
      label: "Category",
      render: (val: unknown) => {
        const name = getCategoryName(val, categoryLookup);
        return <Badge variant="info">{name}</Badge>;
      },
    },
    {
      key: "durationMinutes",
      label: "Duration",
      render: (val: number | undefined) => (
        <span className="inline-flex items-center gap-1 text-sm text-gray-600">
          <Clock className="h-3.5 w-3.5" />
          {val ? `${val} min` : "—"}
        </span>
      ),
    },
    {
      key: "originalPrice",
      label: "Pricing",
      render: (_: number, row: ServicePackage) => {
        const original = row.originalPrice ?? 0;
        const discounted = row.discountedPrice ?? row.price ?? original;
        const hasDiscount = original > 0 && discounted < original;
        return (
          <div className="flex flex-col">
            <span className="inline-flex items-center gap-0.5 font-medium text-gray-900">
              <IndianRupee className="h-3.5 w-3.5" />
              {discounted}
            </span>
            {hasDiscount && (
              <span className="text-[10px] text-gray-400 line-through">₹{original}</span>
            )}
          </div>
        );
      },
    },
    {
      key: "isAvailable",
      label: "Status",
      render: (_: boolean, row: ServicePackage) => {
        const active = row.isAvailable ?? row.isActive ?? true;
        return <Badge variant={active ? "success" : "danger"}>{active ? "Available" : "Hidden"}</Badge>;
      },
    },
    {
      key: "_id",
      label: "Actions",
      render: (_: string, row: ServicePackage) => renderActions(row._id, row.name, row, "package"),
    },
  ];

  function renderActions(
    id: string,
    name: string,
    row: ServiceCategory | ServiceDetails | ServicePackage,
    kind: "category" | "service" | "package",
  ) {
    const active =
      kind === "package"
        ? ((row as ServicePackage).isAvailable ?? (row as ServicePackage).isActive ?? true)
        : (row as ServiceCategory | ServiceDetails).isActive;
    return (
      <div className="flex items-center gap-1">
        <button
          onClick={() => {
            setEditItem({ ...(row as ServiceCategory & ServiceDetails & ServicePackage), __type: kind } as EditableItem);
            setShowModal(true);
          }}
          className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
          title="Edit"
        >
          <Edit2 className="h-4 w-4" />
        </button>
        <button
          onClick={() => handleToggleStatus(id)}
          className={`rounded-lg p-1.5 transition-colors ${active ? "text-green-500 hover:bg-red-50 hover:text-red-600" : "text-gray-400 hover:bg-green-50 hover:text-green-600"}`}
          title={active ? "Disable" : "Enable"}
        >
          {active ? <ToggleRight className="h-4 w-4" /> : <ToggleLeft className="h-4 w-4" />}
        </button>
        <button
          onClick={() => setDeleteTarget({ id, name })}
          className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
          title="Delete"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>
    );
  }

  const noCategories = categories.length === 0 && !isLoading;
  const canAddService = !noCategories;
  const tabLabel =
    activeTab === "categories" ? "Category" :
    activeTab === "services" ? "Service" : "Package";

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <FolderTree className="h-6 w-6 text-purple-600" />
            Household Services
          </h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage service categories, individual services, and duration-based packages
          </p>
        </div>
        <button
          onClick={() => {
            if (activeTab === "services" && !canAddService) {
              toast.error("Create at least one category first");
              setActiveTab("categories");
              return;
            }
            if (activeTab === "packages" && !canAddService) {
              toast.error("Create at least one category first");
              setActiveTab("categories");
              return;
            }
            setEditItem(null);
            setShowModal(true);
          }}
          className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-purple-600 to-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:shadow-md transition-all"
        >
          <Plus className="h-4 w-4" />
          Add {tabLabel}
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <StatsCard title="Categories" value={stats.totalCategories} icon={Layers} color="purple" />
        <StatsCard title="Active Categories" value={stats.activeCategories} icon={Layers} color="green" />
        <StatsCard title="Services" value={stats.totalServices} icon={Wrench} color="blue" />
        <StatsCard title="Active Services" value={stats.activeServices} icon={Wrench} color="green" />
        <StatsCard title="Packages" value={stats.totalPackages} icon={Package} color="orange" />
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {(["categories", "services", "packages"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`py-3 px-1 border-b-2 font-medium text-sm capitalize transition-colors ${
                activeTab === tab
                  ? "border-purple-600 text-purple-600"
                  : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              }`}
            >
              {tab}
              <span className="ml-2 text-xs text-gray-400">
                {tab === "categories" ? categories.length : tab === "services" ? services.length : packages.length}
              </span>
            </button>
          ))}
        </nav>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[220px] max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={`Search ${activeTab}...`}
            className="w-full rounded-lg border border-gray-300 pl-10 pr-4 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
          />
        </div>

        {(activeTab === "services" || activeTab === "packages") && (
          <select
            value={filterCategoryId}
            onChange={(e) => setFilterCategoryId(e.target.value)}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-purple-500 focus:outline-none"
          >
            <option value="">All Categories</option>
            {categories.map((c) => (
              <option key={c._id} value={c._id}>{c.name}</option>
            ))}
          </select>
        )}

        {activeTab !== "packages" && (
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value as "" | "active" | "inactive")}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-purple-500 focus:outline-none"
          >
            <option value="">All Status</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
          </select>
        )}
      </div>

      {/* Empty state banner */}
      {noCategories && activeTab !== "categories" && (
        <div className="rounded-xl bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-800 flex items-center justify-between">
          <span>You need at least one category before creating {activeTab}.</span>
          <button
            onClick={() => setActiveTab("categories")}
            className="text-amber-900 font-medium hover:underline"
          >
            Go to Categories →
          </button>
        </div>
      )}

      {/* Tables */}
      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        {activeTab === "categories" && (
          <Table<ServiceCategory & { __depth?: number }>
            columns={categoryColumns}
            data={hierarchicalCategories}
            isLoading={isLoading}
            emptyMessage="No categories found. Click 'Add Category' to create one."
          />
        )}
        {activeTab === "services" && (
          <Table<ServiceDetails>
            columns={serviceColumns}
            data={filteredServices}
            isLoading={isLoading}
            emptyMessage="No services found"
          />
        )}
        {activeTab === "packages" && (
          <Table<ServicePackage>
            columns={packageColumns}
            data={filteredPackages}
            isLoading={isLoading}
            emptyMessage="No packages found. Packages are duration-based pricing bundles for a category."
          />
        )}
      </div>

      {showModal && (
        <CategoryServiceModal
          type={activeTab === "categories" ? "category" : activeTab === "services" ? "service" : "package"}
          item={editItem}
          categories={categories}
          services={services}
          parentCategories={parentCategories}
          onClose={() => { setShowModal(false); setEditItem(null); }}
          onSuccess={() => { setShowModal(false); setEditItem(null); fetchData(); }}
        />
      )}

      {deleteTarget && (
        <ConfirmDialog
          title={`Delete ${tabLabel}`}
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

interface CategoryServiceModalProps {
  type: "category" | "service" | "package";
  item: EditableItem;
  categories: ServiceCategory[];
  services: ServiceDetails[];
  parentCategories: ServiceCategory[];
  onClose: () => void;
  onSuccess: () => void;
}

function CategoryServiceModal({ type, item, categories, services, parentCategories, onClose, onSuccess }: CategoryServiceModalProps) {
  const initial: FormDataState = useMemo(() => {
    if (!item) return emptyForm;
    if (item.__type === "category") {
      const c = item as ServiceCategory & { __type: "category" };
      return {
        ...emptyForm,
        name: c.name,
        description: c.description || "",
        icon: c.icon || "🏠",
        image: c.image || "",
        isActive: c.isActive,
        parentId: typeof c.parentId === "string" ? c.parentId : (c.parentId as ServiceCategory | null | undefined)?._id || "",
        displayOrder: c.displayOrder ?? 0,
      };
    }
    if (item.__type === "service") {
      const s = item as ServiceDetails & { __type: "service" };
      return {
        ...emptyForm,
        name: s.name || "",
        description: s.description || "",
        icon: s.icon || "",
        image: s.image || "",
        isActive: s.isActive,
        categoryId: getCategoryId(s.categoryId),
        basePrice: s.price ?? s.basePrice ?? 0,
        duration: s.duration ?? 60,
        displayOrder: s.displayOrder ?? 0,
      };
    }
    // package
    const p = item as ServicePackage & { __type: "package" };
    return {
      ...emptyForm,
      name: p.name,
      description: p.description || "",
      isActive: p.isAvailable ?? p.isActive ?? true,
      categoryId: getCategoryId(p.categoryId),
      serviceId: getCategoryId(p.serviceId),
      durationMinutes: p.durationMinutes ?? 60,
      originalPrice: p.originalPrice ?? p.price ?? 0,
      discountedPrice: p.discountedPrice ?? p.price ?? 0,
      isPopular: !!p.isPopular,
      displayOrder: p.displayOrder ?? 0,
    };
  }, [item]);

  const [formData, setFormData] = useState<FormDataState>(initial);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const title = `${item ? "Edit" : "Add"} ${type === "category" ? "Category" : type === "service" ? "Service" : "Package"}`;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      if (type === "category") {
        const payload: Partial<ServiceCategory> = {
          name: formData.name,
          description: formData.description,
          icon: formData.icon,
          image: formData.image,
          isActive: formData.isActive,
          displayOrder: formData.displayOrder,
        };
        if (formData.parentId) payload.parentId = formData.parentId;
        if (item) await categoryService.update((item as ServiceCategory)._id, payload);
        else await categoryService.create(payload);
      } else if (type === "service") {
        if (!formData.categoryId) {
          toast.error("Please select a category");
          setIsSubmitting(false);
          return;
        }
        const payload: Partial<ServiceDetails> = {
          name: formData.name,
          description: formData.description,
          icon: formData.icon,
          image: formData.image,
          basePrice: formData.basePrice,
          price: formData.basePrice,
          duration: formData.duration,
          categoryId: formData.categoryId,
          isActive: formData.isActive,
          displayOrder: formData.displayOrder,
        };
        if (item) await serviceService.update((item as ServiceDetails)._id, payload);
        else await serviceService.create(payload);
      } else {
        if (!formData.categoryId) {
          toast.error("Please select a category");
          setIsSubmitting(false);
          return;
        }
        const discountPercentage = formData.originalPrice > 0
          ? Math.max(0, Math.round(((formData.originalPrice - formData.discountedPrice) / formData.originalPrice) * 100))
          : 0;
        const payload: Partial<ServicePackage> = {
          name: formData.name,
          description: formData.description,
          categoryId: formData.categoryId,
          // Tie the package to a specific service when chosen; otherwise it's a
          // category-wide package shown for every service in that category.
          serviceId: formData.serviceId || undefined,
          durationMinutes: formData.durationMinutes,
          originalPrice: formData.originalPrice,
          discountedPrice: formData.discountedPrice,
          discountPercentage,
          isPopular: formData.isPopular,
          isAvailable: formData.isActive,
          displayOrder: formData.displayOrder,
        };
        if (item) await packageService.update((item as ServicePackage)._id, payload);
        else await packageService.create(payload);
      }
      toast.success(item ? "Updated successfully" : "Created successfully");
      onSuccess();
    } catch {
      toast.error("Failed to save");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal title={title} onClose={onClose} size="lg">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
          />
        </div>

        {type === "category" && (
          <>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Icon (Emoji)</label>
                <input
                  type="text"
                  value={formData.icon}
                  onChange={(e) => setFormData({ ...formData, icon: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  maxLength={4}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Parent Category</label>
                <select
                  value={formData.parentId}
                  onChange={(e) => setFormData({ ...formData, parentId: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none"
                >
                  <option value="">Top-level (no parent)</option>
                  {parentCategories
                    .filter((p) => !item || p._id !== (item as ServiceCategory)._id)
                    .map((c) => (
                      <option key={c._id} value={c._id}>{c.name}</option>
                    ))}
                </select>
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Image</label>
              <ImageUpload value={formData.image} onChange={(url) => setFormData({ ...formData, image: url })} />
            </div>
          </>
        )}

        {type === "service" && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Category *</label>
              <select
                value={formData.categoryId}
                onChange={(e) => setFormData({ ...formData, categoryId: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                required
              >
                <option value="">Select Category</option>
                {categories.map((c) => (
                  <option key={c._id} value={c._id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Icon (Emoji)</label>
              <input
                type="text"
                value={formData.icon}
                onChange={(e) => setFormData({ ...formData, icon: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                maxLength={4}
                placeholder="🧹"
              />
              <p className="mt-1 text-xs text-gray-400">Shown on the service tile when no image is uploaded.</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Image</label>
              <ImageUpload value={formData.image} onChange={(url) => setFormData({ ...formData, image: url })} />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Base Price (₹) *</label>
                <input
                  type="number"
                  value={formData.basePrice}
                  onChange={(e) => setFormData({ ...formData, basePrice: Number(e.target.value) })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  min={0}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Duration (minutes) *</label>
                <input
                  type="number"
                  value={formData.duration}
                  onChange={(e) => setFormData({ ...formData, duration: Number(e.target.value) })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  min={1}
                  required
                />
              </div>
            </div>
          </>
        )}

        {type === "package" && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Category *</label>
              <select
                value={formData.categoryId}
                onChange={(e) => setFormData({ ...formData, categoryId: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                required
              >
                <option value="">Select Category</option>
                {categories.map((c) => (
                  <option key={c._id} value={c._id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Service (optional)</label>
              <select
                value={formData.serviceId}
                onChange={(e) => setFormData({ ...formData, serviceId: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
              >
                <option value="">All services in category (category-wide)</option>
                {services
                  .filter((s) => !formData.categoryId || getCategoryId(s.categoryId) === formData.categoryId)
                  .map((s) => (
                    <option key={s._id} value={s._id}>{s.name}</option>
                  ))}
              </select>
              <p className="mt-1 text-xs text-gray-400">Pick a service to show this package only inside that service.</p>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Duration (min) *</label>
                <input
                  type="number"
                  value={formData.durationMinutes}
                  onChange={(e) => setFormData({ ...formData, durationMinutes: Number(e.target.value) })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  min={1}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Original ₹</label>
                <input
                  type="number"
                  value={formData.originalPrice}
                  onChange={(e) => setFormData({ ...formData, originalPrice: Number(e.target.value) })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  min={0}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Discounted ₹ *</label>
                <input
                  type="number"
                  value={formData.discountedPrice}
                  onChange={(e) => setFormData({ ...formData, discountedPrice: Number(e.target.value) })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
                  min={0}
                  required
                />
              </div>
            </div>
            <div className="flex items-center gap-2">
              <input
                id="isPopular"
                type="checkbox"
                checked={formData.isPopular}
                onChange={(e) => setFormData({ ...formData, isPopular: e.target.checked })}
                className="h-4 w-4 rounded border-gray-300 text-purple-600"
              />
              <label htmlFor="isPopular" className="text-sm text-gray-700 flex items-center gap-1">
                <Sparkles className="h-3.5 w-3.5 text-amber-500" /> Mark as Popular
              </label>
            </div>
          </>
        )}

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Display Order</label>
            <input
              type="number"
              value={formData.displayOrder}
              onChange={(e) => setFormData({ ...formData, displayOrder: Number(e.target.value) })}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
              min={0}
            />
          </div>
          <div className="flex items-end">
            <label className="inline-flex items-center gap-2 text-sm text-gray-700">
              <input
                type="checkbox"
                checked={formData.isActive}
                onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                className="h-4 w-4 rounded border-gray-300 text-purple-600"
              />
              {type === "package" ? "Available to customers" : "Active"}
            </label>
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="px-4 py-2 text-sm text-white bg-gradient-to-r from-purple-600 to-indigo-600 rounded-lg hover:shadow-md disabled:opacity-50"
          >
            {isSubmitting ? "Saving..." : item ? "Update" : "Create"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
