# Antigravity + Claude Code Integration Guide

This guide explains how to use GitHub's Antigravity tools with Claude Code for this Steam project.

---

## What is Antigravity?

Antigravity is GitHub's code understanding and semantic analysis tool that:
- **Understands code semantics** - Not just pattern matching
- **Finds relationships** - See how code connects
- **Traces data flow** - Understand what data moves where
- **Builds indexes** - Fast code search and analysis
- **Integrates with Claude** - Powers better AI suggestions

---

## Setup

### 1. Enable Antigravity in Claude Code

Antigravity is enabled in `.claude/settings.json`:

```json
"antigravity": {
  "enabled": true,
  "codeUnderstandingMode": "semantic",
  "semanticIndexing": true,
  "indexedPaths": [
    "steam/ViewModels/",
    "steam/Views/",
    "steam/Models/",
    "steam/Workers/",
    "streaming/"
  ]
}
```

### 2. Verify Configuration

```bash
# Check that semantic analysis is active
cat .claude/settings.json | grep antigravity

# Verify indexed paths contain your code
ls -la steam/ViewModels/
ls -la steam/Views/
```

### 3. Initialize Index (First Time)

When you first open the project:
1. Claude Code loads `.claude/settings.json`
2. Antigravity scans indexed paths
3. Semantic index is built (~30-60 seconds)
4. Code relationships are mapped

---

## How to Use Antigravity with Claude Code

### Finding Code Relationships

**Ask Claude Code:**
```
"Where is PlaybackViewModel used in the codebase?"
"What calls loadStream()?"
"Show me all references to @Published variables"
"Trace the data flow from ContentView to AVPlayer"
```

**Antigravity will:**
1. Scan semantic index
2. Find all references and relationships
3. Show call graphs
4. Display data flow paths

### Understanding Architecture

**Ask Claude Code:**
```
"Map out the MVVM dependencies in this project"
"Show the relationship between ViewModels and Workers"
"How does data flow from VideoStream to playback?"
"Which Views depend on PlaybackViewModel?"
```

**Antigravity will:**
1. Analyze MVVM structure
2. Show component relationships
3. Identify dependencies
4. Suggest architectural improvements

### Debugging Issues

**Ask Claude Code:**
```
"Why is bufferingCount always 0?"
"Trace the flow of isLoading state from ViewModel to View"
"Where is currentStream modified?"
"Find all places that call setupObservers()"
```

**Antigravity will:**
1. Find all assignments and mutations
2. Show control flow
3. Identify state changes
4. Highlight potential bugs

### Refactoring Code

**Ask Claude Code:**
```
"What would break if I renamed PlaybackViewModel?"
"Show all files that import VideoPlayerWorker"
"Find unused private methods"
"Which constants are used only once?"
```

**Antigravity will:**
1. Find all references
2. Show impact analysis
3. Identify dead code
4. Suggest refactoring targets

---

## Semantic Analysis Features

### Type Resolution
Antigravity understands:
- Type definitions (class, struct, enum)
- Protocol conformances
- Generic type parameters
- Optional types

Example:
```swift
// Antigravity understands the full type:
@Published var currentStream: VideoStream?

// Can find:
// - All assignments to currentStream
// - All unwrapping sites
// - Type-based usages
```

### Import Tracking
Antigravity follows:
- Direct imports (import AVFoundation)
- Nested imports (framework dependencies)
- Transitive dependencies

Example:
```swift
// When you ask "what does PlaybackViewModel depend on?"
// Antigravity finds: AVFoundation, Combine, SwiftUI, os.Logger
```

### Control Flow
Antigravity maps:
- Function calls
- Conditional paths
- Loop structures
- Error handling paths

Example:
```swift
func loadStream(_ stream: VideoStream) {
    // Antigravity sees the call path:
    // 1. validate URL
    // 2. create AVPlayerItem
    // 3. setup observers
    // 4. publish state
}
```

### Data Flow
Antigravity tracks:
- Variable assignments
- Parameter passing
- Return values
- State mutations

Example:
```swift
// Antigravity traces:
// isLoading → @Published in ViewModel
//          → View binds to it
//          → UI renders based on value
```

---

## Common Use Cases

### 1. Finding Where State Changes

```
"I changed PlaybackViewModel.isLoading. What Views are affected?"
```

Antigravity:
- Finds `@Published var isLoading`
- Traces all observers (Views)
- Shows cascade of re-renders
- Identifies dependent UI updates

### 2. Understanding Error Flow

```
"When loadStream fails, how does the error reach the user?"
```

Antigravity:
- Maps error path: loadStream → handleStatusChange → errorMessage
- Shows error propagation
- Identifies error handling points
- Suggests improvements

### 3. Tracing Memory Issues

```
"Are there any retain cycles around PlaybackViewModel?"
```

Antigravity:
- Analyzes reference patterns
- Finds strong captures in closures
- Identifies weak self usage
- Suggests memory optimizations

### 4. Dependency Analysis

```
"What would happen if I move VideoPlayerWorker to a separate module?"
```

Antigravity:
- Lists all importers
- Shows dependency edges
- Identifies breaking changes
- Suggests refactoring steps

### 5. Dead Code Detection

```
"Find any unused functions or properties"
```

Antigravity:
- Analyzes all definitions
- Finds unused methods
- Identifies dead code
- Suggests cleanup

---

## Tips & Best Practices

### ✅ DO

- **Ask specific questions** - "Find all uses of setupObservers" vs "analyze code"
- **Provide context** - "In PlaybackViewModel, where is..."
- **Use file names** - Claude Code + Antigravity work better with specific paths
- **Reference types** - "In VideoStream, find all references"
- **Ask for relationships** - "What depends on this?"

### ❌ DON'T

- **Ask vague questions** - "Why is this slow?" (needs more context)
- **Ask about unindexed paths** - Only indexed paths are semantic analyzed
- **Ignore suggestions** - Antigravity finds patterns humans miss
- **Skip documentation** - This guide + CLAUDE.md are your references

---

## Indexed vs Unindexed Paths

### Indexed (Semantic Analysis)

```
steam/ViewModels/       ✅ Full analysis
steam/Views/            ✅ Full analysis
steam/Models/           ✅ Full analysis
steam/Workers/          ✅ Full analysis
streaming/              ✅ Full analysis
```

**For these paths:**
- Complete semantic understanding
- Type resolution
- Control flow analysis
- Data flow tracing

### Unindexed (Fast Search Only)

```
DerivedData/            ❌ Skipped
build/                  ❌ Skipped
*.xcuserdata            ❌ Skipped
recordings/             ❌ Skipped
```

**For these paths:**
- Can still search by filename
- No semantic analysis
- Faster project scanning

---

## Workflow Example: Adding Playback Controls

### Step 1: Understand Current State
```
"Show me all @Published variables in PlaybackViewModel"
```
→ Antigravity finds all state properties

### Step 2: Find Dependencies
```
"What Views observe PlaybackViewModel state?"
```
→ Antigravity maps View → ViewModel relationships

### Step 3: Trace Data Flow
```
"How does currentStream flow from View to AVPlayer?"
```
→ Antigravity shows the complete data path

### Step 4: Plan Changes
```
"If I add @Published var currentTime, what would need to observe it?"
```
→ Antigravity suggests which Views should update

### Step 5: Refactor with Confidence
```
"Show me all places that would be affected by renaming loadStream to load"
```
→ Antigravity finds all references, enables safe refactoring

---

## Integrating with MCP Servers

Claude Code + Antigravity + MCP servers provide:

```
Claude Code
    ↓
Antigravity (Semantic Analysis)
    ↓
MCP Servers (Git, GitHub, Filesystem)
    ↓
Full Repository Understanding
```

### Available MCP Servers

- **filesystem** - Read/write files, explore structure
- **git** - Analyze commits, branches, history
- **github** - Issues, PRs, repository metadata

### Example: Cross-Platform Analysis

```
"In the last 5 commits, what code patterns changed
and could affect PlaybackViewModel behavior?"
```

Claude Code:
1. Uses Git MCP to read commits
2. Uses Antigravity to analyze changes
3. Shows semantic diffs
4. Identifies risk areas

---

## Troubleshooting

### Antigravity Not Finding Code

**Problem**: "It says PlaybackViewModel isn't found"

**Solution**: 
- Verify `.claude/settings.json` has `steam/ViewModels/` in `indexedPaths`
- Restart Claude Code (reload window)
- Check file path: `steam/ViewModels/PlaybackViewModel.swift`

### Slow Index Generation

**Problem**: "Indexing is taking too long"

**Solution**:
- First index build is slowest (~60s)
- Subsequent changes are incremental
- Consider excluding large directories temporarily
- Check disk space

### Relationships Not Showing

**Problem**: "Claude can't find where this method is called"

**Solution**:
- Make sure all related files are in indexed paths
- Try asking differently: "Find references" vs "Find calls"
- Verify Swift syntax is correct (Antigravity needs valid code)
- Check that both files have proper imports

---

## Advanced: Custom Indexing

To optimize for your workflow, edit `.claude/settings.json`:

```json
"antigravity": {
  "indexedPaths": [
    "steam/ViewModels/",      // Always semantic analyze
    "steam/Views/",
    "streaming/mediamtx.yml", // Can index configs too
  ],
  "skipPaths": [
    "build/",
    "DerivedData/",
  ],
  "semanticAnalysis": {
    "trackDataFlow": true,      // Enable data flow (slower but better)
    "followImports": true,      // Follow @import statements
    "resolveTypes": true        // Resolve type information
  }
}
```

---

## Learning More

- **CLAUDE.md** - General Claude Code guide
- **.claude/agents/** - Specialized agent descriptions
- **ARCHITECTURE.md** - Project architecture overview
- [GitHub Antigravity Docs](https://github.com/github/semantic) - Official guide

---

## Quick Reference

| Question | Antigravity Can Answer |
|----------|----------------------|
| "Where is X used?" | ✅ Yes - Find all references |
| "What depends on X?" | ✅ Yes - Show dependents |
| "What does X depend on?" | ✅ Yes - Show dependencies |
| "Will renaming X break anything?" | ✅ Yes - Impact analysis |
| "Is X dead code?" | ✅ Yes - Find unused code |
| "How does data flow to X?" | ✅ Yes - Trace data flow |
| "What's the call sequence?" | ✅ Yes - Show call graphs |
| "Are there memory leaks?" | ⚠️ Partial - Suggests issues |
| "Why is X slow?" | ⚠️ Partial - Show hot paths |
| "Will this change break production?" | ⚠️ Partial - Needs testing |

---

**Happy coding with Antigravity!** 🚀
