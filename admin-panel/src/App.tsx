import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import DashboardLayout from "./layouts/DashboardLayout";
import {
  Dashboard,
  Users,
  Drivers,
  Login,
  HouseholdServices,
  HouseholdBookings,
  RideBookings,
  CMS,
  AdminManagement,
  VehicleManagement,
  Settings,
  SupportTickets,
  DeliveryBookings,
  FAQManagement,
  Subscriptions,
  Notifications,
  WalletTransactions,
  Finance,
  AuditLogs,
  AutomationRules,
  CabManagement,
  DeliveryManagement,
  HouseholdManagement,
  CommissionPayout,
  OffersManagement,
  ScratchCardManagement,
} from "./pages";
import { useAuth } from "./hooks/useAuth";

// Protected Route wrapper
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardLayout />
            </ProtectedRoute>
          }
        >
          {/* Dashboard */}
          <Route index element={<Dashboard />} />

          {/* User Management */}
          <Route path="users" element={<Users />} />

          {/* Driver Management */}
          <Route path="drivers" element={<Drivers />} />

          {/* Ride Bookings */}
          <Route path="ride-bookings" element={<RideBookings />} />

          {/* Vehicle Management */}
          <Route path="vehicles" element={<VehicleManagement />} />

          {/* Household Services */}
          <Route path="household/services" element={<HouseholdServices />} />
          <Route path="household/bookings" element={<HouseholdBookings />} />

          {/* Delivery Bookings */}
          <Route path="delivery-bookings" element={<DeliveryBookings />} />

          {/* Support Tickets */}
          <Route path="support-tickets" element={<SupportTickets />} />

          {/* Subscriptions */}
          <Route path="subscriptions" element={<Subscriptions />} />

          {/* Notifications */}
          <Route path="notifications" element={<Notifications />} />

          {/* FAQ */}
          <Route path="faqs" element={<FAQManagement />} />

          {/* Offers & Promos */}
          <Route path="offers" element={<OffersManagement />} />

          {/* Scratch Cards */}
          <Route path="scratch-cards" element={<ScratchCardManagement />} />

          {/* Wallet & Transactions */}
          <Route path="wallet" element={<WalletTransactions />} />

          {/* CMS */}
          <Route path="cms" element={<CMS />} />

          {/* Admin Management */}
          <Route path="admins" element={<AdminManagement />} />

          {/* Settings */}
          <Route path="settings" element={<Settings />} />

          {/* Finance & Insights */}
          <Route path="finance" element={<Finance />} />

          {/* Audit Logs */}
          <Route path="audit-logs" element={<AuditLogs />} />

          {/* Automation Rules */}
          <Route path="automation" element={<AutomationRules />} />

          {/* Service Management */}
          <Route path="cab-management" element={<CabManagement />} />
          <Route path="delivery-management" element={<DeliveryManagement />} />
          <Route path="household-management" element={<HouseholdManagement />} />
          <Route path="commission-payouts" element={<CommissionPayout />} />

          {/* 404 - Not Found */}
          <Route
            path="*"
            element={
              <div className="flex flex-col items-center justify-center py-20">
                <h1 className="text-6xl font-bold text-gray-300">404</h1>
                <p className="mt-4 text-xl text-gray-500">Page not found</p>
              </div>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
