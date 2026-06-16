import { useState, useEffect, useCallback } from "react";
import {
  Users,
  Car,
  MapPin,
  IndianRupee,
  AlertTriangle,
  Activity,
  Gauge,
  Radio,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { StatsCard } from "../components";
import { dashboardService, bookingService } from "../services";
import type { DashboardKPIs, TimelineEvent } from "../types";

interface DashboardData {
  users: { total: number; newToday: number };
  drivers: { total: number; active: number; pendingApprovals: number };
  bookings: { total: number; today: number; completedToday: number };
  deliveries: { total: number; today: number };
  services: { total: number; today: number };
  revenue: { today: number; monthly: number };
}

interface RevenueDataPoint {
  _id: string;
  revenue: number;
  bookings: number;
}

interface StatusDataPoint {
  _id: string;
  count: number;
}

interface RecentBooking {
  _id: string;
  userId?: { fullName?: string };
  driverId?: { fullName?: string };
  status: string;
  finalFare?: number;
  fare?: number;
  createdAt: string;
}

const CHART_COLORS = [
  "#F97316",
  "#10B981",
  "#F59E0B",
  "#EF4444",
  "#8B5CF6",
  "#EC4899",
];

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardData | null>(null);
  const [kpis, setKpis] = useState<DashboardKPIs | null>(null);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [revenueData, setRevenueData] = useState<RevenueDataPoint[]>([]);
  const [bookingsByStatus, setBookingsByStatus] = useState<StatusDataPoint[]>(
    [],
  );
  const [recentBookings, setRecentBookings] = useState<RecentBooking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [chartPeriod, setChartPeriod] = useState<"week" | "month">("week");

  const fetchDashboard = useCallback(async () => {
    try {
      const [statsRes, bookingsRes, kpiRes, timelineRes] = await Promise.all([
        dashboardService.getStats(),
        bookingService.getAll({ limit: 5, page: 0 }),
        dashboardService.getKPIs().catch(() => ({ data: null })),
        dashboardService.getEventTimeline(1, 20).catch(() => ({ data: null })),
      ]);
      setStats(statsRes.data);
      const bookings = bookingsRes.data as
        | { bookings?: RecentBooking[]; items?: RecentBooking[] }
        | undefined;
      setRecentBookings(bookings?.bookings || bookings?.items || []);
      if (kpiRes.data) setKpis(kpiRes.data);
      if (timelineRes.data) setTimeline(timelineRes.data?.events || []);
    } catch {
      console.error("Failed to fetch dashboard");
    } finally {
      setIsLoading(false);
    }
  }, []);

  const fetchAnalytics = useCallback(async () => {
    try {
      const [revenueRes, bookingRes] = await Promise.all([
        dashboardService.getRevenueAnalytics(
          chartPeriod === "week" ? "week" : "month",
        ),
        dashboardService.getBookingAnalytics(
          chartPeriod === "week" ? "week" : "month",
        ),
      ]);
      const revData = revenueRes.data as
        | { byDay?: RevenueDataPoint[] }
        | undefined;
      const statData = bookingRes.data as
        | { byStatus?: StatusDataPoint[] }
        | undefined;
      setRevenueData(revData?.byDay || []);
      setBookingsByStatus(statData?.byStatus || []);
    } catch {
      console.error("Failed to fetch analytics");
    }
  }, [chartPeriod]);

  useEffect(() => {
    fetchDashboard();
    // Auto-refresh KPIs every 30s
    const interval = setInterval(async () => {
      try {
        const res = await dashboardService.getKPIs();
        if (res.data) setKpis(res.data);
      } catch {
        // silent
      }
    }, 30000);
    return () => clearInterval(interval);
  }, [fetchDashboard]);

  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  const formatCurrency = (val: number) => {
    if (val >= 100000) return `₹${(val / 100000).toFixed(1)}L`;
    if (val >= 1000) return `₹${(val / 1000).toFixed(1)}K`;
    return `₹${val}`;
  };

  if (isLoading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-orange-500 border-t-transparent" />
          <p className="text-sm text-gray-500">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  const statusColors: Record<string, string> = {
    SEARCHING: "bg-yellow-100 text-yellow-800",
    ASSIGNED: "bg-blue-100 text-blue-800",
    DRIVER_ARRIVED: "bg-indigo-100 text-indigo-800",
    IN_PROGRESS: "bg-purple-100 text-purple-800",
    COMPLETED: "bg-green-100 text-green-800",
    CANCELLED: "bg-red-100 text-red-800",
  };

  const eventTypeColors: Record<string, string> = {
    order_created: "bg-blue-500",
    order_completed: "bg-green-500",
    order_cancelled: "bg-red-500",
    order_update: "bg-purple-500",
    refund_issued: "bg-orange-500",
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Logistics Command Center
        </h1>
        <p className="mt-1 text-sm text-gray-500">
          Real-time operational overview
        </p>
      </div>

      {/* Operational KPI Cards */}
      {kpis && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-center gap-2 mb-2">
              <div className="rounded-lg bg-orange-100 p-1.5">
                <Radio className="h-4 w-4 text-orange-600" />
              </div>
              <span className="text-xs font-medium text-gray-500">
                Live Orders
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {kpis.totalLiveOrders}
            </p>
          </div>

          <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-center gap-2 mb-2">
              <div className="rounded-lg bg-green-100 p-1.5">
                <Car className="h-4 w-4 text-green-600" />
              </div>
              <span className="text-xs font-medium text-gray-500">
                Active Drivers
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {kpis.activeDrivers}
            </p>
            <p className="text-xs text-gray-400 mt-1">
              {kpis.onTripDrivers} on trip · {kpis.idleDrivers} idle
            </p>
          </div>

          <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-center gap-2 mb-2">
              <div
                className={`rounded-lg p-1.5 ${kpis.failureRate > 10 ? "bg-red-100" : "bg-gray-100"}`}
              >
                <AlertTriangle
                  className={`h-4 w-4 ${kpis.failureRate > 10 ? "text-red-600" : "text-gray-600"}`}
                />
              </div>
              <span className="text-xs font-medium text-gray-500">
                Failure Rate
              </span>
            </div>
            <p
              className={`text-2xl font-bold ${kpis.failureRate > 10 ? "text-red-600" : "text-gray-900"}`}
            >
              {kpis.failureRate}%
            </p>
            <p className="text-xs text-gray-400 mt-1">
              {kpis.failedOrders} unassigned
            </p>
          </div>

          <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-center gap-2 mb-2">
              <div className="rounded-lg bg-purple-100 p-1.5">
                <Gauge className="h-4 w-4 text-purple-600" />
              </div>
              <span className="text-xs font-medium text-gray-500">
                Utilization
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {kpis.utilizationRatio}%
            </p>
            <p className="text-xs text-gray-400 mt-1">On Trip vs Idle</p>
          </div>

          <div className="rounded-xl bg-white p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer">
            <div className="flex items-center gap-2 mb-2">
              <div
                className={`rounded-lg p-1.5 ${kpis.activeSOS > 0 ? "bg-red-100" : "bg-gray-100"}`}
              >
                <AlertTriangle
                  className={`h-4 w-4 ${kpis.activeSOS > 0 ? "text-red-600" : "text-gray-600"}`}
                />
              </div>
              <span className="text-xs font-medium text-gray-500">
                Active SOS
              </span>
            </div>
            <p
              className={`text-2xl font-bold ${kpis.activeSOS > 0 ? "text-red-600" : "text-gray-900"}`}
            >
              {kpis.activeSOS}
            </p>
          </div>
        </div>
      )}

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatsCard
          title="Total Users"
          value={stats?.users.total?.toLocaleString() || "0"}
          icon={Users}
          color="blue"
          subtitle={`+${stats?.users.newToday || 0} today`}
        />
        <StatsCard
          title="Active Drivers"
          value={stats?.drivers.active?.toLocaleString() || "0"}
          icon={Car}
          color="green"
          subtitle={`${stats?.drivers.pendingApprovals || 0} pending approvals`}
        />
        <StatsCard
          title="Today's Bookings"
          value={stats?.bookings.today?.toLocaleString() || "0"}
          icon={MapPin}
          color="purple"
          subtitle={`${stats?.bookings.completedToday || 0} completed`}
        />
        <StatsCard
          title="Monthly Revenue"
          value={formatCurrency(stats?.revenue.monthly || 0)}
          icon={IndianRupee}
          color="orange"
          subtitle={`${formatCurrency(stats?.revenue.today || 0)} today`}
        />
      </div>

      {/* Charts + Event Timeline */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Chart */}
        <div className="lg:col-span-2 rounded-xl bg-white p-6 shadow-sm border border-gray-100">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-base font-semibold text-gray-900">
                Revenue & Bookings
              </h3>
              <p className="text-sm text-gray-500">Daily breakdown</p>
            </div>
            <div className="flex gap-1 rounded-lg bg-gray-100 p-1">
              {(["week", "month"] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => setChartPeriod(p)}
                  className={`px-3 py-1 text-xs font-medium rounded-md transition-colors ${
                    chartPeriod === p
                      ? "bg-white text-gray-900 shadow-sm"
                      : "text-gray-500 hover:text-gray-700"
                  }`}
                >
                  {p === "week" ? "7 Days" : "30 Days"}
                </button>
              ))}
            </div>
          </div>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={revenueData}>
              <defs>
                <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#F97316" stopOpacity={0.15} />
                  <stop offset="95%" stopColor="#F97316" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis
                dataKey="_id"
                tick={{ fontSize: 11 }}
                tickFormatter={(v) => {
                  const d = new Date(v);
                  return `${d.getDate()}/${d.getMonth() + 1}`;
                }}
              />
              <YAxis tick={{ fontSize: 11 }} />
              <Tooltip
                contentStyle={{
                  borderRadius: "8px",
                  border: "1px solid #e5e7eb",
                }}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="#F97316"
                strokeWidth={2}
                fill="url(#colorRevenue)"
                name="Revenue"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Event Timeline */}
        <div className="rounded-xl bg-white p-6 shadow-sm border border-gray-100">
          <div className="flex items-center gap-2 mb-4">
            <Activity className="h-4 w-4 text-gray-500" />
            <h3 className="text-base font-semibold text-gray-900">
              Live Events
            </h3>
          </div>
          <div className="space-y-3 max-h-[320px] overflow-y-auto">
            {timeline.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">
                No recent events
              </p>
            ) : (
              timeline.map((event) => (
                <div
                  key={event.id}
                  className="flex items-start gap-3 text-sm"
                >
                  <div
                    className={`mt-1 h-2 w-2 rounded-full flex-shrink-0 ${eventTypeColors[event.type] || "bg-gray-400"}`}
                  />
                  <div className="min-w-0 flex-1">
                    <p className="text-gray-700 truncate">
                      <span className="font-medium">
                        #{event.id?.slice(-6)}
                      </span>{" "}
                      <span
                        className={`inline-flex rounded-full px-1.5 py-0.5 text-[10px] font-medium ${statusColors[event.status] || "bg-gray-100 text-gray-600"}`}
                      >
                        {event.status}
                      </span>
                    </p>
                    <p className="text-xs text-gray-400 truncate">
                      {event.user?.fullName || "Unknown"}{" "}
                      {event.fare ? `· ₹${event.fare}` : ""}
                    </p>
                  </div>
                  <span className="text-[10px] text-gray-400 whitespace-nowrap">
                    {new Date(event.timestamp).toLocaleTimeString("en-IN", {
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Booking Status Pie + Recent Bookings */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="rounded-xl bg-white p-6 shadow-sm border border-gray-100">
          <h3 className="text-base font-semibold text-gray-900 mb-1">
            Booking Status
          </h3>
          <p className="text-sm text-gray-500 mb-4">Distribution overview</p>
          {bookingsByStatus.length > 0 ? (
            <>
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie
                    data={bookingsByStatus}
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={80}
                    paddingAngle={3}
                    dataKey="count"
                    nameKey="_id"
                  >
                    {bookingsByStatus.map((_, i) => (
                      <Cell
                        key={`cell-${i}`}
                        fill={CHART_COLORS[i % CHART_COLORS.length]}
                      />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
              <div className="mt-2 space-y-1.5">
                {bookingsByStatus.map((item, i) => (
                  <div
                    key={item._id}
                    className="flex items-center justify-between text-sm"
                  >
                    <div className="flex items-center gap-2">
                      <div
                        className="h-2.5 w-2.5 rounded-full"
                        style={{
                          backgroundColor:
                            CHART_COLORS[i % CHART_COLORS.length],
                        }}
                      />
                      <span className="text-gray-600">{item._id}</span>
                    </div>
                    <span className="font-medium text-gray-900">
                      {item.count}
                    </span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="flex h-[200px] items-center justify-center text-sm text-gray-400">
              No booking data yet
            </div>
          )}
        </div>

        {/* Recent Bookings Table */}
        <div className="lg:col-span-2 rounded-xl bg-white shadow-sm border border-gray-100">
          <div className="px-6 py-4 border-b border-gray-100">
            <h3 className="text-base font-semibold text-gray-900">
              Recent Bookings
            </h3>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-100">
              <thead>
                <tr className="bg-gray-50/50">
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    ID
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Customer
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Driver
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Fare
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {recentBookings.length === 0 ? (
                  <tr>
                    <td
                      colSpan={6}
                      className="px-6 py-12 text-center text-sm text-gray-400"
                    >
                      No recent bookings
                    </td>
                  </tr>
                ) : (
                  recentBookings.map((b) => (
                    <tr key={b._id} className="hover:bg-gray-50/50">
                      <td className="px-6 py-3 text-sm font-medium text-gray-900">
                        #{b._id?.slice(-6)?.toUpperCase()}
                      </td>
                      <td className="px-6 py-3 text-sm text-gray-700">
                        {b.userId?.fullName || "N/A"}
                      </td>
                      <td className="px-6 py-3 text-sm text-gray-700">
                        {b.driverId?.fullName || "-"}
                      </td>
                      <td className="px-6 py-3">
                        <span
                          className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                            statusColors[b.status] ||
                            "bg-gray-100 text-gray-800"
                          }`}
                        >
                          {b.status}
                        </span>
                      </td>
                      <td className="px-6 py-3 text-sm font-medium text-gray-900">
                        ₹{b.finalFare || b.fare || 0}
                      </td>
                      <td className="px-6 py-3 text-sm text-gray-500">
                        {new Date(b.createdAt).toLocaleDateString()}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
