# 📚 LibraryTrack

A production-ready Flutter application for managing study libraries (reading rooms / co-working spaces). Built with **Clean Architecture** principles, **BLoC/Cubit** state management, and **Firebase** backend.

**Version:** 46.0.1+73  
**Dart SDK:** ^3.10.4

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Key Screens](#-key-screens)
- [Domain Layer](#-domain-layer)
- [Subscription System](#-subscription-system)
- [Seat & Slot Management](#-seat--slot-management)
- [Payment Flow](#-payment-flow)
- [Attendance System](#-attendance-system)
- [Invoice System](#-invoice-system)
- [Student Premium](#-student-premium)
- [Job Alerts & Current Affairs](#-job-alerts--current-affairs)
- [Tools Module](#-tools-module)
- [Notices System](#-notices-system)
- [Expense Tracking](#-expense-tracking)
- [Referral System](#-referral-system)
- [Device Session Management](#-device-session-management)
- [Admin Intelligence](#-admin-intelligence)
- [Push Notifications](#-push-notifications)
- [Testing](#-testing)
- [Getting Started](#-getting-started)
- [Web Landing Page](#-web-landing-page)
- [Dependencies](#-dependencies)

---

## ✨ Features

### Authentication
- 📱 Phone number OTP-based sign-in (Firebase Auth)
- 👤 Role-based access (OWNER / STUDENT / ADMIN)
- 🔐 Persistent authenticated user state with device binding
- 🚪 Secure sign-out with session cleanup
- 📱 **Multi-device session management** - View and revoke active sessions

### Owner Features
- 🏛️ Create and manage library (single library per owner)
- 📊 Dashboard with real-time slot-aware statistics
- 💺 **Slot-aware seat management** (Morning / Evening / Custom slots)
- 📅 Seat reservation with payment-driven activation
- 👥 View occupied AND reserved seats with student details
- 🔄 Edit memberships (change seat/slot)
- ❌ Cancel active memberships or remove pending reservations
- 📈 Dashboard cards showing Available / Reserved / Occupied per slot
- 💵 **Cash payment approval** - Approve or reject student cash payments
- 📱 **UPI payment approval** - Separate approval queue for UPI payments
- 💰 **Revenue Analytics** - Comprehensive earnings dashboard with charts
- 💸 **Expense Tracking** - Record and categorise library running costs
- 📋 **Attendance analytics** - Daily/weekly/monthly attendance insights
- 🧾 **Invoice management** - View, download, and delete student invoices
- 📥 **Bulk Import** - Import multiple students via Excel file
- 🔑 **Custom Razorpay** - Use your own Razorpay account (optional)
- 🔔 **Expiry Reminders** - Send push notifications to members with expiring memberships
- 📲 **WhatsApp Reminders** - Send bulk/individual WhatsApp messages
- 🎫 **Student ID Cards** - Generate downloadable ID cards for members
- 📄 **Document Verification** - Approve student verification documents
- 🔄 **Force Update** - Automatic version checking via Firebase Remote Config
- 💳 **Subscription Management** - View subscription status, renew, upgrade plans
- 📣 **Notices Board** - Post announcements to all members or targeted slots/seats
- 🤝 **Referral Program** - Earn wallet credits or a free month by referring new owners

### Student Features
- 🎫 View active membership with assigned seat, slot & session timing
- 💳 **Razorpay payment** integration for online seat activation
- 📱 **UPI payment** - Pay directly to owner's UPI (PhonePe, GPay, Paytm)
- 💵 **Cash payment** option - Pay at library with owner approval
- 🔄 **Switch to online** - Convert pending cash/UPI to instant online payment
- 🧾 **Monthly invoices** - Download, share, and delete PDF invoices
- 📅 Check membership validity
- ✅ **Daily attendance** - Check-in & check-out tracking
- 📊 **Attendance analytics** - View history, graphs & statistics
- 🔍 **Explore libraries** - Search and discover nearby libraries
- 👤 **Profile management** - Update name and contact details
- 📤 **Document upload** - Upload verification documents (Aadhar, PAN, etc.)
- 📰 **Notices** - Read library announcements from owner
- 🗞️ **Current Affairs** - AI-generated daily exam prep news with bookmarks & likes
- 💼 **Job Alerts** - Curated government/competitive exam job notifications
- 🤖 **AI Chat** - In-app AI assistant for study queries
- 🧠 **AI Quiz** - Generate multiple-choice quizzes from any study material
- 📜 **Quiz History** - Review past quiz attempts and scores
- 🛠️ **Tools Dashboard** - PDF & image productivity tools (OCR, compress, convert, QR)
- ⭐ **Student Premium** - Ad-free experience and priority features via paid plan

### Admin Features
- 📊 **Platform Dashboard** - Global statistics (libraries, students, revenue)
- 🔍 **Library Analytics** - Deep-dive into individual library metrics
- 👥 **User Activity** - Track user engagement and activity patterns
- ⏰ **Hourly Activity Drill-Down** - View active users for any hour with detailed session info
- 📅 **User Activity Timeline** - Track individual user activity patterns over time
- 💳 **Subscription Management** - Approve/reject owner subscriptions
- 🎟️ **Coupon Management** - Create and manage discount coupons
- 📢 **Broadcast Notifications** - Send platform-wide announcements
- 🧠 **Admin Intelligence** - AI-powered insights and recommendations
- 📉 **Churn Prediction** - Identify at-risk libraries
- 🎯 **Retention Tools** - Extend trials, apply discounts, manage offers
- 🚨 **Alert System** - Real-time alerts for critical events
- 📈 **Revenue Intelligence** - Deep revenue analytics (MRR, ARR, plan-wise breakdown, churn)
- 🎁 **Promo Management** - Create targeted promotional offers for owners/students
- 💼 **Jobs Management** - Post and manage job alerts visible to students
- 🗞️ **Current Affairs Management** - Publish and manage daily current affairs articles
- 💸 **Withdrawal Approvals** - Process referral wallet withdrawal requests
- 📊 **Affiliate Analytics** - Track referral program performance
- 📊 **Feature Analytics** - Monitor feature adoption across the platform
- 👨‍🎓 **Student Analytics** - Platform-wide student engagement insights

### Seat & Slot System
- ☀️ **Morning Slot** and 🌙 **Evening Slot** per seat
- ⏰ **Custom Slots** - Define flexible time ranges
- A seat can be occupied in one slot and available in another
- Three seat states per slot:
  - 🟢 **Available** - Free for assignment
  - 🟡 **Reserved** - Payment pending (student not yet paid)
  - 🔴 **Occupied** - Active membership

### Payment Modes
- 💳 **Online (Razorpay)** - Instant activation after payment
- 📱 **UPI Direct** - Pay to owner's UPI ID with approval workflow
- 💵 **Cash** - Owner approval required before activation
- 🔄 **Switch Payment Mode** - Convert pending cash/UPI to online payment

### Revenue Analytics (Owner)
- 📊 **Earnings Dashboard** - Today, Month, Year, All-time earnings
- 🥧 **Pie Chart** - Payment distribution by mode (Online/UPI/Cash)
- 📈 **Line Charts** - Daily (30 days) and Monthly (12 months) trends
- ⏳ **Pending Approvals** - Cash & UPI payments awaiting action

---

## 🏗️ Architecture

This project follows **Pragmatic Clean Architecture** with three distinct layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                         │
│  ┌─────────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │     Screens     │  │   Widgets   │  │   BLoCs / Cubits    │ │
│  │      (UI)       │  │ (Reusable)  │  │ (State Management)  │ │
│  └────────┬────────┘  └─────────────┘  └──────────┬──────────┘ │
│           │                                        │            │
│           │          Depends on Domain             │            │
└───────────┼────────────────────────────────────────┼────────────┘
            │                                        │
            ▼                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                        DOMAIN LAYER                             │
│  ┌─────────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    Entities     │  │  Use Cases  │  │ Repository Interfaces│ │
│  │    (Models)     │  │  (Business  │  │    (Contracts)      │ │
│  │                 │  │    Logic)   │  │                     │ │
│  └─────────────────┘  └─────────────┘  └──────────┬──────────┘ │
│                                                    │            │
│            Framework-agnostic (no Flutter/Firebase imports)     │
└────────────────────────────────────────────────────┼────────────┘
                                                     │
                                                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DATA LAYER                              │
│  ┌─────────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │      DTOs       │  │   Mappers   │  │     Repository      │ │
│  │   (Firebase     │  │  (DTO ↔     │  │   Implementations   │ │
│  │     Models)     │  │   Entity)   │  │ (Firebase/Razorpay) │ │
│  └─────────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                                 │
│                    Implements Domain Contracts                  │
└─────────────────────────────────────────────────────────────────┘
```

### Dependency Rule

> Dependencies always point **inward**. The Domain layer knows nothing about Presentation or Data layers.

```
Presentation → Domain ← Data
```

---

## 📁 Project Structure

```
lib/
├── core/                          # Shared infrastructure
│   ├── config/                    # Firebase options
│   ├── constants/                 # UI constants
│   ├── di/                        # Dependency injection (get_it)
│   │   └── injection_container.dart
│   ├── router/                    # Navigation (go_router)
│   │   └── app_router.dart
│   ├── services/                  # Core services
│   ├── utils/                     # Utility functions
│   │   └── file_download_helper.dart  # Cross-platform file downloads
│   └── widgets/                   # Shared widgets
│
├── domain/                        # Business logic (framework-agnostic)
│   ├── core/                      # Base classes (Failure, UseCase)
│   ├── entities/                  # Domain models (55+ entities)
│   ├── failures/                  # Typed failures
│   ├── repositories/              # Abstract interfaces (32 repositories)
│   ├── services/                  # External service abstractions
│   └── usecases/                  # Business operations (130+ use cases)
│       ├── admin_intelligence/    # Admin-specific use cases
│       ├── ai/                    # AI chat use cases
│       ├── current_affairs/       # Current affairs generation
│       ├── job_alerts/            # Job alert use cases
│       ├── promo/                 # Promotional offer use cases
│       ├── quiz/                  # Quiz history use cases
│       ├── referral/              # Referral & wallet use cases
│       ├── student_premium/       # Student subscription use cases
│       └── tools/                 # PDF/image tool use cases
│
├── data/                          # External data sources
│   ├── models/                    # DTOs (Firebase models)
│   ├── mappers/                   # DTO ↔ Entity conversion
│   ├── repositories/              # Firebase implementations (32)
│   ├── services/                  # External service implementations
│   └── utils/                     # Data layer utilities
│
├── presentation/                  # UI layer
│   ├── admin/                     # Admin module
│   │   ├── cubit/                 # Admin state management
│   │   ├── screens/               # Admin screens (incl. jobs, analytics)
│   │   └── widgets/               # Admin widgets
│   ├── auth/                      # Authentication module
│   ├── core/                      # Shared presentation utilities
│   ├── onboarding/                # Onboarding flow
│   ├── owner/                     # Owner module
│   │   ├── bloc/                  # Owner BLoCs
│   │   ├── cubit/                 # Owner Cubits
│   │   ├── screens/               # Owner screens
│   │   └── widgets/               # Owner widgets
│   └── student/                   # Student module
│       ├── bloc/                  # Student BLoCs
│       ├── cubit/                 # Student Cubits
│       ├── screens/               # Student screens
│       │   ├── jobs/              # Job alerts screens
│       │   └── tools/             # Tools dashboard screens
│       └── widgets/               # Student widgets
│
└── main.dart                      # App entry point
```

---

## 📱 Key Screens

### Owner Screens
| Screen | Description |
|--------|-------------|
| Owner Dashboard | Library stats, revenue card, quick actions, subscription status |
| Revenue Analytics | Earnings charts (pie, line), daily/monthly trends |
| Library Form | Create/edit library, facilities, pricing, payment settings |
| Seat Grid | Visual seat assignment with slot filtering |
| Slot Management | Create and manage custom time slots |
| Occupied Seats | View all assigned seats with edit/cancel actions |
| Cash Approvals | Approve or reject pending cash payments |
| UPI Approvals | Separate queue for UPI payment approvals |
| Payment Approvals | Unified payment approval view |
| Attendance Analytics | Daily/weekly attendance insights with graphs |
| Attendance Management | Mark and manage student attendance |
| Owner Invoices | View, download, share, and delete student invoices |
| Bulk Import | Import multiple students via Excel file |
| Unified Notifications | Send Push + WhatsApp reminders |
| Payment Reminder | Send targeted payment reminders |
| Student Documents | View and approve uploaded documents |
| Subscription Overview | View subscription status, renew, upgrade |
| Pricing Screen | View subscription pricing tiers |
| Notices | Create and manage library announcements |
| Owner Profile | Update owner settings and contact info |
| Referral | Share referral code, track earnings, request withdrawal |
| Active Devices | View and revoke active login sessions |
| Library Preview | Preview library page as a student would see it |

### Student Screens
| Screen | Description |
|--------|-------------|
| Student Dashboard | Membership card, check-in/out, explore libraries |
| Library Details | Complete library info with member-specific data |
| Payment | Online, UPI, or cash payment options |
| Attendance Details | History, graphs, daily/weekly stats |
| Invoices | View, download, share, and delete PDF invoices |
| Profile | Update personal information |
| Profile Completion | Complete profile after signup |
| Explore Libraries | Search and discover nearby libraries |
| Student Documents | Upload verification documents |
| Notices | View library announcements from owner |
| Current Affairs | Daily AI-generated exam prep news feed |
| Current Affair Detail | Full article view with bookmarks and likes |
| Jobs | Curated government/competitive exam job alerts |
| Job Alert Detail | Full job detail with apply link |
| Job Preferences | Set preferred job categories and states |
| Saved Jobs | View bookmarked job alerts |
| Student Premium | Upgrade to premium for ad-free experience |
| AI Chat | In-app AI assistant for study help |
| Tools Dashboard | PDF & image productivity tools hub |
| OCR | Extract text from images using ML Kit |
| Image Compressor | Compress images with quality control |
| Images to PDF | Combine images into a single PDF |
| PDF to Images | Convert PDF pages to image files |
| PDF Page Extractor | Extract specific pages from a PDF |
| QR Generator | Generate QR codes for any text or URL |
| AI Quiz | Generate MCQ quiz from study material |
| Quiz History | Review past quiz attempts and scores |

### Admin Screens
| Screen | Description |
|--------|-------------|
| Admin Dashboard | Platform overview, key metrics, quick actions |
| Admin Analytics | Deep platform analytics |
| Library Analytics | Individual library metrics |
| Owner Details | Detailed owner & library profile |
| Student Analytics | Platform-wide student engagement data |
| Feature Analytics | Monitor feature adoption across the platform |
| Affiliate Analytics | Referral program performance |
| Hourly Activity Drill-Down | View active users for a specific hour with session details |
| User Activity Timeline | Track individual user's activity history over date ranges |
| Subscriptions | Approve/reject owner subscriptions |
| Coupon Management | Create and manage coupons |
| Broadcast | Send platform-wide notifications |
| Admin Intelligence | AI-powered insights dashboard |
| Revenue Intelligence | Revenue analytics: MRR, ARR, churn, plan-wise breakdown |
| Promo Management | Create targeted promo offers for owners/students |
| Jobs Management | Post and manage student-facing job alerts |
| Job Analytics | Job alert engagement metrics |
| Current Affairs Management | Publish and manage daily current affairs articles |
| Withdrawal Approvals | Process referral wallet withdrawal requests |
| Admin Invoices | View all platform invoices |

---

## 🎯 Domain Layer

### Key Entities (55+ entities)

| Entity | Description |
|--------|-------------|
| `User` | Student or Owner profile with role |
| `Library` | Library details, facilities, pricing, UPI ID, Razorpay keys |
| `Membership` | Student-library assignment with seat & slot |
| `Seat` | Individual seat with slot availability |
| `Slot` | Time slot (Morning/Evening) |
| `CustomSlot` | Flexible time range slots |
| `Payment` | Payment record (Online/Cash/UPI) with UTR, proof URL |
| `RevenueAnalytics` | Earnings, trends, payment distribution |
| `RevenueStats` | Admin-level revenue (MRR, ARR, plan-wise breakdown, churn) |
| `Attendance` | Daily check-in/out record |
| `AttendanceStats` | Analytics (hours, streaks, averages) |
| `AttendanceSession` | Individual session tracking |
| `OwnerAttendanceAnalytics` | Owner-level attendance overview |
| `Invoice` | Monthly billing record |
| `Subscription` | Owner subscription with trial, pricing, status |
| `SubscriptionPlan` | Pricing tiers based on seat count |
| `OwnerTrial` | 7-day free trial for new owners |
| `Coupon` | Discount coupon for subscriptions |
| `StudentDocument` | Verification document (Aadhar, PAN, etc.) |
| `AppVersion` | Version info for force update |
| `FcmToken` | Push notification token |
| `WhatsAppReminder` | WhatsApp reminder record |
| `UserActivityDetail` | Detailed user activity for hourly drill-down |
| `UserActivityStats` | Aggregated user activity statistics |
| `AdminDashboardStats` | Platform-wide statistics |
| `AdminDashboardData` | Rich admin dashboard payload |
| `AdminAlert` | Auto-generated admin alerts |
| `ChurnData` | Churn prediction data |
| `AdminAction` | Admin action log |
| `AdminNote` | Notes on libraries/owners |
| `PricingExperiment` | A/B pricing experiments |
| `Expense` | Library expense entry (rent, electricity, salary, etc.) |
| `Notice` | Library announcement with targeting, scheduling, and attachments |
| `CurrentAffair` | AI-generated daily exam prep news article |
| `JobAlert` | Government/competitive exam job alert |
| `JobAlertSource` | Source metadata for a job alert |
| `JobAlertCandidate` | Student job application record |
| `UserJobPreferences` | Student's preferred job categories and states |
| `Quiz` | AI-generated multiple-choice quiz |
| `QuizQuestion` | Individual MCQ within a quiz |
| `QuizResult` | Student's quiz attempt result |
| `StudentPremiumSubscription` | Student paid subscription for premium features |
| `Referral` | Owner referral code and redemption stats |
| `PromoOffer` | Targeted promotional offer for owners/students |
| `DeviceSession` | Active device login session with security info |
| `UserSession` | Aggregated user session record |
| `Presence` | Real-time online/offline presence status |
| `LibraryStats` | Library-level engagement statistics |
| `LibrarySummary` | Lightweight library card for explore view |
| `AnalyticsSummary` | High-level platform analytics snapshot |
| `PaymentBreakdown` | Itemised payment details |
| `LabeledLink` | Key-value link (used in job alerts, notices) |
| `ExtractedJobFields` | ML-extracted fields from job posting text |
| `ToolParams` / `ToolResult` | AI function-calling tool parameter/result types |

### Key Use Cases (130+ use cases)

| Use Case | Description |
|----------|-------------|
| `ReserveSeatForStudent` | Owner assigns seat → creates pending membership |
| `AssignMembershipWithCustomSlot` | Assign with custom time slot |
| `InitiatePayment` | Student starts online payment |
| `InitiateCashPayment` | Student opts for cash payment |
| `InitiateUpiPayment` | Student selects UPI payment option |
| `MarkUpiAsPaid` | Student confirms UPI payment with optional UTR |
| `ApproveCashPayment` | Owner approves cash/UPI → activates membership |
| `RejectCashPayment` | Owner rejects → cancels reservation |
| `GetPendingApprovalPayments` | Fetch all pending cash + UPI approvals |
| `ConfirmPaymentSuccess` | Online payment success → activates membership |
| `GetRevenueAnalytics` | Calculate earnings, charts, time-series data |
| `ResolveRazorpayConfig` | Select owner's or app's Razorpay keys |
| `CheckIn` / `CheckOut` | Student daily attendance |
| `GetAttendanceHistory` | Fetch attendance records |
| `GetAttendanceStats` | Calculate attendance analytics |
| `GetOwnerAttendanceAnalytics` | Owner-level attendance overview |
| `MarkOwnerAttendance` | Mark owner's own attendance |
| `GenerateInvoice` | Create monthly invoice |
| `DeleteInvoice` | Delete invoice and associated payment |
| `GetSeatOccupancySummary` | Slot-aware seat counts |
| `CreateSubscription` | Create new owner subscription |
| `ApproveSubscription` | Admin approves subscription payment |
| `RejectSubscription` | Admin rejects subscription |
| `GetOwnerSubscription` | Get owner's subscription status |
| `CalculateSubscriptionPrice` | Calculate price with discounts |
| `ValidateCoupon` | Validate discount coupon |
| `CreateCoupon` | Admin creates new coupon |
| `StartOwnerTrial` | Start 7-day free trial |
| `CheckVersionUpdate` | Check for force update |
| `SendMembershipExpiryReminder` | Send push notification reminders |
| `SendPaymentReminder` | Send payment reminder notification |
| `SendAdminBroadcastNotification` | Send platform-wide announcement |
| `GenerateStudentIdCard` | Generate downloadable ID card |
| `UploadStudentDocument` | Upload verification document |
| `ApproveStudentDocument` | Owner approves document |
| `GetChurnData` | Get churn prediction data |
| `ExtendTrial` | Admin extends owner trial |
| `ApplyDiscount` | Admin applies retention discount |
| `SuspendLibrary` | Suspend library for violations |
| `GetHourlyActiveUsers` | Fetch active users for a specific hour |
| `GetUserActivityDetails` | Get user's activity timeline over date range |
| `GetUserDeviceSessions` | List active device sessions |
| `LogoutDeviceSession` | Revoke a specific device session |
| `LogoutAllOtherDevices` | Security: sign out all sessions except current |
| `ValidateDailyPresence` | Check/record real-time presence |
| `GetJobAlerts` | Paginated student job alert feed |
| `RecordJobView` | Track job alert engagement |
| `GetActiveStudentPremium` | Check student's premium status |
| `ActivateStudentPremium` | Activate student premium after payment |
| `CancelStudentPremium` | Cancel student premium subscription |
| `GenerateDailyCurrentAffairs` | AI-generate daily news articles |
| `GenerateOnDemandCurrentAffairs` | On-demand current affairs generation |
| `CreateReferralCode` | Owner creates shareable referral code |
| `ValidateReferralCode` | Validate code on subscription |
| `ClaimReferralReward` | Process referral reward (free month / wallet credit) |
| `GetReferralStats` | Owner's referral performance stats |
| `RequestWalletWithdrawal` | Owner requests payout of wallet balance |
| `ApproveWithdrawal` / `RejectWithdrawal` | Admin processes withdrawal |
| `GetActivePromo` | Get active promo for owner |
| `GetActivePromoForStudent` | Get active promo for student |
| `RecordPromoInteraction` | Track promo impression/click/dismiss |
| `CompressImage` | Compress image with quality settings |
| `ConvertImagesToPdf` | Merge images into a PDF |
| `ConvertPdfToImages` | Render PDF pages as images |
| `ExtractPdfPages` | Extract specific pages from a PDF |
| `ExtractTextFromImage` | OCR text extraction using ML Kit |

---

## 💳 Subscription System

### Overview
- **7-day free trial** for all new owners
- **Seat-based pricing** tiers
- **Duration discounts** (3, 6, 12 months)
- **Coupon support** for additional discounts
- **Manual UPI payment** with admin verification

### Pricing Tiers

| Plan | Seats | Monthly Price (₹) |
|------|-------|-------------------|
| Starter | 1-50 | 99 |
| Growth | 51-99 | 149 |
| Professional | 100-149 | 199 |
| Business | 150-199 | 249 |
| Business Plus | 200-249 | 299 |
| Enterprise | 250+ | 349 |

### Duration Discounts

| Duration | Discount |
|----------|----------|
| 1 month | 0% |
| 3 months | 10% |
| 6 months | 15% |
| 12 months | 20% |

### Subscription Workflow

```
Owner creates library → 7-day trial starts → Trial expires
                                                   │
                              ┌────────────────────┴────────────────────┐
                              ▼                                         ▼
                        Subscribe                              Trial Extension
                              │                               (Admin can extend)
                              ▼
                    Select plan + duration
                              │
                              ▼
                    Apply coupon (optional)
                              │
                              ▼
                    Pay via UPI + enter UTR
                              │
                              ▼
                    Admin verifies payment
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
               Approved            Rejected
                    │                   │
                    ▼                   ▼
          Subscription Active    Notification sent
```

### Access Control

| Status | Can Access Features |
|--------|---------------------|
| Trial Active | ✅ Full access |
| Subscription Active | ✅ Full access |
| Admin Bypassed | ✅ Full access (free) |
| Pending Verification | ❌ Blocked (waiting) |
| Trial Expired | ❌ Blocked |
| Subscription Expired | ❌ Blocked |

---

## 💺 Seat & Slot Management

### Dashboard Statistics (Owner)

```
┌─────────────────────────────────────────────────────────────┐
│                   Seat Availability                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ☀️ Morning Slot (6 AM - 12 PM)                              │
│  ┌───────────┬───────────┬───────────┐                       │
│  │ Available │ Reserved  │ Occupied  │                       │
│  │    15     │     3     │    32     │                       │
│  └───────────┴───────────┴───────────┘                       │
│                                                              │
│  🌙 Evening Slot (4 PM - 10 PM)                              │
│  ┌───────────┬───────────┬───────────┐                       │
│  │ Available │ Reserved  │ Occupied  │                       │
│  │    20     │     1     │    29     │                       │
│  └───────────┴───────────┴───────────┘                       │
│                                                              │
│  ⏰ Custom Slots                                              │
│  (Configurable per library)                                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Seat States

```
🟢 Available     → Owner can assign
🟡 Reserved      → Payment pending (blocked)
🔴 Occupied      → Active membership (blocked)
🔵 Selected      → Current selection
```

---

## 💳 Payment Flow

### Online Payment (Razorpay)

```
Owner assigns seat  →  Membership pending  →  Student pays online
                                                      │
                                          ┌───────────┴───────────┐
                                          ▼                       ▼
                                    Success                    Failed
                                       │                         │
                                       ▼                         ▼
                              Membership ACTIVE         Membership CANCELLED
                              Seat OCCUPIED             Seat AVAILABLE
```

### Cash Payment Flow

```
Student selects "Pay Cash"  →  Membership pending  →  Owner sees in "Cash Approvals"
                                                               │
                                               ┌───────────────┴───────────────┐
                                               ▼                               ▼
                                          Approve                           Reject
                                              │                               │
                                              ▼                               ▼
                                    Membership ACTIVE            Membership CANCELLED
                                    Seat OCCUPIED                Seat AVAILABLE
                                    Invoice Generated            Student Notified
```

### UPI Payment Flow

```
Student selects "Pay via UPI"  →  Opens UPI app (PhonePe/GPay/Paytm)
                                          │
                                          ▼
                              Student pays to owner's UPI ID
                                          │
                                          ▼
                              Student clicks "I've Paid" (+ optional UTR)
                                          │
                                          ▼
                              Owner sees in "UPI Approvals"
                                          │
                              ┌───────────┴───────────┐
                              ▼                       ▼
                          Approve                   Reject
                              │                       │
                              ▼                       ▼
                    Membership ACTIVE      Membership CANCELLED
                    Seat OCCUPIED          Seat AVAILABLE
```

### Switch Payment Mode

Students with pending cash/UPI payments can switch to online payment:
```
Pending Cash/UPI  →  Click "Pay Online"  →  Razorpay checkout  →  Instant activation
```

---

## ✅ Attendance System

### Features
- **One check-in/check-out per day** per membership
- Time-window validation (optional)
- Duration tracking
- History and statistics

### Analytics
- 📊 Daily hours spent
- 📈 Weekly/monthly trends
- 🔥 Attendance streaks
- ⏱️ Average session duration

---

## 📥 Bulk Import System

### Overview
Owners can import multiple students at once using an Excel file, streamlining the onboarding process for large groups.

### Features
- **Excel File Upload** - Support for `.xlsx` and `.xls` formats
- **Data Validation** - Validates student information before import
- **Preview Before Import** - Review data before processing
- **Batch Processing** - Handles large datasets efficiently
- **Error Handling** - Detailed error reporting for failed rows
- **Progress Tracking** - Real-time import progress with statistics

### Supported Fields
- Student name
- Phone number
- Seat number
- Slot assignment (Morning/Evening/Custom)
- Payment mode (Online/Cash/UPI)

### Import Workflow
```
Upload Excel File → Validate Data → Preview → Confirm Import → Process → Results
```

### Error Reporting
- Row-by-row error details
- Validation failures
- Duplicate detection
- Missing required fields

---

## 🧾 Invoice System

### Invoice Generation
- Automatically generated after payment approval
- Monthly billing cycle
- PDF download support
- Contains library details, membership info, payment breakdown

### Invoice Management
- **View invoices** - Students and owners can view all invoices
- **Download PDF** - Cross-platform PDF download (web and mobile)
- **Share invoices** - Share via system share sheet
- **Delete invoices** - Owners and students can delete invoices (also removes associated payment for revenue accuracy)

### PDF Features
- Professional layout with library branding
- Itemized billing breakdown
- Cross-platform support (web and mobile)
- Shareable via system share sheet
- Unicode character sanitization for PDF compatibility

---

## ⭐ Student Premium

Students can subscribe to a premium plan for an enhanced experience:
- **Ad-free** - No AdMob banners while using the app
- **Priority push delivery** - Notifications delivered with higher priority
- **Future premium features** - Gated behind the subscription

### Plans
| Plan | Duration | Price |
|------|----------|-------|
| Monthly | 1 month | ₹49 |

### Lifecycle
- Activating via Razorpay sets `validTill` server-side
- Gating checks both `isActive` flag and `validTill` timestamp
- Renewals extend `validTill`; cancellations flip `isActive` but preserve history

---

## 💼 Job Alerts & Current Affairs

Features designed to add value for students studying for competitive/government exams.

### Job Alerts
- Curated government and competitive exam job notifications
- Filter by **category** (SSC, Banking, Railway, UPSC, State PSC, Defence, Teaching, Police, etc.)
- Filter by **state** for location-specific jobs
- Paginated infinite scroll feed
- Full job detail with apply links
- **Saved Jobs** - Bookmark alerts for later
- Track view and apply-click analytics (admin)
- Students can set **job preferences** for a personalised feed

### Current Affairs
- Daily AI-generated news articles for exam preparation
- Categories: National, International, Economy, Science & Tech, Sports, Environment, etc.
- Full article view with source attribution
- **Bookmarks** - Save articles for later revision
- **Likes** - Engage with content
- View count tracking
- Admin publishes articles; students consume them

### AI Quiz
- Generate multiple-choice questions from any pasted study text
- AI returns questions, 4 options, correct index, and explanation
- **Quiz History** - All attempts saved with score and source text
- Review past quizzes and explanations

### AI Chat
- In-app AI assistant accessible to students
- Ask study-related queries
- Supports tool-calling for enriched responses

---

## 🛠️ Tools Module

A suite of PDF and image productivity tools built into the student app:

| Tool | Description |
|------|-------------|
| **OCR** | Extract text from photos using Google ML Kit |
| **Image Compressor** | Reduce image file size with quality slider |
| **Images to PDF** | Combine multiple images into a single PDF |
| **PDF to Images** | Convert PDF pages to image files (via pdfx) |
| **PDF Page Extractor** | Extract a subset of pages from a PDF |
| **QR Generator** | Generate QR codes for any text, URL, or UPI ID |

All tools work offline (except OCR which uses on-device ML model). Output files can be saved to gallery or shared directly.

---

## 📣 Notices System

Library owners can post announcements to their members.

### Features
- **Target audience** - All students, active members only, specific slots, or specific seats
- **Scheduling** - Draft or schedule for future publication
- **Expiry** - Auto-expire notices after a set date
- **Attachments** - Images and PDFs stored in Firebase Storage
- **External links** - Attach URLs (forms, websites)
- **Push notification** - Optionally notify members on publish
- **Engagement tracking** - View count and read count per notice
- Students see unread notice badges and can view all active notices

---

## 💸 Expense Tracking

Owners can record and review library running costs.

### Categories
`Rent` · `Electricity` · `Salary` · `Maintenance` · `Supplies` · `Internet` · `Other`

### Features
- Add/edit/delete expense entries
- Filter by date range and category
- Integrated into revenue view for net profit calculation

---

## 🤝 Referral System

Active subscribed owners can generate a referral code to invite new owners.

### How it Works
```
Owner generates code → Shares with a new owner
                              │
               New owner applies code at checkout
                              │
               15% discount on their first subscription
                              │
               Referrer earns: free month OR ₹149 wallet credit
```

### Wallet & Withdrawals
- Referral rewards accumulate in an in-app wallet
- Owner can request a **withdrawal** via bank transfer/UPI
- Admin reviews and approves/rejects withdrawal requests
- Full withdrawal history maintained

---

## 📱 Device Session Management

Security feature allowing users to manage their active logins.

- View all logged-in devices (device name, platform, last active time, IP, location)
- **Revoke a session** - Sign out a specific device remotely
- **Sign out all other devices** - One-tap security action
- Current device is always shown at the top
- Sessions are tracked per device ID and synced with FCM tokens

---



### Dashboard Overview
- **Platform Health** - Active users, growth metrics
- **Revenue Intelligence** - MRR, ARR, churn rate, plan-wise breakdown, upcoming renewals
- **Alert System** - Real-time critical alerts
- **Churn Prediction** - At-risk library identification
- **Feature Analytics** - Feature adoption and usage across the platform
- **Affiliate Analytics** - Referral program performance metrics
- **Student Analytics** - Platform-wide student engagement insights

### Churn & Retention

| Risk Category | Criteria |
|---------------|----------|
| Inactive 7+ days | No login for 7 days |
| Inactive 14+ days | No login for 14 days |
| Inactive 30+ days | No login for 30 days |
| Trial Expired | Trial ended, not subscribed |
| Low Usage | Minimal student activity |

### Retention Tools
- **Extend Trial** - Give more free days
- **Apply Discount** - One-time discount offer
- **WhatsApp Outreach** - Direct contact link
- **Admin Notes** - Track interactions

### Alert Types

| Alert | Severity | Trigger |
|-------|----------|---------|
| Seat Limit Breach | Warning | Library exceeds subscription seats |
| Payment Failure | Critical | Subscription payment failed |
| DAU Drop | Warning | Daily active users dropped significantly |
| Owner Inactivity | Info | Owner hasn't logged in |
| Renewal Soon | Info | Subscription expiring in 7 days |
| Trial Expiring | Warning | Trial ending in 3 days |

---

## 🔔 Push Notifications

### FCM Token Management

The app automatically syncs FCM tokens:
- On app initialization
- After successful login
- When token refreshes
- When user profile is updated

Tokens are stored in Firestore under `fcm_tokens` collection.

### Notification Types

| Type | Trigger | Recipient |
|------|---------|-----------|
| Expiry Reminder | Owner sends | Students with expiring memberships |
| Payment Reminder | Owner sends | Students with pending payments |
| Broadcast | Admin sends | All platform users |
| Subscription Approved | Admin action | Owner |
| Subscription Rejected | Admin action | Owner |
| Payment Approved | Owner action | Student |
| Payment Rejected | Owner action | Student |

### WhatsApp Integration

- Bulk WhatsApp message sending
- Custom message templates
- Daily send limit tracking
- Queue management for bulk sends

### Cloud Functions

```bash
# Deploy functions
cd functions && npm install
firebase deploy --only functions
```

Functions:
- `sendNotification` - Triggered on document creation
- `sendBatchNotifications` - HTTP callable for bulk sends

---

## 🧪 Testing

### Test Coverage

| Layer | Files | Description |
|-------|-------|-------------|
| Domain Entities | 8 | Entity behavior tests |
| Domain Use Cases | 85 | Business logic tests |
| Data Repositories | 5 | Mocked Firestore tests |
| Presentation | 11 | Bloc/Cubit tests |

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/domain/usecases/check_in_test.dart

# Run domain tests only
flutter test test/domain/
```

### Test Guidelines

- No Firebase imports in domain tests (mock repositories)
- No Flutter imports in domain layer
- Test happy path + all edge cases
- Test reserved vs occupied seat logic
- Naming: `should_<expected>_when_<condition>`

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x
- Dart 3.10+
- Firebase project configured
- Razorpay account (for payments)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd library_manager
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add `google-services.json` (Android) in `android/app/`
   - Add `GoogleService-Info.plist` (iOS) in `ios/Runner/`

4. **Configure Razorpay (App Default)**
   - Update keys in `lib/core/di/injection_container.dart`
   - Owners can optionally add their own keys via Library Settings

5. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 🌐 Web Landing Page

The project includes a responsive marketing landing page for web browsers.

### Running Web Locally

```bash
# Run web app
flutter run -d chrome

# Build for production
flutter build web --release
```

### Web Landing Features

- ✅ Responsive design (mobile, tablet, desktop)
- ✅ Hero section with app mockup
- ✅ Features showcase
- ✅ Screenshots carousel
- ✅ Pricing information
- ✅ Testimonials
- ✅ Contact form (saves to Firestore + email notification)
- ✅ SEO optimized (meta tags, OG tags, structured data)
- ✅ App download CTA buttons

### Assets Setup

Place your landing page assets in:
- `assets/web_landing/logos/` - App logos
- `assets/web_landing/screenshots/` - App screenshots

### Deploying to Firebase Hosting

```bash
# Build and deploy
flutter build web --release
firebase deploy --only hosting

# Custom domain: https://librarytrack.in
```

---

## 📦 Dependencies

### Core

| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management (BLoC/Cubit) |
| `get_it` | Dependency injection |
| `go_router` | Declarative navigation |
| `dartz` | Functional programming (`Either`) |
| `equatable` | Value equality |
| `freezed_annotation` | Immutable classes |

### Firebase

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Phone authentication |
| `cloud_firestore` | Database |
| `firebase_messaging` | Push notifications |
| `firebase_crashlytics` | Crash reporting |
| `firebase_remote_config` | Feature flags & force update |
| `firebase_storage` | File storage |
| `cloud_functions` | Cloud Functions calls |

### Payments & PDF

| Package | Purpose |
|---------|---------|
| `razorpay_flutter` | Payment gateway |
| `url_launcher` | UPI app deep linking |
| `pdf` | PDF generation |
| `printing` | PDF preview & print |
| `share_plus` | File sharing |
| `pdfx` | PDF to image rendering |
| `syncfusion_flutter_pdf` | PDF page extraction & manipulation |
| `gal` | Save images/files to gallery |

### Location & Charts

| Package | Purpose |
|---------|---------|
| `geolocator` | Location services |
| `geocoding` | Address lookup |
| `fl_chart` | Charts & graphs |

### Storage & Utilities

| Package | Purpose |
|---------|---------|
| `shared_preferences` | Local storage |
| `path_provider` | File paths |
| `connectivity_plus` | Network status |
| `package_info_plus` | App version info |
| `device_info_plus` | Device information & session tracking |
| `image_picker` | Image selection |
| `file_picker` | File selection |
| `excel` | Excel file parsing for bulk import |
| `google_mlkit_text_recognition` | On-device OCR |
| `flutter_image_compress` | Image compression |
| `fluttertoast` | Toast notifications |
| `qr_flutter` | QR code generation |
| `crypto` | Hashing utilities |
| `uuid` | UUID generation |
| `in_app_review` | Prompt in-app store review |

### Ads

| Package | Purpose |
|---------|---------|
| `google_mobile_ads` | AdMob banners (hidden for premium students) |

### Notifications

| Package | Purpose |
|---------|---------|
| `flutter_local_notifications` | Local notifications |

### Testing

| Package | Purpose |
|---------|---------|
| `mockito` | Mocking |
| `mocktail` | Alternative mocking |
| `bloc_test` | Bloc/Cubit testing |
| `fake_cloud_firestore` | Firebase mocking |

---

## 📝 Architecture Principles

1. **Separation of Concerns** — Each layer has a single responsibility
2. **Dependency Inversion** — High-level modules don't depend on low-level modules
3. **Single Source of Truth** — State is managed in one place
4. **Immutability** — Entities and state are immutable
5. **Explicit Error Handling** — Use `Either<Failure, T>` not exceptions
6. **Testability** — All business logic is unit testable
7. **Slot-Awareness** — Seat availability is per slot (morning/evening/custom)

---

## 📋 Version Notes

### Current Version: 46.0.1+73

### Latest Features (v46.x)
- ✅ **Job Alerts** - Curated government/exam job feed with category/state filtering, saved jobs, and apply tracking
- ✅ **Current Affairs** - AI-generated daily exam prep news with bookmarks and likes
- ✅ **AI Quiz** - Generate MCQ quizzes from any study text; full quiz history
- ✅ **AI Chat** - In-app AI assistant for student study queries
- ✅ **Tools Dashboard** - OCR, image compress, images-to-PDF, PDF-to-images, PDF page extractor, QR generator
- ✅ **Student Premium** - Paid ad-free subscription for students (₹49/month via Razorpay)
- ✅ **Notices System** - Owner posts targeted announcements with scheduling, attachments, and push notifications
- ✅ **Expense Tracking** - Record and categorise library running costs
- ✅ **Referral System** - Owner referral program with wallet credits, free months, and withdrawal requests
- ✅ **Device Session Management** - View and revoke active login sessions per device
- ✅ **Promo Offers** - Admin creates targeted promos for owners and students
- ✅ **Admin: Jobs Management** - Post and manage student-facing job alerts
- ✅ **Admin: Current Affairs Management** - Publish and manage daily news articles
- ✅ **Admin: Withdrawal Approvals** - Process referral wallet payouts
- ✅ **Admin: Feature, Affiliate & Student Analytics** - Expanded analytics coverage
- ✅ **Revenue Intelligence** - MRR, ARR, plan-wise breakdown, failed renewals, revenue at risk
- ✅ **Owner Attendance** - Owners can mark and review their own attendance
- ✅ **AdMob Integration** - Banner ads shown to free students, hidden for premium
- ✅ **In-App Review** - Prompt users to rate the app at key moments

### Previous Highlights
- ✅ **Hourly Activity Drill-Down** - Admin can see which users were active in any given hour
- ✅ **User Activity Timeline** - Track individual user activity over custom date ranges
- ✅ **Invoice Deletion** - Delete invoices with automatic payment cleanup
- ✅ **Bulk Import** - Import multiple students via Excel
- ✅ **Owner Subscription System** - Seat-based pricing with trial period
- ✅ **Admin Intelligence Dashboard** - Churn prediction, retention tools
- ✅ **Student ID Card Generation** - Generate downloadable ID cards
- ✅ **Student Document Verification** - Upload and approve documents
- ✅ **Unified Notifications** - Combined Push + WhatsApp reminders
- ✅ **Custom Slot Management** - Flexible time slots per library
- ✅ **Coupon System** - Discount coupons for owner subscriptions
- ✅ **Force Update** - Version gating via Remote Config
- ✅ **Admin Broadcast** - Platform-wide announcements
- ✅ **FCM Push Notifications** - End-to-end notification system
- ✅ **WhatsApp Reminders** - Bulk/individual message sending
- ✅ UPI direct payment with owner approval workflow
- ✅ Revenue Analytics dashboard with charts
- ✅ Dual Razorpay key support (owner's or app's)
- ✅ Separated Cash & UPI approval queues
- ✅ Switch from pending cash/UPI to online payment

### V1 Constraints
- Single library per owner
- No seat deletion (only cancel membership)
- Fixed + custom slot timings

---

## 📄 License

This project is proprietary software.

---

<p align="center">
  Built with ❤️ using Flutter & Clean Architecture
</p>
