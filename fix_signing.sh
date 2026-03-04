#!/bin/bash
# Fix signing after each xcodegen regeneration

echo "Fixing code signing..."

# Path to the Xcode project
PROJECT_PATH="/Users/kutaygunal/Desktop/PostureAIApp/PostureAI/PostureAI.xcodeproj/project.pbxproj"

# Your Team ID (edit this line with your actual Team ID)
# To find your Team ID:
# 1. Open Xcode
# 2. Preferences (⌘,) > Accounts
# 3. Click on your Apple ID, then the team
# 4. Copy the Team ID (looks like: ABC123DEF4)
TEAM_ID=""

if [ -z "$TEAM_ID" ]; then
    echo "⚠️  Please edit this script and add your DEVELOPMENT_TEAM ID"
    echo "   Open: /Users/kutaygunal/Desktop/PostureAIApp/PostureAI/fix_signing.sh"
    echo ""
    echo "   To find your Team ID:"
    echo "   1. Open Xcode"
    echo "   2. Preferences (⌘,) > Accounts"
    echo "   3. Click on your Apple ID > Team"
    echo "   4. Copy the Team ID"
    echo ""
    echo "   Then set: TEAM_ID=\"YOUR_TEAM_ID_HERE\""
    exit 1
fi

# Replace the team ID in the project file
sed -i '' "s/DEVELOPMENT_TEAM = \"\";/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$PROJECT_PATH"

echo "✅ Code signing fixed with Team ID: $TEAM_ID"
echo ""
echo "Usage after each 'xcodegen generate':"
echo "  ./fix_signing.sh"
