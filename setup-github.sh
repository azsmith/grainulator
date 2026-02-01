#!/bin/bash

# Grainulator GitHub Setup Script
# This script helps you authenticate and create the GitHub repository

set -e  # Exit on error

echo "================================================"
echo "Grainulator GitHub Repository Setup"
echo "================================================"
echo ""

# Step 1: Authenticate with GitHub
echo "Step 1: Authenticating with GitHub..."
echo "You'll be prompted to log in to GitHub."
echo ""

gh auth login

echo ""
echo "✓ Authentication complete!"
echo ""

# Step 2: Create the repository
echo "Step 2: Creating GitHub repository..."
echo ""

cd ~/projects/grainulator

gh repo create grainulator \
  --public \
  --description "A sophisticated macOS granular synthesis application with multi-track capabilities" \
  --source=. \
  --remote=origin

echo ""
echo "✓ Repository created!"
echo ""

# Step 3: Push the code
echo "Step 3: Pushing code to GitHub..."
echo ""

git push -u origin main

echo ""
echo "================================================"
echo "✓ Setup Complete!"
echo "================================================"
echo ""
echo "Your repository is now available at:"
gh repo view --web
echo ""
echo "Next steps:"
echo "  1. Add topics/labels on GitHub"
echo "  2. Configure branch protection (optional)"
echo "  3. Enable Discussions (optional)"
echo ""
