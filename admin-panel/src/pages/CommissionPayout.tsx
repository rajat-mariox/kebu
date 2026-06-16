import { useState, useEffect } from "react";
import toast from "react-hot-toast";
import {
  IndianRupee,
  Percent,
  Plus,
  Edit2,
  Trash2,
  X,
  CheckCircle,
  Clock,
  AlertTriangle,
  Send,
} from "lucide-react";
import {
  getCommissionConfigs,
  createCommissionConfig,
  updateCommissionConfig,
  deleteCommissionConfig,
  getPayouts,
  getPayoutSummary,
  processPayouts,
  completePayouts,
} from "../services/service-config.service";
import type { CommissionConfig, PayoutItem } from "../types";
import { Pagination } from "../components";

type Tab = "commission" | "payouts";
type ServiceType = "cab" | "delivery" | "household";

const STATUS_COLORS: Record<string, string> = {
  pending: "bg-yellow-100 text-yellow-700",
  processing: "bg-blue-100 text-blue-700",
  completed: "bg-green-100 text-green-700",
  failed: "bg-red-100 text-red-700",
};

export default function CommissionPayout() {
  const [tab, setTab] = useState<Tab>("commission");

  // Commission
  const [configs, setConfigs] = useState<CommissionConfig[]>([]);
  const [configFilter, setConfigFilter] = useState<ServiceType | "">("");
  const [configModal, setConfigModal] = useState(false);
  const [editingConfig, setEditingConfig] = useState<CommissionConfig | null>(null);
  const [configForm, setConfigForm] = useState({
    name: "",
    serviceType: "cab" as ServiceType,
    commissionType: "percentage" as "percentage" | "flat",
    value: 10,
    minCommission: 0,
    maxCommission: 0,
    isActive: true,
  });

  // Payouts
  const [payoutsList, setPayoutsList] = useState<PayoutItem[]>([]);
  const [payoutTotal, setPayoutTotal] = useState(0);
  const [payoutPage, setPayoutPage] = useState(0);
  const payoutLimit = 15;
  const [payoutServiceFilter, setPayoutServiceFilter] = useState<ServiceType | "">("");
  const [payoutStatusFilter, setPayoutStatusFilter] = useState("");
  const [payoutRecipientFilter, setPayoutRecipientFilter] = useState("");
  const [selectedPayouts, setSelectedPayouts] = useState<string[]>([]);
  const [transactionRef, setTransactionRef] = useState("");
  const [completeModal, setCompleteModal] = useState(false);

  // Summary
  const [summary, setSummary] = useState<{
    totalPending: number;
    totalProcessing: number;
    totalCompleted: number;
    totalAmount: number;
    pendingAmount: number;
  } | null>(null);

  // ── Commission Loading ────────────────────────────────────
  const loadConfigs = async () => {
    try {
      const res = await getCommissionConfigs(configFilter || undefined);
      setConfigs(res.data.data?.configs || res.data.data || []);
    } catch {
      toast.error("Failed to load commission configs");
    }
  };

  // ── Payout Loading ────────────────────────────────────────
  const loadPayouts = async () => {
    try {
      const params: Record<string, string | number> = { page: payoutPage, limit: payoutLimit };
      if (payoutServiceFilter) params.serviceType = payoutServiceFilter;
      if (payoutStatusFilter) params.status = payoutStatusFilter;
      if (payoutRecipientFilter) params.recipientType = payoutRecipientFilter;
      const res = await getPayouts(params);
      const data = res.data.data || res.data;
      setPayoutsList(data?.items || data?.payouts || []);
      setPayoutTotal(data?.total || 0);
    } catch {
      toast.error("Failed to load payouts");
    }
  };

  const loadSummary = async () => {
    try {
      const res = await getPayoutSummary();
      setSummary(res.data.data || res.data);
    } catch { /* silent */ }
  };

  useEffect(() => {
    if (tab === "commission") loadConfigs();
    if (tab === "payouts") {
      loadPayouts();
      loadSummary();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, configFilter, payoutPage, payoutServiceFilter, payoutStatusFilter, payoutRecipientFilter]);

  // ── Commission CRUD ───────────────────────────────────────
  const openConfigCreate = () => {
    setEditingConfig(null);
    setConfigForm({ name: "", serviceType: "cab", commissionType: "percentage", value: 10, minCommission: 0, maxCommission: 0, isActive: true });
    setConfigModal(true);
  };

  const openConfigEdit = (c: CommissionConfig) => {
    setEditingConfig(c);
    setConfigForm({
      name: c.name,
      serviceType: c.serviceType,
      commissionType: c.commissionType,
      value: c.value,
      minCommission: c.minCommission || 0,
      maxCommission: c.maxCommission || 0,
      isActive: c.isActive,
    });
    setConfigModal(true);
  };

  const saveConfig = async () => {
    try {
      if (editingConfig) {
        await updateCommissionConfig(editingConfig._id, configForm);
        toast.success("Commission config updated");
      } else {
        await createCommissionConfig(configForm);
        toast.success("Commission config created");
      }
      setConfigModal(false);
      loadConfigs();
    } catch {
      toast.error("Failed to save config");
    }
  };

  const removeConfig = async (id: string) => {
    if (!confirm("Delete this commission config?")) return;
    try {
      await deleteCommissionConfig(id);
      toast.success("Deleted");
      loadConfigs();
    } catch {
      toast.error("Failed to delete");
    }
  };

  // ── Payout Actions ────────────────────────────────────────
  const togglePayoutSelect = (id: string) => {
    setSelectedPayouts((prev) =>
      prev.includes(id) ? prev.filter((p) => p !== id) : [...prev, id],
    );
  };

  const selectAllPending = () => {
    const pendingIds = payoutsList.filter((p) => p.status === "pending").map((p) => p._id);
    setSelectedPayouts((prev) => {
      const allSelected = pendingIds.every((id) => prev.includes(id));
      return allSelected ? prev.filter((id) => !pendingIds.includes(id)) : [...new Set([...prev, ...pendingIds])];
    });
  };

  const handleProcessPayouts = async () => {
    if (selectedPayouts.length === 0) return toast.error("Select payouts to process");
    try {
      await processPayouts(selectedPayouts);
      toast.success(`${selectedPayouts.length} payouts marked as processing`);
      setSelectedPayouts([]);
      loadPayouts();
      loadSummary();
    } catch {
      toast.error("Failed to process payouts");
    }
  };

  const handleCompletePayouts = async () => {
    if (!transactionRef.trim()) return toast.error("Enter transaction reference");
    try {
      await completePayouts(selectedPayouts, transactionRef.trim());
      toast.success("Payouts completed");
      setCompleteModal(false);
      setTransactionRef("");
      setSelectedPayouts([]);
      loadPayouts();
      loadSummary();
    } catch {
      toast.error("Failed to complete payouts");
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <IndianRupee className="h-7 w-7 text-violet-600" /> Commission & Payouts
          </h1>
          <p className="text-sm text-gray-500 mt-1">Manage commission structures and process vendor/driver payouts</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 w-fit">
        {([
          { key: "commission", label: "Commission Rules", icon: Percent },
          { key: "payouts", label: "Payouts", icon: Send },
        ] as { key: Tab; label: string; icon: React.ElementType }[]).map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              tab === key ? "bg-white text-violet-600 shadow-sm" : "text-gray-500 hover:text-gray-700"
            }`}
          >
            <Icon className="h-4 w-4" /> {label}
          </button>
        ))}
      </div>

      {/* ═══════════ COMMISSION TAB ═══════════ */}
      {tab === "commission" && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex gap-2">
              <select
                className="border rounded-lg px-3 py-2 text-sm"
                value={configFilter}
                onChange={(e) => setConfigFilter(e.target.value as ServiceType | "")}
              >
                <option value="">All Services</option>
                <option value="cab">Cab</option>
                <option value="delivery">Delivery</option>
                <option value="household">Household</option>
              </select>
            </div>
            <button onClick={openConfigCreate} className="flex items-center gap-2 px-4 py-2 bg-violet-600 text-white rounded-lg hover:bg-violet-700 text-sm font-medium">
              <Plus className="h-4 w-4" /> Add Commission Rule
            </button>
          </div>

          <div className="bg-white rounded-xl border overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Service</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Value</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Min / Max</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {configs.length === 0 ? (
                  <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">No commission rules configured</td></tr>
                ) : configs.map((c) => (
                  <tr key={c._id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm font-medium text-gray-900">{c.name}</td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-violet-100 text-violet-700 capitalize">{c.serviceType}</span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600 capitalize">{c.commissionType}</td>
                    <td className="px-4 py-3 text-sm font-semibold text-violet-600">
                      {c.commissionType === "percentage" ? `${c.value}%` : `₹${c.value}`}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500">
                      {c.minCommission || c.maxCommission
                        ? `₹${c.minCommission || 0} - ₹${c.maxCommission || "∞"}`
                        : "-"}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 text-xs rounded-full ${c.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
                        {c.isActive ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button onClick={() => openConfigEdit(c)} className="p-1.5 text-gray-400 hover:text-blue-600"><Edit2 className="h-4 w-4" /></button>
                      <button onClick={() => removeConfig(c._id)} className="p-1.5 text-gray-400 hover:text-red-600"><Trash2 className="h-4 w-4" /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ═══════════ PAYOUTS TAB ═══════════ */}
      {tab === "payouts" && (
        <div className="space-y-6">
          {/* Summary Cards */}
          {summary && (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: "Pending", value: summary.totalPending, amount: summary.pendingAmount, icon: Clock, color: "yellow" },
                { label: "Processing", value: summary.totalProcessing, icon: AlertTriangle, color: "blue" },
                { label: "Completed", value: summary.totalCompleted, icon: CheckCircle, color: "green" },
                { label: "Total Amount", value: `₹${((summary.totalAmount || 0) / 1000).toFixed(1)}K`, icon: IndianRupee, color: "violet" },
              ].map((kpi) => (
                <div key={kpi.label} className="bg-white rounded-xl border p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <kpi.icon className={`h-4 w-4 text-${kpi.color}-500`} />
                    <span className="text-xs text-gray-500">{kpi.label}</span>
                  </div>
                  <p className="text-xl font-bold text-gray-900">{kpi.value}</p>
                  {"amount" in kpi && kpi.amount ? (
                    <p className="text-xs text-gray-400 mt-1">₹{Math.round(kpi.amount)} pending</p>
                  ) : null}
                </div>
              ))}
            </div>
          )}

          {/* Filters & Actions */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex flex-wrap gap-2">
              <select className="border rounded-lg px-3 py-2 text-sm" value={payoutServiceFilter} onChange={(e) => { setPayoutServiceFilter(e.target.value as ServiceType | ""); setPayoutPage(0); }}>
                <option value="">All Services</option>
                <option value="cab">Cab</option>
                <option value="delivery">Delivery</option>
                <option value="household">Household</option>
              </select>
              <select className="border rounded-lg px-3 py-2 text-sm" value={payoutStatusFilter} onChange={(e) => { setPayoutStatusFilter(e.target.value); setPayoutPage(0); }}>
                <option value="">All Status</option>
                <option value="pending">Pending</option>
                <option value="processing">Processing</option>
                <option value="completed">Completed</option>
                <option value="failed">Failed</option>
              </select>
              <select className="border rounded-lg px-3 py-2 text-sm" value={payoutRecipientFilter} onChange={(e) => { setPayoutRecipientFilter(e.target.value); setPayoutPage(0); }}>
                <option value="">All Recipients</option>
                <option value="driver">Drivers</option>
                <option value="provider">Providers</option>
              </select>
            </div>
            <div className="flex gap-2">
              {selectedPayouts.length > 0 && (
                <>
                  <button
                    onClick={handleProcessPayouts}
                    className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium"
                  >
                    <Clock className="h-4 w-4" /> Process ({selectedPayouts.length})
                  </button>
                  <button
                    onClick={() => setCompleteModal(true)}
                    className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm font-medium"
                  >
                    <CheckCircle className="h-4 w-4" /> Complete ({selectedPayouts.length})
                  </button>
                </>
              )}
            </div>
          </div>

          {/* Payouts Table */}
          <div className="bg-white rounded-xl border overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left">
                    <input
                      type="checkbox"
                      className="rounded"
                      onChange={selectAllPending}
                      checked={payoutsList.filter((p) => p.status === "pending").length > 0 && payoutsList.filter((p) => p.status === "pending").every((p) => selectedPayouts.includes(p._id))}
                    />
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Service</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Period</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Earnings</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Commission</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Net Payout</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Trips</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {payoutsList.length === 0 ? (
                  <tr><td colSpan={10} className="px-4 py-8 text-center text-gray-400">No payouts found</td></tr>
                ) : payoutsList.map((p) => (
                  <tr key={p._id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      {(p.status === "pending" || p.status === "processing") && (
                        <input
                          type="checkbox"
                          className="rounded"
                          checked={selectedPayouts.includes(p._id)}
                          onChange={() => togglePayoutSelect(p._id)}
                        />
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm font-medium text-gray-900">{p.recipientName}</td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-600 capitalize">{p.recipientType}</span>
                    </td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-violet-100 text-violet-700 capitalize">{p.serviceType}</span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {new Date(p.period.start).toLocaleDateString()} - {new Date(p.period.end).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3 text-sm text-right text-gray-900">₹{Math.round(p.totalEarnings)}</td>
                    <td className="px-4 py-3 text-sm text-right text-red-600">-₹{Math.round(p.totalCommission)}</td>
                    <td className="px-4 py-3 text-sm text-right font-semibold text-green-600">₹{Math.round(p.netPayout)}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{p.bookingCount}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 text-xs rounded-full capitalize ${STATUS_COLORS[p.status] || "bg-gray-100 text-gray-500"}`}>
                        {p.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {payoutTotal > payoutLimit && (
            <Pagination
              page={payoutPage}
              limit={payoutLimit}
              total={payoutTotal}
              onPageChange={setPayoutPage}
            />
          )}
        </div>
      )}

      {/* ═══════════ COMMISSION MODAL ═══════════ */}
      {configModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">{editingConfig ? "Edit" : "Add"} Commission Rule</h2>
              <button onClick={() => setConfigModal(false)} className="text-gray-400 hover:text-gray-600"><X className="h-5 w-5" /></button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.name} onChange={(e) => setConfigForm((f) => ({ ...f, name: e.target.value }))} />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Service Type</label>
                <select className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.serviceType} onChange={(e) => setConfigForm((f) => ({ ...f, serviceType: e.target.value as ServiceType }))}>
                  <option value="cab">Cab</option>
                  <option value="delivery">Delivery</option>
                  <option value="household">Household</option>
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Commission Type</label>
                  <select className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.commissionType} onChange={(e) => setConfigForm((f) => ({ ...f, commissionType: e.target.value as "percentage" | "flat" }))}>
                    <option value="percentage">Percentage</option>
                    <option value="flat">Flat Amount</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Value {configForm.commissionType === "percentage" ? "(%)" : "(₹)"}
                  </label>
                  <input type="number" min="0" step={configForm.commissionType === "percentage" ? "0.5" : "1"} className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.value} onChange={(e) => setConfigForm((f) => ({ ...f, value: Number(e.target.value) }))} />
                </div>
              </div>
              {configForm.commissionType === "percentage" && (
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Min Commission (₹)</label>
                    <input type="number" min="0" className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.minCommission} onChange={(e) => setConfigForm((f) => ({ ...f, minCommission: Number(e.target.value) }))} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Max Commission (₹)</label>
                    <input type="number" min="0" className="w-full border rounded-lg px-3 py-2 text-sm" value={configForm.maxCommission} onChange={(e) => setConfigForm((f) => ({ ...f, maxCommission: Number(e.target.value) }))} />
                  </div>
                </div>
              )}
              <label className="flex items-center gap-2">
                <input type="checkbox" checked={configForm.isActive} onChange={(e) => setConfigForm((f) => ({ ...f, isActive: e.target.checked }))} className="rounded" />
                <span className="text-sm text-gray-700">Active</span>
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setConfigModal(false)} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
                <button onClick={saveConfig} className="px-4 py-2 text-sm bg-violet-600 text-white rounded-lg hover:bg-violet-700">{editingConfig ? "Update" : "Create"}</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ═══════════ COMPLETE PAYOUT MODAL ═══════════ */}
      {completeModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Complete Payouts</h2>
              <button onClick={() => setCompleteModal(false)} className="text-gray-400 hover:text-gray-600"><X className="h-5 w-5" /></button>
            </div>
            <p className="text-sm text-gray-500 mb-4">
              Mark {selectedPayouts.length} payout(s) as completed. Enter the bank transaction reference.
            </p>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Transaction Reference</label>
              <input
                className="w-full border rounded-lg px-3 py-2 text-sm"
                placeholder="e.g., NEFT/IMPS ref number"
                value={transactionRef}
                onChange={(e) => setTransactionRef(e.target.value)}
              />
            </div>
            <div className="flex justify-end gap-3 mt-6">
              <button onClick={() => setCompleteModal(false)} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
              <button onClick={handleCompletePayouts} className="px-4 py-2 text-sm bg-green-600 text-white rounded-lg hover:bg-green-700">Confirm & Complete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
