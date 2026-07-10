# Deployment Guide for librarytrack.in

## Prerequisites

1. **Node.js and npm** installed
2. **Firebase CLI** installed
3. **Firebase project** configured (academic-master)

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

## Step 2: Login to Firebase

```bash
firebase login
```

## Step 3: Initialize Firebase Hosting

```bash
firebase init hosting
```

When prompted:
- **Select existing project**: Choose `academic-master`
- **Public directory**: `build/web`
- **Single-page app**: Yes
- **Set up automatic builds**: No (or Yes if using CI/CD)
- **Overwrite index.html**: No (we have our own)

## Step 4: Build the Web App

```bash
flutter clean
flutter pub get
flutter build web --release
```

## Step 5: Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

## Step 6: Configure Custom Domain (librarytrack.in)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `academic-master`
3. Go to **Hosting** section
4. Click **Add custom domain**
5. Enter: `librarytrack.in`
6. Follow the DNS configuration steps:
   - Add A record pointing to Firebase IP addresses
   - Add CNAME record if required
   - Wait for DNS propagation (can take up to 48 hours)

### DNS Configuration for librarytrack.in

**In Hostinger DNS Management:**

1. **DELETE existing A record:**
   - Type: A
   - Name: @
   - Points to: 84.32.84.32
   - Action: Delete this record

2. **ADD new A record for Firebase:**
   - Type: A
   - Name: @ (or librarytrack.in)
   - Points to: 199.36.158.100
   - TTL: 14400

3. **ADD TXT record for verification:**
   - Type: TXT
   - Name: @ (or librarytrack.in)
   - Value: hosting-site=academic-master
   - TTL: 300

4. **KEEP existing CNAME records** (for email):
   - All `hostingermail-*._domainkey` records
   - `www` → `librarytrack.in`
   - `autodiscover` records

See `DNS_SETUP.md` for detailed instructions.

## Step 7: SSL Certificate

Firebase automatically provisions SSL certificates for custom domains. This usually takes a few minutes to a few hours.

## Verification

After deployment, verify:
- ✅ https://librarytrack.in loads correctly
- ✅ All assets (images, screenshots) load properly
- ✅ Navigation scrolling works
- ✅ Contact form submits correctly
- ✅ Mobile responsiveness works

## Future Deployments

For future updates, simply run:

```bash
flutter build web --release
firebase deploy --only hosting
```

## Troubleshooting

### Assets not loading
- Check that `pubspec.yaml` has correct asset paths
- Verify assets are in `build/web/assets/` after build
- Clear browser cache

### Domain not working
- Check DNS records are correct
- Wait for DNS propagation (up to 48 hours)
- Verify SSL certificate is active in Firebase Console

### Build errors
- Run `flutter clean` before building
- Ensure all dependencies are installed: `flutter pub get`
- Check Flutter version compatibility

