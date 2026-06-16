import { useState, useEffect } from "react";
import {
  Zap,
  Plus,
  Pencil,
  Trash2,
  ToggleLeft,
  ToggleRight,
  Clock,
  IndianRupee,
  Gift,
  AlertTriangle,
} from "lucide-react";
import { automationService } from "../services/automation.service";
import { Modal, Button } from "../components";
import type { AutomationRule } from "../types";
import toast from "react-hot-toast";

type Category = "pricing" | "promotion" | "operational";

const CATEGORIES: { key: Category; label: string; icon: React.ElementType; color: string }[] = [
  { key: "pricing", label: "Pricing Rules", icon: IndianRupee, color: "text-green-600 bg-green-50" },
  { key: "promotion", label: "Promotions", icon: Gift, color: "text-purple-600 bg-purple-50" },
  { key: "operational", label: "Operational Triggers", icon: AlertTriangle, color: "text-orange-600 bg-orange-50" },
];

const RULE_TYPES: Record<Category, { value: string; label: string }[]> = {
  pricing: [
    { value: "per_km_rate", label: "Per KM Rate" },
    { value: "base_fare", label: "Base Fare" },
    { value: "surge_multiplier", label: "Surge Multiplier" },
    { value: "minimum_fare", label: "Minimum Fare" },
    { value: "distance_slab", label: "Distance Slab Pricing" },
    { value: "time_based_rate", label: "Time-Based Rate" },
  ],
  promotion: [
    { value: "ride_count_discount", label: "Ride Count Discount" },
    { value: "first_ride", label: "First Ride Offer" },
    { value: "referral_bonus", label: "Referral Bonus" },
    { value: "cashback", label: "Cashback Offer" },
    { value: "flat_discount", label: "Flat Discount" },
    { value: "percent_discount", label: "Percentage Discount" },
    { value: "free_ride", label: "Free Ride" },
  ],
  operational: [
    { value: "driver_cancellation", label: "Driver Cancellation Rate" },
    { value: "idle_driver", label: "Idle Driver Alert" },
    { value: "unassigned_order", label: "Unassigned Order Alert" },
    { value: "sos_response", label: "SOS Response Time" },
    { value: "cancellation_spike", label: "Cancellation Spike" },
    { value: "credit_exceeded", label: "Credit Exceeded" },
  ],
};

const CONDITION_FIELDS: Record<string, { label: string; unit: string }[]> = {
  per_km_rate: [{ label: "Distance (km)", unit: "km" }],
  base_fare: [{ label: "Distance (km)", unit: "km" }],
  surge_multiplier: [{ label: "Demand Ratio", unit: "ratio" }],
  minimum_fare: [{ label: "Distance (km)", unit: "km" }],
  distance_slab: [{ label: "Distance (km)", unit: "km" }],
  time_based_rate: [{ label: "Hour of Day", unit: "hour" }],
  ride_count_discount: [{ label: "Total Rides", unit: "rides" }],
  first_ride: [{ label: "Ride Number", unit: "rides" }],
  referral_bonus: [{ label: "Referrals Made", unit: "count" }],
  cashback: [{ label: "Order Amount", unit: "rupees" }],
  flat_discount: [{ label: "Order Amount", unit: "rupees" }],
  percent_discount: [{ label: "Order Amount", unit: "rupees" }],
  free_ride: [{ label: "Total Rides", unit: "rides" }],
  driver_cancellation: [{ label: "Cancellation Rate", unit: "percent" }],
  idle_driver: [{ label: "Idle Time", unit: "minutes" }],
  unassigned_order: [{ label: "Wait Time", unit: "minutes" }],
  sos_response: [{ label: "Response Time", unit: "minutes" }],
  cancellation_spike: [{ label: "Cancellations/Hour", unit: "count" }],
  credit_exceeded: [{ label: "Credit Usage", unit: "percent" }],
};

const ACTION_TYPES: Record<Category, { value: string; label: string }[]> = {
  pricing: [
    { value: "set_rate", label: "Set Rate (₹)" },
  ],
  promotion: [
    { value: "flat_discount", label: "Flat Discount (₹)" },
    { value: "percent_discount", label: "Percentage Discount (%)" },
    { value: "cashback", label: "Cashback (₹)" },
    { value: "free_ride", label: "Free Ride" },
  ],
  operational: [
    { value: "auto_warning", label: "Auto Warning" },
    { value: "flag", label: "Flag" },
    { value: "notify", label: "Notify Team" },
    { value: "escalate", label: "Escalate" },
    { value: "dashboard_alert", label: "Dashboard Alert" },
    { value: "suspend", label: "Suspend" },
  ],
};

const OPERATORS = [
  { value: "gt", label: "Greater than (>)" },
  { value: "gte", label: "Greater or equal (>=)" },
  { value: "lt", label: "Less than (<)" },
  { value: "lte", label: "Less or equal (<=)" },
  { value: "eq", label: "Equals (=)" },
  { value: "between", label: "Between" },
];

const defaultForm = (cat: Category) => ({
  name: "",
  description: "",
  category: cat,
  ruleType: RULE_TYPES[cat][0].value,
  condition: {
    field: CONDITION_FIELDS[RULE_TYPES[cat][0].value]?.[0]?.label || "",
    operator: "gte",
    value: 0,
    valueMax: undefined as number | undefined,
    unit: CONDITION_FIELDS[RULE_TYPES[cat][0].value]?.[0]?.unit || "",
  },
  action: {
    type: ACTION_TYPES[cat][0].value,
    value: 0,
    maxDiscount: undefined as number | undefined,
    message: "",
  },
  applicableTo: { userType: "all" as "all" | "new" | "existing" },
  priority: 0,
  usageLimit: undefined as number | undefined,
  validFrom: "",
  validUntil: "",
});

export default function AutomationRules() {
  const [rules, setRules] = useState<AutomationRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<Category>("pricing");
  const [showModal, setShowModal] = useState(false);
  const [editingRule, setEditingRule] = useState<AutomationRule | null>(null);
  const [form, setForm] = useState(defaultForm("pricing"));
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const fetchRules = async () => {
    setLoading(true);
    try {
      const res = await automationService.getRules();
      setRules(res.data?.data?.rules || []);
    } catch {
      toast.error("Failed to load rules");
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchRules();
  }, []);

  const filteredRules = rules.filter((r) => r.category === activeTab);

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      toast.error("Rule name is required");
      return;
    }
    try {
      const payload = {
        ...form,
        condition: {
          ...form.condition,
          valueMax: form.condition.operator === "between" ? form.condition.valueMax : undefined,
        },
      };
      if (editingRule) {
        await automationService.updateRule(editingRule._id, payload);
        toast.success("Rule updated");
      } else {
        await automationService.createRule(payload);
        toast.success("Rule created");
      }
      setShowModal(false);
      setEditingRule(null);
      fetchRules();
    } catch {
      toast.error("Failed to save rule");
    }
  };

  const handleToggle = async (ruleId: string) => {
    try {
      await automationService.toggleRule(ruleId);
      fetchRules();
    } catch {
      toast.error("Failed to toggle rule");
    }
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    setDeleting(true);
    try {
      await automationService.deleteRule(deleteId);
      toast.success("Rule deleted");
      setDeleteId(null);
      fetchRules();
    } catch {
      toast.error("Failed to delete rule");
    }
    setDeleting(false);
  };

  const openEdit = (rule: AutomationRule) => {
    setEditingRule(rule);
    setForm({
      name: rule.name,
      description: rule.description || "",
      category: rule.category,
      ruleType: rule.ruleType,
      condition: {
        field: rule.condition.field,
        operator: rule.condition.operator,
        value: rule.condition.value,
        valueMax: rule.condition.valueMax,
        unit: rule.condition.unit || "",
      },
      action: {
        type: rule.action.type,
        value: rule.action.value || 0,
        maxDiscount: rule.action.maxDiscount,
        message: rule.action.message || "",
      },
      applicableTo: { ...rule.applicableTo, userType: rule.applicableTo?.userType ?? "all" },
      priority: rule.priority,
      usageLimit: rule.usageLimit,
      validFrom: rule.validFrom?.split("T")[0] || "",
      validUntil: rule.validUntil?.split("T")[0] || "",
    });
    setShowModal(true);
  };

  const openCreate = () => {
    setEditingRule(null);
    setForm(defaultForm(activeTab));
    setShowModal(true);
  };

  const onRuleTypeChange = (ruleType: string) => {
    const fields = CONDITION_FIELDS[ruleType] || [];
    setForm({
      ...form,
      ruleType,
      condition: {
        ...form.condition,
        field: fields[0]?.label || "",
        unit: fields[0]?.unit || "",
      },
    });
  };

  const getCategoryConfig = (cat: Category) =>
    CATEGORIES.find((c) => c.key === cat)!;

  const formatActionLabel = (rule: AutomationRule) => {
    const { action } = rule;
    switch (action.type) {
      case "set_rate":
        return `₹${action.value}/unit`;
      case "flat_discount":
        return `₹${action.value} off`;
      case "percent_discount":
        return `${action.value}% off${action.maxDiscount ? ` (max ₹${action.maxDiscount})` : ""}`;
      case "cashback":
        return `₹${action.value} cashback`;
      case "free_ride":
        return "Free ride";
      default:
        return action.type.replace(/_/g, " ");
    }
  };

  const formatCondition = (rule: AutomationRule) => {
    const opSymbol =
      rule.condition.operator === "gt" ? ">"
        : rule.condition.operator === "gte" ? ">="
          : rule.condition.operator === "lt" ? "<"
            : rule.condition.operator === "lte" ? "<="
              : rule.condition.operator === "eq" ? "="
                : "between";

    if (rule.condition.operator === "between") {
      return `${rule.condition.value} - ${rule.condition.valueMax} ${rule.condition.unit || ""}`;
    }
    return `${opSymbol} ${rule.condition.value} ${rule.condition.unit || ""}`;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Automation Rules</h1>
          <p className="mt-1 text-sm text-gray-500">
            Configure pricing, promotions, and operational triggers
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4 mr-2" />
          Create Rule
        </Button>
      </div>

      {/* Category Tabs */}
      <div className="flex gap-3">
        {CATEGORIES.map((cat) => {
          const count = rules.filter((r) => r.category === cat.key).length;
          const Icon = cat.icon;
          return (
            <button
              key={cat.key}
              onClick={() => setActiveTab(cat.key)}
              className={`flex items-center gap-2 rounded-xl px-4 py-3 text-sm font-medium transition-all ${
                activeTab === cat.key
                  ? "bg-white shadow-sm border border-gray-200 text-gray-900"
                  : "text-gray-500 hover:bg-white/50 hover:text-gray-700"
              }`}
            >
              <div className={`rounded-lg p-1.5 ${cat.color}`}>
                <Icon className="h-4 w-4" />
              </div>
              {cat.label}
              <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs">
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Rules List */}
      {loading ? (
        <div className="flex h-60 items-center justify-center">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-blue-600 border-t-transparent" />
        </div>
      ) : filteredRules.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 rounded-xl bg-white border border-gray-100">
          <Zap className="h-12 w-12 text-gray-300 mb-3" />
          <p className="text-sm text-gray-400">
            No {getCategoryConfig(activeTab).label.toLowerCase()} configured
          </p>
          <button
            onClick={openCreate}
            className="mt-3 text-sm text-blue-600 hover:underline"
          >
            Create your first rule
          </button>
        </div>
      ) : (
        <div className="grid gap-3">
          {filteredRules.map((rule) => {
            const catConfig = getCategoryConfig(rule.category);
            return (
              <div
                key={rule._id}
                className={`rounded-xl bg-white p-5 shadow-sm border transition-all ${
                  rule.isActive
                    ? "border-gray-100 hover:shadow-md"
                    : "border-gray-200 opacity-50"
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 mb-1">
                      <h3 className="text-base font-semibold text-gray-900 truncate">
                        {rule.name}
                      </h3>
                      <span
                        className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
                          rule.isActive
                            ? "bg-green-100 text-green-700"
                            : "bg-gray-100 text-gray-500"
                        }`}
                      >
                        {rule.isActive ? "Active" : "Inactive"}
                      </span>
                      {rule.priority > 0 && (
                        <span className="rounded-full bg-blue-50 px-2 py-0.5 text-[10px] font-medium text-blue-600">
                          Priority {rule.priority}
                        </span>
                      )}
                    </div>
                    {rule.description && (
                      <p className="text-sm text-gray-500 mb-2">
                        {rule.description}
                      </p>
                    )}

                    {/* Rule Logic Display */}
                    <div className="flex flex-wrap items-center gap-2 text-sm">
                      <span className="text-gray-500">When</span>
                      <span className="rounded bg-blue-50 px-2 py-0.5 font-medium text-blue-700">
                        {rule.condition.field}
                      </span>
                      <span className="font-mono text-gray-700">
                        {formatCondition(rule)}
                      </span>
                      <span className="text-gray-400 mx-1">→</span>
                      <span className="rounded bg-green-50 px-2 py-0.5 font-medium text-green-700">
                        {formatActionLabel(rule)}
                      </span>
                    </div>

                    {/* Meta info */}
                    <div className="mt-3 flex flex-wrap items-center gap-4 text-xs text-gray-400">
                      <span className="flex items-center gap-1">
                        <span className={`h-1.5 w-1.5 rounded-full ${catConfig.color.split(" ")[0]}`} />
                        {RULE_TYPES[rule.category]?.find((t) => t.value === rule.ruleType)?.label || rule.ruleType}
                      </span>
                      {rule.triggerCount > 0 && (
                        <span>Used {rule.triggerCount}x</span>
                      )}
                      {rule.validUntil && (
                        <span className="flex items-center gap-1">
                          <Clock className="h-3 w-3" />
                          Until{" "}
                          {new Date(rule.validUntil).toLocaleDateString("en-IN", {
                            day: "numeric",
                            month: "short",
                          })}
                        </span>
                      )}
                      {rule.usageLimit && (
                        <span>
                          {rule.currentUsage}/{rule.usageLimit} uses
                        </span>
                      )}
                      {rule.applicableTo?.userType && rule.applicableTo.userType !== "all" && (
                        <span className="rounded bg-amber-50 px-1.5 py-0.5 text-amber-700">
                          {rule.applicableTo.userType} users
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Action buttons */}
                  <div className="flex items-center gap-1 ml-4">
                    <button
                      onClick={() => handleToggle(rule._id)}
                      className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
                      title={rule.isActive ? "Disable" : "Enable"}
                    >
                      {rule.isActive ? (
                        <ToggleRight className="h-5 w-5 text-green-600" />
                      ) : (
                        <ToggleLeft className="h-5 w-5 text-gray-400" />
                      )}
                    </button>
                    <button
                      onClick={() => openEdit(rule)}
                      className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      <Pencil className="h-4 w-4 text-gray-500" />
                    </button>
                    <button
                      onClick={() => setDeleteId(rule._id)}
                      className="p-1.5 rounded-lg hover:bg-red-50 transition-colors"
                    >
                      <Trash2 className="h-4 w-4 text-red-500" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <Modal
          title={editingRule ? "Edit Rule" : `Create ${getCategoryConfig(form.category as Category).label.slice(0, -1)}`}
          onClose={() => {
            setShowModal(false);
            setEditingRule(null);
          }}
          size="lg"
        >
          <div className="space-y-4">
            {/* Category selector (only for create) */}
            {!editingRule && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category
                </label>
                <div className="flex gap-2">
                  {CATEGORIES.map((cat) => (
                    <button
                      key={cat.key}
                      onClick={() => {
                        setForm(defaultForm(cat.key));
                      }}
                      className={`flex-1 rounded-lg px-3 py-2 text-sm font-medium border transition-colors ${
                        form.category === cat.key
                          ? "bg-blue-50 border-blue-200 text-blue-700"
                          : "border-gray-200 text-gray-500 hover:bg-gray-50"
                      }`}
                    >
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Rule Name
                </label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-blue-500"
                  placeholder="e.g., 10+ rides get ₹200 off"
                />
              </div>

              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <input
                  type="text"
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-blue-500"
                  placeholder="Brief description of the rule"
                />
              </div>
            </div>

            {/* Rule Type */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Rule Type
              </label>
              <select
                value={form.ruleType}
                onChange={(e) => onRuleTypeChange(e.target.value)}
                className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
              >
                {RULE_TYPES[form.category as Category]?.map((rt) => (
                  <option key={rt.value} value={rt.value}>
                    {rt.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Condition */}
            <div className="rounded-lg bg-gray-50 p-4 border border-gray-100">
              <label className="block text-sm font-semibold text-gray-700 mb-3">
                Condition
              </label>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-sm text-gray-500">When</span>
                <span className="rounded bg-blue-100 px-2 py-1 text-sm font-medium text-blue-800">
                  {form.condition.field || "field"}
                </span>
                <select
                  value={form.condition.operator}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      condition: { ...form.condition, operator: e.target.value },
                    })
                  }
                  className="rounded-lg border border-gray-200 px-2 py-1 text-sm"
                >
                  {OPERATORS.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
                <input
                  type="number"
                  value={form.condition.value}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      condition: {
                        ...form.condition,
                        value: Number(e.target.value),
                      },
                    })
                  }
                  className="w-24 rounded-lg border border-gray-200 px-3 py-1 text-sm"
                  placeholder="Value"
                />
                {form.condition.operator === "between" && (
                  <>
                    <span className="text-sm text-gray-400">and</span>
                    <input
                      type="number"
                      value={form.condition.valueMax || ""}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          condition: {
                            ...form.condition,
                            valueMax: Number(e.target.value) || undefined,
                          },
                        })
                      }
                      className="w-24 rounded-lg border border-gray-200 px-3 py-1 text-sm"
                      placeholder="Max"
                    />
                  </>
                )}
                <span className="text-sm text-gray-400">
                  {form.condition.unit}
                </span>
              </div>
            </div>

            {/* Action */}
            <div className="rounded-lg bg-gray-50 p-4 border border-gray-100">
              <label className="block text-sm font-semibold text-gray-700 mb-3">
                Action
              </label>
              <div className="flex flex-wrap items-center gap-3">
                <select
                  value={form.action.type}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      action: { ...form.action, type: e.target.value },
                    })
                  }
                  className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
                >
                  {ACTION_TYPES[form.category as Category]?.map((a) => (
                    <option key={a.value} value={a.value}>
                      {a.label}
                    </option>
                  ))}
                </select>
                {["set_rate", "flat_discount", "percent_discount", "cashback"].includes(
                  form.action.type,
                ) && (
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      value={form.action.value}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          action: {
                            ...form.action,
                            value: Number(e.target.value),
                          },
                        })
                      }
                      className="w-24 rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
                      placeholder={
                        form.action.type === "percent_discount"
                          ? "%"
                          : "₹"
                      }
                    />
                    <span className="text-sm text-gray-400">
                      {form.action.type === "percent_discount" ? "%" : "₹"}
                    </span>
                  </div>
                )}
                {form.action.type === "percent_discount" && (
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-gray-500">Max</span>
                    <input
                      type="number"
                      value={form.action.maxDiscount || ""}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          action: {
                            ...form.action,
                            maxDiscount: Number(e.target.value) || undefined,
                          },
                        })
                      }
                      className="w-20 rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
                      placeholder="₹ cap"
                    />
                  </div>
                )}
              </div>
              {["auto_warning", "flag", "notify", "escalate", "dashboard_alert"].includes(
                form.action.type,
              ) && (
                <input
                  type="text"
                  value={form.action.message}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      action: { ...form.action, message: e.target.value },
                    })
                  }
                  className="mt-3 w-full rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
                  placeholder="Alert message"
                />
              )}
            </div>

            {/* Optional settings */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  User Type
                </label>
                <select
                  value={form.applicableTo?.userType || "all"}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      applicableTo: {
                        ...form.applicableTo,
                        userType: e.target.value as "all" | "new" | "existing",
                      },
                    })
                  }
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                >
                  <option value="all">All Users</option>
                  <option value="new">New Users Only</option>
                  <option value="existing">Existing Users</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Priority
                </label>
                <input
                  type="number"
                  value={form.priority}
                  onChange={(e) =>
                    setForm({ ...form, priority: Number(e.target.value) })
                  }
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                  placeholder="0 = lowest"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Valid From
                </label>
                <input
                  type="date"
                  value={form.validFrom}
                  onChange={(e) =>
                    setForm({ ...form, validFrom: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Valid Until
                </label>
                <input
                  type="date"
                  value={form.validUntil}
                  onChange={(e) =>
                    setForm({ ...form, validUntil: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Usage Limit (per user)
                </label>
                <input
                  type="number"
                  value={form.usageLimit || ""}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      usageLimit: Number(e.target.value) || undefined,
                    })
                  }
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                  placeholder="Unlimited"
                />
              </div>
            </div>

            {/* Submit */}
            <div className="flex justify-end gap-3 pt-4 border-t">
              <Button
                variant="secondary"
                onClick={() => {
                  setShowModal(false);
                  setEditingRule(null);
                }}
              >
                Cancel
              </Button>
              <Button onClick={handleSubmit}>
                {editingRule ? "Update Rule" : "Create Rule"}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Delete Confirmation */}
      {deleteId && (
        <Modal title="Delete Rule" onClose={() => setDeleteId(null)} size="sm">
          <div className="flex flex-col items-center text-center py-2">
            <div className="rounded-full bg-red-100 p-3">
              <AlertTriangle className="h-6 w-6 text-red-600" />
            </div>
            <p className="mt-3 text-sm text-gray-600">
              Are you sure you want to delete this rule? This cannot be undone.
            </p>
          </div>
          <div className="flex justify-end gap-3 pt-4">
            <Button variant="secondary" onClick={() => setDeleteId(null)}>
              Cancel
            </Button>
            <Button variant="danger" onClick={handleDelete} isLoading={deleting}>
              Delete
            </Button>
          </div>
        </Modal>
      )}
    </div>
  );
}
