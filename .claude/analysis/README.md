Last Modified: 08/10/2026 (1786502400) by amonrit

# 📊 Dependency Analysis System

This system automatically analyzes and tracks Swift code dependencies across commits, helping you:

✅ **Verify commit correctness** — See what changed and why  
✅ **Track architecture** — Monitor how dependencies evolve  
✅ **Revert with confidence** — See exactly what was different in old versions  
✅ **Detect issues early** — Catch architecture violations and circular dependencies  

---

## 🚀 Quick Start

### 1. Install Pre-Commit Hook

```bash
chmod +x .claude/analysis/setup-hook.sh
./.claude/analysis/setup-hook.sh
```

This will auto-generate a dependency snapshot **before every commit**.

### 2. View Current Dependencies

```bash
cat .claude/analysis/dependency-map.md
```

**Output:** Human-readable dependency graph with:
- File dependencies
- Framework imports
- Architecture layers
- Key relationships

### 3. List All Snapshots

```bash
python3 .claude/analysis/snapshot-manager.py list
```

Shows all snapshots with commit info and file counts.

### 4. Compare Two Commits

```bash
# Compare a specific commit to current HEAD
python3 .claude/analysis/snapshot-manager.py compare abc123

# Compare two commits
python3 .claude/analysis/snapshot-manager.py compare abc123 def456
```

**Output:** 
- ✨ New files added
- ❌ Files removed
- ⚠️ Dependencies changed (imports added/removed)

---

## 📁 Directory Structure

```
.claude/analysis/
├── analyze-dependencies.py       ← Main analyzer (Swift dependency extraction)
├── snapshot-manager.py           ← Snapshot versioning & comparison
├── setup-hook.sh                 ← Hook installation script
├── dependency-map.json           ← Current state (machine-readable)
├── dependency-map.md             ← Current state (human-readable)
└── history/
    ├── abc123.json               ← Snapshot for commit abc123
    ├── def456.json               ← Snapshot for commit def456
    └── ...
```

---

## 📊 How It Works

### 1. Dependency Analysis (`analyze-dependencies.py`)

Scans all `.swift` files and extracts:

```swift
// Extracts:
import AVFoundation              ← Framework dependency
import Combine
import Foundation

class PlaybackViewModel {         ← Local type definition
    let worker: VideoPlayerWorker ← Local dependency
    var state: PlaybackState      ← Local dependency
}
```

**Generates:**

```json
{
  "files": {
    "ViewModels/PlaybackViewModel.swift": {
      "imports": {
        "apple": ["AVFoundation", "Combine", "Foundation"],
        "local": [],
        "external": []
      },
      "references": ["VideoPlayerWorker", "PlaybackState"],
      "total_imports": 3
    }
  },
  "graph": {
    "nodes": [...],
    "edges": [...]
  }
}
```

### 2. Snapshot Versioning (`snapshot-manager.py`)

Each commit gets a snapshot:
- **Stored by:** Git commit hash (e.g., `abc123.json`)
- **Contains:** Full dependency state + git metadata
- **Allows:** Time-travel analysis — see what dependencies were at any commit

### 3. Pre-Commit Hook

```bash
# Before committing:
git add MyFile.swift
git commit -m "feat: add new feature"

# Automatically:
# 1. Analyzes dependencies
# 2. Saves snapshot to history/abc123.json
# 3. Updates dependency-map.json and dependency-map.md
```

---

## 🔍 Analysis Details

### File Layers

```
steamApp.swift (Entry Point)
    ↓
ContentView.swift (UI Coordinator)
    ├─ PlaybackViewModel (State)
    ├─ VideoPlayerView (Player UI)
    └─ FullScreenPlayerView (Full-screen UI)

PlaybackViewModel (Business Logic)
    ├─ VideoPlayerWorker (KVO Observers)
    ├─ PlaybackState (State Model)
    └─ VideoStream (Data Model)

VideoPlayerWorker (Utilities)
    └─ (Pure logic, no project dependencies)
```

### Dependency Metrics

| Metric | Value |
|--------|-------|
| **Total Files** | 8 Swift files |
| **Average Imports** | ~3-4 per file |
| **Apple Frameworks** | 6 (Foundation, AVFoundation, SwiftUI, Combine, AVKit, os) |
| **Local Dependencies** | ~2 per file on average |
| **Circular Dependencies** | ✅ None detected |

---

## 💡 Use Cases

### "Did I introduce any new dependencies?"

```bash
# Compare current HEAD to a specific commit
python3 .claude/analysis/snapshot-manager.py compare main

# Output will show:
# ➕ New imports in each file
# ➖ Removed imports
# ✨ New files
# ❌ Deleted files
```

### "What changed in PlaybackViewModel between versions?"

```bash
# Manual check in the snapshots
cd .claude/analysis/history/
diff abc123.json def456.json | grep "PlaybackViewModel" -A 10 -B 10
```

### "This commit is slow — did I break architecture?"

```bash
# Get the snapshot of this commit
python3 .claude/analysis/snapshot-manager.py compare abc123

# Look for:
# ⚠️ Circular dependencies
# ⚠️ Excessive new imports
# ⚠️ Files in wrong layers importing from upper layers
```

### "Revert a commit and understand what broke"

```bash
# Before reverting:
python3 .claude/analysis/snapshot-manager.py compare HEAD~1

# After reverting:
python3 .claude/analysis/snapshot-manager.py compare HEAD~1 HEAD

# See exactly what dependencies were different
```

---

## ⚙️ Configuration

### Exclude Directories

Edit `analyze-dependencies.py`:

```python
exclude_dirs = {'build', '.build', 'Pods', '.swift-version', 'DerivedData'}
```

### Add Custom Frameworks

Edit `categorize_frameworks()` in `analyze-dependencies.py`:

```python
apple_frameworks = {
    'Foundation', 'UIKit', 'SwiftUI', 'AVFoundation', 'AVKit',
    'Combine', 'os', 'MyCustomFramework'  ← Add here
}
```

### Disable Pre-Commit Hook

```bash
# Temporarily
export GIT_SKIP_HOOKS=true
git commit -m "..."

# Permanently
chmod -x .git/hooks/pre-commit
```

---

## 🔧 Troubleshooting

### Hook not running?

```bash
# Check hook exists and is executable
ls -la .git/hooks/pre-commit

# Reinstall
./.claude/analysis/setup-hook.sh
```

### Python script fails?

```bash
# Test manually
python3 .claude/analysis/analyze-dependencies.py

# Check for errors
python3 -m py_compile .claude/analysis/analyze-dependencies.py
```

### Snapshots not saving?

```bash
# Check history directory
ls -la .claude/analysis/history/

# Verify permissions
chmod -R 755 .claude/analysis/history/
```

---

## 📖 Related Documentation

- [[CLAUDE.md]] — Project overview and architecture
- [[docs/ARCHITECTURE.md]] — Deep dive into MVVM pattern
- [[GETTING_STARTED.md]] — Setup guide

---

## 🎯 Next Steps

1. ✅ Install pre-commit hook: `./.claude/analysis/setup-hook.sh`
2. ✅ View dependency map: `cat .claude/analysis/dependency-map.md`
3. ✅ Make a commit and verify snapshot is saved
4. ✅ Compare commits: `python3 .claude/analysis/snapshot-manager.py compare main`

---

**Questions?** Check the snapshots in `.claude/analysis/history/` or review the JSON structure.
