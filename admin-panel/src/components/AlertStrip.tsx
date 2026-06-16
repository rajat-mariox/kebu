import { useState, useEffect } from "react";
import {
  AlertTriangle,
  X,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { alertService } from "../services/alert.service";
import type { Alert } from "../types";

export default function AlertStrip() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());

  useEffect(() => {
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, []);

  const fetchAlerts = async () => {
    try {
      const res = await alertService.getActiveAlerts();
      setAlerts(res.data?.data?.alerts || []);
    } catch {
      // silent fail
    }
  };

  const handleResolve = async (alertId: string) => {
    try {
      await alertService.resolveAlert(alertId);
      setDismissed((prev) => new Set(prev).add(alertId));
      fetchAlerts();
    } catch {
      // silent
    }
  };

  const visibleAlerts = alerts.filter((a) => !dismissed.has(a._id));

  if (visibleAlerts.length === 0) return null;

  const current = visibleAlerts[currentIndex % visibleAlerts.length];
  if (!current) return null;

  const severityStyles = {
    red: "bg-red-600 text-white",
    amber: "bg-amber-500 text-white",
    info: "bg-blue-500 text-white",
  };

  return (
    <div
      className={`flex items-center gap-3 px-4 py-2 text-sm ${severityStyles[current.severity]}`}
    >
      <AlertTriangle className="h-4 w-4 flex-shrink-0" />

      {visibleAlerts.length > 1 && (
        <button
          onClick={() =>
            setCurrentIndex(
              (i) => (i - 1 + visibleAlerts.length) % visibleAlerts.length,
            )
          }
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
      )}

      <div className="flex-1 min-w-0">
        <span className="font-semibold">{current.title}: </span>
        <span>{current.message}</span>
      </div>

      <span className="rounded-full bg-white/20 px-2 py-0.5 text-xs">
        {currentIndex % visibleAlerts.length + 1}/{visibleAlerts.length}
      </span>

      {visibleAlerts.length > 1 && (
        <button
          onClick={() =>
            setCurrentIndex((i) => (i + 1) % visibleAlerts.length)
          }
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      )}

      <button
        onClick={() => handleResolve(current._id)}
        className="ml-2 rounded-full p-0.5 hover:bg-white/20 transition-colors"
        title="Resolve alert"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}
