# Force Update Setup Guide

This guide explains how to configure and use the Force Update feature in LibraryTrack.

## Overview

The Force Update feature allows you to:
- **Check app version** on startup
- **Force users to update** if their version is below the minimum required
- **Show a non-dismissible dialog** that redirects users to Play Store/App Store
- **Control everything remotely** via Firebase Remote Config (no app update needed)

## How It Works

1. **On App Start**: The app checks Firebase Remote Config for:
   - `minimum_required_version` - Minimum version users must have
   - `force_update_enabled` - Whether force update is active
   - `update_message` - Custom message to show users
   - `update_url` - Play Store/App Store URL (optional, defaults to your app)

2. **Version Comparison**: Compares current app version with minimum required version

3. **Force Update Dialog**: If update is required AND force update is enabled:
   - Shows a non-dismissible dialog
   - Prevents app usage until update
   - "Update Now" button opens Play Store/App Store

## Firebase Remote Config Setup

### Step 1: Open Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `academic-master`
3. Navigate to **Remote Config** (under Build → Remote Config)

### Step 2: Add Parameters

Add the following parameters:

#### 1. `minimum_required_version`
- **Type**: String
- **Default Value**: `0.0.0` (allows all versions)
- **Description**: Minimum app version required (e.g., `37.0.0`)
- **Example**: `37.0.0`

#### 2. `force_update_enabled`
- **Type**: Boolean
- **Default Value**: `false`
- **Description**: Enable/disable force update
- **Example**: `true` (to enable force update)

#### 3. `update_message` (Optional)
- **Type**: String
- **Default Value**: `""` (empty)
- **Description**: Custom message shown to users
- **Example**: `"A critical update is available. Please update to continue using LibraryTrack."`

#### 4. `update_url` (Optional)
- **Type**: String
- **Default Value**: `""` (empty)
- **Description**: Custom Play Store/App Store URL
- **Example**: `"https://play.google.com/store/apps/details?id=com.academic.master"`
- **Note**: If empty, defaults to your app's Play Store URL

### Step 3: Publish Changes

1. Click **"Publish changes"** to activate the configuration
2. Changes take effect immediately (no app restart needed)

## Example Configuration

### Scenario: Force Update for Version 38.0.0

```
minimum_required_version: "38.0.0"
force_update_enabled: true
update_message: "A new version with important security updates is available. Please update now."
update_url: "" (uses default Play Store URL)
```

### Scenario: Disable Force Update

```
minimum_required_version: "0.0.0"
force_update_enabled: false
update_message: ""
update_url: ""
```

## Version Format

- **Format**: `MAJOR.MINOR.PATCH` (e.g., `37.0.0`)
- **Comparison**: Semantic versioning (37.0.0 < 38.0.0)
- **Current Version**: Read from `pubspec.yaml` → `version: 37.0.0+37`
  - The part before `+` is the version string (`37.0.0`)

## Testing Force Update

### Test Locally

1. **Set Remote Config values**:
   - `minimum_required_version`: Set to a version higher than current (e.g., `99.0.0`)
   - `force_update_enabled`: `true`

2. **Run the app**:
   ```bash
   flutter run
   ```

3. **Expected Behavior**:
   - Dialog appears immediately on app start
   - Dialog cannot be dismissed
   - "Update Now" button opens Play Store

### Test in Production

1. **Gradual Rollout** (Recommended):
   - Start with `force_update_enabled: false`
   - Monitor app usage
   - Enable force update when ready

2. **Full Force Update**:
   - Set `minimum_required_version` to new version
   - Set `force_update_enabled: true`
   - Publish changes

## Best Practices

1. **Version Bumping**: Always increment version in `pubspec.yaml` before releasing:
   ```yaml
   version: 38.0.0+38  # Increment both version and build number
   ```

2. **Gradual Rollout**: Test force update with a small percentage first (if using Remote Config conditions)

3. **Clear Messages**: Provide clear, user-friendly update messages

4. **Fallback Behavior**: If Remote Config fails to fetch, app continues normally (fail gracefully)

5. **Monitor**: Check Firebase Remote Config dashboard for fetch success rates

## Troubleshooting

### Force Update Not Showing

1. **Check Remote Config**:
   - Verify parameters are published
   - Check parameter names (case-sensitive)
   - Verify `force_update_enabled` is `true`

2. **Check Version Comparison**:
   - Current version must be **less than** minimum required
   - Example: Current `37.0.0`, Minimum `38.0.0` → Update required

3. **Check Network**:
   - Remote Config requires internet connection
   - First fetch may take a few seconds

### Dialog Not Dismissible

- **This is intentional** - Force update dialogs should not be dismissible
- Users must update to continue using the app

### Update Button Not Working

1. **Check URL**: Verify `update_url` is correct
2. **Check Platform**: Ensure Play Store/App Store is available on device
3. **Check Permissions**: App needs permission to open external URLs

## Code Structure

### Domain Layer
- `lib/domain/entities/app_version.dart` - Version entity
- `lib/domain/repositories/version_repository.dart` - Repository interface
- `lib/domain/usecases/check_version_update.dart` - Use case

### Data Layer
- `lib/data/repositories/version_repository_impl.dart` - Firebase Remote Config implementation

### Presentation Layer
- `lib/presentation/core/cubit/version_check_cubit.dart` - State management
- `lib/presentation/core/widgets/force_update_dialog.dart` - UI dialog

## Integration Points

- **App Initialization**: `lib/main.dart` - Checks version on startup
- **Dependency Injection**: `lib/core/di/injection_container.dart` - Registers services

## Security Notes

- Remote Config values are **public** (not encrypted)
- Don't store sensitive data in Remote Config
- Version checking is client-side (can be bypassed by determined users)
- For critical security updates, consider server-side validation

---

**Need Help?** Check Firebase Remote Config documentation or contact support.

