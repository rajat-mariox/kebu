// User Types
export interface User {
  _id: string;
  fullName: string;
  email: string;
  mobileNumber: string;
  countryCode: string;
  profileImage?: string;
  gender: "Male" | "Female" | "Other";
  dob?: string;
  isActive: boolean;
  isDeleted: boolean;
  notificationAllowed: boolean;
  referralCode?: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserPopulated {
  _id: string;
  fullName: string;
  mobileNumber: string;
  email?: string;
}

// Driver Types
export interface Driver {
  _id: string;
  fullName: string;
  email: string;
  mobileNumber: string;
  countryCode: string;
  bloodGroup?: string;
  gender: "Male" | "Female" | "Other";
  dob?: string;
  city?: string;
  state?: string;
  status: DriverStatus;
  rejectionReason?: string;
  suspensionReason?: string;
  isActive: boolean;
  isOnline: boolean;
  isDeleted: boolean;
  rating: number;
  totalRides: number;
  createdAt: string;
  updatedAt: string;
}

export type DriverStatus =
  | "draft"
  | "documents_uploaded"
  | "vehicle_added"
  | "under_verification"
  | "approved"
  | "rejected"
  | "suspended";

// Booking Types
export interface BookingUser {
  _id: string;
  fullName: string;
  mobileNumber: string;
}

export interface BookingDriver {
  _id: string;
  fullName: string;
  mobileNumber: string;
  rating?: number;
}

export interface Booking {
  _id: string;
  userId: BookingUser | string;
  driverId?: BookingDriver | string | null;
  vehicleTypeId: VehicleType | string;
  pickup: Location;
  drop: Location;
  distanceKm: number;
  durationMin: number;
  fare: number;
  surgeFare: number;
  discount: number;
  finalFare: number;
  status: BookingStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  cancellationReason?: string;
  cancelledBy?: "USER" | "DRIVER" | "SYSTEM";
  rating?: number;
  feedback?: string;
  tip: number;
  riderName?: string;
  riderPhone?: string;
  promoCode?: string;
  promoDiscount: number;
  scheduledAt?: string;
  assignedAt?: string;
  driverArrivedAt?: string;
  pickedAt?: string;
  completedAt?: string;
  otp?: string;
  createdAt: string;
  updatedAt: string;
}

export type BookingStatus =
  | "SEARCHING"
  | "ASSIGNED"
  | "DRIVER_ARRIVED"
  | "PICKED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

export type PaymentMethod = "CASH" | "WALLET" | "CARD" | "UPI";
export type PaymentStatus = "PENDING" | "PAID" | "FAILED" | "REFUNDED";

export interface Location {
  address: string;
  lat: number;
  lng: number;
}

// Vehicle Types
export interface VehicleType {
  _id: string;
  name: string;
  description?: string;
  image?: string;
  baseFare: number;
  perKmRate: number;
  perMinRate: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface VehicleCategory {
  _id: string;
  name: string;
  description?: string;
  image?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Household Service Types
export interface ServiceCategory {
  _id: string;
  name: string;
  slug?: string;
  description?: string;
  image?: string;
  icon?: string;
  parentId?: string | ServiceCategory | null;
  isActive: boolean;
  order?: number;
  displayOrder?: number;
  createdAt: string;
  updatedAt: string;
}

export interface ServiceDetails {
  _id: string;
  categoryId: ServiceCategory | string;
  name: string;
  description?: string;
  shortDescription?: string;
  image?: string;
  icon?: string;
  basePrice?: number;
  price: number;
  unit?: string;
  duration: number;
  isActive: boolean;
  displayOrder?: number;
  createdAt: string;
  updatedAt: string;
}

export interface ServicePackage {
  _id: string;
  serviceId?: ServiceDetails | string;
  categoryId?: ServiceCategory | string;
  name: string;
  description?: string;
  durationMinutes?: number;
  originalPrice?: number;
  discountedPrice?: number;
  discountPercentage?: number;
  price?: number;
  features?: string[];
  isPopular?: boolean;
  isAvailable?: boolean;
  displayOrder?: number;
  isActive?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ServiceProvider {
  _id: string;
  name: string;
  email: string;
  mobileNumber: string;
  countryCode: string;
  profileImage?: string;
  status: "pending" | "approved" | "rejected" | "suspended";
  rating: number;
  totalServices: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ServiceBooking {
  _id: string;
  userId: User | string;
  providerId?: ServiceProvider | string;
  serviceId: ServiceDetails | string;
  packageId?: ServicePackage | string;
  address: Location;
  scheduledDate: string;
  scheduledTime: string;
  status: ServiceBookingStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  amount: number;
  discount: number;
  finalAmount: number;
  rating?: number;
  feedback?: string;
  cancellationReason?: string;
  cancelledBy?: "USER" | "PROVIDER" | "SYSTEM";
  createdAt: string;
  updatedAt: string;
}

export type ServiceBookingStatus =
  | "PENDING"
  | "CONFIRMED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

// CMS Types
export interface CMSPage {
  _id: string;
  slug: string;
  key?: string;
  title: string;
  content: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Admin Types
export interface Admin {
  _id: string;
  id?: string;
  name: string;
  email: string;
  mobileNumber?: string;
  role: string | AdminRole;
  permissions: Permission[] | string[];
  isActive: boolean;
  lastLogin?: string;
  createdAt: string;
  updatedAt: string;
}

export interface AdminRole {
  _id: string;
  name: string;
  description?: string;
  permissions: Permission[];
  isActive: boolean;
  isSystem?: boolean;
  createdAt: string;
  updatedAt: string;
}

export type Permission =
  | "dashboard:view"
  | "users:view"
  | "users:create"
  | "users:edit"
  | "users:delete"
  | "users:export"
  | "drivers:view"
  | "drivers:create"
  | "drivers:edit"
  | "drivers:delete"
  | "drivers:approve"
  | "drivers:suspend"
  | "drivers:export"
  | "bookings:view"
  | "bookings:edit"
  | "bookings:cancel"
  | "bookings:export"
  | "bookings:refund"
  | "household:view"
  | "household:create"
  | "household:edit"
  | "household:delete"
  | "categories:view"
  | "categories:create"
  | "categories:edit"
  | "categories:delete"
  | "service-bookings:view"
  | "service-bookings:edit"
  | "service-bookings:cancel"
  | "providers:view"
  | "providers:create"
  | "providers:edit"
  | "providers:delete"
  | "providers:approve"
  | "cms:view"
  | "cms:create"
  | "cms:edit"
  | "cms:delete"
  | "admins:view"
  | "admins:create"
  | "admins:edit"
  | "admins:delete"
  | "roles:view"
  | "roles:create"
  | "roles:edit"
  | "roles:delete"
  | "settings:view"
  | "settings:edit"
  | "finance:view"
  | "finance:export"
  | "finance:refund"
  | "pricing:edit"
  | "audit:view"
  | "audit:export"
  | "alerts:view"
  | "alerts:manage"
  | "automation:view"
  | "automation:manage"
  | "notifications:view"
  | "notifications:send";

// API Response Types
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface PaginatedResponse<T> {
  items?: T[];
  total?: number;
  page?: number;
  limit?: number;
  totalPages?: number;
}

export interface UserListResponse {
  users?: User[];
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface AdminListResponse {
  items?: Admin[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface CMSListResponse {
  pages?: CMSPage[];
  items?: CMSPage[];
}

export interface ServiceCategoryListResponse {
  categories?: ServiceCategory[];
}

export interface ServiceDetailsListResponse {
  services?: ServiceDetails[];
}

export interface VehicleCategoryListResponse {
  categories?: VehicleCategory[];
}

export interface VehicleTypeListResponse {
  vehicleTypes?: VehicleType[];
}

export interface BookingListResponse {
  bookings?: Booking[];
  items?: Booking[];
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface ServiceBookingListResponse {
  items?: ServiceBooking[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

// Dashboard Stats Types
export interface DashboardStats {
  users: { total: number; newToday: number };
  drivers: { total: number; active: number; pendingApprovals: number };
  bookings: { total: number; today: number; completedToday: number };
  deliveries: { total: number; today: number };
  services: { total: number; today: number };
  revenue: { today: number; monthly: number };
}

export interface LegacyDashboardStats {
  totalUsers: number;
  totalDrivers: number;
  totalBookings: number;
  totalRevenue: number;
  activeBookings: number;
  onlineDrivers: number;
  todayBookings: number;
  todayRevenue: number;
  userGrowth: number;
  bookingGrowth: number;
  revenueGrowth: number;
}

export interface ChartData {
  name: string;
  value: number;
}

export interface BookingChartData {
  date: string;
  bookings: number;
  revenue: number;
}

// Audit Log Types
export interface AuditLog {
  _id: string;
  adminId: string;
  adminName: string;
  adminRole: string;
  actionType: string;
  entity: string;
  entityId?: string;
  description: string;
  oldValue?: Record<string, any>;
  newValue?: Record<string, any>;
  comment?: string;
  ipAddress?: string;
  userAgent?: string;
  createdAt: string;
}

// Alert Types
export interface Alert {
  _id: string;
  type: string;
  severity: "red" | "amber" | "info";
  title: string;
  message: string;
  entityType?: string;
  entityId?: string;
  isRead: boolean;
  isResolved: boolean;
  resolvedBy?: string;
  resolvedAt?: string;
  metadata?: Record<string, any>;
  createdAt: string;
}

// Finance Types
export interface FinanceOverview {
  grossRevenue: number;
  netRevenue: number;
  refundTotal: number;
  refundCount: number;
  refundRatio: number;
  totalDiscount: number;
  totalTips: number;
  rideRevenue: number;
  rideCount: number;
  deliveryRevenue: number;
  deliveryCount: number;
}

export interface RevenueTrendItem {
  date: string;
  revenue: number;
  bookings: number;
}

export interface VehicleRevenueBreakdown {
  _id: string;
  revenue: number;
  count: number;
}

// Dashboard KPI Types
export interface DashboardKPIs {
  totalLiveOrders: number;
  activeDrivers: number;
  failureRate: number;
  utilizationRatio: number;
  activeSOS: number;
  onTripDrivers: number;
  idleDrivers: number;
  failedOrders: number;
  todayBookings: number;
  todayRevenue: number;
  todayCancellations: number;
}

// Event Timeline
export interface TimelineEvent {
  id: string;
  type: string;
  status: string;
  user?: { _id: string; fullName: string; mobileNumber: string };
  driver?: { _id: string; fullName: string; mobileNumber: string };
  fare: number;
  pickup: string;
  drop: string;
  timestamp: string;
  createdAt: string;
}

// Driver Performance
export interface DriverPerformance {
  acceptanceRate: number;
  cancellationRate: number;
  weeklyEarnings: number;
  codAmount: number;
  totalRides: number;
  rating: number;
  daysSinceLastTrip: number | null;
  documents: {
    type: string;
    expiry: string;
    status: "valid" | "expiring_soon" | "expired";
  }[];
  appVersion: string;
  deviceModel: string;
}

// Automation Rule Types
export interface AutomationRule {
  _id: string;
  name: string;
  description?: string;
  category: "pricing" | "promotion" | "operational";
  ruleType: string;
  condition: {
    field: string;
    operator: string;
    value: number;
    valueMax?: number;
    unit?: string;
  };
  action: {
    type: string;
    value?: number;
    maxDiscount?: number;
    target?: string;
    message?: string;
  };
  applicableTo?: {
    vehicleTypes?: string[];
    userType?: "all" | "new" | "existing";
    cities?: string[];
  };
  validFrom?: string;
  validUntil?: string;
  usageLimit?: number;
  totalUsageLimit?: number;
  currentUsage: number;
  priority: number;
  isActive: boolean;
  lastTriggered?: string;
  triggerCount: number;
  createdBy: { _id: string; name: string; email: string } | string;
  createdAt: string;
  updatedAt: string;
}

// Search Result
export interface SearchResult {
  type: "user" | "driver" | "booking" | "ticket";
  id: string;
  title: string;
  subtitle: string;
  extra?: string;
}

// Surge Config
export interface SurgeConfig {
  _id: string;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  multiplier: number;
  conditions: {
    triggerType: "demand" | "time" | "weather" | "event" | "manual";
    timeStart?: string;
    timeEnd?: string;
    daysOfWeek?: number[];
    demandThreshold?: number;
    zoneId?: string;
  };
  vehicleTypeIds?: string[];
  maxMultiplier: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Commission Config
export interface CommissionConfig {
  _id: string;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  commissionType: "percentage" | "flat";
  value: number;
  minCommission?: number;
  maxCommission?: number;
  vehicleTypeId?: string;
  serviceCategoryId?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Cancellation Policy
export interface CancellationPolicy {
  _id: string;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  rules: {
    cancelledBy: "USER" | "DRIVER" | "PROVIDER" | "SYSTEM";
    beforeStatus: string;
    chargeType: "none" | "percentage" | "flat";
    chargeValue: number;
    refundPercentage: number;
    penaltyToDriver?: number;
  }[];
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Delivery Package Type
export interface DeliveryPackageType {
  _id: string;
  name: string;
  description?: string;
  icon?: string;
  maxWeight: number;
  maxDimensions?: { length: number; width: number; height: number };
  baseFare: number;
  perKmRate: number;
  perStopCharge: number;
  minimumFare: number;
  isActive: boolean;
  displayOrder: number;
  createdAt: string;
  updatedAt: string;
}

// Payout
export interface PayoutItem {
  _id: string;
  recipientType: "driver" | "provider";
  recipientId: string;
  recipientName: string;
  serviceType: "cab" | "delivery" | "household";
  period: { start: string; end: string };
  totalEarnings: number;
  totalCommission: number;
  totalDeductions: number;
  netPayout: number;
  bookingCount: number;
  status: "pending" | "processing" | "completed" | "failed";
  transactionRef?: string;
  processedAt?: string;
  processedBy?: string;
  remarks?: string;
  createdAt: string;
  updatedAt: string;
}

// Service Analytics
export interface CabAnalytics {
  stats: {
    totalRides: number;
    completed: number;
    cancelled: number;
    totalRevenue: number;
    totalSurge: number;
    totalDiscount: number;
    totalTips: number;
    avgFare: number;
    avgDistance: number;
    avgDuration: number;
  };
  byVehicleType: { _id: string; rides: number; revenue: number; avgFare: number }[];
  byPayment: { _id: string; count: number; total: number }[];
  trend: { date: string; rides: number; revenue: number; cancellations: number }[];
  avgRating: number;
  avgWaitTime: number;
}

export interface DeliveryAnalytics {
  stats: {
    totalOrders: number;
    completed: number;
    cancelled: number;
    totalRevenue: number;
    avgFare: number;
  };
  byType: { _id: string; count: number; revenue: number }[];
  byStatus: { _id: string; count: number }[];
  trend: { date: string; orders: number; revenue: number }[];
}

export interface HouseholdAnalytics {
  stats: {
    totalBookings: number;
    completed: number;
    cancelled: number;
    totalRevenue: number;
    avgCost: number;
  };
  byCategory: { _id: string; count: number; revenue: number }[];
  byStatus: { _id: string; count: number }[];
  trend: { date: string; bookings: number; revenue: number }[];
  topProviders: { _id: string; name: string; bookings: number; revenue: number; avgRating: number }[];
}

// Export Log
export interface ExportLogEntry {
  _id: string;
  adminId: string;
  adminName: string;
  exportType: string;
  filters?: Record<string, any>;
  recordCount: number;
  ipAddress?: string;
  createdAt: string;
}
