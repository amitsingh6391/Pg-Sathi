# Remote Config Troubleshooting Guide

If you're seeing `0.0.0` instead of your configured values, follow these steps:

## Step 1: Verify Firebase Remote Config Setup

### Check Parameter Names (Case-Sensitive!)
Make sure parameter names match **exactly**:
- ✅ `minimum_required_version` (lowercase, with underscores)
- ✅ `force_update_enabled` (lowercase, with underscores)
- ✅ `update_message` (lowercase, with underscores)
- ✅ `update_url` (lowercase, with underscores)

### Check Parameter Types
- `minimum_required_version`: **String** (e.g., `"38.0.0"`)
- `force_update_enabled`: **Boolean** (e.g., `true`)
- `update_message`: **String** (e.g., `"Please update"`)
- `update_url`: **String** (e.g., `"https://play.google.com/..."`)

## Step 2: Verify Values Are Published

1. Go to Firebase Console → Remote Config
2. Check that parameters are **published** (not just saved as draft)
3. Look for green "Published" badge or timestamp

## Step 3: Check App Logs

Run the app and check console logs. You should see:

```
🔧 Remote Config: Fetch and activate result: true
✅ Remote Config: Successfully fetched and activated
📋 Remote Config Values:
  - minimum_required_version: 38.0.0
  - force_update_enabled: true
  - update_message: Please update to continue
  - update_url: 
```

If you see `0.0.0` in logs, Remote Config is using defaults (fetch failed).

## Step 4: Common Issues

### Issue 1: Values Not Published
**Symptom**: Logs show `0.0.0` even after setting values

**Solution**:
1. In Firebase Console, click **"Publish changes"** button
2. Wait a few seconds for propagation
3. Restart the app

### Issue 2: Network/Firebase Not Initialized
**Symptom**: `fetchAndActivate` returns `false`

**Solution**:
- Ensure device has internet connection
- Ensure Firebase is properly initialized
- Check Firebase project is correct

### Issue 3: Parameter Name Mismatch
**Symptom**: Values not updating

**Solution**:
- Double-check parameter names match exactly (case-sensitive)
- No spaces or typos

### Issue 4: Wrong Parameter Type
**Symptom**: Boolean values not working

**Solution**:
- `force_update_enabled` must be **Boolean** type, not String
- Use `true`/`false`, not `"true"`/`"false"`

## Step 5: Test Remote Config Directly

### Option A: Use Firebase Console Test
1. Go to Remote Config → Test
2. Add test device
3. Set test values
4. Run app on test device

### Option B: Force Fetch in Code
Temporarily modify `minimumFetchInterval` to `0` (already done in code) to allow immediate fetches.

## Step 6: Verify Current App Version

Check your `pubspec.yaml`:
```yaml
version: 37.0.0+37
```

The version string is `37.0.0` (part before `+`).

For force update to trigger:
- Set `minimum_required_version` to **higher** than current (e.g., `38.0.0`)
- Set `force_update_enabled: true`

## Step 7: Debug Checklist

- [ ] Parameters added in Firebase Console
- [ ] Parameter names match exactly (case-sensitive)
- [ ] Parameter types are correct (String/Boolean)
- [ ] Values are **published** (not draft)
- [ ] App has internet connection
- [ ] Firebase project is correct (`academic-master`)
- [ ] App version in `pubspec.yaml` is lower than `minimum_required_version`
- [ ] `force_update_enabled` is set to `true`
- [ ] Check console logs for Remote Config values

## Quick Test

1. **Set in Firebase Console**:
   ```
   minimum_required_version: "99.0.0"
   force_update_enabled: true
   ```

2. **Publish changes**

3. **Run app**:
   ```bash
   flutter run
   ```

4. **Check logs** - Should see:
   ```
   📋 Remote Config Values:
     - minimum_required_version: 99.0.0
     - force_update_enabled: true
   ```

5. **Expected**: Force update dialog appears immediately

## Still Not Working?

1. **Clear app data** and reinstall:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Check Firebase project**: Ensure you're using the correct Firebase project

3. **Verify Remote Config is enabled**: Check Firebase Console → Remote Config is accessible

4. **Check Firebase Rules**: Ensure Remote Config is accessible (should be public by default)

---

**Note**: Remote Config values are cached. After publishing, it may take a few seconds to propagate. The app fetches on startup, so restart the app after publishing changes.

