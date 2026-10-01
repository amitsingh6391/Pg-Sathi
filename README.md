# PG Sathi

PG Sathi is a Flutter-based PG and hostel management application for owners, tenants, and admins.

## What this project does

This app helps manage the full lifecycle of a PG business:

- Owner dashboard for managing rooms, beds, and tenants
- Tenant onboarding and stay management
- Rent/payment tracking with online, cash, and UPI flows
- Attendance tracking for members
- Notice board and communication features
- Revenue analytics and financial reporting
- Subscription management and trial flow
- Admin monitoring and approval system
- Push notifications and deep linking

## Main users

### Owner
- Create and manage PG profile
- Assign rooms/beds to tenants
- Track occupancy and reservations
- Approve payments and manage dues
- View revenue and analytics
- Send notices and reminders
- Manage subscriptions and invoices

### Tenant
- Sign in and manage profile
- View assigned PG stay details
- Pay fees through available payment modes
- Check attendance and invoices
- Upload documents
- Read notices and updates

### Admin
- Review platform activity
- Manage subscriptions and coupons
- Monitor revenue and user growth
- Approve withdrawals and promotions
- Handle platform-wide notifications

## Tech stack

- Flutter + Dart
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Firebase Messaging
- Firebase Analytics
- Firebase Crashlytics
- Firebase Remote Config
- Flutter Bloc / Cubit
- GoRouter
- Razorpay
- SharedPreferences
- PDF and file handling libraries

## Architecture

The project follows a clean layered architecture:

- Presentation layer: screens, widgets, and state management
- Domain layer: business logic and use cases
- Data layer: repositories and Firebase integrations

## Project structure

```text
lib/
├── core/
├── data/
├── domain/
├── presentation/
├── main.dart
├── firebase_options.dart
└── ...
```

## Features implemented

- Role-based authentication
- PG profile and room management
- Tenant membership workflow
- Payment approval system
- Invoice generation and PDF support
- Attendance tracking
- Notifications and deep links
- Analytics dashboards
- Subscription and trial handling
- Referral and promo support
- Admin oversight tools

## Setup

### Prerequisites
- Flutter SDK
- Android Studio / VS Code
- Firebase project
- Emulator or physical device

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Test

```bash
flutter test
```

## Summary

PG Sathi is a complete PG management platform built in Flutter with Firebase, covering operations for owners, tenants, and admins in one app.

It is designed as a production-ready multi-role system with real business workflows, analytics, payments, and notifications.

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
- Ask study-related queries d
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
