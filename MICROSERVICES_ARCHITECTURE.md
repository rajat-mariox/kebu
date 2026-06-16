# Microservices Architecture for KEBU

## 🎯 Current Monolithic Architecture

The current system has all services in one backend:
- Authentication (User & Driver)
- Booking Management
- Payment Processing
- Real-time Communication (Socket.IO)
- Driver Location Tracking
- Notifications (FCM)
- Admin Panel APIs
- Vehicle Management

**Pros of Current Setup:**
- ✅ Simple deployment
- ✅ Easy local development
- ✅ No distributed transaction complexity
- ✅ Fast inter-service communication

**Cons:**
- ❌ Scaling one component requires scaling all
- ❌ Single point of failure
- ❌ Tight coupling
- ❌ Hard to maintain as system grows
- ❌ Technology lock-in

## 🏗️ Proposed Microservices Architecture

### 1. **Authentication Service**
**Responsibility:** User and Driver authentication, OTP management

**Tech Stack:**
- Node.js + Express
- Redis (OTP storage)
- MongoDB (User/Driver data)
- JWT token generation

**APIs:**
```
POST /auth/customer/login
POST /auth/customer/verify-otp
POST /auth/driver/login
POST /auth/driver/verify-otp
POST /auth/refresh-token
PUT /auth/update-fcm-token
GET /auth/profile
```

**Database:** `users`, `drivers` collections

**Why Separate?**
- Authentication is critical and needs high availability
- Can scale independently during login spikes
- Can implement advanced security without affecting other services

---

### 2. **Booking Service**
**Responsibility:** Ride booking, fare calculation, ride lifecycle management

**Tech Stack:**
- Node.js + Express
- MongoDB
- Message Queue (RabbitMQ/Kafka) for event publishing

**APIs:**
```
POST /booking/create
GET /booking/:id
GET /booking/active
POST /booking/:id/cancel
POST /booking/:id/rate
GET /booking/fare-estimate
GET /booking/history
```

**Events Published:**
- `booking.created` → Notification Service, Driver Service
- `booking.assigned` → Notification Service, User
- `booking.completed` → Payment Service, Analytics
- `booking.cancelled` → Notification Service, Refund Service

**Database:** `bookings` collection

---

### 3. **Driver Location Service**
**Responsibility:** Real-time driver location tracking, nearby driver search

**Tech Stack:**
- Node.js + Express
- MongoDB with 2dsphere indexes
- Redis (for caching active driver locations)

**APIs:**
```
POST /location/update
GET /location/nearby
GET /location/driver/:id
POST /location/start-tracking
POST /location/stop-tracking
```

**Database:** `driver_locations` collection

**Why Separate?**
- High-frequency location updates need optimized handling
- Geospatial queries are resource-intensive
- Can use Redis for ultra-fast nearby driver lookups

---

### 4. **Notification Service**
**Responsibility:** Push notifications, SMS, Email

**Tech Stack:**
- Node.js + Express
- Firebase Admin SDK (FCM)
- Twilio (SMS)
- SendGrid (Email)
- Bull Queue (for delayed/retry notifications)

**APIs:**
```
POST /notification/send-push
POST /notification/send-sms
POST /notification/send-email
POST /notification/bulk-push
```

**Events Consumed:**
- `booking.created` → Notify nearby drivers
- `booking.assigned` → Notify customer & driver
- `booking.cancelled` → Notify both parties
- `ride.started` → Notify customer
- `driver.arrived` → Notify customer

**Why Separate?**
- Notifications can be sent asynchronously
- Failures shouldn't block main booking flow
- Can easily switch notification providers

---

### 5. **Real-time Communication Service (Socket Service)**
**Responsibility:** WebSocket connections for live updates

**Tech Stack:**
- Node.js + Socket.IO
- Redis Adapter (for horizontal scaling)
- Message Queue consumer

**Events:**
```
// Driver Events
new_ride_request (→ driver)
ride_taken (→ drivers)
location_update (driver → service)

// Customer Events
ride_accepted (→ customer)
driver_arrived (→ customer)
driver_location (→ customer)
ride_started (→ customer)
```

**Why Separate?**
- WebSocket connections are stateful and resource-intensive
- Can scale independently from API services
- Easier to implement connection pooling and load balancing

---

### 6. **Payment Service**
**Responsibility:** Payment processing, wallet management, transactions

**Tech Stack:**
- Node.js + Express
- MongoDB
- Stripe/Razorpay SDK
- PCI DSS compliant

**APIs:**
```
POST /payment/process
GET /payment/methods
POST /payment/wallet/add-money
GET /payment/wallet/balance
GET /payment/transactions
POST /payment/refund
```

**Database:** `transactions`, `wallets` collections

**Why Separate?**
- Payments need highest security standards
- Can be PCI DSS certified independently
- Easy to add new payment gateways

---

### 7. **Admin Service**
**Responsibility:** Admin panel APIs, reporting, analytics

**Tech Stack:**
- Node.js + Express
- MongoDB aggregations
- Read replicas for analytics

**APIs:**
```
GET /admin/dashboard/stats
GET /admin/bookings
GET /admin/drivers
GET /admin/vehicles
POST /admin/driver/approve
GET /admin/reports/revenue
```

---

### 8. **Vehicle Service**
**Responsibility:** Vehicle categories, types, pricing management

**Tech Stack:**
- Node.js + Express
- MongoDB

**APIs:**
```
GET /vehicle/categories
GET /vehicle/types
POST /admin/vehicle/category
PUT /admin/vehicle/category/:id
POST /admin/vehicle/type
```

---

## 🔄 Communication Between Services

### 1. **Synchronous (REST APIs)**
Use for immediate responses needed:
- Auth Service ← Booking Service (verify token)
- Vehicle Service ← Booking Service (get pricing)
- Location Service ← Booking Service (find nearby drivers)

### 2. **Asynchronous (Message Queue)**
Use for fire-and-forget operations:
- Booking Service → Notification Service (send push)
- Booking Service → Payment Service (process payment)
- Booking Service → Analytics Service (log event)

**Recommended:** RabbitMQ or Apache Kafka

**Example Flow:**
```javascript
// Booking Service publishes event
messageQueue.publish('booking.created', {
  bookingId: booking._id,
  userId: booking.userId,
  driverId: booking.driverId,
  fare: booking.finalFare,
});

// Notification Service consumes event
messageQueue.consume('booking.created', async (event) => {
  await sendPushNotification(event.userId, 'Booking confirmed!');
  await sendSMS(event.userId, 'Your ride is being assigned...');
});
```

### 3. **Event Streaming (WebSocket/Socket.IO)**
Use for real-time bidirectional communication:
- Customer App ↔ Socket Service
- Driver App ↔ Socket Service
- Socket Service ↔ Booking Service (via message queue)

---

## 🛠️ Implementation Phases

### **Phase 1: Preparation (Week 1-2)**
- [ ] Set up Docker environment
- [ ] Set up Kubernetes cluster (or Docker Compose for start)
- [ ] Set up RabbitMQ/Kafka
- [ ] Set up API Gateway (Kong/Nginx)
- [ ] Set up service discovery (Consul/Eureka)

### **Phase 2: Extract First Service - Notification (Week 3-4)**
- [ ] Create standalone notification service
- [ ] Set up message queue consumers
- [ ] Test with existing monolith
- [ ] Deploy alongside monolith

### **Phase 3: Extract Critical Services (Week 5-8)**
- [ ] Extract Authentication Service
- [ ] Extract Booking Service
- [ ] Extract Driver Location Service
- [ ] Update monolith to call these services

### **Phase 4: Extract Remaining Services (Week 9-12)**
- [ ] Extract Payment Service
- [ ] Extract Socket Service
- [ ] Extract Admin Service
- [ ] Extract Vehicle Service

### **Phase 5: Decommission Monolith (Week 13-16)**
- [ ] Migrate all clients to new services
- [ ] Run in parallel for 2 weeks
- [ ] Monitor and fix issues
- [ ] Shut down monolith

---

## 🚀 Deployment Architecture

```
                     ┌─────────────────┐
                     │  API Gateway    │
                     │  (Kong/Nginx)   │
                     └────────┬────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
      ┌───────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐
      │ Auth Service │ │  Booking  │ │  Location   │
      │   (3 pods)   │ │(5 pods)   │ │  Service    │
      └──────────────┘ └───────────┘ └─────────────┘
              │               │               │
              └───────┬───────┴───────┬───────┘
                      │               │
              ┌───────▼───────────────▼──────┐
              │    Message Queue (RabbitMQ)  │
              └───────┬──────────────────────┘
                      │
      ┌───────────────┼───────────────┐
      │               │               │
┌─────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐
│Notification│ │  Payment  │ │   Socket    │
│  Service   │ │  Service  │ │   Service   │
└────────────┘ └───────────┘ └─────────────┘
```

---

## 📊 Technology Stack

### Service Framework
- **Node.js** - All microservices (consistency)
- **Express** - REST API framework
- **Socket.IO** - Real-time communication

### Databases
- **MongoDB** - Primary database (with separate DBs per service)
- **Redis** - Caching, session management
- **PostgreSQL** - Optional for payment service (ACID transactions)

### Message Queue
- **RabbitMQ** - Simpler, easier to manage
- **Apache Kafka** - If need high throughput streaming

### Infrastructure
- **Docker** - Containerization
- **Kubernetes** - Orchestration (or Docker Swarm for simpler setup)
- **Kong/Nginx** - API Gateway
- **Consul** - Service discovery
- **Prometheus + Grafana** - Monitoring
- **ELK Stack** - Logging (Elasticsearch, Logstash, Kibana)

### CI/CD
- **GitHub Actions** - Build and test
- **Docker Hub** - Container registry
- **ArgoCD** - GitOps deployment

---

## 🔒 Security Considerations

### 1. **API Gateway Level**
- Rate limiting per service
- JWT validation
- Request/response logging
- DDoS protection

### 2. **Service-to-Service**
- Mutual TLS (mTLS)
- API keys for internal services
- Service mesh (Istio) for advanced security

### 3. **Database Security**
- Separate databases per service
- Encrypted connections
- Read replicas for analytics
- Regular backups

---

## 💰 Cost Comparison

### **Monolith (Current):**
- 1 server: ₹5,000/month
- 1 database: ₹3,000/month
- **Total: ₹8,000/month**

### **Microservices (Projected):**
- API Gateway: ₹2,000/month
- 5 service instances (avg): ₹15,000/month
- Message Queue: ₹3,000/month
- Monitoring/Logging: ₹2,000/month
- **Total: ₹22,000/month** (2.75x increase)

**But:**
- Better scalability (scale only what you need)
- Higher uptime (no single point of failure)
- Faster development (teams can work independently)
- Easier maintenance

---

## 📈 Scalability Benefits

### **Scenario: Peak Hours (5 PM - 10 PM)**

**Monolith:**
- Need to scale entire application
- 1 instance → 5 instances = 5x cost

**Microservices:**
- Booking Service: 2 → 5 instances (high demand)
- Location Service: 1 → 3 instances (tracking)
- Notification Service: 1 → 2 instances
- Auth Service: 1 instance (not peak time)
- Total: ~2.5x cost (vs 5x in monolith)

---

## 🎯 Recommendation

### **For Current Stage (MVP/Early Growth):**
**Keep Monolith** with improvements:
- ✅ Implement current E2E flow changes
- ✅ Add proper monitoring
- ✅ Optimize database queries
- ✅ Add caching layer (Redis)
- ✅ Horizontal scaling capability

### **When to Migrate to Microservices:**
1. **User Base:** > 50,000 active users
2. **Team Size:** > 10 developers
3. **Geographic Expansion:** Multiple cities/countries
4. **Feature Complexity:** Multiple products (food delivery, courier, etc.)
5. **Performance Issues:** Monolith becomes bottleneck

### **Hybrid Approach (Recommended Next Step):**
1. Keep main monolith
2. Extract **Notification Service** first (easy, non-critical)
3. Extract **Location Service** second (resource-intensive)
4. Monitor and learn
5. Gradually extract more services

---

## 📚 Resources

### Learning Microservices
- [Microservices.io](https://microservices.io/) - Patterns and best practices
- [Martin Fowler - Microservices](https://martinfowler.com/articles/microservices.html)
- [Node.js Microservices Course](https://www.youtube.com/watch?v=XUSHH0E-7zk)

### Tools
- [Kong Gateway](https://konghq.com/)
- [RabbitMQ Tutorial](https://www.rabbitmq.com/getstarted.html)
- [Docker Compose Multi-Container](https://docs.docker.com/compose/)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/)

---

## 🏁 Conclusion

**Current Recommendation:** 
1. ✅ Implement the E2E booking flow with FCM (as done)
2. ✅ Add monitoring and observability
3. ✅ Optimize current monolith
4. ⏳ Plan microservices migration for 6-12 months from now

**Start Migration When:**
- Facing scaling issues
- Team growing beyond 5 developers
- Need independent deployment cycles
- Have budget for infrastructure increase

The current monolithic architecture with the implemented improvements (FCM, socket notifications, device tracking) is:
- ✅ Sufficient for MVP and early growth
- ✅ Easier to maintain with small team
- ✅ Faster to develop new features
- ✅ Lower operational overhead

Migrate to microservices when the benefits outweigh the complexity costs.
