#!/bin/bash
# Pre-commit hook to generate dependency snapshots
# Install: cp .claude/analysis/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -e

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
ANALYSIS_DIR="$PROJECT_ROOT/.claude/analysis"
HISTORY_DIR="$ANALYSIS_DIR/history"
PYTHON_SCRIPT="$ANALYSIS_DIR/analyze-dependencies.py"

# Ensure directories exist
mkdir -p "$HISTORY_DIR"

# Get current git info
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%s)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Run analyzer
echo "🔍 Analyzing dependencies for commit..."
cd "$PROJECT_ROOT"
python3 "$PYTHON_SCRIPT" >/dev/null 2>&1 || {
    echo "⚠️  Warning: Dependency analysis failed"
    exit 0
}

# Save snapshot with commit hash
SNAPSHOT_FILE="$HISTORY_DIR/${COMMIT_HASH}.json"
if [ -f "$ANALYSIS_DIR/dependency-map.json" ]; then
    # Add git metadata to snapshot
    python3 << 'EOF'
import json
from pathlib import Path
from datetime import datetime

analysis_dir = "$PROJECT_ROOT/.claude/analysis"
snapshot_file = "$HISTORY_DIR/${COMMIT_HASH}.json"

# Read the generated map
with open(f"{analysis_dir}/dependency-map.json", "r") as f:
    data = json.load(f)

# Add git metadata
data["git"] = {
    "commit": "$COMMIT_HASH",
    "timestamp": $TIMESTAMP,
    "date": "$DATE"
}

# Write snapshot
Path("$HISTORY_DIR").mkdir(parents=True, exist_ok=True)
with open(snapshot_file, "w") as f:
    json.dump(data, f, indent=2)

print(f"✅ Snapshot saved: {snapshot_file}")
EOF
fi

echo "✅ Dependency snapshot created"
exit 0
