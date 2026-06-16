import { useState, useEffect, useCallback } from "react";
import { Plus, Edit2, Trash2, HelpCircle } from "lucide-react";
import toast from "react-hot-toast";
import { Badge } from "../components";
import { Modal } from "../components/Modal";
import ConfirmDialog from "../components/ConfirmDialog";
import api from "../services/api";

interface FAQ {
  _id: string;
  question: string;
  answer: string;
  category: string;
  order: number;
  isActive: boolean;
  createdAt: string;
}

const categories = ["GENERAL", "CONTACT", "PAYMENT", "BOOKING", "DRIVER", "SERVICE"];

export default function FAQManagement() {
  const [faqs, setFaqs] = useState<FAQ[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [categoryFilter, setCategoryFilter] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [editingFaq, setEditingFaq] = useState<FAQ | null>(null);
  const [deletingFaq, setDeletingFaq] = useState<FAQ | null>(null);
  const [formLoading, setFormLoading] = useState(false);
  const [form, setForm] = useState({ question: "", answer: "", category: "GENERAL", order: 0, isActive: true });

  const fetchFaqs = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/faqs", { params: { category: categoryFilter || undefined } });
      setFaqs(res.data?.data?.faqs || []);
    } catch {
      toast.error("Failed to load FAQs");
    } finally {
      setIsLoading(false);
    }
  }, [categoryFilter]);

  useEffect(() => { fetchFaqs(); }, [fetchFaqs]);

  const openCreate = () => {
    setEditingFaq(null);
    setForm({ question: "", answer: "", category: "GENERAL", order: 0, isActive: true });
    setShowForm(true);
  };

  const openEdit = (faq: FAQ) => {
    setEditingFaq(faq);
    setForm({ question: faq.question, answer: faq.answer, category: faq.category, order: faq.order, isActive: faq.isActive });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.question.trim() || !form.answer.trim()) {
      toast.error("Question and answer are required");
      return;
    }
    setFormLoading(true);
    try {
      if (editingFaq) {
        await api.put(`/admin/faqs/${editingFaq._id}`, form);
        toast.success("FAQ updated");
      } else {
        await api.post("/admin/faqs", form);
        toast.success("FAQ created");
      }
      setShowForm(false);
      fetchFaqs();
    } catch {
      toast.error("Failed to save FAQ");
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingFaq) return;
    try {
      await api.delete(`/admin/faqs/${deletingFaq._id}`);
      toast.success("FAQ deleted");
      setDeletingFaq(null);
      fetchFaqs();
    } catch {
      toast.error("Delete failed");
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">FAQ Management</h1>
          <p className="mt-1 text-sm text-gray-500">Manage frequently asked questions for customers and drivers</p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add FAQ
        </button>
      </div>

      <div className="flex gap-3">
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
        >
          <option value="">All Categories</option>
          {categories.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
          </div>
        ) : faqs.length === 0 ? (
          <div className="text-center py-20 text-gray-500">
            <HelpCircle className="h-12 w-12 mx-auto mb-3 text-gray-300" />
            <p className="font-medium">No FAQs found</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {faqs.map((faq) => (
              <div key={faq._id} className="p-4 hover:bg-gray-50">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <Badge variant="info">{faq.category}</Badge>
                      <Badge variant={faq.isActive ? "success" : "danger"}>
                        {faq.isActive ? "Active" : "Inactive"}
                      </Badge>
                      <span className="text-xs text-gray-400">Order: {faq.order}</span>
                    </div>
                    <h3 className="text-sm font-semibold text-gray-900">{faq.question}</h3>
                    <p className="text-sm text-gray-600 mt-1">{faq.answer}</p>
                  </div>
                  <div className="flex items-center gap-1">
                    <button onClick={() => openEdit(faq)} className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600">
                      <Edit2 className="h-4 w-4" />
                    </button>
                    <button onClick={() => setDeletingFaq(faq)} className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600">
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showForm && (
        <Modal title={editingFaq ? "Edit FAQ" : "Add FAQ"} onClose={() => setShowForm(false)}>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Question</label>
              <input
                value={form.question}
                onChange={(e) => setForm({ ...form, question: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Answer</label>
              <textarea
                value={form.answer}
                onChange={(e) => setForm({ ...form, answer: e.target.value })}
                rows={4}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                <select
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  {categories.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Order</label>
                <input
                  type="number"
                  value={form.order}
                  onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="flex items-end">
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
                    className="rounded"
                  />
                  Active
                </label>
              </div>
            </div>
            <div className="flex justify-end gap-3">
              <button onClick={() => setShowForm(false)} className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50">
                Cancel
              </button>
              <button onClick={handleSave} disabled={formLoading} className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50">
                {formLoading ? "Saving..." : editingFaq ? "Update" : "Create"}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {deletingFaq && (
        <ConfirmDialog
          title="Delete FAQ"
          message={`Delete "${deletingFaq.question}"?`}
          confirmLabel="Delete"
          variant="danger"
          onConfirm={handleDelete}
          onCancel={() => setDeletingFaq(null)}
        />
      )}
    </div>
  );
}
