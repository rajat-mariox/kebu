import { useState, useEffect, useCallback } from "react";
import { Plus, Trash2, Gift } from "lucide-react";
import toast from "react-hot-toast";
import { Badge } from "../components";
import { Modal } from "../components/Modal";
import ConfirmDialog from "../components/ConfirmDialog";
import { scratchCardService, userService } from "../services";
import type { ScratchCardRecord } from "../services";

type RewardType = "WALLET_CREDIT" | "DISCOUNT_COUPON" | "BETTER_LUCK";
type StatusFilter = "" | "UNSCRATCHED" | "SCRATCHED" | "EXPIRED";

interface UserOption {
  _id: string;
  name?: string;
  phone?: string;
  email?: string;
}

export default function ScratchCardManagement() {
  const [cards, setCards] = useState<ScratchCardRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("");
  const [showForm, setShowForm] = useState(false);
  const [deleting, setDeleting] = useState<ScratchCardRecord | null>(null);
  const [users, setUsers] = useState<UserOption[]>([]);
  const [saving, setSaving] = useState(false);

  const [form, setForm] = useState({
    userIds: [] as string[],
    title: "",
    description: "",
    rewardType: "WALLET_CREDIT" as RewardType,
    rewardValue: 10,
    couponCode: "",
    expiresAt: "",
  });

  const fetchCards = useCallback(async () => {
    setLoading(true);
    try {
      const { cards } = await scratchCardService.getAll({
        status: statusFilter || undefined,
        limit: 100,
      });
      setCards(cards);
    } catch {
      toast.error("Failed to load scratch cards");
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    fetchCards();
  }, [fetchCards]);

  useEffect(() => {
    userService
      .getAll({ limit: 500 })
      .then((res) => {
        const data = res.data as unknown as { users?: UserOption[]; items?: UserOption[] };
        setUsers(data?.users || data?.items || []);
      })
      .catch(() => {});
  }, []);

  const openCreate = () => {
    const twoWeeks = new Date();
    twoWeeks.setDate(twoWeeks.getDate() + 14);
    setForm({
      userIds: [],
      title: "",
      description: "",
      rewardType: "WALLET_CREDIT",
      rewardValue: 10,
      couponCode: "",
      expiresAt: twoWeeks.toISOString().slice(0, 16),
    });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.title.trim()) return toast.error("Title is required");
    if (form.userIds.length === 0) return toast.error("Select at least one user");
    if (!form.expiresAt) return toast.error("Expiry required");

    setSaving(true);
    try {
      const { created } = await scratchCardService.create({
        userIds: form.userIds,
        title: form.title,
        description: form.description || undefined,
        rewardType: form.rewardType,
        rewardValue: form.rewardValue,
        couponCode: form.rewardType === "DISCOUNT_COUPON" ? form.couponCode : undefined,
        expiresAt: new Date(form.expiresAt).toISOString(),
        sourceType: "admin_gift",
      });
      toast.success(`${created} scratch card${created === 1 ? "" : "s"} issued`);
      setShowForm(false);
      fetchCards();
    } catch {
      toast.error("Failed to create scratch card");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleting) return;
    try {
      await scratchCardService.remove(deleting._id);
      toast.success("Scratch card deleted");
      setDeleting(null);
      fetchCards();
    } catch {
      toast.error("Failed to delete");
    }
  };

  const userLabel = (card: ScratchCardRecord) => {
    const u = card.userId;
    if (typeof u === "string") return u;
    return u?.name || u?.phone || u?.email || u?._id;
  };

  const statusBadge = (status: string) => {
    const map: Record<string, "success" | "warning" | "danger" | "secondary"> = {
      UNSCRATCHED: "warning",
      SCRATCHED: "success",
      EXPIRED: "danger",
    };
    return <Badge variant={map[status] || "secondary"}>{status}</Badge>;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Scratch Cards</h1>
          <p className="text-sm text-gray-500 mt-1">
            Issue and manage reward scratch cards for customers
          </p>
        </div>
        <button
          onClick={openCreate}
          className="inline-flex items-center gap-2 rounded-lg bg-orange-500 px-4 py-2 text-sm font-medium text-white hover:bg-orange-600"
        >
          <Plus className="h-4 w-4" /> Issue Card
        </button>
      </div>

      <div className="flex items-center gap-3">
        <select
          className="rounded-lg border border-gray-200 px-3 py-2 text-sm"
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}
        >
          <option value="">All Status</option>
          <option value="UNSCRATCHED">Unscratched</option>
          <option value="SCRATCHED">Scratched</option>
          <option value="EXPIRED">Expired</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-gray-500">Loading...</div>
        ) : cards.length === 0 ? (
          <div className="p-12 text-center">
            <Gift className="h-10 w-10 mx-auto text-gray-300" />
            <p className="mt-2 text-sm text-gray-500">No scratch cards issued yet</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs uppercase text-gray-500">
              <tr>
                <th className="px-4 py-3 text-left">User</th>
                <th className="px-4 py-3 text-left">Title</th>
                <th className="px-4 py-3 text-left">Reward</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 text-left">Expires</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {cards.map((c) => (
                <tr key={c._id} className="hover:bg-gray-50">
                  <td className="px-4 py-3">{userLabel(c)}</td>
                  <td className="px-4 py-3 font-medium">{c.title}</td>
                  <td className="px-4 py-3">
                    {c.rewardType === "WALLET_CREDIT" && `₹${c.rewardValue}`}
                    {c.rewardType === "DISCOUNT_COUPON" && `${c.couponCode || "-"} (${c.rewardValue}%)`}
                    {c.rewardType === "BETTER_LUCK" && "Better luck next time"}
                  </td>
                  <td className="px-4 py-3">{statusBadge(c.status)}</td>
                  <td className="px-4 py-3 text-xs text-gray-500">
                    {new Date(c.expiresAt).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => setDeleting(c)}
                      className="text-red-500 hover:text-red-700"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showForm && (
      <Modal onClose={() => setShowForm(false)} title="Issue Scratch Card">
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Users</label>
            <select
              multiple
              size={5}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
              value={form.userIds}
              onChange={(e) => {
                const selected = Array.from(e.target.selectedOptions).map((o) => o.value);
                setForm({ ...form, userIds: selected });
              }}
            >
              {users.map((u) => (
                <option key={u._id} value={u._id}>
                  {u.name || u.phone || u.email || u._id}
                </option>
              ))}
            </select>
            <p className="text-xs text-gray-400 mt-1">Hold Ctrl/Cmd to select multiple</p>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Title</label>
            <input
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              placeholder="e.g. Thanks for riding!"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Description</label>
            <textarea
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              rows={2}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Reward Type</label>
              <select
                className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                value={form.rewardType}
                onChange={(e) => setForm({ ...form, rewardType: e.target.value as RewardType })}
              >
                <option value="WALLET_CREDIT">Wallet Credit</option>
                <option value="DISCOUNT_COUPON">Discount Coupon</option>
                <option value="BETTER_LUCK">Better Luck Next Time</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                {form.rewardType === "DISCOUNT_COUPON" ? "Percent (%)" : "Amount (₹)"}
              </label>
              <input
                type="number"
                className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
                value={form.rewardValue}
                onChange={(e) => setForm({ ...form, rewardValue: Number(e.target.value) })}
                disabled={form.rewardType === "BETTER_LUCK"}
              />
            </div>
          </div>

          {form.rewardType === "DISCOUNT_COUPON" && (
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Coupon Code</label>
              <input
                className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm uppercase"
                value={form.couponCode}
                onChange={(e) => setForm({ ...form, couponCode: e.target.value.toUpperCase() })}
              />
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Expires At</label>
            <input
              type="datetime-local"
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
              value={form.expiresAt}
              onChange={(e) => setForm({ ...form, expiresAt: e.target.value })}
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              onClick={() => setShowForm(false)}
              className="px-4 py-2 text-sm rounded-lg border border-gray-200"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="px-4 py-2 text-sm rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50"
            >
              {saving ? "Saving..." : "Issue Cards"}
            </button>
          </div>
        </div>
      </Modal>
      )}

      {deleting && (
        <ConfirmDialog
          onCancel={() => setDeleting(null)}
          onConfirm={handleDelete}
          title="Delete scratch card?"
          message={`Delete "${deleting?.title}"?`}
        />
      )}
    </div>
  );
}
