#!/bin/bash

# Script to copy Razorpay dSYM files to the archive
# This fixes the TestFlight upload error for missing Razorpay dSYM

set -e

echo "Copying Razorpay dSYM files..."

# Find Razorpay dSYM files in Pods
RAZORPAY_DSYM_PATH="${PODS_ROOT}/razorpay-pod/Razorpay.framework.dSYM"
RAZORPAY_CORE_DSYM_PATH="${PODS_ROOT}/razorpay-core-pod/Razorpay.framework.dSYM"

# Destination in the archive
ARCHIVE_DSYM_DIR="${DWARF_DSYM_FOLDER_PATH}"

if [ -d "$RAZORPAY_DSYM_PATH" ]; then
    echo "Found Razorpay dSYM at: $RAZORPAY_DSYM_PATH"
    cp -R "$RAZORPAY_DSYM_PATH" "$ARCHIVE_DSYM_DIR/" || true
fi

if [ -d "$RAZORPAY_CORE_DSYM_PATH" ]; then
    echo "Found Razorpay Core dSYM at: $RAZORPAY_CORE_DSYM_PATH"
    cp -R "$RAZORPAY_CORE_DSYM_PATH" "$ARCHIVE_DSYM_DIR/" || true
fi

echo "Razorpay dSYM copy completed"

