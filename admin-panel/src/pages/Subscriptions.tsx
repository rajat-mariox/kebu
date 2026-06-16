import { useState, useEffect, useCallback } from "react";
import { Plus, Edit2, Trash2, Crown } from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Pagination } from "../components";
import { Modal } from "../components/Modal";
import ConfirmDialog from "../components/ConfirmDialog";
import api from "../services/api";

interface SubscriptionPlan {
  _id: string;
  name: string;
  description: string;
  duration: number;
  price: number;
  originalPrice?: number;
  benefits: {
    priceLockGuarantee: boolean;
    zeroWaitGuarantee: boolean;
    unlimitedDeliveries: boolean;
    priorityRides: boolean;
    discountPercentage?: number;
    freeDeliveriesPerMonth?: number;
    prioritySupportAccess: boolean;
  };
  image?: string;
  tag?: string;
  isTrialAvailable: boolean;
  trialDays: number;
  isActive: boolean;
}

interface UserSubscription {
  _id: string;
  userId: { _id: string; fullName: string; mobileNumber: string; email?: string };
  planId: { _id: string; name: string; duration: number; price: number };
  startDate: string;
  endDate: string;
  amount: number;
  status: string;
  autoRenew: boolean;
  isTrial: boolean;
  createdAt: string;
}

export default function Subscriptions() {
  const [tab, setTab] = useState<"plans" | "subscribers">("plans");
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [subscribers, setSubscribers] = useState<UserSubscription[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingPlan, setEditingPlan] = useState<SubscriptionPlan | null>(null);
  const [deletingPlan, setDeletingPlan] = useState<SubscriptionPlan | null>(null);
  const [formLoading, setFormLoading] = useState(false);
  const [subPage, setSubPage] = useState(0);
  const [subTotal, setSubTotal] = useState(0);

  const defaultForm = {
    name: "", description: "", duration: 30, price: 0, originalPrice: 0,
    tag: "", isTrialAvailable: false, trialDays: 0, isActive: true,
    benefits: {
      priceLockGuarantee: false, zeroWaitGuarantee: false, unlimitedDeliveries: false,
      priorityRides: false, discountPercentage: 0, freeDeliveriesPerMonth: 0, prioritySupportAccess: false,
    },
  };
  const [form, setForm] = useState(defaultForm);

  const fetchPlans = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/subscription-plans");
      setPlans(res.data?.data?.plans || []);
    } catch {
      toast.error("Failed to load plans");
    } finally {
      setIsLoading(false);
    }
  }, []);

  const fetchSubscribers = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/user-subscriptions", { params: { page: subPage, limit: 10 } });
      const data = res.data?.data;
      setSubscribers(data?.subscriptions || []);
      setSubTotal(data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to load subscribers");
    } finally {
      setIsLoading(false);
    }
  }, [subPage]);

  useEffect(() => {
    if (tab === "plans") fetchPlans();
    else fetchSubscribers();
  }, [tab, fetchPlans, fetchSubscribers]);

  const openCreate = () => {
    setEditingPlan(null);
    setForm(defaultForm);
    setShowForm(true);
  };

  const openEdit = (plan: SubscriptionPlan) => {
    setEditingPlan(plan);
    setForm({
      name: plan.name, description: plan.description, duration: plan.duration,
      price: plan.price, originalPrice: plan.originalPrice || 0,
      tag: plan.tag || "", isTrialAvailable: plan.isTrialAvailable, trialDays: plan.trialDays,
      isActive: plan.isActive, benefits: { ...defaultForm.benefits, ...plan.benefits },
    });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.name.trim()) { toast.error("Name is required"); return; }
    setFormLoading(true);
    try {
      if (editingPlan) {
        await api.put(`/admin/subscription-plans/${editingPlan._id}`, form);
        toast.success("Plan updated");
      } else {
        await api.post("/admin/subscription-plans", form);
        toast.success("Plan created");
      }
      setShowForm(false);
      fetchPlans();
    } catch {
      toast.error("Failed to save");
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingPlan) return;
    try {
      await api.delete(`/admin/subscription-plans/${deletingPlan._id}`);
      toast.success("Plan deleted");
      setDeletingPlan(null);
      fetchPlans();
    } catch {
      toast.error("Delete failed");
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Subscriptions</h1>
          <p className="mt-1 text-sm text-gray-500">Manage subscription plans and view active subscribers</p>
        </div>
        {tab === "plans" && (
          <button onClick={openCreate} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
            <Plus className="h-4 w-4" /> Add Plan
          </button>
        )}
      </div>

      <div className="flex border-b">
        {(["plans", "subscribers"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${tab === t ? "border-blue-600 text-blue-600" : "border-transparent text-gray-500 hover:text-gray-700"}`}
          >
            {t === "plans" ? "Plans" : "Active Subscribers"}
          </button>
        ))}
      </div>

      {tab === "plans" && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {isLoading ? (
            <div className="col-span-full flex items-center justify-center py-20">
              <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
            </div>
          ) : plans.length === 0 ? (
            <div className="col-span-full text-center py-20 text-gray-500">
              <Crown className="h-12 w-12 mx-auto mb-3 text-gray-300" />
              <p className="font-medium">No subscription plans</p>
            </div>
          ) : (
            plans.map((plan) => (
              <div key={plan._id} className="bg-white rounded-xl border border-gray-200 p-5 relative">
                {plan.tag && (
                  <span className="absolute -top-2 right-4 bg-orange-500 text-white text-xs font-bold px-2 py-0.5 rounded-full">
                    {plan.tag}
                  </span>
                )}
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="font-semibold text-gray-900">{plan.name}</h3>
                    <p className="text-xs text-gray-500 mt-0.5">{plan.duration} days</p>
                  </div>
                  <div className="flex gap-1">
                    <button onClick={() => openEdit(plan)} className="p-1 text-gray-400 hover:text-blue-600"><Edit2 className="h-4 w-4" /></button>
                    <button onClick={() => setDeletingPlan(plan)} className="p-1 text-gray-400 hover:text-red-600"><Trash2 className="h-4 w-4" /></button>
                  </div>
                </div>
                <div className="mt-3">
                  <span className="text-2xl font-bold text-gray-900">₹{plan.price}</span>
                  {plan.originalPrice && plan.originalPrice > plan.price && (
                    <span className="ml-2 text-sm text-gray-400 line-through">₹{plan.originalPrice}</span>
                  )}
                </div>
                <p className="text-sm text-gray-600 mt-2">{plan.description}</p>
                <div className="mt-3 space-y-1">
                  {plan.benefits.priorityRides && <p className="text-xs text-green-600">Priority Rides</p>}
                  {plan.benefits.unlimitedDeliveries && <p className="text-xs text-green-600">Unlimited Deliveries</p>}
                  {plan.benefits.priceLockGuarantee && <p className="text-xs text-green-600">Price Lock</p>}
                  {plan.benefits.prioritySupportAccess && <p className="text-xs text-green-600">Priority Support</p>}
                  {(plan.benefits.discountPercentage || 0) > 0 && <p className="text-xs text-green-600">{plan.benefits.discountPercentage}% Discount</p>}
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <Badge variant={plan.isActive ? "success" : "danger"}>{plan.isActive ? "Active" : "Inactive"}</Badge>
                  {plan.isTrialAvailable && <Badge variant="warning">{plan.trialDays}d Trial</Badge>}
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {tab === "subscribers" && (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          {isLoading ? (
            <div className="flex items-center justify-center py-20">
              <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
            </div>
          ) : subscribers.length === 0 ? (
            <div className="text-center py-20 text-gray-500">No subscribers found</div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-gray-50/50">
                  <th className="text-left py-3 px-4 font-medium text-gray-500">User</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">Plan</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">Amount</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">Period</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">Status</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">Auto Renew</th>
                </tr>
              </thead>
              <tbody>
                {subscribers.map((sub) => (
                  <tr key={sub._id} className="border-b border-gray-50">
                    <td className="py-3 px-4">
                      <p className="font-medium text-gray-900">{sub.userId?.fullName || "N/A"}</p>
                      <p className="text-xs text-gray-500">{sub.userId?.mobileNumber}</p>
                    </td>
                    <td className="py-3 px-4 text-sm">{sub.planId?.name || "N/A"}</td>
                    <td className="py-3 px-4 font-medium">₹{sub.amount}</td>
                    <td className="py-3 px-4 text-xs text-gray-600">
                      {new Date(sub.startDate).toLocaleDateString()} - {new Date(sub.endDate).toLocaleDateString()}
                    </td>
                    <td className="py-3 px-4">
                      <Badge variant={sub.status === "ACTIVE" ? "success" : sub.status === "EXPIRED" ? "danger" : "warning"}>
                        {sub.status}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-sm">{sub.autoRenew ? "Yes" : "No"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <Pagination page={subPage} limit={10} total={subTotal} onPageChange={setSubPage} />
        </div>
      )}

      {showForm && (
        <Modal title={editingPlan ? "Edit Plan" : "Add Plan"} onClose={() => setShowForm(false)} size="lg">
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tag (optional)</label>
                <input value={form.tag} onChange={(e) => setForm({ ...form, tag: e.target.value })} placeholder="BEST VALUE"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none" />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={2}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none" />
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Duration (days)</label>
                <input type="number" value={form.duration} onChange={(e) => setForm({ ...form, duration: parseInt(e.target.value) || 0 })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Price (₹)</label>
                <input type="number" value={form.price} onChange={(e) => setForm({ ...form, price: parseInt(e.target.value) || 0 })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Original Price (₹)</label>
                <input type="number" value={form.originalPrice} onChange={(e) => setForm({ ...form, originalPrice: parseInt(e.target.value) || 0 })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
            </div>
            <div>
              <p className="text-sm font-medium text-gray-700 mb-2">Benefits</p>
              <div className="grid grid-cols-2 gap-2">
                {(["priceLockGuarantee", "zeroWaitGuarantee", "unlimitedDeliveries", "priorityRides", "prioritySupportAccess"] as const).map((key) => (
                  <label key={key} className="flex items-center gap-2 text-sm">
                    <input type="checkbox" checked={form.benefits[key] as boolean}
                      onChange={(e) => setForm({ ...form, benefits: { ...form.benefits, [key]: e.target.checked } })}
                      className="rounded" />
                    {key.replace(/([A-Z])/g, " $1").trim()}
                  </label>
                ))}
              </div>
              <div className="grid grid-cols-2 gap-3 mt-2">
                <div>
                  <label className="block text-xs text-gray-600 mb-1">Discount %</label>
                  <input type="number" value={form.benefits.discountPercentage}
                    onChange={(e) => setForm({ ...form, benefits: { ...form.benefits, discountPercentage: parseInt(e.target.value) || 0 } })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
                </div>
                <div>
                  <label className="block text-xs text-gray-600 mb-1">Free Deliveries/Month</label>
                  <input type="number" value={form.benefits.freeDeliveriesPerMonth}
                    onChange={(e) => setForm({ ...form, benefits: { ...form.benefits, freeDeliveriesPerMonth: parseInt(e.target.value) || 0 } })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={form.isTrialAvailable}
                  onChange={(e) => setForm({ ...form, isTrialAvailable: e.target.checked })} className="rounded" />
                Trial Available
              </label>
              {form.isTrialAvailable && (
                <input type="number" value={form.trialDays} placeholder="Trial days"
                  onChange={(e) => setForm({ ...form, trialDays: parseInt(e.target.value) || 0 })}
                  className="w-24 rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
              )}
              <label className="flex items-center gap-2 text-sm ml-auto">
                <input type="checkbox" checked={form.isActive}
                  onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="rounded" />
                Active
              </label>
            </div>
            <div className="flex justify-end gap-3 border-t pt-3">
              <button onClick={() => setShowForm(false)} className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
              <button onClick={handleSave} disabled={formLoading} className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50">
                {formLoading ? "Saving..." : editingPlan ? "Update" : "Create"}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {deletingPlan && (
        <ConfirmDialog title="Delete Plan" message={`Delete "${deletingPlan.name}"?`}
          confirmLabel="Delete" variant="danger" onConfirm={handleDelete} onCancel={() => setDeletingPlan(null)} />
      )}
    </div>
  );
}
