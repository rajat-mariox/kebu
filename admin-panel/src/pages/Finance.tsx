import { useState, useEffect, useCallback } from "react";
import {
  IndianRupee,
  TrendingUp,
  TrendingDown,
  ArrowUpRight,
  Download,
  RefreshCw,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
} from "recharts";
import { financeService } from "../services/finance.service";
import type { FinanceOverview, RevenueTrendItem, VehicleRevenueBreakdown } from "../types";
import toast from "react-hot-toast";

type DateRange = "today" | "7d" | "30d" | "90d" | "custom";

export default function Finance() {
  const [overview, setOverview] = useState<FinanceOverview | null>(null);
  const [trend, setTrend] = useState<RevenueTrendItem[]>([]);
  const [vehicleBreakdown, setVehicleBreakdown] = useState<VehicleRevenueBreakdown[]>([]);
  const [range, setRange] = useState<DateRange>("30d");
  const [customStart, setCustomStart] = useState("");
  const [customEnd, setCustomEnd] = useState("");
  const [loading, setLoading] = useState(true);

  const getParams = useCallback(() => {
    if (range === "custom" && customStart && customEnd) {
      return { startDate: customStart, endDate: customEnd };
    }
    return { range };
  }, [range, customStart, customEnd]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const params = getParams();
      const [overviewRes, trendRes, vehicleRes] = await Promise.all([
        financeService.getOverview(params),
        financeService.getRevenueTrend(params),
        financeService.getVehicleBreakdown(params),
      ]);
      setOverview(overviewRes.data?.data || null);
      setTrend(trendRes.data?.data?.trend || []);
      setVehicleBreakdown(vehicleRes.data?.data?.breakdown || []);
    } catch {
      toast.error("Failed to load finance data");
    }
    setLoading(false);
  }, [getParams]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleExport = async () => {
    try {
      const params = getParams();
      await financeService.exportFinanceData(params);
      toast.success("Finance data exported");
    } catch {
      toast.error("Export failed");
    }
  };

  const formatCurrency = (val: number) => {
    if (val >= 10000000) return `₹${(val / 10000000).toFixed(2)}Cr`;
    if (val >= 100000) return `₹${(val / 100000).toFixed(2)}L`;
    if (val >= 1000) return `₹${(val / 1000).toFixed(1)}K`;
    return `₹${val.toFixed(0)}`;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Finance & Insights</h1>
          <p className="mt-1 text-sm text-gray-500">Revenue, expenses, and financial analytics</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchData}
            className="rounded-lg border border-gray-200 p-2 text-gray-500 hover:bg-gray-50"
          >
            <RefreshCw className="h-4 w-4" />
          </button>
          <button
            onClick={handleExport}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Download className="h-4 w-4" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Date Filter */}
      <div className="flex flex-wrap items-center gap-2">
        {(
          [
            ["today", "Today"],
            ["7d", "7 Days"],
            ["30d", "30 Days"],
            ["90d", "90 Days"],
            ["custom", "Custom"],
          ] as [DateRange, string][]
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setRange(key)}
            className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
              range === key
                ? "bg-blue-600 text-white"
                : "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50"
            }`}
          >
            {label}
          </button>
        ))}
        {range === "custom" && (
          <div className="flex items-center gap-2 ml-2">
            <input
              type="date"
              value={customStart}
              onChange={(e) => setCustomStart(e.target.value)}
              className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
            />
            <span className="text-gray-400">to</span>
            <input
              type="date"
              value={customEnd}
              onChange={(e) => setCustomEnd(e.target.value)}
              className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
            />
          </div>
        )}
      </div>

      {loading ? (
        <div className="flex h-[40vh] items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
        </div>
      ) : (
        <>
          {/* Revenue Metrics */}
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-3 xl:grid-cols-6">
            <MetricCard
              label="Gross Revenue"
              value={formatCurrency(overview?.grossRevenue || 0)}
              icon={<IndianRupee className="h-4 w-4 text-green-600" />}
              bg="bg-green-50"
            />
            <MetricCard
              label="Net Revenue"
              value={formatCurrency(overview?.netRevenue || 0)}
              icon={<TrendingUp className="h-4 w-4 text-blue-600" />}
              bg="bg-blue-50"
            />
            <MetricCard
              label="Refunds"
              value={formatCurrency(overview?.refundTotal || 0)}
              icon={<TrendingDown className="h-4 w-4 text-red-600" />}
              bg="bg-red-50"
              sub={`${overview?.refundRatio || 0}% ratio`}
            />
            <MetricCard
              label="Discounts"
              value={formatCurrency(overview?.totalDiscount || 0)}
              icon={<ArrowUpRight className="h-4 w-4 text-orange-600" />}
              bg="bg-orange-50"
            />
            <MetricCard
              label="Ride Revenue"
              value={formatCurrency(overview?.rideRevenue || 0)}
              icon={<IndianRupee className="h-4 w-4 text-purple-600" />}
              bg="bg-purple-50"
              sub={`${overview?.rideCount || 0} rides`}
            />
            <MetricCard
              label="Delivery Revenue"
              value={formatCurrency(overview?.deliveryRevenue || 0)}
              icon={<IndianRupee className="h-4 w-4 text-indigo-600" />}
              bg="bg-indigo-50"
              sub={`${overview?.deliveryCount || 0} deliveries`}
            />
          </div>

          {/* Charts */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Revenue Trend */}
            <div className="lg:col-span-2 rounded-xl bg-white p-6 shadow-sm border border-gray-100">
              <h3 className="text-base font-semibold text-gray-900 mb-4">Revenue Trend</h3>
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={trend}>
                  <defs>
                    <linearGradient id="finRevGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.15} />
                      <stop offset="95%" stopColor="#3B82F6" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis
                    dataKey="date"
                    tick={{ fontSize: 11 }}
                    tickFormatter={(v) => {
                      const d = new Date(v);
                      return `${d.getDate()}/${d.getMonth() + 1}`;
                    }}
                  />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip contentStyle={{ borderRadius: "8px", border: "1px solid #e5e7eb" }} />
                  <Area
                    type="monotone"
                    dataKey="revenue"
                    stroke="#3B82F6"
                    strokeWidth={2}
                    fill="url(#finRevGrad)"
                    name="Revenue (₹)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* Revenue by Vehicle Type */}
            <div className="rounded-xl bg-white p-6 shadow-sm border border-gray-100">
              <h3 className="text-base font-semibold text-gray-900 mb-4">By Vehicle Type</h3>
              {vehicleBreakdown.length > 0 ? (
                <>
                  <ResponsiveContainer width="100%" height={200}>
                    <BarChart data={vehicleBreakdown} layout="vertical">
                      <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                      <XAxis type="number" tick={{ fontSize: 11 }} />
                      <YAxis
                        type="category"
                        dataKey="_id"
                        tick={{ fontSize: 11 }}
                        width={80}
                      />
                      <Tooltip contentStyle={{ borderRadius: "8px", border: "1px solid #e5e7eb" }} />
                      <Bar dataKey="revenue" fill="#8B5CF6" radius={[0, 4, 4, 0]} name="Revenue (₹)" />
                    </BarChart>
                  </ResponsiveContainer>
                  <div className="mt-4 space-y-2">
                    {vehicleBreakdown.map((item) => (
                      <div key={item._id} className="flex items-center justify-between text-sm">
                        <span className="text-gray-600">{item._id}</span>
                        <div className="text-right">
                          <span className="font-medium text-gray-900">
                            {formatCurrency(item.revenue)}
                          </span>
                          <span className="text-xs text-gray-400 ml-2">
                            ({item.count} trips)
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <div className="flex h-[200px] items-center justify-center text-sm text-gray-400">
                  No data available
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function MetricCard({
  label,
  value,
  icon,
  bg,
  sub,
}: {
  label: string;
  value: string;
  icon: React.ReactNode;
  bg: string;
  sub?: string;
}) {
  return (
    <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100">
      <div className="flex items-center gap-2 mb-2">
        <div className={`rounded-lg p-1.5 ${bg}`}>{icon}</div>
        <span className="text-xs font-medium text-gray-500">{label}</span>
      </div>
      <p className="text-xl font-bold text-gray-900">{value}</p>
      {sub && <p className="text-xs text-gray-400 mt-1">{sub}</p>}
    </div>
  );
}
