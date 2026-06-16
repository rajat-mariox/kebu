import { useState, useEffect, useCallback } from "react";
import { Wallet, ArrowUpCircle, ArrowDownCircle, IndianRupee } from "lucide-react";
import toast from "react-hot-toast";
import { Badge, Pagination, StatsCard } from "../components";
import api from "../services/api";

interface Transaction {
  _id: string;
  userId: { _id: string; fullName: string; mobileNumber: string; email?: string };
  amount: number;
  type: "CREDIT" | "DEBIT";
  description: string;
  balanceBefore: number;
  balanceAfter: number;
  status: string;
  createdAt: string;
}

interface WalletStats {
  totalWallets: number;
  totalBalance: number;
  totalCredits: number;
  totalDebits: number;
}

export default function WalletTransactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [stats, setStats] = useState<WalletStats>({ totalWallets: 0, totalBalance: 0, totalCredits: 0, totalDebits: 0 });
  const limit = 20;

  const fetchTransactions = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get("/admin/wallet/transactions", {
        params: { page, limit, type: typeFilter || undefined },
      });
      const data = res.data?.data;
      setTransactions(data?.transactions || []);
      setTotal(data?.pagination?.total || 0);
    } catch {
      toast.error("Failed to load transactions");
    } finally {
      setIsLoading(false);
    }
  }, [page, typeFilter]);

  const fetchStats = async () => {
    try {
      const res = await api.get("/admin/wallet/stats");
      if (res.data?.data) setStats(res.data.data);
    } catch { /* ignore */ }
  };

  useEffect(() => { fetchStats(); }, []);
  useEffect(() => { fetchTransactions(); }, [fetchTransactions]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Wallet & Transactions</h1>
        <p className="mt-1 text-sm text-gray-500">View wallet balances and transaction history</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatsCard title="Total Wallets" value={stats.totalWallets} icon={Wallet} color="blue" />
        <StatsCard title="Total Balance" value={`₹${stats.totalBalance.toLocaleString()}`} icon={IndianRupee} color="green" />
        <StatsCard title="Total Credits" value={`₹${stats.totalCredits.toLocaleString()}`} icon={ArrowUpCircle} color="purple" />
        <StatsCard title="Total Debits" value={`₹${stats.totalDebits.toLocaleString()}`} icon={ArrowDownCircle} color="red" />
      </div>

      <div className="flex gap-3">
        <select
          value={typeFilter}
          onChange={(e) => { setTypeFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
        >
          <option value="">All Types</option>
          <option value="CREDIT">Credit</option>
          <option value="DEBIT">Debit</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
          </div>
        ) : transactions.length === 0 ? (
          <div className="text-center py-20 text-gray-500">
            <Wallet className="h-12 w-12 mx-auto mb-3 text-gray-300" />
            <p className="font-medium">No transactions found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50/50">
                <th className="text-left py-3 px-4 font-medium text-gray-500">User</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Type</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Amount</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Description</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Balance Before</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Balance After</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Status</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Date</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((tx) => (
                <tr key={tx._id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="py-3 px-4">
                    <p className="font-medium text-gray-900">{tx.userId?.fullName || "N/A"}</p>
                    <p className="text-xs text-gray-500">{tx.userId?.mobileNumber}</p>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1">
                      {tx.type === "CREDIT" ? (
                        <ArrowUpCircle className="h-4 w-4 text-green-500" />
                      ) : (
                        <ArrowDownCircle className="h-4 w-4 text-red-500" />
                      )}
                      <span className={`text-xs font-medium ${tx.type === "CREDIT" ? "text-green-600" : "text-red-600"}`}>
                        {tx.type}
                      </span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <span className={`font-medium ${tx.type === "CREDIT" ? "text-green-600" : "text-red-600"}`}>
                      {tx.type === "CREDIT" ? "+" : "-"}₹{tx.amount}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-xs text-gray-600 max-w-[200px] truncate">{tx.description || "-"}</td>
                  <td className="py-3 px-4 text-sm text-gray-600">₹{tx.balanceBefore}</td>
                  <td className="py-3 px-4 text-sm text-gray-600">₹{tx.balanceAfter}</td>
                  <td className="py-3 px-4">
                    <Badge variant={tx.status === "COMPLETED" ? "success" : tx.status === "FAILED" ? "danger" : "warning"}>
                      {tx.status}
                    </Badge>
                  </td>
                  <td className="py-3 px-4 text-xs text-gray-500">{new Date(tx.createdAt).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
      </div>
    </div>
  );
}
