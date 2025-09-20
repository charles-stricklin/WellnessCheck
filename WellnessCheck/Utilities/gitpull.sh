#!/bin/zsh

cd ~/Library/CloudStorage/GoogleDrive-charlesstricklin@gmail.com/My\ Drive/Documents/Development/iOS/My\ Projects/WellnessCheck/WellnessCheck || {
    echo "❌ Failed to change directory. Make sure the path is correct."
    exit 1
}

echo "📥 Pulling latest changes from GitHub..."

git pull origin main

if [ $? -eq 0 ]; then
    echo "✅ Pull complete."
    echo "🚀 Launching Xcode..."
    open WellnessCheck.xcodeproj
else
    echo "❌ Pull failed. Check for merge conflicts or errors."
fi