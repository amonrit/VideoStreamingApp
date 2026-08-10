Last Modified: 08/10/2026 (1786502400) by amonrit

# 🎯 Dependency Analysis System - Usage Guide

**ยินดีต้อนรับ!** You now have a complete dependency analysis system that:

✅ Automatically tracks code dependencies  
✅ Creates snapshots with every commit  
✅ Compares versions to spot changes  
✅ Helps verify commit correctness  

---

## 📦 What You Got

### Core Components

| File | Purpose |
|------|---------|
| `analyze-dependencies.py` | Scans Swift files and extracts dependencies |
| `snapshot-manager.py` | Manages versions and comparisons |
| `setup-hook.sh` | Installs pre-commit hook |
| `dependency-map.md` | Human-readable current state (you can read this!) |
| `dependency-map.json` | Machine-readable current state |
| `history/` | All snapshots (one per commit) |

### ✅ Pre-Commit Hook Installed

Every commit now automatically:
1. Analyzes your Swift dependencies
2. Saves a snapshot with the commit hash
3. Updates the human-readable dependency map

---

## 📊 What Your Code Looks Like Right Now

### Current Architecture

```
🏗️  LAYERS:

┌─────────────────────────────────────┐
│  Entry Point: steamApp.swift        │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  UI Coordinator: ContentView         │
├─────────────────────────────────────┤
│  ├─ PlaybackViewModel (State)       │
│  ├─ VideoPlayerView (Player UI)     │
│  └─ FullScreenPlayerView (Full-screen) │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  Business Logic Layer                │
├─────────────────────────────────────┤
│  ├─ PlaybackViewModel               │
│  │  ├─ VideoPlayerWorker (utils)   │
│  │  ├─ PlaybackState (model)       │
│  │  └─ VideoStream (model)         │
└─────────────────────────────────────┘
```

### Key Stats

| Metric | Value |
|--------|-------|
| **Total Swift Files** | 8 |
| **Apple Frameworks** | 6 (Foundation, AVFoundation, SwiftUI, Combine, AVKit, os) |
| **Circular Dependencies** | ✅ None |
| **Architecture Health** | ✅ Good (clean layering) |

---

## 🚀 How to Use It

### 1️⃣ View Current Dependencies

```bash
# Human-readable format
cat .claude/analysis/dependency-map.md

# Machine-readable format
cat .claude/analysis/dependency-map.json | jq .
```

**Output shows:**
- Which files depend on which frameworks
- Local dependencies between files
- Architecture visualization

### 2️⃣ List All Snapshots (Commits Analyzed)

```bash
cd /Users/amonrit/Documents/steam
python3 .claude/analysis/snapshot-manager.py list
```

**Example output:**
```
📋 Available Snapshots:

  0c14f81      | 2026-08-10 18:07:35 | 8 files
```

(Currently you have 1 snapshot — more will be added with each commit)

### 3️⃣ Compare Two Commits (See What Changed)

```bash
# Compare commit 0c14f81 to current HEAD
python3 .claude/analysis/snapshot-manager.py compare 0c14f81

# Compare two specific commits
python3 .claude/analysis/snapshot-manager.py compare 0c14f81 def456
```

**Output shows:**
```
📊 Comparing 0c14f81 → HEAD

✨ New Files (0):
  (none)

❌ Removed Files (0):
  (none)

⚠️  Modified Files (X):
  PlaybackViewModel.swift:
    ➕ Combine          (added)
    ➕ AVFoundation     (added)
    ➖ Foundation       (removed)
```

---

## 🎯 Real-World Scenarios

### Scenario 1: "Did This Commit Break Anything?"

```bash
# After a problematic commit, compare to the previous version
git log --oneline | head -5
# Output: abc123 feat: new feature
#         def456 fix: old commit

python3 .claude/analysis/snapshot-manager.py compare def456
```

**You'll see:**
- ✨ New files added
- ❌ Files removed
- ⚠️ Import changes (were new frameworks added?)
- ⚠️ Reference changes (did dependencies get messed up?)

### Scenario 2: "I Want to Revert — What Will Change?"

```bash
# Check what was different in the commit you want to revert
git log --oneline | grep "the commit I want to revert"
python3 .claude/analysis/snapshot-manager.py compare abc123

# If the dependency changes look fine, revert:
git revert abc123
```

### Scenario 3: "The App Is Slow — Did I Add Too Many Imports?"

```bash
# See all snapshots over time
python3 .claude/analysis/snapshot-manager.py list

# Compare slowness point to a week ago
python3 .claude/analysis/snapshot-manager.py compare old_commit_hash new_commit_hash
```

If there are many ➕ (new imports), that might be the culprit.

### Scenario 4: "Document What Changed Between Versions"

```bash
# For release notes or documentation
python3 .claude/analysis/snapshot-manager.py compare v1.0 v2.0 > CHANGES.txt
```

---

## 🔧 How It Automatically Works

### When You Commit

```bash
$ git add .
$ git commit -m "feat: add new feature"

# Automatically happens:
# 1. Analyzes all Swift files ✅
# 2. Extracts imports & references ✅
# 3. Saves snapshot with commit hash ✅
# 4. Updates dependency-map.md ✅

[main abc123] feat: add new feature
 2 files changed, 50 insertions(+)
🔍 Analyzing dependencies...
✅ Snapshot saved: .claude/analysis/history/abc123.json
```

### The Snapshot Contains

```json
{
  "timestamp": "2026-08-10T18:06:22",
  "files": {
    "ViewModels/PlaybackViewModel.swift": {
      "imports": {
        "apple": ["AVFoundation", "Combine", ...],
        "local": [],
        "external": []
      },
      "references": ["VideoPlayerWorker", "VideoStream"],
      "total_imports": 5
    },
    // ... other files
  },
  "metadata": {
    "git_commit": "abc123",
    "timestamp": 1691234567,
    "date": "2026-08-10 10:00:00"
  }
}
```

---

## 📈 Understanding the Reports

### Dependency Report Example

```markdown
# Swift Dependency Map

## 📁 File Dependencies

### `ViewModels/PlaybackViewModel.swift`

**Apple Frameworks:**
  - `AVFoundation`
  - `Combine`
  - `Foundation`
  - `SwiftUI`
  - `os`

**Local Dependencies:**
  - `PlaybackState`      ← Depends on this model
  - `VideoPlayerWorker`  ← Depends on this utility
  - `VideoStream`        ← Depends on this model
```

**What this means:**
- ✅ PlaybackViewModel uses 5 Apple frameworks (reasonable)
- ✅ It depends on 3 local types (clean architecture)
- ✅ No circular dependencies (ViewModel doesn't depend on Views)

---

## ⚠️ Things to Watch For

### Red Flags (Architecture Issues)

❌ **Circular Dependencies**
```
ViewA → ViewB → ViewA  (DANGER!)
```
Solution: Use a ViewModel/Manager to mediate.

❌ **Views importing Views**
```
ContentView → DetailsView → ComplexView → ContentView
```
Solution: Keep views isolated, use ViewModels to communicate.

❌ **Model importing Views**
```
PlaybackState (Model) → VideoPlayerView (View)
```
Solution: Models should never know about Views.

❌ **Too many framework imports**
```
import Foundation, UIKit, SwiftUI, Combine, AVFoundation, ...
// 10+ imports in one file
```
Solution: Split into smaller files or extract helpers.

### How to Detect

```bash
# Compare snapshots to see when a bad dependency was added
python3 .claude/analysis/snapshot-manager.py compare bad_commit good_commit

# Look for ➕ that shouldn't be there
# Then fix and commit
```

---

## 🛠️ Advanced Usage

### Export Snapshot to CSV (for tracking)

```bash
python3 << 'EOF'
import json
from pathlib import Path

snap_file = Path(".claude/analysis/history/abc123.json")
with open(snap_file) as f:
    data = json.load(f)

for file, deps in data["files"].items():
    imports = deps["imports"]["apple"] + deps["imports"]["local"]
    print(f"{file},{len(imports)},{len(deps['references'])}")
EOF
```

### Find Dependencies Added in the Last N Commits

```bash
ls -lt .claude/analysis/history/*.json | head -5
# Shows 5 most recent snapshots
# Compare them one by one
```

### Delete Old Snapshots (Cleanup)

```bash
# Keep only last 10 commits' snapshots
cd .claude/analysis/history/
ls -t *.json | tail -n +11 | xargs rm -f
```

---

## 📝 Editing & Extending

### Add Custom Framework Categories

Edit `.claude/analysis/analyze-dependencies.py`:

```python
apple_frameworks = {
    'Foundation', 'UIKit', 'SwiftUI', 'AVFoundation',
    'MyCustomFramework'  ← Add here
}
```

Then regenerate:
```bash
python3 .claude/analysis/analyze-dependencies.py
```

### Exclude Directories from Analysis

Edit `.claude/analysis/analyze-dependencies.py`:

```python
exclude_dirs = {
    'build', '.build', 'Pods', 'DerivedData',
    'MyIgnoredDir'  ← Add here
}
```

---

## 🚨 Troubleshooting

### Pre-commit hook not running?

```bash
# Check it exists
ls -la .git/hooks/pre-commit

# Check it's executable
file .git/hooks/pre-commit
# Should say: executable

# Reinstall if needed
bash .claude/analysis/setup-hook.sh
```

### Snapshots not being saved?

```bash
# Test manually
python3 .claude/analysis/analyze-dependencies.py

# Check if it created the files
ls -la .claude/analysis/*.json
ls -la .claude/analysis/history/
```

### Python script not found errors?

```bash
# Ensure python3 is available
which python3
python3 --version  # Should be 3.7+

# Check script permissions
chmod +x .claude/analysis/*.py
```

---

## 🎓 Learning Path

1. **Now:** Read current state
   ```bash
   cat .claude/analysis/dependency-map.md
   ```

2. **Next commit:** Watch pre-commit hook work
   ```bash
   git add .
   git commit -m "test commit"
   # Watch for "✅ Snapshot saved" message
   ```

3. **Compare:** View snapshots
   ```bash
   python3 .claude/analysis/snapshot-manager.py list
   ```

4. **Deep dive:** Read snapshot JSON
   ```bash
   cat .claude/analysis/history/0c14f81.json | jq .
   ```

---

## 📚 Related Documentation

- **[[README.md]]** — Technical deep-dive
- **[[CLAUDE.md]]** — Project overview
- **[[docs/ARCHITECTURE.md]]** — MVVM pattern details

---

## ✨ Summary

**You now have:**

✅ **Auto-tracking** — Every commit snapshots dependencies  
✅ **Comparison** — See what changed between versions  
✅ **History** — Full archive in `.claude/analysis/history/`  
✅ **Reports** — Human-readable `.md` and machine-readable `.json`  
✅ **Analysis** — Detect architecture issues early  

**Next step:** Make a commit and watch the pre-commit hook create a snapshot! 🎉
