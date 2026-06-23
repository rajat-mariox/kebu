import { useState, useEffect } from "react";
import toast from "react-hot-toast";
import {
  Home,
  TrendingUp,
  IndianRupee,
  Star,
  Plus,
  Edit2,
  Trash2,
  X,
  Zap,
  Ban,
  Users,
} from "lucide-react";
import {
  serviceHoursService,
  bookingTypeConfigService,
  type HouseholdServiceHours,
  type BookingTypeConfig,
} from "../services/household.service";
import { offerService, type OfferRecord } from "../services/offer.service";
import ImageUpload from "../components/ImageUpload";
import {
  getSurgeConfigs,
  createSurgeConfig,
  updateSurgeConfig,
  deleteSurgeConfig,
  getCancellationPolicies,
  createCancellationPolicy,
  updateCancellationPolicy,
  deleteCancellationPolicy,
  getHouseholdAnalytics,
} from "../services/service-config.service";
import type {
  SurgeConfig,
  CancellationPolicy,
  HouseholdAnalytics,
} from "../types";
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";

const COLORS = ["#3b82f6", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899"];
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

type Tab =
  | "analytics"
  | "surge"
  | "cancellation"
  | "hours"
  | "prebook"
  | "pricing"
  | "banners";

const TAB_OPTIONS: { key: Tab; label: string }[] = [
  { key: "analytics", label: "Analytics" },
  { key: "pricing", label: "Services & Pricing" },
  { key: "banners", label: "Banners" },
  { key: "surge", label: "Surge Pricing" },
  { key: "cancellation", label: "Cancellation Policy" },
  { key: "hours", label: "Operating Hours" },
  { key: "prebook", label: "Global Pre-book Pricing" },
];

const BANNER_SECTIONS: Array<{ value: OfferRecord["section"]; label: string }> =
  [
    { value: "latest", label: "Latest Offers" },
    { value: "limited", label: "Limited Offer" },
    { value: "just_for_you", label: "Just For You" },
  ];

type BannerFormState = {
  title: string;
  subtitle: string;
  description: string;
  section: OfferRecord["section"];
  code: string;
  bannerImage: string;
  tag: string;
  priority: number;
  startDate: string;
  endDate: string;
  isActive: boolean;
};

const toInputDate = (iso?: string) => {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

const emptyBannerForm = (): BannerFormState => {
  const today = new Date();
  const nextMonth = new Date();
  nextMonth.setDate(nextMonth.getDate() + 30);
  return {
    title: "",
    subtitle: "",
    description: "",
    section: "latest",
    code: "",
    bannerImage: "",
    tag: "",
    priority: 0,
    startDate: toInputDate(today.toISOString()),
    endDate: toInputDate(nextMonth.toISOString()),
    isActive: true,
  };
};

export default function HouseholdManagement() {
  const [tab, setTab] = useState<Tab>("analytics");
  const [range, setRange] = useState("7d");

  // Analytics
  const [analytics, setAnalytics] = useState<HouseholdAnalytics | null>(null);
  const [loadingAnalytics, setLoadingAnalytics] = useState(false);

  // Surge
  const [surges, setSurges] = useState<SurgeConfig[]>([]);
  const [surgeModal, setSurgeModal] = useState(false);
  const [editingSurge, setEditingSurge] = useState<SurgeConfig | null>(null);
  const [surgeForm, setSurgeForm] = useState({
    name: "",
    multiplier: 1.5,
    maxMultiplier: 3,
    isActive: true,
    conditions: {
      triggerType: "time" as SurgeConfig["conditions"]["triggerType"],
      timeStart: "",
      timeEnd: "",
      daysOfWeek: [] as number[],
      demandThreshold: 0,
    },
  });

  // Operating hours
  const [hours, setHours] = useState<HouseholdServiceHours | null>(null);
  const [hoursLoading, setHoursLoading] = useState(false);
  const [hoursSaving, setHoursSaving] = useState(false);

  // Pre-book pricing (Single / Multiple)
  const [bookingTypes, setBookingTypes] = useState<BookingTypeConfig[]>([]);
  const [bookingTypesLoading, setBookingTypesLoading] = useState(false);
  const [bookingTypeSaving, setBookingTypeSaving] = useState<string | null>(null);

  // Household Banners (offers filtered to applicableOn HOUSEHOLD)
  const [banners, setBanners] = useState<OfferRecord[]>([]);
  const [bannersLoading, setBannersLoading] = useState(false);
  const [bannerModal, setBannerModal] = useState(false);
  const [editingBanner, setEditingBanner] = useState<OfferRecord | null>(null);
  const [bannerForm, setBannerForm] = useState<BannerFormState>(emptyBannerForm());
  const [bannerSaving, setBannerSaving] = useState(false);

  // Cancellation
  const [policies, setPolicies] = useState<CancellationPolicy[]>([]);
  const [policyModal, setPolicyModal] = useState(false);
  const [editingPolicy, setEditingPolicy] = useState<CancellationPolicy | null>(null);
  const [policyForm, setPolicyForm] = useState<{
    name: string;
    isActive: boolean;
    rules: {
      cancelledBy: CancellationPolicy["rules"][number]["cancelledBy"];
      beforeStatus: string;
      chargeType: CancellationPolicy["rules"][number]["chargeType"];
      chargeValue: number;
      refundPercentage: number;
      penaltyToDriver: number;
    }[];
  }>({
    name: "",
    isActive: true,
    rules: [
      {
        cancelledBy: "USER",
        beforeStatus: "PENDING",
        chargeType: "none",
        chargeValue: 0,
        refundPercentage: 100,
        penaltyToDriver: 0,
      },
    ],
  });

  useEffect(() => {
    if (tab === "analytics") loadAnalytics();
    if (tab === "surge") loadSurges();
    if (tab === "cancellation") loadPolicies();
    if (tab === "hours") loadHours();
    if (tab === "prebook") loadBookingTypes();
    if (tab === "banners") loadBanners();
  }, [tab, range]);

  // ── Data Loading ──────────────────────────────────────────
  const loadAnalytics = async () => {
    setLoadingAnalytics(true);
    try {
      const res = await getHouseholdAnalytics({ range });
      setAnalytics(res.data.data);
    } catch {
      toast.error("Failed to load analytics");
    }
    setLoadingAnalytics(false);
  };

  const loadSurges = async () => {
    try {
      const res = await getSurgeConfigs("household");
      setSurges(res.data.data?.configs || []);
    } catch {
      toast.error("Failed to load surge configs");
    }
  };

  const loadPolicies = async () => {
    try {
      const res = await getCancellationPolicies("household");
      setPolicies(res.data.data?.policies || []);
    } catch {
      toast.error("Failed to load policies");
    }
  };

  const loadHours = async () => {
    setHoursLoading(true);
    try {
      const res = await serviceHoursService.get();
      setHours(res.data ?? null);
    } catch {
      toast.error("Failed to load operating hours");
    } finally {
      setHoursLoading(false);
    }
  };

  const loadBookingTypes = async () => {
    setBookingTypesLoading(true);
    try {
      const res = await bookingTypeConfigService.getAll();
      setBookingTypes(res.data?.bookingTypes || []);
    } catch {
      toast.error("Failed to load pre-book pricing");
    } finally {
      setBookingTypesLoading(false);
    }
  };

  const loadBanners = async () => {
    setBannersLoading(true);
    try {
      // Pull all offers and keep household-applicable ones (HOUSEHOLD or ALL).
      const list = await offerService.getAll();
      setBanners(
        list.filter(
          (o) => o.applicableOn === "HOUSEHOLD" || o.applicableOn === "ALL",
        ),
      );
    } catch {
      toast.error("Failed to load household banners");
    } finally {
      setBannersLoading(false);
    }
  };

  const openBannerCreate = () => {
    setEditingBanner(null);
    setBannerForm(emptyBannerForm());
    setBannerModal(true);
  };

  const openBannerEdit = (banner: OfferRecord) => {
    setEditingBanner(banner);
    setBannerForm({
      title: banner.title || "",
      subtitle: banner.subtitle || "",
      description: banner.description || "",
      section: banner.section || "latest",
      code: banner.code || "",
      bannerImage: banner.bannerImage || banner.image || "",
      tag: banner.tag || "",
      priority: banner.priority || 0,
      startDate: toInputDate(banner.startDate),
      endDate: toInputDate(banner.endDate),
      isActive: banner.isActive,
    });
    setBannerModal(true);
  };

  const saveBanner = async () => {
    if (!bannerForm.title.trim() || !bannerForm.description.trim()) {
      toast.error("Title and description are required");
      return;
    }
    if (!bannerForm.startDate || !bannerForm.endDate) {
      toast.error("Start and end date are required");
      return;
    }
    if (new Date(bannerForm.endDate) < new Date(bannerForm.startDate)) {
      toast.error("End date must be after start date");
      return;
    }

    const payload: Partial<OfferRecord> = {
      title: bannerForm.title.trim(),
      subtitle: bannerForm.subtitle.trim() || undefined,
      description: bannerForm.description.trim(),
      section: bannerForm.section,
      // Household banners always target the cleaning/household flow + applicable on household.
      applicableOn: "HOUSEHOLD",
      targetService: "cleaning",
      code: bannerForm.code.trim() || undefined,
      bannerImage: bannerForm.bannerImage || undefined,
      image: bannerForm.bannerImage || undefined,
      tag: bannerForm.tag.trim() || undefined,
      priority: Number(bannerForm.priority) || 0,
      startDate: new Date(bannerForm.startDate).toISOString(),
      endDate: new Date(bannerForm.endDate).toISOString(),
      isActive: bannerForm.isActive,
    };

    setBannerSaving(true);
    try {
      if (editingBanner) {
        await offerService.update(editingBanner._id, payload);
        toast.success("Banner updated");
      } else {
        await offerService.create(payload);
        toast.success("Banner created");
      }
      setBannerModal(false);
      loadBanners();
    } catch (err: any) {
      const msg =
        err?.response?.data?.msg || err?.message || "Failed to save banner";
      toast.error(msg);
    } finally {
      setBannerSaving(false);
    }
  };

  const removeBanner = async (banner: OfferRecord) => {
    if (!confirm(`Delete banner "${banner.title}"?`)) return;
    try {
      await offerService.remove(banner._id);
      toast.success("Banner deleted");
      loadBanners();
    } catch {
      toast.error("Delete failed");
    }
  };

  const toggleBanner = async (banner: OfferRecord) => {
    try {
      await offerService.toggleStatus(banner._id);
      toast.success(banner.isActive ? "Banner deactivated" : "Banner activated");
      loadBanners();
    } catch {
      toast.error("Toggle failed");
    }
  };

  const saveBookingType = async (cfg: BookingTypeConfig) => {
    setBookingTypeSaving(cfg.bookingType);
    try {
      const res = await bookingTypeConfigService.update(cfg.bookingType, {
        title: cfg.title,
        description: cfg.description,
        basePrice: cfg.basePrice,
        discountedPrice: cfg.discountedPrice,
        displayOrder: cfg.displayOrder,
        isActive: cfg.isActive,
      });
      const updated = res.data?.bookingType;
      if (updated) {
        setBookingTypes((list) =>
          list.map((b) => (b.bookingType === cfg.bookingType ? updated : b)),
        );
      }
      toast.success(`${cfg.bookingType === "SINGLE" ? "Single" : "Multiple"} booking pricing saved`);
    } catch {
      toast.error("Failed to save pricing");
    } finally {
      setBookingTypeSaving(null);
    }
  };

  const saveHours = async () => {
    if (!hours) return;
    setHoursSaving(true);
    try {
      const res = await serviceHoursService.update({
        openTime: hours.openTime,
        closeTime: hours.closeTime,
        daysActive: hours.daysActive,
        timezone: hours.timezone,
        isEnabled: hours.isEnabled,
        closedMessage: hours.closedMessage,
      });
      setHours(res.data ?? hours);
      toast.success("Operating hours updated");
    } catch {
      toast.error("Failed to save operating hours");
    } finally {
      setHoursSaving(false);
    }
  };

  // ── Surge CRUD ────────────────────────────────────────────
  const openSurgeCreate = () => {
    setEditingSurge(null);
    setSurgeForm({
      name: "", multiplier: 1.5, maxMultiplier: 3, isActive: true,
      conditions: { triggerType: "time", timeStart: "", timeEnd: "", daysOfWeek: [], demandThreshold: 0 },
    });
    setSurgeModal(true);
  };

  const openSurgeEdit = (s: SurgeConfig) => {
    setEditingSurge(s);
    setSurgeForm({
      name: s.name,
      multiplier: s.multiplier,
      maxMultiplier: s.maxMultiplier,
      isActive: s.isActive,
      conditions: {
        triggerType: s.conditions.triggerType,
        timeStart: s.conditions.timeStart || "",
        timeEnd: s.conditions.timeEnd || "",
        daysOfWeek: s.conditions.daysOfWeek || [],
        demandThreshold: s.conditions.demandThreshold || 0,
      },
    });
    setSurgeModal(true);
  };

  const saveSurge = async () => {
    try {
      const payload = { ...surgeForm, serviceType: "household" };
      if (editingSurge) {
        await updateSurgeConfig(editingSurge._id, payload);
        toast.success("Surge config updated");
      } else {
        await createSurgeConfig(payload);
        toast.success("Surge config created");
      }
      setSurgeModal(false);
      loadSurges();
    } catch {
      toast.error("Failed to save surge config");
    }
  };

  const removeSurge = async (id: string) => {
    if (!confirm("Delete this surge config?")) return;
    try {
      await deleteSurgeConfig(id);
      toast.success("Deleted");
      loadSurges();
    } catch {
      toast.error("Failed to delete");
    }
  };

  // ── Cancellation CRUD ─────────────────────────────────────
  const openPolicyCreate = () => {
    setEditingPolicy(null);
    setPolicyForm({
      name: "", isActive: true,
      rules: [{ cancelledBy: "USER", beforeStatus: "PENDING", chargeType: "none", chargeValue: 0, refundPercentage: 100, penaltyToDriver: 0 }],
    });
    setPolicyModal(true);
  };

  const openPolicyEdit = (p: CancellationPolicy) => {
    setEditingPolicy(p);
    setPolicyForm({
      name: p.name,
      isActive: p.isActive,
      rules: p.rules.map((r) => ({
        cancelledBy: r.cancelledBy,
        beforeStatus: r.beforeStatus,
        chargeType: r.chargeType,
        chargeValue: r.chargeValue,
        refundPercentage: r.refundPercentage,
        penaltyToDriver: r.penaltyToDriver || 0,
      })),
    });
    setPolicyModal(true);
  };

  const savePolicy = async () => {
    try {
      const payload = { ...policyForm, serviceType: "household" };
      if (editingPolicy) {
        await updateCancellationPolicy(editingPolicy._id, payload);
        toast.success("Policy updated");
      } else {
        await createCancellationPolicy(payload);
        toast.success("Policy created");
      }
      setPolicyModal(false);
      loadPolicies();
    } catch {
      toast.error("Failed to save policy");
    }
  };

  const removePolicy = async (id: string) => {
    if (!confirm("Delete this policy?")) return;
    try {
      await deleteCancellationPolicy(id);
      toast.success("Deleted");
      loadPolicies();
    } catch {
      toast.error("Failed to delete");
    }
  };

  const addRule = () => {
    setPolicyForm((f) => ({
      ...f,
      rules: [...f.rules, { cancelledBy: "USER" as const, beforeStatus: "PENDING", chargeType: "none" as const, chargeValue: 0, refundPercentage: 100, penaltyToDriver: 0 }],
    }));
  };

  const removeRule = (idx: number) => {
    setPolicyForm((f) => ({ ...f, rules: f.rules.filter((_, i) => i !== idx) }));
  };

  const updateRule = (idx: number, field: string, value: any) => {
    setPolicyForm((f) => ({
      ...f,
      rules: f.rules.map((r, i) => (i === idx ? { ...r, [field]: value } : r)),
    }));
  };

  const toggleDay = (day: number) => {
    setSurgeForm((f) => ({
      ...f,
      conditions: {
        ...f.conditions,
        daysOfWeek: f.conditions.daysOfWeek.includes(day)
          ? f.conditions.daysOfWeek.filter((d) => d !== day)
          : [...f.conditions.daysOfWeek, day],
      },
    }));
  };

  const st = analytics?.stats;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Home className="h-7 w-7 text-teal-600" /> Household Management
          </h1>
          <p className="text-sm text-gray-500 mt-1">Manage household service pricing, surge rules, and cancellation policies</p>
        </div>
      </div>

      {/* Section selector (dropdown) */}
      <div className="flex items-center gap-3">
        <label className="text-sm font-medium text-gray-700">Section</label>
        <select
          value={tab}
          onChange={(e) => setTab(e.target.value as Tab)}
          className="border rounded-lg px-3 py-2 text-sm bg-white shadow-sm focus:border-teal-500 focus:outline-none focus:ring-1 focus:ring-teal-500"
        >
          {TAB_OPTIONS.map(({ key, label }) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
      </div>

      {/* ═══════════ ANALYTICS TAB ═══════════ */}
      {tab === "analytics" && (
        <div className="space-y-6">
          <div className="flex gap-2">
            {["today", "7d", "30d"].map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={`px-3 py-1.5 text-sm rounded-lg ${
                  range === r ? "bg-teal-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                }`}
              >
                {r === "today" ? "Today" : r === "7d" ? "7 Days" : "30 Days"}
              </button>
            ))}
          </div>

          {loadingAnalytics ? (
            <div className="flex justify-center py-12"><div className="h-8 w-8 animate-spin rounded-full border-4 border-teal-600 border-t-transparent" /></div>
          ) : analytics ? (
            <>
              {/* KPI Cards */}
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                {[
                  { label: "Total Bookings", value: st?.totalBookings || 0, icon: Home, color: "teal" },
                  { label: "Completed", value: st?.completed || 0, icon: TrendingUp, color: "green" },
                  { label: "Cancelled", value: st?.cancelled || 0, icon: Ban, color: "red" },
                  { label: "Revenue", value: `₹${((st?.totalRevenue || 0) / 1000).toFixed(1)}K`, icon: IndianRupee, color: "emerald" },
                  { label: "Avg Cost", value: `₹${Math.round(st?.avgCost || 0)}`, icon: IndianRupee, color: "purple" },
                ].map((kpi) => (
                  <div key={kpi.label} className="bg-white rounded-xl border p-4">
                    <div className="flex items-center gap-2 mb-2">
                      <kpi.icon className={`h-4 w-4 text-${kpi.color}-500`} />
                      <span className="text-xs text-gray-500">{kpi.label}</span>
                    </div>
                    <p className="text-xl font-bold text-gray-900">{kpi.value}</p>
                  </div>
                ))}
              </div>

              {/* Charts */}
              <div className="grid lg:grid-cols-2 gap-6">
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Booking Trend</h3>
                  <ResponsiveContainer width="100%" height={280}>
                    <LineChart data={analytics.trend}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip />
                      <Line type="monotone" dataKey="bookings" stroke="#14b8a6" strokeWidth={2} dot={false} />
                      <Line type="monotone" dataKey="revenue" stroke="#10b981" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>

                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Revenue by Category</h3>
                  <ResponsiveContainer width="100%" height={280}>
                    <BarChart data={analytics.byCategory}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="_id" fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip />
                      <Bar dataKey="revenue" fill="#14b8a6" radius={[6, 6, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Status & Top Providers */}
              <div className="grid lg:grid-cols-2 gap-6">
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Status Breakdown</h3>
                  <ResponsiveContainer width="100%" height={250}>
                    <PieChart>
                      <Pie data={analytics.byStatus} dataKey="count" nameKey="_id" cx="50%" cy="50%" outerRadius={90} label={({ name, percent }) => `${name} ${((percent ?? 0) * 100).toFixed(0)}%`}>
                        {analytics.byStatus.map((_, i) => (
                          <Cell key={i} fill={COLORS[i % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </div>

                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4 flex items-center gap-2">
                    <Users className="h-4 w-4" /> Top Providers
                  </h3>
                  {analytics.topProviders?.length ? (
                    <div className="space-y-3">
                      {analytics.topProviders.slice(0, 5).map((p, i) => (
                        <div key={p._id} className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <span className="w-6 h-6 rounded-full bg-teal-100 text-teal-700 text-xs flex items-center justify-center font-semibold">{i + 1}</span>
                            <div>
                              <p className="text-sm font-medium text-gray-900">{p.name}</p>
                              <p className="text-xs text-gray-400">{p.bookings} bookings</p>
                            </div>
                          </div>
                          <div className="text-right">
                            <p className="text-sm font-semibold text-gray-900">₹{Math.round(p.revenue)}</p>
                            <div className="flex items-center gap-1 justify-end">
                              <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                              <span className="text-xs text-gray-500">{p.avgRating.toFixed(1)}</span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-gray-400 py-4 text-center">No provider data available</p>
                  )}
                </div>
              </div>
            </>
          ) : null}
        </div>
      )}

      {/* ═══════════ SURGE TAB ═══════════ */}
      {tab === "surge" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={openSurgeCreate} className="flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 text-sm font-medium">
              <Plus className="h-4 w-4" /> Add Surge Rule
            </button>
          </div>
          <div className="bg-white rounded-xl border overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Trigger</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Multiplier</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Max</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Days</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {surges.length === 0 ? (
                  <tr><td colSpan={8} className="px-4 py-8 text-center text-gray-400">No surge rules configured</td></tr>
                ) : surges.map((s) => (
                  <tr key={s._id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm font-medium text-gray-900">{s.name}</td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-amber-100 text-amber-700 capitalize">{s.conditions.triggerType}</span>
                    </td>
                    <td className="px-4 py-3 text-sm font-semibold text-amber-600">{s.multiplier}x</td>
                    <td className="px-4 py-3 text-sm text-gray-500">{s.maxMultiplier}x</td>
                    <td className="px-4 py-3 text-sm text-gray-500">
                      {s.conditions.timeStart && s.conditions.timeEnd ? `${s.conditions.timeStart} - ${s.conditions.timeEnd}` : "-"}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500">
                      {s.conditions.daysOfWeek?.length ? s.conditions.daysOfWeek.map((d) => DAYS[d]).join(", ") : "All"}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 text-xs rounded-full ${s.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
                        {s.isActive ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button onClick={() => openSurgeEdit(s)} className="p-1.5 text-gray-400 hover:text-blue-600"><Edit2 className="h-4 w-4" /></button>
                      <button onClick={() => removeSurge(s._id)} className="p-1.5 text-gray-400 hover:text-red-600"><Trash2 className="h-4 w-4" /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ═══════════ CANCELLATION TAB ═══════════ */}
      {tab === "cancellation" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={openPolicyCreate} className="flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 text-sm font-medium">
              <Plus className="h-4 w-4" /> Add Policy
            </button>
          </div>
          {policies.length === 0 ? (
            <div className="bg-white rounded-xl border p-8 text-center text-gray-400">No cancellation policies configured</div>
          ) : policies.map((p) => (
            <div key={p._id} className="bg-white rounded-xl border p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <h3 className="font-semibold text-gray-900">{p.name}</h3>
                  <span className={`px-2 py-0.5 text-xs rounded-full ${p.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
                    {p.isActive ? "Active" : "Inactive"}
                  </span>
                </div>
                <div className="flex gap-1">
                  <button onClick={() => openPolicyEdit(p)} className="p-1.5 text-gray-400 hover:text-blue-600"><Edit2 className="h-4 w-4" /></button>
                  <button onClick={() => removePolicy(p._id)} className="p-1.5 text-gray-400 hover:text-red-600"><Trash2 className="h-4 w-4" /></button>
                </div>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-xs text-gray-500 uppercase border-b">
                    <th className="py-2 text-left">Cancelled By</th>
                    <th className="py-2 text-left">Before Status</th>
                    <th className="py-2 text-left">Charge</th>
                    <th className="py-2 text-left">Refund %</th>
                    <th className="py-2 text-left">Provider Penalty</th>
                  </tr>
                </thead>
                <tbody>
                  {p.rules.map((r, i) => (
                    <tr key={i} className="border-b last:border-0">
                      <td className="py-2 font-medium">{r.cancelledBy}</td>
                      <td className="py-2 text-gray-600">{r.beforeStatus}</td>
                      <td className="py-2 text-gray-600">
                        {r.chargeType === "none" ? "No charge" : r.chargeType === "flat" ? `₹${r.chargeValue}` : `${r.chargeValue}%`}
                      </td>
                      <td className="py-2 text-gray-600">{r.refundPercentage}%</td>
                      <td className="py-2 text-gray-600">{r.penaltyToDriver ? `₹${r.penaltyToDriver}` : "-"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}

      {/* ═══════════ HOUSEHOLD BANNERS TAB ═══════════ */}
      {tab === "banners" && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border p-4 flex items-center justify-between">
            <div>
              <h3 className="font-semibold text-gray-900">Household Banners</h3>
              <p className="text-sm text-gray-500 mt-0.5">
                Banners shown on the customer Household screen. Inactive or
                expired banners are hidden automatically.
              </p>
            </div>
            <button
              onClick={openBannerCreate}
              className="flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 text-sm font-medium"
            >
              <Plus className="h-4 w-4" /> Add Banner
            </button>
          </div>

          {bannersLoading ? (
            <div className="bg-white rounded-xl border p-8 text-center text-gray-400">
              Loading...
            </div>
          ) : banners.length === 0 ? (
            <div className="bg-white rounded-xl border p-8 text-center text-gray-400">
              No household banners yet. Click "Add Banner" to create one.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
              {banners.map((b) => (
                <div
                  key={b._id}
                  className="bg-white rounded-xl border overflow-hidden flex flex-col"
                >
                  <div className="h-32 bg-gradient-to-r from-pink-500 to-purple-600 flex items-center justify-center">
                    {b.bannerImage || b.image ? (
                      <img
                        src={b.bannerImage || b.image}
                        alt={b.title}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <span className="text-white text-sm font-medium px-3 text-center">
                        {b.title}
                      </span>
                    )}
                  </div>
                  <div className="p-4 space-y-2 flex-1 flex flex-col">
                    <div className="flex items-start justify-between gap-2">
                      <h4 className="font-semibold text-gray-900 text-sm leading-tight">
                        {b.title}
                      </h4>
                      <span
                        className={`text-xs px-2 py-0.5 rounded-full ${
                          b.isActive
                            ? "bg-green-100 text-green-700"
                            : "bg-gray-100 text-gray-500"
                        }`}
                      >
                        {b.isActive ? "Active" : "Inactive"}
                      </span>
                    </div>
                    {b.subtitle && (
                      <p className="text-xs text-gray-500 line-clamp-2">
                        {b.subtitle}
                      </p>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-500">
                      <span className="px-2 py-0.5 rounded bg-gray-100 capitalize">
                        {b.section.replace("_", " ")}
                      </span>
                      {b.code && (
                        <span className="px-2 py-0.5 rounded bg-amber-100 text-amber-700">
                          {b.code}
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-gray-400">
                      {toInputDate(b.startDate)} → {toInputDate(b.endDate)}
                    </div>
                    <div className="flex items-center gap-2 pt-2 mt-auto">
                      <button
                        onClick={() => openBannerEdit(b)}
                        className="flex-1 px-3 py-1.5 text-xs border rounded-lg hover:bg-gray-50 flex items-center justify-center gap-1"
                      >
                        <Edit2 className="h-3 w-3" /> Edit
                      </button>
                      <button
                        onClick={() => toggleBanner(b)}
                        className="flex-1 px-3 py-1.5 text-xs border rounded-lg hover:bg-gray-50 flex items-center justify-center gap-1"
                      >
                        <Zap className="h-3 w-3" />
                        {b.isActive ? "Disable" : "Enable"}
                      </button>
                      <button
                        onClick={() => removeBanner(b)}
                        className="px-3 py-1.5 text-xs border rounded-lg hover:bg-red-50 text-red-600"
                      >
                        <Trash2 className="h-3 w-3" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ═══════════ BANNER MODAL ═══════════ */}
      {bannerModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">
                {editingBanner ? "Edit Banner" : "Add Household Banner"}
              </h2>
              <button
                onClick={() => setBannerModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Title *
                  </label>
                  <input
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.title}
                    onChange={(e) =>
                      setBannerForm((f) => ({ ...f, title: e.target.value }))
                    }
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Subtitle
                  </label>
                  <input
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.subtitle}
                    onChange={(e) =>
                      setBannerForm((f) => ({ ...f, subtitle: e.target.value }))
                    }
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description *
                </label>
                <textarea
                  rows={2}
                  className="w-full border rounded-lg px-3 py-2 text-sm"
                  value={bannerForm.description}
                  onChange={(e) =>
                    setBannerForm((f) => ({
                      ...f,
                      description: e.target.value,
                    }))
                  }
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Banner Image
                </label>
                <ImageUpload
                  value={bannerForm.bannerImage}
                  onChange={(url) =>
                    setBannerForm((f) => ({ ...f, bannerImage: url }))
                  }
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Section
                  </label>
                  <select
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.section}
                    onChange={(e) =>
                      setBannerForm((f) => ({
                        ...f,
                        section: e.target.value as OfferRecord["section"],
                      }))
                    }
                  >
                    {BANNER_SECTIONS.map((s) => (
                      <option key={s.value} value={s.value}>
                        {s.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Promo Code (optional)
                  </label>
                  <input
                    className="w-full border rounded-lg px-3 py-2 text-sm uppercase"
                    value={bannerForm.code}
                    onChange={(e) =>
                      setBannerForm((f) => ({ ...f, code: e.target.value }))
                    }
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tag
                  </label>
                  <input
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    placeholder="e.g. Trending"
                    value={bannerForm.tag}
                    onChange={(e) =>
                      setBannerForm((f) => ({ ...f, tag: e.target.value }))
                    }
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Start Date *
                  </label>
                  <input
                    type="date"
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.startDate}
                    onChange={(e) =>
                      setBannerForm((f) => ({
                        ...f,
                        startDate: e.target.value,
                      }))
                    }
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    End Date *
                  </label>
                  <input
                    type="date"
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.endDate}
                    onChange={(e) =>
                      setBannerForm((f) => ({ ...f, endDate: e.target.value }))
                    }
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Priority
                  </label>
                  <input
                    type="number"
                    min={0}
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    value={bannerForm.priority}
                    onChange={(e) =>
                      setBannerForm((f) => ({
                        ...f,
                        priority: Number(e.target.value),
                      }))
                    }
                  />
                </div>
              </div>

              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={bannerForm.isActive}
                  onChange={(e) =>
                    setBannerForm((f) => ({ ...f, isActive: e.target.checked }))
                  }
                  className="rounded"
                />
                <span className="text-sm text-gray-700">Active</span>
              </label>

              <div className="flex justify-end gap-3 pt-2">
                <button
                  onClick={() => setBannerModal(false)}
                  className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={saveBanner}
                  disabled={bannerSaving}
                  className="px-4 py-2 text-sm bg-teal-600 text-white rounded-lg hover:bg-teal-700 disabled:opacity-50"
                >
                  {bannerSaving
                    ? "Saving..."
                    : editingBanner
                      ? "Update"
                      : "Create"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ═══════════ OPERATING HOURS TAB ═══════════ */}
      {tab === "hours" && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border p-6 max-w-2xl">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="font-semibold text-gray-900 text-lg">Household Service Operating Hours</h3>
                <p className="text-sm text-gray-500 mt-1">Controls when customers can book household services</p>
              </div>
              {hours?.isOpen !== undefined && (
                <span className={`px-3 py-1 text-xs font-medium rounded-full ${hours.isOpen ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700"}`}>
                  {hours.isOpen ? "Currently Open" : "Currently Closed"}
                </span>
              )}
            </div>

            {hoursLoading || !hours ? (
              <div className="py-8 text-center text-gray-400">Loading...</div>
            ) : (
              <div className="space-y-5">
                <label className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    checked={hours.isEnabled}
                    onChange={(e) => setHours({ ...hours, isEnabled: e.target.checked })}
                    className="h-4 w-4"
                  />
                  <span className="text-sm font-medium text-gray-700">Service enabled</span>
                </label>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Open Time</label>
                    <input
                      type="time"
                      value={hours.openTime}
                      onChange={(e) => setHours({ ...hours, openTime: e.target.value })}
                      className="w-full border rounded-lg px-3 py-2 text-sm"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Close Time</label>
                    <input
                      type="time"
                      value={hours.closeTime}
                      onChange={(e) => setHours({ ...hours, closeTime: e.target.value })}
                      className="w-full border rounded-lg px-3 py-2 text-sm"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Active Days</label>
                  <div className="flex gap-2 flex-wrap">
                    {DAYS.map((d, i) => {
                      const active = hours.daysActive.includes(i);
                      return (
                        <button
                          key={d}
                          type="button"
                          onClick={() =>
                            setHours({
                              ...hours,
                              daysActive: active
                                ? hours.daysActive.filter((x) => x !== i)
                                : [...hours.daysActive, i].sort(),
                            })
                          }
                          className={`px-3 py-1.5 rounded-lg text-sm font-medium ${active ? "bg-teal-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}
                        >
                          {d}
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Timezone</label>
                  <input
                    value={hours.timezone}
                    onChange={(e) => setHours({ ...hours, timezone: e.target.value })}
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    placeholder="Asia/Kolkata"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Closed Message</label>
                  <textarea
                    value={hours.closedMessage ?? ""}
                    onChange={(e) => setHours({ ...hours, closedMessage: e.target.value })}
                    rows={2}
                    className="w-full border rounded-lg px-3 py-2 text-sm"
                    placeholder="Shown to customers when outside service hours"
                  />
                </div>

                <div className="pt-2">
                  <button
                    onClick={saveHours}
                    disabled={hoursSaving}
                    className="px-5 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 disabled:opacity-50 text-sm font-medium"
                  >
                    {hoursSaving ? "Saving..." : "Save Changes"}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ═══════════ PRE-BOOK PRICING TAB ═══════════ */}
      {tab === "prebook" && (
        <div className="space-y-4 max-w-4xl">
          <div className="bg-white rounded-xl border p-6">
            <h3 className="font-semibold text-gray-900 text-lg">
              Pre-book Tile Pricing
            </h3>
            <p className="text-sm text-gray-500 mt-1">
              Controls the "Single Booking" and "Multiple Booking" cards customers see on the pre-book screen.
            </p>
          </div>

          {bookingTypesLoading ? (
            <div className="bg-white rounded-xl border p-8 text-center text-gray-400">
              Loading...
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {bookingTypes.map((cfg) => (
                <div key={cfg.bookingType} className="bg-white rounded-xl border p-6 space-y-4">
                  <div className="flex items-center justify-between">
                    <h4 className="font-semibold text-gray-900">
                      {cfg.bookingType === "SINGLE" ? "Single Booking" : "Multiple Booking"}
                    </h4>
                    <label className="flex items-center gap-2 text-xs">
                      <input
                        type="checkbox"
                        checked={cfg.isActive}
                        onChange={(e) =>
                          setBookingTypes((list) =>
                            list.map((b) =>
                              b.bookingType === cfg.bookingType
                                ? { ...b, isActive: e.target.checked }
                                : b,
                            ),
                          )
                        }
                        className="h-4 w-4"
                      />
                      Active
                    </label>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
                    <input
                      value={cfg.title}
                      onChange={(e) =>
                        setBookingTypes((list) =>
                          list.map((b) =>
                            b.bookingType === cfg.bookingType
                              ? { ...b, title: e.target.value }
                              : b,
                          ),
                        )
                      }
                      className="w-full border rounded-lg px-3 py-2 text-sm"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                    <input
                      value={cfg.description ?? ""}
                      onChange={(e) =>
                        setBookingTypes((list) =>
                          list.map((b) =>
                            b.bookingType === cfg.bookingType
                              ? { ...b, description: e.target.value }
                              : b,
                          ),
                        )
                      }
                      className="w-full border rounded-lg px-3 py-2 text-sm"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Base Price (₹)</label>
                      <input
                        type="number"
                        min={0}
                        value={cfg.basePrice}
                        onChange={(e) =>
                          setBookingTypes((list) =>
                            list.map((b) =>
                              b.bookingType === cfg.bookingType
                                ? { ...b, basePrice: Number(e.target.value) }
                                : b,
                            ),
                          )
                        }
                        className="w-full border rounded-lg px-3 py-2 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Discounted Price (₹)</label>
                      <input
                        type="number"
                        min={0}
                        value={cfg.discountedPrice ?? 0}
                        onChange={(e) =>
                          setBookingTypes((list) =>
                            list.map((b) =>
                              b.bookingType === cfg.bookingType
                                ? { ...b, discountedPrice: Number(e.target.value) }
                                : b,
                            ),
                          )
                        }
                        className="w-full border rounded-lg px-3 py-2 text-sm"
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Display Order</label>
                    <input
                      type="number"
                      min={0}
                      value={cfg.displayOrder}
                      onChange={(e) =>
                        setBookingTypes((list) =>
                          list.map((b) =>
                            b.bookingType === cfg.bookingType
                              ? { ...b, displayOrder: Number(e.target.value) }
                              : b,
                          ),
                        )
                      }
                      className="w-full border rounded-lg px-3 py-2 text-sm"
                    />
                  </div>
                  <button
                    onClick={() => saveBookingType(cfg)}
                    disabled={bookingTypeSaving === cfg.bookingType}
                    className="px-5 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 disabled:opacity-50 text-sm font-medium"
                  >
                    {bookingTypeSaving === cfg.bookingType ? "Saving..." : "Save"}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ═══════════ SURGE MODAL ═══════════ */}
      {surgeModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">{editingSurge ? "Edit" : "Add"} Surge Rule</h2>
              <button onClick={() => setSurgeModal(false)} className="text-gray-400 hover:text-gray-600"><X className="h-5 w-5" /></button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.name} onChange={(e) => setSurgeForm((f) => ({ ...f, name: e.target.value }))} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Multiplier</label>
                  <input type="number" step="0.1" min="1" className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.multiplier} onChange={(e) => setSurgeForm((f) => ({ ...f, multiplier: parseFloat(e.target.value) }))} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Max Multiplier</label>
                  <input type="number" step="0.1" min="1" className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.maxMultiplier} onChange={(e) => setSurgeForm((f) => ({ ...f, maxMultiplier: parseFloat(e.target.value) }))} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Trigger Type</label>
                <select className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.conditions.triggerType} onChange={(e) => setSurgeForm((f) => ({ ...f, conditions: { ...f.conditions, triggerType: e.target.value as any } }))}>
                  <option value="time">Time-based</option>
                  <option value="demand">Demand-based</option>
                  <option value="weather">Weather</option>
                  <option value="event">Event</option>
                  <option value="manual">Manual</option>
                </select>
              </div>
              {(surgeForm.conditions.triggerType === "time" || surgeForm.conditions.triggerType === "event") && (
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
                    <input type="time" className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.conditions.timeStart} onChange={(e) => setSurgeForm((f) => ({ ...f, conditions: { ...f.conditions, timeStart: e.target.value } }))} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">End Time</label>
                    <input type="time" className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.conditions.timeEnd} onChange={(e) => setSurgeForm((f) => ({ ...f, conditions: { ...f.conditions, timeEnd: e.target.value } }))} />
                  </div>
                </div>
              )}
              {surgeForm.conditions.triggerType === "demand" && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Demand Threshold (ratio)</label>
                  <input type="number" step="0.1" min="0" className="w-full border rounded-lg px-3 py-2 text-sm" value={surgeForm.conditions.demandThreshold} onChange={(e) => setSurgeForm((f) => ({ ...f, conditions: { ...f.conditions, demandThreshold: parseFloat(e.target.value) } }))} />
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Active Days</label>
                <div className="flex gap-2">
                  {DAYS.map((d, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => toggleDay(i)}
                      className={`w-10 h-10 rounded-lg text-xs font-medium ${
                        surgeForm.conditions.daysOfWeek.includes(i) ? "bg-teal-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                      }`}
                    >
                      {d}
                    </button>
                  ))}
                </div>
                <p className="text-xs text-gray-400 mt-1">Leave empty for all days</p>
              </div>
              <label className="flex items-center gap-2">
                <input type="checkbox" checked={surgeForm.isActive} onChange={(e) => setSurgeForm((f) => ({ ...f, isActive: e.target.checked }))} className="rounded" />
                <span className="text-sm text-gray-700">Active</span>
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setSurgeModal(false)} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
                <button onClick={saveSurge} className="px-4 py-2 text-sm bg-teal-600 text-white rounded-lg hover:bg-teal-700">{editingSurge ? "Update" : "Create"}</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ═══════════ CANCELLATION MODAL ═══════════ */}
      {policyModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">{editingPolicy ? "Edit" : "Add"} Cancellation Policy</h2>
              <button onClick={() => setPolicyModal(false)} className="text-gray-400 hover:text-gray-600"><X className="h-5 w-5" /></button>
            </div>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Policy Name</label>
                  <input className="w-full border rounded-lg px-3 py-2 text-sm" value={policyForm.name} onChange={(e) => setPolicyForm((f) => ({ ...f, name: e.target.value }))} />
                </div>
                <label className="flex items-center gap-2 self-end pb-2">
                  <input type="checkbox" checked={policyForm.isActive} onChange={(e) => setPolicyForm((f) => ({ ...f, isActive: e.target.checked }))} className="rounded" />
                  <span className="text-sm text-gray-700">Active</span>
                </label>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-gray-700">Rules</h3>
                  <button onClick={addRule} className="text-xs text-teal-600 hover:text-teal-800 flex items-center gap-1"><Plus className="h-3 w-3" /> Add Rule</button>
                </div>
                {policyForm.rules.map((rule, idx) => (
                  <div key={idx} className="border rounded-lg p-4 space-y-3 relative">
                    {policyForm.rules.length > 1 && (
                      <button onClick={() => removeRule(idx)} className="absolute top-2 right-2 text-gray-300 hover:text-red-500"><X className="h-4 w-4" /></button>
                    )}
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Cancelled By</label>
                        <select className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.cancelledBy} onChange={(e) => updateRule(idx, "cancelledBy", e.target.value)}>
                          <option value="USER">User</option>
                          <option value="PROVIDER">Provider</option>
                          <option value="SYSTEM">System</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Before Status</label>
                        <select className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.beforeStatus} onChange={(e) => updateRule(idx, "beforeStatus", e.target.value)}>
                          <option value="PENDING">Pending</option>
                          <option value="CONFIRMED">Confirmed</option>
                          <option value="IN_PROGRESS">In Progress</option>
                        </select>
                      </div>
                    </div>
                    <div className="grid grid-cols-3 gap-3">
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Charge Type</label>
                        <select className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.chargeType} onChange={(e) => updateRule(idx, "chargeType", e.target.value)}>
                          <option value="none">None</option>
                          <option value="flat">Flat</option>
                          <option value="percentage">Percentage</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Charge Value</label>
                        <input type="number" className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.chargeValue} onChange={(e) => updateRule(idx, "chargeValue", Number(e.target.value))} />
                      </div>
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Refund %</label>
                        <input type="number" min="0" max="100" className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.refundPercentage} onChange={(e) => updateRule(idx, "refundPercentage", Number(e.target.value))} />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs text-gray-500 mb-1">Penalty to Provider (₹)</label>
                      <input type="number" className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.penaltyToDriver} onChange={(e) => updateRule(idx, "penaltyToDriver", Number(e.target.value))} />
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setPolicyModal(false)} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
                <button onClick={savePolicy} className="px-4 py-2 text-sm bg-teal-600 text-white rounded-lg hover:bg-teal-700">{editingPolicy ? "Update" : "Create"}</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
