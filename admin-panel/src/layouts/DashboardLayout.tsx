import { useState, useEffect } from "react";
import { Outlet, NavLink, useNavigate, useLocation } from "react-router-dom";
import { Toaster } from "react-hot-toast";
import { useAuth } from "../hooks/useAuth";
import GlobalSearch from "../components/GlobalSearch";
import AlertStrip from "../components/AlertStrip";
import appIcon from "../assets/app_icon.png";
import {
  LayoutDashboard,
  Users,
  Car,
  MapPin,
  Truck,
  Home,
  FileText,
  ShieldCheck,
  Settings,
  LogOut,
  Menu,
  X,
  ChevronDown,
  Bell,
  MessageSquare,
  Crown,
  Wallet,
  TrendingUp,
  Radio,
  ClipboardList,
  Zap,
  Gift,
} from "lucide-react";

interface NavItem {
  name: string;
  href: string;
  icon: React.ElementType;
  children?: { name: string; href: string }[];
}

interface NavGroup {
  label: string;
  items: NavItem[];
}

const navigationGroups: NavGroup[] = [
  {
    label: "Command",
    items: [
      { name: "Dashboard", href: "/", icon: LayoutDashboard },
      { name: "Finance & Insights", href: "/finance", icon: TrendingUp },
    ],
  },
  {
    label: "Operations",
    items: [
      {
        name: "Bookings",
        href: "/bookings",
        icon: MapPin,
        children: [
          { name: "Ride Bookings", href: "/ride-bookings" },
          { name: "Delivery Orders", href: "/delivery-bookings" },
        ],
      },
      {
        name: "Service Config",
        href: "/service-config",
        icon: Radio,
        children: [
          { name: "Cab Management", href: "/cab-management" },
          { name: "Delivery Management", href: "/delivery-management" },
          { name: "Household Management", href: "/household-management" },
          { name: "Commission & Payouts", href: "/commission-payouts" },
        ],
      },
      { name: "Vehicles", href: "/vehicles", icon: Truck },
      { name: "Support Tickets", href: "/support-tickets", icon: MessageSquare },
    ],
  },
  {
    label: "Stakeholders",
    items: [
      { name: "Users", href: "/users", icon: Users },
      { name: "Vendors", href: "/drivers", icon: Car },
      {
        name: "Household Services",
        href: "/household",
        icon: Home,
        children: [
          { name: "Services & Categories", href: "/household/services" },
          { name: "Bookings", href: "/household/bookings" },
        ],
      },
    ],
  },
  {
    label: "Growth",
    items: [
      { name: "Subscriptions", href: "/subscriptions", icon: Crown },
      { name: "Notifications", href: "/notifications", icon: Bell },
      { name: "Coupons & FAQ", href: "/faqs", icon: Gift },
      { name: "Offers & Promos", href: "/offers", icon: Gift },
      { name: "Scratch Cards", href: "/scratch-cards", icon: Gift },
    ],
  },
  {
    label: "Control",
    items: [
      { name: "Admin Management", href: "/admins", icon: ShieldCheck },
      { name: "Audit Logs", href: "/audit-logs", icon: ClipboardList },
      { name: "Automation Rules", href: "/automation", icon: Zap },
      { name: "CMS", href: "/cms", icon: FileText },
      { name: "Wallet & Transactions", href: "/wallet", icon: Wallet },
      { name: "Settings", href: "/settings", icon: Settings },
    ],
  },
];

export default function DashboardLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [expandedMenus, setExpandedMenus] = useState<string[]>([
    "Bookings",
    "Household Services",
    "Service Config",
  ]);
  const { admin, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  // Auto-logout after inactivity (configurable, default 30 min)
  useEffect(() => {
    let timeout: ReturnType<typeof setTimeout>;
    const INACTIVITY_TIMEOUT = 30 * 60 * 1000;

    const resetTimer = () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        logout();
        navigate("/login");
      }, INACTIVITY_TIMEOUT);
    };

    const events = ["mousedown", "keydown", "scroll", "mousemove", "touchstart"];
    events.forEach((e) => window.addEventListener(e, resetTimer));
    resetTimer();

    return () => {
      clearTimeout(timeout);
      events.forEach((e) => window.removeEventListener(e, resetTimer));
    };
  }, [logout, navigate]);

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  const toggleMenu = (name: string) => {
    setExpandedMenus((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name],
    );
  };

  const isChildActive = (item: NavItem) => {
    return item.children?.some((child) => location.pathname === child.href);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 3000,
          style: { borderRadius: "12px", padding: "12px 16px" },
        }}
      />

      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-[260px] bg-gray-950 transform transition-transform duration-300 ease-in-out lg:translate-x-0 ${
          sidebarOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {/* Logo */}
        <div className="flex h-16 items-center gap-3 px-6 border-b border-gray-800/60">
          <img src={appIcon} alt="Kebu" className="h-9 w-9 rounded-xl shadow-lg shadow-orange-500/20" />
          <div>
            <h1 className="text-base font-bold bg-gradient-to-r from-amber-400 to-orange-400 bg-clip-text text-transparent tracking-tight">
              Kebu Admin
            </h1>
            <p className="text-[10px] text-gray-500 -mt-0.5">
              Management Portal
            </p>
          </div>
          <button
            className="ml-auto lg:hidden text-gray-400 hover:text-white"
            onClick={() => setSidebarOpen(false)}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Navigation - grouped */}
        <nav className="mt-2 px-3 space-y-4 overflow-y-auto h-[calc(100vh-4rem)] pb-8">
          {navigationGroups.map((group) => (
            <div key={group.label}>
              <p className="px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-gray-600">
                {group.label}
              </p>
              <div className="space-y-0.5">
                {group.items.map((item) => (
                  <div key={item.name}>
                    {item.children ? (
                      <div>
                        <button
                          onClick={() => toggleMenu(item.name)}
                          className={`w-full group flex items-center justify-between px-3 py-2 text-[13px] font-medium rounded-lg transition-all duration-200 ${
                            isChildActive(item)
                              ? "bg-orange-500/10 text-orange-300"
                              : "text-gray-400 hover:bg-gray-800/60 hover:text-gray-200"
                          }`}
                        >
                          <div className="flex items-center gap-3">
                            <item.icon className="h-[18px] w-[18px]" />
                            {item.name}
                          </div>
                          <ChevronDown
                            className={`h-4 w-4 transition-transform ${
                              expandedMenus.includes(item.name)
                                ? "rotate-180"
                                : ""
                            }`}
                          />
                        </button>
                        {expandedMenus.includes(item.name) && (
                          <div className="ml-9 mt-1 space-y-0.5 border-l border-gray-800 pl-0">
                            {item.children.map((child) => (
                              <NavLink
                                key={child.href}
                                to={child.href}
                                className={({ isActive }) =>
                                  `block px-3 py-2 text-[13px] rounded-lg transition-all duration-200 ${
                                    isActive
                                      ? "bg-gradient-to-r from-orange-500/15 to-rose-500/10 text-orange-300 font-medium border-l-2 border-orange-400 -ml-[1px]"
                                      : "text-gray-500 hover:text-gray-300 hover:bg-gray-800/30"
                                  }`
                                }
                              >
                                {child.name}
                              </NavLink>
                            ))}
                          </div>
                        )}
                      </div>
                    ) : (
                      <NavLink
                        to={item.href}
                        end={item.href === "/"}
                        className={({ isActive }) =>
                          `group flex items-center gap-3 px-3 py-2 text-[13px] font-medium rounded-lg transition-all duration-200 ${
                            isActive
                              ? "bg-gradient-to-r from-orange-500/15 to-rose-500/10 text-orange-300"
                              : "text-gray-400 hover:bg-gray-800/60 hover:text-gray-200"
                          }`
                        }
                      >
                        <item.icon className="h-[18px] w-[18px]" />
                        {item.name}
                      </NavLink>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </nav>
      </aside>

      {/* Main content */}
      <div className="lg:pl-[260px]">
        {/* Alert Strip */}
        <AlertStrip />

        {/* Top header */}
        <header className="sticky top-0 z-40 flex h-16 items-center gap-x-4 border-b border-gray-100 bg-white/90 backdrop-blur-xl px-4 sm:px-6 lg:px-8">
          <button
            type="button"
            className="lg:hidden -m-2.5 p-2.5 text-gray-500 hover:text-gray-900"
            onClick={() => setSidebarOpen(true)}
          >
            <Menu className="h-5 w-5" />
          </button>

          {/* Global Search */}
          <GlobalSearch />

          <div className="flex-1" />

          <div className="flex items-center gap-x-4">
            <button className="relative rounded-lg p-2 text-gray-400 hover:bg-orange-50 hover:text-orange-600 transition-colors">
              <Bell className="h-5 w-5" />
              <span className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-orange-500 ring-2 ring-white" />
            </button>

            <div className="h-6 w-px bg-gray-200" />

            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white text-sm font-semibold shadow-sm shadow-orange-500/25">
                {admin?.name?.charAt(0).toUpperCase() || "A"}
              </div>
              <div className="hidden sm:block">
                <p className="text-sm font-medium text-gray-900">
                  {admin?.name || "Admin"}
                </p>
                <p className="text-xs text-gray-400">
                  {typeof admin?.role === "string"
                    ? admin.role.replace("_", " ")
                    : "Admin"}
                </p>
              </div>
            </div>

            {admin?.lastLogin && (
              <div className="hidden lg:block text-[10px] text-gray-400 text-right">
                <p>Last login</p>
                <p>
                  {new Date(admin.lastLogin).toLocaleDateString("en-IN", {
                    day: "numeric",
                    month: "short",
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </p>
              </div>
            )}

            <button
              onClick={handleLogout}
              className="flex items-center gap-2 rounded-lg bg-red-50 px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-100 transition-colors"
            >
              <LogOut className="h-4 w-4" />
              <span className="hidden sm:inline">Logout</span>
            </button>
          </div>
        </header>

        {/* Page content */}
        <main className="p-4 sm:p-6 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
