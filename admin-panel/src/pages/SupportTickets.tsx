import { useState, useEffect, useCallback, useRef } from "react";
import {
  Search,
  MessageSquare,
  Eye,
  Clock,
  AlertCircle,
  CheckCircle,
  XCircle,
  Send,
  ArrowLeft,
  User,
  Car,
} from "lucide-react";
import toast from "react-hot-toast";
import { StatsCard, Pagination } from "../components";
import {
  supportService,
  type SupportTicket,
  type SupportTicketStats,
} from "../services/support.service";

const statusColors: Record<string, string> = {
  OPEN: "bg-red-100 text-red-700",
  IN_PROGRESS: "bg-yellow-100 text-yellow-700",
  RESOLVED: "bg-green-100 text-green-700",
  CLOSED: "bg-gray-100 text-gray-600",
};

const priorityColors: Record<string, string> = {
  HIGH: "bg-red-100 text-red-700",
  MEDIUM: "bg-orange-100 text-orange-700",
  LOW: "bg-blue-100 text-blue-700",
};

const categoryLabels: Record<string, string> = {
  BOOKING: "Booking",
  PAYMENT: "Payment",
  DRIVER: "Driver",
  SERVICE: "Service",
  APP: "App",
  OTHER: "Other",
};

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function timeAgo(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

// ==================== TICKET DETAIL / CHAT VIEW ====================

function TicketDetail({
  ticketId,
  onBack,
}: {
  ticketId: string;
  onBack: () => void;
}) {
  const [ticket, setTicket] = useState<SupportTicket | null>(null);
  const [loading, setLoading] = useState(true);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);
  const [statusLoading, setStatusLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const fetchTicket = useCallback(async () => {
    try {
      const res = await supportService.getById(ticketId);
      setTicket(res.data?.ticket || null);
    } catch {
      toast.error("Failed to load ticket");
    } finally {
      setLoading(false);
    }
  }, [ticketId]);

  useEffect(() => {
    fetchTicket();
  }, [fetchTicket]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [ticket?.messages]);

  const handleSendReply = async () => {
    if (!reply.trim()) return;
    setSending(true);
    try {
      const res = await supportService.reply(ticketId, reply.trim());
      setTicket(res.data?.ticket || ticket);
      setReply("");
      toast.success("Reply sent");
    } catch {
      toast.error("Failed to send reply");
    } finally {
      setSending(false);
    }
  };

  const handleStatusChange = async (status: string) => {
    setStatusLoading(true);
    try {
      const res = await supportService.updateStatus(ticketId, status);
      setTicket(res.data?.ticket || ticket);
      toast.success(`Ticket ${status.toLowerCase().replace("_", " ")}`);
    } catch {
      toast.error("Failed to update status");
    } finally {
      setStatusLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
      </div>
    );
  }

  if (!ticket) {
    return (
      <div className="text-center py-20 text-gray-500">Ticket not found</div>
    );
  }

  const requester = ticket.driverId || ticket.userId;
  const requesterType = ticket.driverId ? "Driver" : "Customer";

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          onClick={onBack}
          className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700"
        >
          <ArrowLeft className="h-4 w-4" />
          Back
        </button>
        <h2 className="text-lg font-semibold text-gray-900 flex-1">
          {ticket.subject}
        </h2>
        <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${statusColors[ticket.status]}`}>
          {ticket.status.replace("_", " ")}
        </span>
        <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${priorityColors[ticket.priority]}`}>
          {ticket.priority}
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Chat area */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-gray-200 flex flex-col" style={{ height: "calc(100vh - 260px)" }}>
          {/* Messages */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {/* Initial ticket message */}
            <div className="flex gap-3">
              <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0">
                {ticket.driverId ? (
                  <Car className="h-4 w-4 text-blue-600" />
                ) : (
                  <User className="h-4 w-4 text-blue-600" />
                )}
              </div>
              <div className="flex-1">
                <div className="flex items-baseline gap-2">
                  <span className="text-sm font-medium text-gray-900">
                    {requester?.fullName || "Unknown"}
                  </span>
                  <span className="text-xs text-gray-400">
                    {formatDate(ticket.createdAt)}
                  </span>
                </div>
                <div className="mt-1 bg-gray-50 rounded-lg p-3 text-sm text-gray-700">
                  {ticket.description}
                </div>
              </div>
            </div>

            {/* Thread messages */}
            {ticket.messages.map((msg, idx) => {
              const isAdmin = msg.senderType === "ADMIN";
              return (
                <div
                  key={msg._id || idx}
                  className={`flex gap-3 ${isAdmin ? "flex-row-reverse" : ""}`}
                >
                  <div
                    className={`h-8 w-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                      isAdmin
                        ? "bg-green-100"
                        : msg.senderType === "DRIVER"
                          ? "bg-blue-100"
                          : "bg-purple-100"
                    }`}
                  >
                    {isAdmin ? (
                      <span className="text-xs font-bold text-green-700">A</span>
                    ) : msg.senderType === "DRIVER" ? (
                      <Car className="h-4 w-4 text-blue-600" />
                    ) : (
                      <User className="h-4 w-4 text-purple-600" />
                    )}
                  </div>
                  <div className={`flex-1 ${isAdmin ? "text-right" : ""}`}>
                    <div
                      className={`flex items-baseline gap-2 ${isAdmin ? "justify-end" : ""}`}
                    >
                      <span className="text-sm font-medium text-gray-900">
                        {isAdmin ? "Admin" : requester?.fullName || "User"}
                      </span>
                      <span className="text-xs text-gray-400">
                        {formatDate(msg.createdAt)}
                      </span>
                    </div>
                    <div
                      className={`mt-1 inline-block rounded-lg p-3 text-sm max-w-[85%] ${
                        isAdmin
                          ? "bg-blue-50 text-blue-900"
                          : "bg-gray-50 text-gray-700"
                      }`}
                    >
                      {msg.message}
                    </div>
                  </div>
                </div>
              );
            })}
            <div ref={messagesEndRef} />
          </div>

          {/* Reply input */}
          {ticket.status !== "CLOSED" && (
            <div className="border-t border-gray-200 p-3">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={reply}
                  onChange={(e) => setReply(e.target.value)}
                  onKeyDown={(e) =>
                    e.key === "Enter" && !e.shiftKey && handleSendReply()
                  }
                  placeholder="Type your reply..."
                  className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <button
                  onClick={handleSendReply}
                  disabled={sending || !reply.trim()}
                  className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Send className="h-4 w-4" />
                  {sending ? "Sending..." : "Send"}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar info */}
        <div className="space-y-4">
          {/* Requester info */}
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">
              {requesterType} Info
            </h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">Name</span>
                <span className="font-medium">{requester?.fullName || "N/A"}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Phone</span>
                <span className="font-medium">
                  {requester?.mobileNumber || "N/A"}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Email</span>
                <span className="font-medium text-xs">
                  {requester?.email || "N/A"}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Type</span>
                <span className="font-medium">{requesterType}</span>
              </div>
            </div>
          </div>

          {/* Ticket details */}
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">
              Ticket Details
            </h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">Category</span>
                <span className="font-medium">
                  {categoryLabels[ticket.category]}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Created</span>
                <span className="font-medium">{formatDate(ticket.createdAt)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Assigned To</span>
                <span className="font-medium">
                  {ticket.assignedTo?.name || "Unassigned"}
                </span>
              </div>
              {ticket.resolvedAt && (
                <div className="flex justify-between">
                  <span className="text-gray-500">Resolved</span>
                  <span className="font-medium">
                    {formatDate(ticket.resolvedAt)}
                  </span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-gray-500">Messages</span>
                <span className="font-medium">{ticket.messages.length + 1}</span>
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">
              Actions
            </h3>
            <div className="space-y-2">
              {ticket.status !== "IN_PROGRESS" &&
                ticket.status !== "RESOLVED" &&
                ticket.status !== "CLOSED" && (
                  <button
                    onClick={() => handleStatusChange("IN_PROGRESS")}
                    disabled={statusLoading}
                    className="w-full rounded-lg bg-yellow-50 px-3 py-2 text-sm font-medium text-yellow-700 hover:bg-yellow-100 disabled:opacity-50"
                  >
                    Mark In Progress
                  </button>
                )}
              {ticket.status !== "RESOLVED" && ticket.status !== "CLOSED" && (
                <button
                  onClick={() => handleStatusChange("RESOLVED")}
                  disabled={statusLoading}
                  className="w-full rounded-lg bg-green-50 px-3 py-2 text-sm font-medium text-green-700 hover:bg-green-100 disabled:opacity-50"
                >
                  Mark Resolved
                </button>
              )}
              {ticket.status !== "CLOSED" && (
                <button
                  onClick={() => handleStatusChange("CLOSED")}
                  disabled={statusLoading}
                  className="w-full rounded-lg bg-gray-50 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100 disabled:opacity-50"
                >
                  Close Ticket
                </button>
              )}
              {ticket.status === "CLOSED" && (
                <button
                  onClick={() => handleStatusChange("OPEN")}
                  disabled={statusLoading}
                  className="w-full rounded-lg bg-blue-50 px-3 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100 disabled:opacity-50"
                >
                  Reopen Ticket
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==================== MAIN PAGE ====================

export default function SupportTickets() {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [priorityFilter, setPriorityFilter] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);
  const [stats, setStats] = useState<SupportTicketStats>({
    total: 0,
    open: 0,
    inProgress: 0,
    resolved: 0,
    closed: 0,
    highPriority: 0,
  });
  const limit = 15;

  const fetchTickets = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await supportService.getAll({
        page: page + 1,
        limit,
        search: search || undefined,
        status: statusFilter || undefined,
        priority: priorityFilter || undefined,
        category: categoryFilter || undefined,
      });
      const data = res.data;
      setTickets(data?.tickets || []);
      setTotal(data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to fetch tickets");
    } finally {
      setIsLoading(false);
    }
  }, [page, search, statusFilter, priorityFilter, categoryFilter]);

  const fetchStats = async () => {
    try {
      const res = await supportService.getStats();
      if (res.data) setStats(res.data);
    } catch {
      /* ignore */
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  useEffect(() => {
    fetchTickets();
  }, [fetchTickets]);

  // If viewing a specific ticket
  if (selectedTicketId) {
    return (
      <TicketDetail
        ticketId={selectedTicketId}
        onBack={() => {
          setSelectedTicketId(null);
          fetchTickets();
          fetchStats();
        }}
      />
    );
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Support Tickets</h1>
        <p className="text-sm text-gray-500 mt-1">
          Manage customer and driver support requests
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        <StatsCard
          title="Total"
          value={stats.total}
          icon={MessageSquare}
          color="blue"
        />
        <StatsCard
          title="Open"
          value={stats.open}
          icon={AlertCircle}
          color="red"
        />
        <StatsCard
          title="In Progress"
          value={stats.inProgress}
          icon={Clock}
          color="orange"
        />
        <StatsCard
          title="Resolved"
          value={stats.resolved}
          icon={CheckCircle}
          color="green"
        />
        <StatsCard
          title="Closed"
          value={stats.closed}
          icon={XCircle}
          color="indigo"
        />
        <StatsCard
          title="High Priority"
          value={stats.highPriority}
          icon={AlertCircle}
          color="red"
        />
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by subject..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(0);
              }}
              className="w-full rounded-lg border border-gray-300 pl-9 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(0);
            }}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">All Status</option>
            <option value="OPEN">Open</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="RESOLVED">Resolved</option>
            <option value="CLOSED">Closed</option>
          </select>
          <select
            value={priorityFilter}
            onChange={(e) => {
              setPriorityFilter(e.target.value);
              setPage(0);
            }}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">All Priority</option>
            <option value="HIGH">High</option>
            <option value="MEDIUM">Medium</option>
            <option value="LOW">Low</option>
          </select>
          <select
            value={categoryFilter}
            onChange={(e) => {
              setCategoryFilter(e.target.value);
              setPage(0);
            }}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">All Categories</option>
            <option value="BOOKING">Booking</option>
            <option value="PAYMENT">Payment</option>
            <option value="DRIVER">Driver</option>
            <option value="SERVICE">Service</option>
            <option value="APP">App</option>
            <option value="OTHER">Other</option>
          </select>
        </div>
      </div>

      {/* Ticket List */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
          </div>
        ) : tickets.length === 0 ? (
          <div className="text-center py-20 text-gray-500">
            <MessageSquare className="h-12 w-12 mx-auto mb-3 text-gray-300" />
            <p className="font-medium">No support tickets found</p>
            <p className="text-sm mt-1">Tickets from drivers and customers will appear here</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/50">
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Subject
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    From
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Category
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Priority
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Status
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Assigned
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-500">
                    Created
                  </th>
                  <th className="text-right py-3 px-4 font-medium text-gray-500">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                {tickets.map((ticket) => {
                  const requester = ticket.driverId || ticket.userId;
                  const isDriver = !!ticket.driverId;
                  return (
                    <tr
                      key={ticket._id}
                      className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                      onClick={() => setSelectedTicketId(ticket._id)}
                    >
                      <td className="py-3 px-4">
                        <div className="font-medium text-gray-900 max-w-[200px] truncate">
                          {ticket.subject}
                        </div>
                        <div className="text-xs text-gray-400 mt-0.5 max-w-[200px] truncate">
                          {ticket.description}
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div
                            className={`h-6 w-6 rounded-full flex items-center justify-center ${
                              isDriver ? "bg-blue-100" : "bg-purple-100"
                            }`}
                          >
                            {isDriver ? (
                              <Car className="h-3 w-3 text-blue-600" />
                            ) : (
                              <User className="h-3 w-3 text-purple-600" />
                            )}
                          </div>
                          <div>
                            <div className="font-medium text-gray-900 text-xs">
                              {requester?.fullName || "Unknown"}
                            </div>
                            <div className="text-xs text-gray-400">
                              {isDriver ? "Driver" : "Customer"}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <span className="text-xs text-gray-600">
                          {categoryLabels[ticket.category]}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <span
                          className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${priorityColors[ticket.priority]}`}
                        >
                          {ticket.priority}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <span
                          className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${statusColors[ticket.status]}`}
                        >
                          {ticket.status.replace("_", " ")}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-xs text-gray-600">
                        {ticket.assignedTo?.name || (
                          <span className="text-gray-400">Unassigned</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-xs text-gray-500">
                        {timeAgo(ticket.createdAt)}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedTicketId(ticket._id);
                          }}
                          className="inline-flex items-center gap-1 rounded-lg bg-blue-50 px-2.5 py-1.5 text-xs font-medium text-blue-600 hover:bg-blue-100"
                        >
                          <Eye className="h-3.5 w-3.5" />
                          View
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {total > limit && (
          <Pagination
            page={page}
            limit={limit}
            total={total}
            onPageChange={setPage}
          />
        )}
      </div>
    </div>
  );
}
