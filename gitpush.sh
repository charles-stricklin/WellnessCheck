#!/bin/bash
set -e

# Go to the repo root (not Code/)
cd ~/Documents/Development/iOS/My\ iOS\ Projects/WellnessCheck/

echo ">>> Incrementing version numbers and updating changelogs..."

# Update version numbers in Swift files under Code/
find ./Code -name "*.swift" | while read file; do
  if grep -q "// Version:" "$file"; then
    current=$(grep "// Version:" "$file" | awk '{print $3}')

    num=$(echo "$current" | sed -E 's/v([0-9]+\.[0-9]+)([a-z])/\1/')
    letter=$(echo "$current" | sed -E 's/v([0-9]+\.[0-9]+)([a-z])/\2/')

    newnum=$(printf "%.3f" $(echo "$num + 0.001" | bc))
    new="v${newnum}${letter}"

    echo " - $file: $current → $new"

    sed -i '' "s/$current/$new/" "$file"

    if ! grep -q "/// Added" "$file"; then
      cat <<CHANGELOG >> "$file"

/// Added: 
/// Updated: 
/// Bug Fixes: 

CHANGELOG
    fi
  fi
done

echo ">>> Staging changes..."
git add .

echo ">>> Committing..."
git commit -m "chore: auto-increment version numbers and update changelog placeholders" || echo "No changes to commit."

echo ">>> Ensuring correct remote..."
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/charles-stricklin/WellnessCheck.git

echo ">>> Pushing to GitHub..."
git push origin main

echo ">>> Done. Verify at: https://github.com/charles-stricklin/WellnessCheck"