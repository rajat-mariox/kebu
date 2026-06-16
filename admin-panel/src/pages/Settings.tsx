import { useState, useEffect } from "react";
import {
  Settings as SettingsIcon,
  Save,
  Eye,
  EyeOff,
  Plus,
  Trash2,
  Key,
  Map,
  CreditCard,
  Bell,
  Globe,
} from "lucide-react";
import toast from "react-hot-toast";
import { settingsService } from "../services";
import type { AppSetting } from "../services/settings.service";

const categoryIcons: Record<string, React.ReactNode> = {
  maps: <Map className="h-5 w-5" />,
  payment: <CreditCard className="h-5 w-5" />,
  firebase: <Bell className="h-5 w-5" />,
  sms: <Globe className="h-5 w-5" />,
  general: <Key className="h-5 w-5" />,
};

const categoryLabels: Record<string, string> = {
  maps: "Google Maps",
  payment: "Payment Gateway",
  firebase: "Firebase",
  sms: "SMS Service",
  general: "General",
};

export default function Settings() {
  const [settings, setSettings] = useState<AppSetting[]>([]);
  const [editValues, setEditValues] = useState<Record<string, string>>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [visibleKeys, setVisibleKeys] = useState<Set<string>>(new Set());
  const [showAddForm, setShowAddForm] = useState(false);
  const [newSetting, setNewSetting] = useState({
    key: "",
    label: "",
    category: "general",
    isPublic: false,
    value: "",
  });

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    setIsLoading(true);
    try {
      const res = await settingsService.getSettings();
      const list = res.data?.settings || [];
      setSettings(list);
      const vals: Record<string, string> = {};
      for (const s of list) {
        vals[s.key] = s.value;
      }
      setEditValues(vals);
    } catch {
      toast.error("Failed to load settings");
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      const updates = Object.entries(editValues).map(([key, value]) => ({
        key,
        value,
      }));
      const res = await settingsService.updateSettings(updates);
      const list = res.data?.settings || [];
      setSettings(list);
      toast.success("Settings saved successfully");
    } catch {
      toast.error("Failed to save settings");
    } finally {
      setIsSaving(false);
    }
  };

  const handleAddSetting = async () => {
    if (!newSetting.key || !newSetting.label) {
      toast.error("Key and label are required");
      return;
    }
    try {
      await settingsService.addSetting(newSetting);
      toast.success("Setting added");
      setShowAddForm(false);
      setNewSetting({
        key: "",
        label: "",
        category: "general",
        isPublic: false,
        value: "",
      });
      fetchSettings();
    } catch {
      toast.error("Failed to add setting");
    }
  };

  const handleDelete = async (key: string) => {
    if (!confirm(`Delete setting "${key}"?`)) return;
    try {
      await settingsService.deleteSetting(key);
      toast.success("Setting deleted");
      fetchSettings();
    } catch {
      toast.error("Failed to delete setting");
    }
  };

  const toggleVisibility = (key: string) => {
    setVisibleKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const hasChanges = settings.some((s) => editValues[s.key] !== s.value);

  // Group by category
  const grouped = settings.reduce(
    (acc, s) => {
      const cat = s.category || "general";
      if (!acc[cat]) acc[cat] = [];
      acc[cat].push(s);
      return acc;
    },
    {} as Record<string, AppSetting[]>,
  );

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <SettingsIcon className="h-7 w-7 text-blue-600" />
            App Settings
          </h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage API keys and configuration. Public keys are accessible by
            mobile apps.
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setShowAddForm(!showAddForm)}
            className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            <Plus className="h-4 w-4" />
            Add Key
          </button>
          <button
            onClick={handleSave}
            disabled={isSaving || !hasChanges}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Save className="h-4 w-4" />
            {isSaving ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </div>

      {/* Add Setting Form */}
      {showAddForm && (
        <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
          <h3 className="text-sm font-semibold text-blue-900 mb-3">
            Add New Setting
          </h3>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
            <input
              type="text"
              placeholder="key_name"
              value={newSetting.key}
              onChange={(e) =>
                setNewSetting({
                  ...newSetting,
                  key: e.target.value.toLowerCase().replace(/\s+/g, "_"),
                })
              }
              className="rounded-md border border-gray-300 px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="Display Label"
              value={newSetting.label}
              onChange={(e) =>
                setNewSetting({ ...newSetting, label: e.target.value })
              }
              className="rounded-md border border-gray-300 px-3 py-2 text-sm"
            />
            <select
              value={newSetting.category}
              onChange={(e) =>
                setNewSetting({ ...newSetting, category: e.target.value })
              }
              className="rounded-md border border-gray-300 px-3 py-2 text-sm"
            >
              <option value="general">General</option>
              <option value="maps">Maps</option>
              <option value="payment">Payment</option>
              <option value="firebase">Firebase</option>
              <option value="sms">SMS</option>
            </select>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={newSetting.isPublic}
                onChange={(e) =>
                  setNewSetting({ ...newSetting, isPublic: e.target.checked })
                }
                className="rounded border-gray-300"
              />
              Public (visible to apps)
            </label>
            <div className="flex gap-2">
              <button
                onClick={handleAddSetting}
                className="rounded-md bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
              >
                Add
              </button>
              <button
                onClick={() => setShowAddForm(false)}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Settings grouped by category */}
      {Object.entries(grouped).map(([category, items]) => (
        <div key={category} className="rounded-lg bg-white shadow">
          <div className="flex items-center gap-3 border-b border-gray-200 px-6 py-4">
            <span className="text-blue-600">
              {categoryIcons[category] || categoryIcons.general}
            </span>
            <h2 className="text-lg font-semibold text-gray-900">
              {categoryLabels[category] || category}
            </h2>
            <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-500">
              {items.length} key{items.length !== 1 ? "s" : ""}
            </span>
          </div>
          <div className="divide-y divide-gray-100">
            {items.map((setting) => (
              <div
                key={setting.key}
                className="flex items-center gap-4 px-6 py-4"
              >
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-gray-900">
                      {setting.label}
                    </span>
                    <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs font-mono text-gray-500">
                      {setting.key}
                    </span>
                    {setting.isPublic ? (
                      <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-700">
                        Public
                      </span>
                    ) : (
                      <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs text-red-700">
                        Private
                      </span>
                    )}
                  </div>
                  <div className="mt-2 flex items-center gap-2">
                    <div className="relative flex-1">
                      {setting.key === "sms_audience" ? (
                        <select
                          value={editValues[setting.key] ?? "all"}
                          onChange={(e) =>
                            setEditValues({
                              ...editValues,
                              [setting.key]: e.target.value,
                            })
                          }
                          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                        >
                          <option value="all">All (customers + vendors)</option>
                          <option value="customers">Customers only</option>
                          <option value="vendors">Vendors only</option>
                        </select>
                      ) : setting.key === "sms_otp_template" ? (
                        <textarea
                          value={editValues[setting.key] ?? ""}
                          onChange={(e) =>
                            setEditValues({
                              ...editValues,
                              [setting.key]: e.target.value,
                            })
                          }
                          rows={2}
                          placeholder="Use ##OTP## as the placeholder for the OTP code"
                          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                        />
                      ) : (
                        <>
                          <input
                            type={
                              visibleKeys.has(setting.key) ? "text" : "password"
                            }
                            value={editValues[setting.key] ?? ""}
                            onChange={(e) =>
                              setEditValues({
                                ...editValues,
                                [setting.key]: e.target.value,
                              })
                            }
                            placeholder="Enter value..."
                            className="w-full rounded-md border border-gray-300 px-3 py-2 pr-10 text-sm font-mono focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                          />
                          <button
                            onClick={() => toggleVisibility(setting.key)}
                            className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                          >
                            {visibleKeys.has(setting.key) ? (
                              <EyeOff className="h-4 w-4" />
                            ) : (
                              <Eye className="h-4 w-4" />
                            )}
                          </button>
                        </>
                      )}
                    </div>
                    <button
                      onClick={() => handleDelete(setting.key)}
                      className="rounded-md p-2 text-gray-400 hover:bg-red-50 hover:text-red-500"
                      title="Delete setting"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                  {editValues[setting.key] !== setting.value && (
                    <p className="mt-1 text-xs text-amber-600">Unsaved changes</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      {settings.length === 0 && (
        <div className="rounded-lg bg-white p-12 text-center shadow">
          <Key className="mx-auto h-12 w-12 text-gray-300" />
          <h3 className="mt-4 text-lg font-medium text-gray-900">
            No settings configured
          </h3>
          <p className="mt-2 text-sm text-gray-500">
            Settings will be auto-generated when apps first request them, or
            click "Add Key" to create them manually.
          </p>
        </div>
      )}
    </div>
  );
}
