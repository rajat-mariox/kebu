import { useState, useEffect } from "react";
import toast from "react-hot-toast";
import {
  Car,
  TrendingUp,
  IndianRupee,
  Star,
  Plus,
  Edit2,
  Trash2,
  X,
  Zap,
  Ban,
  BarChart3,
} from "lucide-react";
import {
  getSurgeConfigs,
  createSurgeConfig,
  updateSurgeConfig,
  deleteSurgeConfig,
  getCancellationPolicies,
  createCancellationPolicy,
  updateCancellationPolicy,
  deleteCancellationPolicy,
  getCabAnalytics,
} from "../services/service-config.service";
import type { SurgeConfig, CancellationPolicy, CabAnalytics } from "../types";
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

type Tab = "analytics" | "surge" | "cancellation";

export default function CabManagement() {
  const [tab, setTab] = useState<Tab>("analytics");
  const [range, setRange] = useState("7d");

  // Analytics
  const [analytics, setAnalytics] = useState<CabAnalytics | null>(null);
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

  // Cancellation
  const [policies, setPolicies] = useState<CancellationPolicy[]>([]);
  const [policyModal, setPolicyModal] = useState(false);
  const [editingPolicy, setEditingPolicy] = useState<CancellationPolicy | null>(null);
  const [policyForm, setPolicyForm] = useState({
    name: "",
    isActive: true,
    rules: [
      {
        cancelledBy: "USER" as "USER" | "DRIVER" | "SYSTEM" | "PROVIDER",
        beforeStatus: "ASSIGNED",
        chargeType: "none" as "none" | "percentage" | "flat",
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
  }, [tab, range]);

  const loadAnalytics = async () => {
    setLoadingAnalytics(true);
    try {
      const res = await getCabAnalytics({ range });
      setAnalytics(res.data.data);
    } catch { toast.error("Failed to load analytics"); }
    setLoadingAnalytics(false);
  };

  const loadSurges = async () => {
    try {
      const res = await getSurgeConfigs("cab");
      setSurges(res.data.data?.configs || []);
    } catch { toast.error("Failed to load surge configs"); }
  };

  const loadPolicies = async () => {
    try {
      const res = await getCancellationPolicies("cab");
      setPolicies(res.data.data?.policies || []);
    } catch { toast.error("Failed to load policies"); }
  };

  // Surge CRUD
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
      const payload = { ...surgeForm, serviceType: "cab" };
      if (editingSurge) {
        await updateSurgeConfig(editingSurge._id, payload);
        toast.success("Surge config updated");
      } else {
        await createSurgeConfig(payload);
        toast.success("Surge config created");
      }
      setSurgeModal(false);
      loadSurges();
    } catch { toast.error("Failed to save surge config"); }
  };

  const removeSurge = async (id: string) => {
    if (!confirm("Delete this surge config?")) return;
    try {
      await deleteSurgeConfig(id);
      toast.success("Deleted");
      loadSurges();
    } catch { toast.error("Failed to delete"); }
  };

  // Cancellation CRUD
  const openPolicyCreate = () => {
    setEditingPolicy(null);
    setPolicyForm({
      name: "", isActive: true,
      rules: [{ cancelledBy: "USER", beforeStatus: "ASSIGNED", chargeType: "none", chargeValue: 0, refundPercentage: 100, penaltyToDriver: 0 }],
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
      const payload = { ...policyForm, serviceType: "cab" };
      if (editingPolicy) {
        await updateCancellationPolicy(editingPolicy._id, payload);
        toast.success("Policy updated");
      } else {
        await createCancellationPolicy(payload);
        toast.success("Policy created");
      }
      setPolicyModal(false);
      loadPolicies();
    } catch { toast.error("Failed to save policy"); }
  };

  const removePolicy = async (id: string) => {
    if (!confirm("Delete this policy?")) return;
    try {
      await deleteCancellationPolicy(id);
      toast.success("Deleted");
      loadPolicies();
    } catch { toast.error("Failed to delete"); }
  };

  const addRule = () => {
    setPolicyForm((f) => ({
      ...f,
      rules: [...f.rules, { cancelledBy: "USER" as const, beforeStatus: "ASSIGNED", chargeType: "none" as const, chargeValue: 0, refundPercentage: 100, penaltyToDriver: 0 }],
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

  const s = analytics?.stats;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Car className="h-7 w-7 text-blue-600" /> Cab Management
          </h1>
          <p className="text-sm text-gray-500 mt-1">Manage ride pricing, surge rules, and cancellation policies</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 w-fit">
        {([
          { key: "analytics", label: "Analytics", icon: BarChart3 },
          { key: "surge", label: "Surge Pricing", icon: Zap },
          { key: "cancellation", label: "Cancellation Policy", icon: Ban },
        ] as { key: Tab; label: string; icon: React.ElementType }[]).map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              tab === key ? "bg-white text-blue-600 shadow-sm" : "text-gray-500 hover:text-gray-700"
            }`}
          >
            <Icon className="h-4 w-4" /> {label}
          </button>
        ))}
      </div>

      {/* Analytics Tab */}
      {tab === "analytics" && (
        <div className="space-y-6">
          {/* Range selector */}
          <div className="flex gap-2">
            {["today", "7d", "30d"].map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={`px-3 py-1.5 text-sm rounded-lg ${
                  range === r ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                }`}
              >
                {r === "today" ? "Today" : r === "7d" ? "7 Days" : "30 Days"}
              </button>
            ))}
          </div>

          {loadingAnalytics ? (
            <div className="flex justify-center py-12"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>
          ) : analytics ? (
            <>
              {/* KPI Cards */}
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
                {[
                  { label: "Total Rides", value: s?.totalRides || 0, icon: Car, color: "blue" },
                  { label: "Completed", value: s?.completed || 0, icon: TrendingUp, color: "green" },
                  { label: "Cancelled", value: s?.cancelled || 0, icon: Ban, color: "red" },
                  { label: "Revenue", value: `₹${((s?.totalRevenue || 0) / 1000).toFixed(1)}K`, icon: IndianRupee, color: "emerald" },
                  { label: "Avg Fare", value: `₹${Math.round(s?.avgFare || 0)}`, icon: IndianRupee, color: "purple" },
                  { label: "Avg Rating", value: analytics.avgRating?.toFixed(1) || "N/A", icon: Star, color: "yellow" },
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

              {/* Charts Row */}
              <div className="grid lg:grid-cols-2 gap-6">
                {/* Trend */}
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Ride Trend</h3>
                  <ResponsiveContainer width="100%" height={280}>
                    <LineChart data={analytics.trend}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip />
                      <Line type="monotone" dataKey="rides" stroke="#3b82f6" strokeWidth={2} dot={false} />
                      <Line type="monotone" dataKey="cancellations" stroke="#ef4444" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>

                {/* By Vehicle Type */}
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Revenue by Vehicle Type</h3>
                  <ResponsiveContainer width="100%" height={280}>
                    <BarChart data={analytics.byVehicleType}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="_id" fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip />
                      <Bar dataKey="revenue" fill="#3b82f6" radius={[6, 6, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Payment Methods Pie */}
              <div className="grid lg:grid-cols-2 gap-6">
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Payment Methods</h3>
                  <ResponsiveContainer width="100%" height={250}>
                    <PieChart>
                      <Pie data={analytics.byPayment} dataKey="total" nameKey="_id" cx="50%" cy="50%" outerRadius={90} label={({ name, percent }) => `${name} ${((percent ?? 0) * 100).toFixed(0)}%`}>
                        {analytics.byPayment.map((_, i) => (
                          <Cell key={i} fill={COLORS[i % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="bg-white rounded-xl border p-5">
                  <h3 className="text-sm font-semibold text-gray-700 mb-4">Quick Stats</h3>
                  <div className="space-y-4">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Avg Wait Time</span>
                      <span className="font-semibold">{analytics.avgWaitTime} min</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Avg Distance</span>
                      <span className="font-semibold">{(s?.avgDistance || 0).toFixed(1)} km</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Avg Duration</span>
                      <span className="font-semibold">{Math.round(s?.avgDuration || 0)} min</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Total Surge</span>
                      <span className="font-semibold text-amber-600">₹{Math.round(s?.totalSurge || 0)}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Total Tips</span>
                      <span className="font-semibold text-green-600">₹{Math.round(s?.totalTips || 0)}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-500">Total Discounts</span>
                      <span className="font-semibold text-red-600">₹{Math.round(s?.totalDiscount || 0)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </>
          ) : null}
        </div>
      )}

      {/* Surge Tab */}
      {tab === "surge" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={openSurgeCreate} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium">
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

      {/* Cancellation Tab */}
      {tab === "cancellation" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={openPolicyCreate} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium">
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
                    <th className="py-2 text-left">Driver Penalty</th>
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

      {/* Surge Modal */}
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
                        surgeForm.conditions.daysOfWeek.includes(i) ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
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
                <button onClick={saveSurge} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700">{editingSurge ? "Update" : "Create"}</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Cancellation Policy Modal */}
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
                  <button onClick={addRule} className="text-xs text-blue-600 hover:text-blue-800 flex items-center gap-1"><Plus className="h-3 w-3" /> Add Rule</button>
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
                          <option value="DRIVER">Driver</option>
                          <option value="SYSTEM">System</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs text-gray-500 mb-1">Before Status</label>
                        <select className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.beforeStatus} onChange={(e) => updateRule(idx, "beforeStatus", e.target.value)}>
                          <option value="ASSIGNED">Assigned</option>
                          <option value="DRIVER_ARRIVED">Driver Arrived</option>
                          <option value="PICKED">Picked Up</option>
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
                      <label className="block text-xs text-gray-500 mb-1">Penalty to Driver (₹)</label>
                      <input type="number" className="w-full border rounded-lg px-3 py-2 text-sm" value={rule.penaltyToDriver} onChange={(e) => updateRule(idx, "penaltyToDriver", Number(e.target.value))} />
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setPolicyModal(false)} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
                <button onClick={savePolicy} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700">{editingPolicy ? "Update" : "Create"}</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
