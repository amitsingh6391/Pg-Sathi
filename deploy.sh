#!/bin/bash
# PG Sathi — Full Deploy Script
# Builds a static landing page (fast load) + Flutter web app at /app/

set -e

# Force IPv4 for Node.js to avoid IPv6 timeout issues with Firebase/Google APIs
export NODE_OPTIONS="--dns-result-order=ipv4first"

echo "🚀 Starting deployment process..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if logged in to Firebase, re-authenticate if needed
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo "⚠️  Firebase authentication issue detected. Re-authenticating..."
    firebase login --reauth
    
    # Verify login succeeded
    if ! firebase projects:list &> /dev/null; then
        echo "❌ Firebase authentication failed. Please try manually:"
        echo "   firebase logout"
        echo "   firebase login"
        exit 1
    fi
fi

echo "✅ Firebase authentication verified"

# Clean and get dependencies
echo "📦 Cleaning and getting dependencies..."
flutter clean
flutter pub get

# Build Flutter web app with /app/ base path
echo "🔨 Building Flutter web app (base-href=/app/)..."
flutter build web --release --base-href=/app/

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed. Please check errors above."
    exit 1
fi
echo "✅ Flutter build successful!"

# Assemble deployment directory
echo "📁 Assembling deployment directory..."
rm -rf build/deploy
mkdir -p build/deploy/app

# 1. Copy static landing page to root
cp landing/index.html build/deploy/index.html

# 2. Copy shared web assets (favicon, icons, manifest, ads.txt)
cp web/favicon.png build/deploy/favicon.png
cp web/manifest.json build/deploy/manifest.json
cp web/app-ads.txt build/deploy/app-ads.txt
cp -r web/icons build/deploy/icons

# 3. Copy landing page assets (logos, screenshots)
mkdir -p build/deploy/assets/web_landing
cp -r assets/web_landing/logos build/deploy/assets/web_landing/logos
cp -r assets/web_landing/screenshots build/deploy/assets/web_landing/screenshots

# 4. Copy Flutter web build to /app/ subdirectory
cp -r build/web/* build/deploy/app/

echo "✅ Deployment directory assembled!"
echo "   📄 Landing page → build/deploy/index.html (root /)"
echo "   🎯 Flutter app  → build/deploy/app/ (/app/)"

# Deploy to Firebase
echo "📤 Deploying to Firebase Hosting..."
firebase deploy --only hosting
echo ""
echo "✅ Deployment complete!"
echo "🌐 Your site is available at:"
echo "   - https://pg-sathi.web.app        (fast landing page)"
echo "   - https://pg-sathi.web.app/app/   (Flutter web app)"
