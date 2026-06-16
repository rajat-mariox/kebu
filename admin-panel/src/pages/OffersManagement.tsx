import { useState, useEffect, useCallback } from "react";
import { Plus, Edit2, Trash2, Tag, Power } from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Modal, ImageUpload } from "../components";
import ConfirmDialog from "../components/ConfirmDialog";
import { offerService, type OfferRecord } from "../services/offer.service";

const SECTIONS: Array<{ value: OfferRecord["section"]; label: string }> = [
  { value: "latest", label: "Latest Offers" },
  { value: "limited", label: "Limited Offer" },
  { value: "just_for_you", label: "Just For You" },
];

const TARGET_SERVICES: Array<{
  value: OfferRecord["targetService"];
  label: string;
}> = [
  { value: "none", label: "No redirection" },
  { value: "booking", label: "Book a Ride" },
  { value: "cleaning", label: "Household / Cleaning" },
  { value: "parcel", label: "Send Parcel" },
];

type FormState = {
  title: string;
  subtitle: string;
  description: string;
  section: OfferRecord["section"];
  targetService: OfferRecord["targetService"];
  targetCategory: string;
  code: string;
  image: string;
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

const emptyForm = (): FormState => {
  const today = new Date();
  const nextMonth = new Date();
  nextMonth.setDate(nextMonth.getDate() + 30);
  return {
    title: "",
    subtitle: "",
    description: "",
    section: "latest",
    targetService: "none",
    targetCategory: "",
    code: "",
    image: "",
    bannerImage: "",
    tag: "",
    priority: 0,
    startDate: toInputDate(today.toISOString()),
    endDate: toInputDate(nextMonth.toISOString()),
    isActive: true,
  };
};

export default function OffersManagement() {
  const [offers, setOffers] = useState<OfferRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [sectionFilter, setSectionFilter] = useState("");
  const [serviceFilter, setServiceFilter] = useState("");
  const [search, setSearch] = useState("");

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<OfferRecord | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm());
  const [formLoading, setFormLoading] = useState(false);

  const [deleting, setDeleting] = useState<OfferRecord | null>(null);

  const fetchOffers = useCallback(async () => {
    setIsLoading(true);
    try {
      const list = await offerService.getAll({
        section: sectionFilter || undefined,
        targetService: serviceFilter || undefined,
        search: search.trim() || undefined,
      });
      setOffers(list);
    } catch {
      toast.error("Failed to load offers");
    } finally {
      setIsLoading(false);
    }
  }, [sectionFilter, serviceFilter, search]);

  useEffect(() => {
    fetchOffers();
  }, [fetchOffers]);

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm());
    setShowForm(true);
  };

  const openEdit = (offer: OfferRecord) => {
    setEditing(offer);
    setForm({
      title: offer.title || "",
      subtitle: offer.subtitle || "",
      description: offer.description || "",
      section: offer.section || "latest",
      targetService: offer.targetService || "none",
      targetCategory: offer.targetCategory || "",
      code: offer.code || "",
      image: offer.image || "",
      bannerImage: offer.bannerImage || "",
      tag: offer.tag || "",
      priority: offer.priority || 0,
      startDate: toInputDate(offer.startDate),
      endDate: toInputDate(offer.endDate),
      isActive: offer.isActive,
    });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.title.trim() || !form.description.trim()) {
      toast.error("Title and description are required");
      return;
    }
    if (!form.startDate || !form.endDate) {
      toast.error("Start and end date are required");
      return;
    }
    if (new Date(form.endDate) < new Date(form.startDate)) {
      toast.error("End date must be after start date");
      return;
    }

    const payload: Partial<OfferRecord> = {
      title: form.title.trim(),
      subtitle: form.subtitle.trim() || undefined,
      description: form.description.trim(),
      section: form.section,
      targetService: form.targetService,
      targetCategory: form.targetCategory.trim() || undefined,
      code: form.code.trim() || undefined,
      image: form.image || undefined,
      bannerImage: form.bannerImage || undefined,
      tag: form.tag.trim() || undefined,
      priority: Number(form.priority) || 0,
      startDate: new Date(form.startDate).toISOString(),
      endDate: new Date(form.endDate).toISOString(),
      isActive: form.isActive,
    };

    setFormLoading(true);
    try {
      if (editing) {
        await offerService.update(editing._id, payload);
        toast.success("Offer updated");
      } else {
        await offerService.create(payload);
        toast.success("Offer created");
      }
      setShowForm(false);
      fetchOffers();
    } catch (err: any) {
      const msg =
        err?.response?.data?.msg || err?.message || "Failed to save offer";
      toast.error(msg);
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!deleting) return;
    try {
      await offerService.remove(deleting._id);
      toast.success("Offer deleted");
      setDeleting(null);
      fetchOffers();
    } catch {
      toast.error("Delete failed");
    }
  };

  const handleToggle = async (offer: OfferRecord) => {
    try {
      await offerService.toggleStatus(offer._id);
      toast.success(offer.isActive ? "Offer deactivated" : "Offer activated");
      fetchOffers();
    } catch {
      toast.error("Failed to update status");
    }
  };

  const sectionLabel = (s: string) =>
    SECTIONS.find((x) => x.value === s)?.label || s;
  const serviceLabel = (s: string) =>
    TARGET_SERVICES.find((x) => x.value === s)?.label || s;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Offers & Promos</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage banners shown in Latest / Limited / Just For You on the customer home.
          </p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add Offer
        </button>
      </div>

      <div className="flex flex-wrap gap-3">
        <select
          value={sectionFilter}
          onChange={(e) => setSectionFilter(e.target.value)}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
        >
          <option value="">All Sections</option>
          {SECTIONS.map((s) => (
            <option key={s.value} value={s.value}>
              {s.label}
            </option>
          ))}
        </select>
        <select
          value={serviceFilter}
          onChange={(e) => setServiceFilter(e.target.value)}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
        >
          <option value="">All Target Services</option>
          {TARGET_SERVICES.map((s) => (
            <option key={s.value} value={s.value}>
              {s.label}
            </option>
          ))}
        </select>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search title, description, code"
          className="flex-1 min-w-[240px] rounded-lg border border-gray-300 px-4 py-2 text-sm"
        />
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
          </div>
        ) : offers.length === 0 ? (
          <div className="text-center py-20 text-gray-500">
            <Tag className="h-12 w-12 mx-auto mb-3 text-gray-300" />
            <p className="font-medium">No offers yet</p>
            <p className="text-sm mt-1">Click "Add Offer" to create one.</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {offers.map((offer) => (
              <div key={offer._id} className="p-4 hover:bg-gray-50">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex gap-4 flex-1">
                    {offer.image ? (
                      <img
                        src={offer.image}
                        alt={offer.title}
                        className="h-16 w-16 rounded-lg object-cover border border-gray-200"
                      />
                    ) : (
                      <div className="h-16 w-16 rounded-lg bg-gray-100 flex items-center justify-center">
                        <Tag className="h-6 w-6 text-gray-400" />
                      </div>
                    )}
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <Badge variant="info">{sectionLabel(offer.section)}</Badge>
                        {offer.targetService !== "none" && (
                          <Badge variant="secondary">{serviceLabel(offer.targetService)}</Badge>
                        )}
                        <Badge variant={offer.isActive ? "success" : "danger"}>
                          {offer.isActive ? "Active" : "Inactive"}
                        </Badge>
                        {offer.tag && (
                          <span className="text-xs text-gray-500">#{offer.tag}</span>
                        )}
                        <span className="text-xs text-gray-400">
                          Priority: {offer.priority}
                        </span>
                      </div>
                      <h3 className="text-sm font-semibold text-gray-900">
                        {offer.title}
                      </h3>
                      {offer.subtitle && (
                        <p className="text-xs text-gray-500">{offer.subtitle}</p>
                      )}
                      <p className="text-sm text-gray-600 mt-1 line-clamp-2">
                        {offer.description}
                      </p>
                      <p className="text-xs text-gray-400 mt-1">
                        {new Date(offer.startDate).toLocaleDateString()} →{" "}
                        {new Date(offer.endDate).toLocaleDateString()}
                        {offer.code && <> · Code: <b>{offer.code}</b></>}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => handleToggle(offer)}
                      title={offer.isActive ? "Deactivate" : "Activate"}
                      className="rounded-lg p-1.5 text-gray-400 hover:bg-amber-50 hover:text-amber-600"
                    >
                      <Power className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => openEdit(offer)}
                      className="rounded-lg p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600"
                    >
                      <Edit2 className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => setDeleting(offer)}
                      className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600"
                    >
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
        <Modal
          title={editing ? "Edit Offer" : "Add Offer"}
          onClose={() => setShowForm(false)}
        >
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Title
                </label>
                <input
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Subtitle
                </label>
                <input
                  value={form.subtitle}
                  onChange={(e) =>
                    setForm({ ...form, subtitle: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Description
              </label>
              <textarea
                value={form.description}
                onChange={(e) =>
                  setForm({ ...form, description: e.target.value })
                }
                rows={3}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Section
                </label>
                <select
                  value={form.section}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      section: e.target.value as FormState["section"],
                    })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  {SECTIONS.map((s) => (
                    <option key={s.value} value={s.value}>
                      {s.label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Target Service (on tap)
                </label>
                <select
                  value={form.targetService}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      targetService: e.target
                        .value as FormState["targetService"],
                    })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  {TARGET_SERVICES.map((s) => (
                    <option key={s.value} value={s.value}>
                      {s.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Target Category (optional)
                </label>
                <input
                  value={form.targetCategory}
                  onChange={(e) =>
                    setForm({ ...form, targetCategory: e.target.value })
                  }
                  placeholder="e.g. deep-cleaning, cab-mini"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Promo Code (optional)
                </label>
                <input
                  value={form.code}
                  onChange={(e) =>
                    setForm({ ...form, code: e.target.value.toUpperCase() })
                  }
                  placeholder="e.g. WELCOME50"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm uppercase"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <ImageUpload
                label="Card Image"
                value={form.image}
                onChange={(url) => setForm({ ...form, image: url })}
              />
              <ImageUpload
                label="Banner Image"
                value={form.bannerImage}
                onChange={(url) => setForm({ ...form, bannerImage: url })}
              />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tag
                </label>
                <input
                  value={form.tag}
                  onChange={(e) => setForm({ ...form, tag: e.target.value })}
                  placeholder="Trending / New"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Priority
                </label>
                <input
                  type="number"
                  value={form.priority}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      priority: parseInt(e.target.value) || 0,
                    })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="flex items-end">
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(e) =>
                      setForm({ ...form, isActive: e.target.checked })
                    }
                    className="rounded"
                  />
                  Active
                </label>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Start Date
                </label>
                <input
                  type="date"
                  value={form.startDate}
                  onChange={(e) =>
                    setForm({ ...form, startDate: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  End Date
                </label>
                <input
                  type="date"
                  value={form.endDate}
                  onChange={(e) =>
                    setForm({ ...form, endDate: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <button
                onClick={() => setShowForm(false)}
                className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={formLoading}
                className="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                {formLoading
                  ? "Saving..."
                  : editing
                    ? "Update Offer"
                    : "Create Offer"}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {deleting && (
        <ConfirmDialog
          title="Delete Offer"
          message={`Delete "${deleting.title}"? This cannot be undone.`}
          confirmLabel="Delete"
          variant="danger"
          onConfirm={handleDelete}
          onCancel={() => setDeleting(null)}
        />
      )}
    </div>
  );
}
