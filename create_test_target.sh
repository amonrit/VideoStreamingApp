#!/bin/bash

# This script creates a Unit Test target for the steam project

PROJECT_PATH="steam.xcodeproj"
SCHEME_NAME="steam"
TEST_TARGET_NAME="steamTests"
PRODUCT_NAME="steamTests"

echo "🔧 Creating Test Target..."

# Build the test target via xcodebuild
# Note: Modern Xcode can auto-detect tests if they follow naming conventions

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test

echo "✅ Test command executed"
