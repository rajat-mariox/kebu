import { useState, useEffect, useCallback, useRef } from "react";
import {
  Bell,
  Send,
  Users,
  Car,
  Truck,
  Home,
  Search,
  X,
  CheckCircle,
  UserPlus,
  Megaphone,
} from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Pagination } from "../components";
import api from "../services/api";

// ── Types ───────────────────────────────────────────────
interface NotificationItem {
  _id: string;
  userId: { _id: string; fullName: string; mobileNumber: string };
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  createdAt: string;
}

interface Recipient {
  _id: string;
  fullName: string;
  mobileNumber?: string;
  email?: string;
  serviceType?: string;
}

type Tab = "history" | "send";
type Audience = "users" | "vendors" | "all";
type RecipientMode = "all" | "specific";

const typeColors: Record<string, "info" | "success" | "warning" | "danger"> = {
  SYSTEM: "info",
  ORDER: "success",
  OFFER: "warning",
  REMINDER: "warning",
  MESSAGE: "info",
};

const SERVICE_TYPE_OPTIONS = [
  { value: "cab", label: "Cab Drivers", icon: Car, color: "blue" },
  { value: "parcel", label: "Delivery Partners", icon: Truck, color: "orange" },
  { value: "cleaning", label: "Household Providers", icon: Home, color: "teal" },
];

// ── Component ───────────────────────────────────────────
export default function Notifications() {
  const [tab, setTab] = useState<Tab>("send");

  // History state
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [typeFilter, setTypeFilter] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const limit = 20;

  // Send form state
  const [audience, setAudience] = useState<Audience>("users");
  const [recipientMode, setRecipientMode] = useState<RecipientMode>("all");
  const [selectedServiceTypes, setSelectedServiceTypes] = useState<string[]>([]);
  const [selectedRecipients, setSelectedRecipients] = useState<Recipient[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<Recipient[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [notifType, setNotifType] = useState("SYSTEM");
  const [sending, setSending] = useState(false);
  const [previewCount, setPreviewCount] = useState<number | null>(null);
  const searchRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  // ── Fetch History ─────────────────────────────────────
  const fetchNotifications = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/notifications", {
        params: { page, limit, type: typeFilter || undefined },
      });
      const data = res.data?.data;
      setNotifications(data?.notifications || []);
      setTotal(data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to load notifications");
    } finally {
      setIsLoading(false);
    }
  }, [page, typeFilter]);

  useEffect(() => {
    if (tab === "history") fetchNotifications();
  }, [tab, fetchNotifications]);

  // ── Recipient Search ──────────────────────────────────
  const searchRecipients = useCallback(
    async (q: string) => {
      if (q.length < 2) {
        setSearchResults([]);
        return;
      }
      setSearchLoading(true);
      try {
        const endpoint = audience === "vendors" ? "/admin/drivers" : "/admin/users";
        const res = await api.get(endpoint, { params: { search: q, limit: 10, page: 0 } });
        const data = res.data?.data;
        const items: Recipient[] = (data?.users || data?.drivers || data?.items || []).map((r: any) => ({
          _id: r._id,
          fullName: r.fullName || r.name || "Unknown",
          mobileNumber: r.mobileNumber || r.phone,
          email: r.email,
          serviceType: r.serviceType,
        }));
        // Filter out already selected
        const selectedIds = new Set(selectedRecipients.map((r) => r._id));
        setSearchResults(items.filter((r) => !selectedIds.has(r._id)));
      } catch {
        setSearchResults([]);
      } finally {
        setSearchLoading(false);
      }
    },
    [audience, selectedRecipients],
  );

  const handleSearchInput = (value: string) => {
    setSearchQuery(value);
    setShowDropdown(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => searchRecipients(value), 300);
  };

  const addRecipient = (r: Recipient) => {
    setSelectedRecipients((prev) => [...prev, r]);
    setSearchResults((prev) => prev.filter((p) => p._id !== r._id));
    setSearchQuery("");
    setShowDropdown(false);
  };

  const removeRecipient = (id: string) => {
    setSelectedRecipients((prev) => prev.filter((r) => r._id !== id));
  };

  const toggleServiceType = (st: string) => {
    setSelectedServiceTypes((prev) =>
      prev.includes(st) ? prev.filter((s) => s !== st) : [...prev, st],
    );
  };

  // ── Close dropdown on outside click ───────────────────
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  // ── Preview count ─────────────────────────────────────
  useEffect(() => {
    if (recipientMode === "specific") {
      setPreviewCount(selectedRecipients.length);
      return;
    }
    // Estimate for "all" mode
    const fetchCount = async () => {
      try {
        if (audience === "users" || audience === "all") {
          const uRes = await api.get("/admin/users", { params: { limit: 1, page: 0 } });
          const uTotal = uRes.data?.data?.pagination?.total || uRes.data?.data?.total || 0;
          if (audience === "users") { setPreviewCount(uTotal); return; }
          const dRes = await api.get("/admin/drivers", { params: { limit: 1, page: 0, status: "approved" } });
          const dTotal = dRes.data?.data?.pagination?.total || dRes.data?.data?.total || 0;
          setPreviewCount(uTotal + dTotal);
        } else {
          const dRes = await api.get("/admin/drivers", { params: { limit: 1, page: 0, status: "approved" } });
          setPreviewCount(dRes.data?.data?.pagination?.total || dRes.data?.data?.total || 0);
        }
      } catch {
        setPreviewCount(null);
      }
    };
    fetchCount();
  }, [audience, recipientMode, selectedRecipients.length]);

  // ── Reset recipients when audience changes ────────────
  useEffect(() => {
    setSelectedRecipients([]);
    setSelectedServiceTypes([]);
    setSearchQuery("");
    setSearchResults([]);
  }, [audience]);

  // ── Send ──────────────────────────────────────────────
  const handleSend = async () => {
    if (!title.trim() || !message.trim()) {
      toast.error("Title and message are required");
      return;
    }
    if (recipientMode === "specific" && selectedRecipients.length === 0) {
      toast.error("Select at least one recipient");
      return;
    }

    const body: Record<string, any> = {
      title: title.trim(),
      message: message.trim(),
      type: notifType,
      audience,
    };

    if (recipientMode === "specific") {
      if (audience === "vendors") {
        body.driverIds = selectedRecipients.map((r) => r._id);
      } else {
        body.userIds = selectedRecipients.map((r) => r._id);
      }
    } else if (audience === "vendors" && selectedServiceTypes.length > 0) {
      body.serviceTypes = selectedServiceTypes;
    }

    setSending(true);
    try {
      const res = await api.post("/admin/notifications/send", body);
      const data = res.data?.data;
      const sentUsers = data?.users || 0;
      const sentVendors = data?.vendors || 0;
      const totalSent = data?.sent || sentUsers + sentVendors;

      const parts: string[] = [];
      if (sentUsers > 0) parts.push(`${sentUsers} user${sentUsers > 1 ? "s" : ""}`);
      if (sentVendors > 0) parts.push(`${sentVendors} vendor${sentVendors > 1 ? "s" : ""}`);
      toast.success(`Sent to ${parts.length > 0 ? parts.join(" & ") : `${totalSent} recipients`}`);

      // Reset form
      setTitle("");
      setMessage("");
      setNotifType("SYSTEM");
      setSelectedRecipients([]);
      setSelectedServiceTypes([]);
      setRecipientMode("all");
    } catch {
      toast.error("Failed to send notification");
    } finally {
      setSending(false);
    }
  };

  // ── Render ────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Bell className="h-7 w-7 text-orange-500" /> Notifications
          </h1>
          <p className="mt-1 text-sm text-gray-500">
            Send targeted push notifications to users and vendors
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 w-fit">
        {([
          { key: "send" as Tab, label: "Compose & Send", icon: Send },
          { key: "history" as Tab, label: "History", icon: Bell },
        ]).map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              tab === key
                ? "bg-white text-orange-600 shadow-sm"
                : "text-gray-500 hover:text-gray-700"
            }`}
          >
            <Icon className="h-4 w-4" /> {label}
          </button>
        ))}
      </div>

      {/* ════════════ SEND TAB ════════════ */}
      {tab === "send" && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Form */}
          <div className="lg:col-span-2 space-y-6">
            {/* Step 1: Audience */}
            <div className="bg-white rounded-xl border p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Step 1: Choose Audience</h3>
              <p className="text-xs text-gray-400 mb-4">Who should receive this notification?</p>
              <div className="grid grid-cols-3 gap-3">
                {([
                  { key: "users" as Audience, label: "Customers", icon: Users, desc: "App users" },
                  { key: "vendors" as Audience, label: "Vendors", icon: Car, desc: "Drivers & providers" },
                  { key: "all" as Audience, label: "Everyone", icon: Megaphone, desc: "All users & vendors" },
                ] as const).map(({ key, label, icon: Icon, desc }) => (
                  <button
                    key={key}
                    onClick={() => setAudience(key)}
                    className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${
                      audience === key
                        ? "border-orange-400 bg-orange-50 text-orange-700"
                        : "border-gray-200 hover:border-gray-300 text-gray-600"
                    }`}
                  >
                    <Icon className="h-6 w-6" />
                    <span className="text-sm font-medium">{label}</span>
                    <span className="text-[11px] text-gray-400">{desc}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Step 2: Recipients */}
            <div className="bg-white rounded-xl border p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Step 2: Select Recipients</h3>
              <p className="text-xs text-gray-400 mb-4">Send to everyone or pick specific recipients</p>

              {/* Mode toggle */}
              <div className="flex gap-3 mb-4">
                <button
                  onClick={() => setRecipientMode("all")}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm font-medium transition-all ${
                    recipientMode === "all"
                      ? "border-orange-400 bg-orange-50 text-orange-700"
                      : "border-gray-200 text-gray-500 hover:border-gray-300"
                  }`}
                >
                  <Megaphone className="h-4 w-4" />
                  Send to All {audience === "users" ? "Customers" : audience === "vendors" ? "Vendors" : ""}
                </button>
                <button
                  onClick={() => setRecipientMode("specific")}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm font-medium transition-all ${
                    recipientMode === "specific"
                      ? "border-orange-400 bg-orange-50 text-orange-700"
                      : "border-gray-200 text-gray-500 hover:border-gray-300"
                  }`}
                >
                  <UserPlus className="h-4 w-4" />
                  Pick Specific Recipients
                </button>
              </div>

              {/* Vendor category filter (only for "all" + vendors) */}
              {recipientMode === "all" && (audience === "vendors" || audience === "all") && (
                <div className="mb-4">
                  <p className="text-xs font-medium text-gray-600 mb-2">Filter by vendor category:</p>
                  <div className="flex flex-wrap gap-2">
                    {SERVICE_TYPE_OPTIONS.map(({ value, label, icon: Icon, color }) => (
                      <button
                        key={value}
                        onClick={() => toggleServiceType(value)}
                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                          selectedServiceTypes.includes(value)
                            ? `border-${color}-400 bg-${color}-50 text-${color}-700`
                            : "border-gray-200 text-gray-500 hover:border-gray-300"
                        }`}
                      >
                        <Icon className="h-3.5 w-3.5" />
                        {label}
                        {selectedServiceTypes.includes(value) && (
                          <CheckCircle className="h-3.5 w-3.5 ml-0.5" />
                        )}
                      </button>
                    ))}
                    {selectedServiceTypes.length === 0 && (
                      <span className="text-[11px] text-gray-400 self-center ml-2">
                        No filter = all vendor categories
                      </span>
                    )}
                  </div>
                </div>
              )}

              {/* Specific recipient search */}
              {recipientMode === "specific" && audience !== "all" && (
                <div className="space-y-3">
                  <div className="relative" ref={searchRef}>
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                      <input
                        value={searchQuery}
                        onChange={(e) => handleSearchInput(e.target.value)}
                        onFocus={() => searchQuery.length >= 2 && setShowDropdown(true)}
                        placeholder={`Search ${audience === "vendors" ? "vendors" : "users"} by name or phone...`}
                        className="w-full pl-10 pr-4 py-2.5 rounded-lg border border-gray-200 text-sm focus:border-orange-400 focus:ring-1 focus:ring-orange-400 focus:outline-none"
                      />
                    </div>

                    {/* Dropdown */}
                    {showDropdown && (searchResults.length > 0 || searchLoading || searchQuery.length >= 2) && (
                      <div className="absolute z-20 mt-1 w-full bg-white rounded-lg border shadow-lg max-h-60 overflow-y-auto">
                        {searchLoading && (
                          <div className="flex items-center justify-center py-4">
                            <div className="h-4 w-4 animate-spin rounded-full border-2 border-orange-500 border-t-transparent" />
                          </div>
                        )}
                        {!searchLoading && searchResults.length === 0 && searchQuery.length >= 2 && (
                          <div className="py-4 text-center text-sm text-gray-400">No results found</div>
                        )}
                        {!searchLoading &&
                          searchResults.map((r) => (
                            <button
                              key={r._id}
                              onClick={() => addRecipient(r)}
                              className="flex items-center gap-3 w-full px-4 py-2.5 hover:bg-orange-50 text-left transition-colors"
                            >
                              <div className="h-8 w-8 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-white text-xs font-semibold">
                                {r.fullName?.charAt(0)?.toUpperCase() || "?"}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-medium text-gray-900 truncate">{r.fullName}</p>
                                <p className="text-xs text-gray-400">
                                  {r.mobileNumber || r.email || ""}
                                  {r.serviceType && ` · ${r.serviceType}`}
                                </p>
                              </div>
                            </button>
                          ))}
                      </div>
                    )}
                  </div>

                  {/* Selected chips */}
                  {selectedRecipients.length > 0 && (
                    <div className="flex flex-wrap gap-2">
                      {selectedRecipients.map((r) => (
                        <span
                          key={r._id}
                          className="inline-flex items-center gap-1.5 pl-1 pr-2 py-1 rounded-full bg-orange-50 border border-orange-200 text-xs font-medium text-orange-700"
                        >
                          <span className="h-5 w-5 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-white text-[10px] font-bold">
                            {r.fullName?.charAt(0)?.toUpperCase()}
                          </span>
                          {r.fullName}
                          <button
                            onClick={() => removeRecipient(r._id)}
                            className="ml-0.5 text-orange-400 hover:text-orange-600"
                          >
                            <X className="h-3 w-3" />
                          </button>
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {recipientMode === "specific" && audience === "all" && (
                <div className="rounded-lg bg-amber-50 border border-amber-200 p-3">
                  <p className="text-xs text-amber-700">
                    For specific recipients, please select either <strong>Customers</strong> or{" "}
                    <strong>Vendors</strong> as the audience first.
                  </p>
                </div>
              )}
            </div>

            {/* Step 3: Compose */}
            <div className="bg-white rounded-xl border p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Step 3: Compose Message</h3>
              <p className="text-xs text-gray-400 mb-4">Write your notification content</p>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Notification Type
                  </label>
                  <select
                    value={notifType}
                    onChange={(e) => setNotifType(e.target.value)}
                    className="w-full rounded-lg border border-gray-200 px-3 py-2.5 text-sm focus:border-orange-400 focus:ring-1 focus:ring-orange-400 focus:outline-none"
                  >
                    <option value="SYSTEM">System Alert</option>
                    <option value="OFFER">Offer / Promotion</option>
                    <option value="REMINDER">Reminder</option>
                    <option value="MESSAGE">General Message</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
                  <input
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g., Weekend Special Offer!"
                    maxLength={100}
                    className="w-full rounded-lg border border-gray-200 px-3 py-2.5 text-sm focus:border-orange-400 focus:ring-1 focus:ring-orange-400 focus:outline-none"
                  />
                  <p className="text-[11px] text-gray-400 mt-1">{title.length}/100</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Message</label>
                  <textarea
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    rows={4}
                    placeholder="Write your notification message here..."
                    maxLength={500}
                    className="w-full rounded-lg border border-gray-200 px-3 py-2.5 text-sm focus:border-orange-400 focus:ring-1 focus:ring-orange-400 focus:outline-none resize-none"
                  />
                  <p className="text-[11px] text-gray-400 mt-1">{message.length}/500</p>
                </div>
              </div>
            </div>
          </div>

          {/* Preview sidebar */}
          <div className="space-y-4">
            {/* Preview card */}
            <div className="bg-white rounded-xl border p-6 sticky top-24">
              <h3 className="text-sm font-semibold text-gray-900 mb-4">Preview & Send</h3>

              {/* Phone preview */}
              <div className="bg-gray-900 rounded-2xl p-4 mb-4">
                <div className="bg-gray-800 rounded-xl p-3">
                  <div className="flex items-start gap-2.5">
                    <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center flex-shrink-0">
                      <Bell className="h-4 w-4 text-white" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className="text-xs font-semibold text-white truncate">
                          {title || "Notification Title"}
                        </p>
                        <span className="text-[9px] text-gray-400 ml-2">now</span>
                      </div>
                      <p className="text-[11px] text-gray-300 mt-0.5 line-clamp-3">
                        {message || "Your notification message will appear here..."}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Summary */}
              <div className="space-y-3 mb-6">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Audience</span>
                  <span className="font-medium text-gray-900 capitalize">{audience}</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Mode</span>
                  <span className="font-medium text-gray-900 capitalize">
                    {recipientMode === "all" ? "Broadcast" : "Targeted"}
                  </span>
                </div>
                {audience === "vendors" && recipientMode === "all" && selectedServiceTypes.length > 0 && (
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Categories</span>
                    <span className="font-medium text-gray-900">
                      {selectedServiceTypes.join(", ")}
                    </span>
                  </div>
                )}
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Recipients</span>
                  <span className="font-medium text-orange-600">
                    ~{previewCount ?? "..."} {recipientMode === "all" ? "" : "selected"}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Type</span>
                  <Badge variant={typeColors[notifType] || "info"}>{notifType}</Badge>
                </div>
              </div>

              <button
                onClick={handleSend}
                disabled={sending || !title.trim() || !message.trim()}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-amber-500 via-orange-500 to-rose-500 text-white rounded-xl text-sm font-semibold shadow-lg shadow-orange-500/25 hover:from-amber-600 hover:via-orange-600 hover:to-rose-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {sending ? (
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                ) : (
                  <Send className="h-4 w-4" />
                )}
                {sending ? "Sending..." : "Send Notification"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ════════════ HISTORY TAB ════════════ */}
      {tab === "history" && (
        <div className="space-y-4">
          <div className="flex gap-3">
            <select
              value={typeFilter}
              onChange={(e) => {
                setTypeFilter(e.target.value);
                setPage(0);
              }}
              className="rounded-lg border border-gray-200 px-4 py-2 text-sm focus:border-orange-400 focus:ring-1 focus:ring-orange-400 focus:outline-none"
            >
              <option value="">All Types</option>
              <option value="SYSTEM">System</option>
              <option value="ORDER">Order</option>
              <option value="OFFER">Offer</option>
              <option value="REMINDER">Reminder</option>
              <option value="MESSAGE">Message</option>
            </select>
          </div>

          <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
            {isLoading ? (
              <div className="flex items-center justify-center py-20">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-orange-500 border-t-transparent" />
              </div>
            ) : notifications.length === 0 ? (
              <div className="text-center py-20 text-gray-500">
                <Bell className="h-12 w-12 mx-auto mb-3 text-gray-300" />
                <p className="font-medium">No notifications found</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-50">
                {notifications.map((n) => (
                  <div key={n._id} className="p-4 hover:bg-gray-50 flex items-start gap-3">
                    <div
                      className={`h-8 w-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                        n.isRead ? "bg-gray-100" : "bg-orange-100"
                      }`}
                    >
                      <Bell className={`h-4 w-4 ${n.isRead ? "text-gray-400" : "text-orange-500"}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <span className="text-sm font-medium text-gray-900">{n.title}</span>
                        <Badge variant={typeColors[n.type] || "info"}>{n.type}</Badge>
                        {!n.isRead && <span className="h-2 w-2 rounded-full bg-orange-500" />}
                      </div>
                      <p className="text-sm text-gray-600 truncate">{n.message}</p>
                      <div className="flex items-center gap-3 mt-1">
                        <span className="text-xs text-gray-400">
                          To: {n.userId?.fullName || "Unknown"}
                        </span>
                        <span className="text-xs text-gray-400">
                          {new Date(n.createdAt).toLocaleString()}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        </div>
      )}
    </div>
  );
}
