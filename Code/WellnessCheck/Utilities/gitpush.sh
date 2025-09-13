#!/bin/zsh

echo "🔄 Staging changes..."
git add .

echo "📝 Committing with timestamp..."
git commit -m "Update from $(hostname) on $(date '+%Y-%m-%d %H:%M:%S')" || {
    echo "⚠️ Nothing new to commit."
    exit 0
}

echo "📤 Pushing to GitHub..."
git push origin main && echo "✅ Push complete."
