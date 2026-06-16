import { useState, useEffect, useCallback } from "react";
import {
  ClipboardList,
  Search,
  Download,
  Filter,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { auditService } from "../services/audit.service";
import { Pagination } from "../components";
import type { AuditLog } from "../types";
import toast from "react-hot-toast";

const ACTION_TYPES = [
  "CREATE",
  "UPDATE",
  "DELETE",
  "STATUS_CHANGE",
  "APPROVE",
  "REJECT",
  "SUSPEND",
  "REFUND",
  "LOGIN",
  "LOGOUT",
  "EXPORT",
  "PRICING_EDIT",
  "PASSWORD_RESET",
  "SETTING_CHANGE",
];

const ENTITIES = [
  "User",
  "Driver",
  "Booking",
  "Admin",
  "VehicleType",
  "ServiceCategory",
  "CMS",
  "Setting",
  "Role",
];

const actionColors: Record<string, string> = {
  CREATE: "bg-green-100 text-green-800",
  UPDATE: "bg-blue-100 text-blue-800",
  DELETE: "bg-red-100 text-red-800",
  STATUS_CHANGE: "bg-purple-100 text-purple-800",
  APPROVE: "bg-emerald-100 text-emerald-800",
  REJECT: "bg-orange-100 text-orange-800",
  SUSPEND: "bg-red-100 text-red-800",
  REFUND: "bg-amber-100 text-amber-800",
  LOGIN: "bg-gray-100 text-gray-800",
  LOGOUT: "bg-gray-100 text-gray-600",
  EXPORT: "bg-indigo-100 text-indigo-800",
  PRICING_EDIT: "bg-yellow-100 text-yellow-800",
  PASSWORD_RESET: "bg-pink-100 text-pink-800",
  SETTING_CHANGE: "bg-slate-100 text-slate-800",
};

export default function AuditLogs() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [actionType, setActionType] = useState("");
  const [entity, setEntity] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const limit = 20;

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const res = await auditService.getAuditLogs({
        page,
        limit,
        search: search || undefined,
        actionType: actionType || undefined,
        entity: entity || undefined,
        startDate: startDate || undefined,
        endDate: endDate || undefined,
      });
      const data = res.data?.data;
      setLogs(data?.items || []);
      setTotal(data?.total || 0);
    } catch {
      toast.error("Failed to load audit logs");
    }
    setLoading(false);
  }, [page, search, actionType, entity, startDate, endDate]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  const handleExport = async () => {
    try {
      await auditService.exportAuditLogs({
        actionType: actionType || undefined,
        entity: entity || undefined,
        startDate: startDate || undefined,
        endDate: endDate || undefined,
      });
      toast.success("Audit logs exported");
    } catch {
      toast.error("Export failed");
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Audit Logs</h1>
          <p className="mt-1 text-sm text-gray-500">
            Complete audit trail of all admin actions ({total} total)
          </p>
        </div>
        <button
          onClick={handleExport}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Download className="h-4 w-4" />
          Export
        </button>
      </div>

      {/* Search & Filters */}
      <div className="space-y-3">
        <div className="flex items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by admin name, description, or entity ID..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              className="w-full rounded-lg border border-gray-200 bg-white py-2 pl-10 pr-4 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none"
            />
          </div>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center gap-2 rounded-lg border px-4 py-2 text-sm font-medium transition-colors ${
              showFilters
                ? "bg-blue-50 border-blue-200 text-blue-700"
                : "border-gray-200 text-gray-600 hover:bg-gray-50"
            }`}
          >
            <Filter className="h-4 w-4" />
            Filters
          </button>
        </div>

        {showFilters && (
          <div className="flex flex-wrap gap-3 rounded-lg bg-gray-50 p-4 border border-gray-100">
            <select
              value={actionType}
              onChange={(e) => {
                setActionType(e.target.value);
                setPage(1);
              }}
              className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm"
            >
              <option value="">All Actions</option>
              {ACTION_TYPES.map((t) => (
                <option key={t} value={t}>
                  {t.replace(/_/g, " ")}
                </option>
              ))}
            </select>
            <select
              value={entity}
              onChange={(e) => {
                setEntity(e.target.value);
                setPage(1);
              }}
              className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm"
            >
              <option value="">All Entities</option>
              {ENTITIES.map((e) => (
                <option key={e} value={e}>
                  {e}
                </option>
              ))}
            </select>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm"
              placeholder="Start date"
            />
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm"
              placeholder="End date"
            />
            <button
              onClick={() => {
                setActionType("");
                setEntity("");
                setStartDate("");
                setEndDate("");
                setSearch("");
                setPage(1);
              }}
              className="text-sm text-gray-500 hover:text-gray-700 underline"
            >
              Clear all
            </button>
          </div>
        )}
      </div>

      {/* Logs Table */}
      <div className="rounded-xl bg-white shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex h-60 items-center justify-center">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-blue-600 border-t-transparent" />
          </div>
        ) : logs.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-gray-400">
            <ClipboardList className="h-12 w-12 mb-3" />
            <p className="text-sm">No audit logs found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-100">
              <thead>
                <tr className="bg-gray-50/50">
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Timestamp
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Admin
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Action
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Entity
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Description
                  </th>
                  <th className="px-4 py-3 w-10"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {logs.map((log) => (
                  <>
                    <tr
                      key={log._id}
                      className="hover:bg-gray-50/50 cursor-pointer"
                      onClick={() =>
                        setExpandedId(
                          expandedId === log._id ? null : log._id,
                        )
                      }
                    >
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {new Date(log.createdAt).toLocaleString("en-IN", {
                          day: "2-digit",
                          month: "short",
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </td>
                      <td className="px-4 py-3">
                        <p className="text-sm font-medium text-gray-900">
                          {log.adminName}
                        </p>
                        <p className="text-xs text-gray-400">
                          {log.adminRole}
                        </p>
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex rounded-full px-2 py-0.5 text-[10px] font-medium ${actionColors[log.actionType] || "bg-gray-100 text-gray-700"}`}
                        >
                          {log.actionType.replace(/_/g, " ")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-700">
                        {log.entity}
                        {log.entityId && (
                          <span className="text-xs text-gray-400 ml-1">
                            #{log.entityId.slice(-6)}
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">
                        {log.description}
                      </td>
                      <td className="px-4 py-3">
                        {expandedId === log._id ? (
                          <ChevronUp className="h-4 w-4 text-gray-400" />
                        ) : (
                          <ChevronDown className="h-4 w-4 text-gray-400" />
                        )}
                      </td>
                    </tr>
                    {expandedId === log._id && (
                      <tr key={`${log._id}-detail`}>
                        <td
                          colSpan={6}
                          className="bg-gray-50 px-6 py-4"
                        >
                          <div className="grid grid-cols-2 gap-4 text-sm">
                            {log.comment && (
                              <div className="col-span-2">
                                <span className="font-medium text-gray-700">
                                  Comment:{" "}
                                </span>
                                <span className="text-gray-600">
                                  {log.comment}
                                </span>
                              </div>
                            )}
                            {log.oldValue && (
                              <div>
                                <p className="font-medium text-gray-700 mb-1">
                                  Old Value
                                </p>
                                <pre className="rounded bg-white p-2 text-xs text-gray-600 overflow-auto max-h-32 border">
                                  {JSON.stringify(log.oldValue, null, 2)}
                                </pre>
                              </div>
                            )}
                            {log.newValue && (
                              <div>
                                <p className="font-medium text-gray-700 mb-1">
                                  New Value
                                </p>
                                <pre className="rounded bg-white p-2 text-xs text-gray-600 overflow-auto max-h-32 border">
                                  {JSON.stringify(log.newValue, null, 2)}
                                </pre>
                              </div>
                            )}
                            <div className="col-span-2 flex gap-6 text-xs text-gray-400">
                              {log.ipAddress && (
                                <span>IP: {log.ipAddress}</span>
                              )}
                              {log.userAgent && (
                                <span className="truncate max-w-md">
                                  UA: {log.userAgent}
                                </span>
                              )}
                            </div>
                          </div>
                        </td>
                      </tr>
                    )}
                  </>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {total > limit && (
          <div className="border-t border-gray-100 px-4 py-3">
            <Pagination
              page={page}
              total={total}
              limit={limit}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>
    </div>
  );
}
