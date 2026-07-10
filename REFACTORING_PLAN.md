# Library Manager - Refactoring Plan

## Executive Summary

This document outlines the comprehensive refactoring plan for the Library Manager codebase. The refactoring is focused on improving maintainability, reducing file sizes, removing duplicate code, and enforcing clean architecture principles.

**⚠️ CRITICAL: No feature changes, no UI/UX changes, no API contract changes.**

---

## Phase 1: Large File Splitting (Priority: HIGH)

### Files Requiring Immediate Attention

| File | Lines | Action Required |
|------|-------|-----------------|
| `occupied_seats_screen.dart` | 3,719 | Split into 8+ widget files |
| `profile_screen.dart` | 1,461 | Split into 4+ widget files |
| `library_form_screen.dart` | 1,338 | Split into 3+ widget files |
| `payment_screen.dart` | 1,269 | Split into 3+ widget files |
| `attendance_details_screen.dart` | 1,257 | Split into 3+ widget files |
| `injection_container.dart` | 1,085 | Split by domain (auth, library, payment, etc.) |

### Extraction Plan for `occupied_seats_screen.dart`

Create folder: `lib/presentation/owner/widgets/occupied_seats/`

Extract the following widgets:
1. `occupied_seats_list.dart` - `_OccupiedSeatsList` widget
2. `student_card.dart` - `_StudentCard` widget
3. `convert_payment_bottom_sheet.dart` - `_ConvertPaymentBottomSheet` widget
4. `student_details_sheet.dart` - `_StudentDetailsSheet` widget
5. `occupied_seats_empty_views.dart` - Empty/Error/Search views ✅ DONE
6. `invoices_section.dart` - `_InvoicesSection` and `_InvoiceCard`
7. `documents_section.dart` - `_DocumentsSection` and `_DocumentCard`
8. `image_viewer_screen.dart` - `_ImageViewerScreen`

---

## Phase 2: Duplicate Code Removal (Priority: HIGH)

### Identified Duplicates

1. **AttendanceBloc vs AttendanceCubit**
   - Location: `lib/presentation/student/bloc/attendance_bloc.dart`
   - Status: Marked as "legacy" in comments
   - Action: Remove `AttendanceBloc` after verifying `AttendanceCubit` covers all use cases
   - Files to update:
     - `injection_container.dart`
     - `attendance_card.dart` (student widgets)

2. **Attendance Card Widgets**
   - `lib/presentation/owner/widgets/attendance_card.dart` (875 lines)
   - `lib/presentation/student/widgets/attendance_card.dart` (540 lines)
   - Action: Evaluate if these can share common components

---

## Phase 3: Unused Code Removal (Priority: MEDIUM)

### Confirmed Unused Elements

| File | Element | Type |
|------|---------|------|
| `mark_owner_attendance.dart` | `_getSlotStartTime` | Method |
| `owner_attendance_management_cubit.dart` | `_isToday` | Method |
| `library_details_screen.dart` | `isHighlighted` parameter | Parameter |

---

## Phase 4: Deprecation Fixes (Priority: MEDIUM)

### `withOpacity` Deprecation (300+ occurrences)

Replace all instances of:
```dart
color.withOpacity(0.5)
```
With:
```dart
color.withValues(alpha: 0.5)
```

### Other Deprecations

| Deprecated | Replacement | Files Affected |
|------------|-------------|----------------|
| `WillPopScope` | `PopScope` | `force_update_dialog.dart` |
| `desiredAccuracy` | `LocationSettings` | `location_service_impl.dart` |
| `translate` | `translateByVector3` | `contact_section.dart`, `fullscreen_image_viewer.dart` |
| `scale` | `scaleByDouble` | `seat_grid_screen.dart`, `fullscreen_image_viewer.dart` |

---

## Phase 5: Architecture Violations (Priority: MEDIUM)

### Direct Repository Access in Presentation Layer

Found in `occupied_seats_screen.dart`:
```dart
final membershipRepo = sl<MembershipRepository>();
```

**Fix**: Move this logic to the Cubit/BLoC layer.

### Print Statements in Production Code

Files with `print()` calls that should use proper logging:
- `main.dart`
- `fcm_token_service.dart`
- `local_notification_service.dart`
- `version_repository_impl.dart`
- `phone_auth_cubit.dart`
- `version_check_cubit.dart`
- `contact_form_cubit.dart`

---

## Phase 6: DI Container Split (Priority: LOW)

Split `injection_container.dart` (1,085 lines) into:

```
lib/core/di/
├── injection_container.dart (main entry, imports all modules)
├── modules/
│   ├── external_module.dart (Firebase, SharedPrefs, etc.)
│   ├── service_module.dart (Services registration)
│   ├── repository_module.dart (Repository bindings)
│   ├── auth_module.dart (Auth use cases and blocs)
│   ├── library_module.dart (Library use cases and blocs)
│   ├── membership_module.dart (Membership use cases and blocs)
│   ├── payment_module.dart (Payment use cases and blocs)
│   ├── attendance_module.dart (Attendance use cases and blocs)
│   ├── admin_module.dart (Admin use cases and blocs)
│   └── student_module.dart (Student use cases and blocs)
```

---

## Testing Requirements

After each phase:
1. Run `flutter analyze` - must pass with no errors
2. Run `flutter test` - all existing tests must pass
3. Manual verification of critical flows:
   - Seat assignment
   - Payments (cash, UPI, partial)
   - Memberships
   - Attendance
   - Invoices
   - Notifications

---

## Implementation Order

1. ✅ Analysis complete
2. ✅ Empty views extracted for occupied_seats
3. 🔄 Continue extracting occupied_seats widgets
4. ⏳ Remove legacy AttendanceBloc
5. ⏳ Fix withOpacity deprecations
6. ⏳ Remove unused code
7. ⏳ Split injection_container
8. ⏳ Final verification

---

## Notes

- All changes are incremental
- Each widget extraction should be followed by verification
- Maintain backward compatibility
- No new features or behavior changes
