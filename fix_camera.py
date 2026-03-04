import re

with open('PostureAI.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Add camera usage description after generated info plist
if 'INFOPLIST_KEY_NSCameraUsageDescription' not in content:
    content = content.replace(
        'GENERATE_INFOPLIST_FILE = YES;',
        'GENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Posture AI needs camera access to analyze your posture.";'
    )
    print("Added NSCameraUsageDescription")
else:
    print("Already exists")

with open('PostureAI.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
