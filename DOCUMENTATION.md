Last Modified: 08/10/2026 (1786502400) by amonrit

# 📚 Documentation Guide — Find What You Need

This is your **master index** for all Steam documentation. Each section tells you which file to read for your specific task.

---

## 🚀 **Getting Started (First Time)**

**Just got the project? Start here → 5 minutes**

→ **[GETTING_STARTED.md](./GETTING_STARTED.md)**
- Prerequisites check
- Start streaming server (Docker)
- Build iOS app (Xcode)
- Quick test (publish + play)

---

## 📖 **Main Documentation**

All docs are in the `docs/` folder:

### 1. **[docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md)** — Local Development
**For:** Adding features, debugging, working locally  
**Contains:**
- Project structure & where to make changes
- Running locally (`make dev-all`)
- Debugging techniques
- Common tasks workflow

**When to use:** Every day while developing

---

### 2. **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — How It Works (Deep Dive)
**For:** Understanding system design, code review, learning MVVM  
**Contains:**
- MVVM pattern explained with code
- Data flow (user interaction → playback)
- Component responsibilities
- State management strategy

**When to use:** Understanding "why" before changing code

---

### 3. **[docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)** — Production & New Machines
**For:** Deploying server to new machines, production setup  
**Contains:**
- Machine requirements
- Step-by-step deployment
- Network setup
- Troubleshooting

**When to use:** Setting up on a new machine

---

### 4. **[docs/COMMIT_GUIDE.md](./docs/COMMIT_GUIDE.md)** — Writing Good Commits
**For:** Committing code that follows project standards  
**Contains:**
- Commit message format (type, scope, subject)
- All 9 commit types with examples
- Good vs bad commits
- Tips for atomic commits

**When to use:** Before every `git commit`

---

### 5. **[docs/COMMIT_WORKFLOW.md](./docs/COMMIT_WORKFLOW.md)** — Commit Tools & Workflow
**For:** Using commit helpers, understanding the workflow  
**Contains:**
- Auto-reminder setup
- `commit-help.sh` script examples
- Before/during/after workflow
- Checklist

**When to use:** Unsure about commit flow

---

### 6. **[docs/AI_WORKFLOW.md](./docs/AI_WORKFLOW.md)** — Working with Claude Code, Cursor, Copilot
**For:** Using AI tools effectively on this project  
**Contains:**
- Claude Code setup & specialized agents
- Do's & Don'ts for better AI responses
- Code review workflow with AI
- Debugging with AI assistance

**When to use:** Want AI to help with code, reviews, debugging

---

## 🌐 **Streaming Server**

### **[streaming/QUICK_REFERENCE.md](./streaming/QUICK_REFERENCE.md)** — MediaMTX Cheatsheet
**For:** Quick commands, common operations  
**Contains:**
- Start/stop/restart commands
- Quick publish examples (FFmpeg, OBS)
- Quick view examples (VLC, FFplay)
- All protocol URLs (RTMP, RTSP, HLS, WebRTC, SRT)

**When to use:** Need a command, forgot the syntax

### **[streaming/PUBLISH_EXAMPLES.md](./streaming/PUBLISH_EXAMPLES.md)** — How to Publish Streams
**For:** Different ways to publish streams  
**Contains:**
- FFmpeg from video file
- FFmpeg screen capture
- OBS Studio setup
- iPhone app publishing

**When to use:** Want to publish a stream to test

---

## 🤖 **AI Assistant Context**

These files help AI assistants (Claude, Copilot, etc.) understand your project:

### **[CLAUDE.md](./CLAUDE.md)** — For Claude Code & AI Assistants
**For:** AI tools to understand your project structure and conventions  
**Contains:**
- Project overview (MVVM architecture)
- Common commands
- Development standards
- Critical context (retry logic, threading, etc.)
- Links to detailed docs

**When to use:** AI uses this automatically when analyzing code

### **[.claude/SETUP.md](./.claude/SETUP.md)** — Antigravity & Claude Code Setup
**For:** Understanding semantic analysis, Antigravity configuration  
**Contains:**
- What Antigravity does
- How to enable/verify it
- Using it for code exploration
- Advanced features

**When to use:** Configuring Claude Code, troubleshooting AI features

### **[.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md)** — Markdown Header Standard
**For:** Understanding the header rule for all .md files  
**Contains:**
- Format (Last Modified, timestamp, username)
- Examples
- When to update

**When to use:** Creating or editing .md files

### **[.claude/instructions/swift-style.md](./.claude/instructions/swift-style.md)** — Swift Code Style
**For:** Understanding code formatting standards  
**Contains:**
- Naming conventions
- File organization
- Indentation rules
- SwiftUI best practices

**When to use:** Writing or reviewing Swift code

### **[.claude/agents/](./​.claude/agents/)** — Specialized Agents
**For:** Using expert agents for specific tasks

- **swift-ios-expert.md** → Use when: `/swift-ios-expert "Review this Swift code"`
- **streaming-expert.md** → Use when: `/streaming-expert "Debug this server issue"`

---

## 📋 **Other References**

### **[README.md](./README.md)** — Project Overview
- Features, badges, quick links
- Not a guide, just a landing page

### **[FEATURES_ROADMAP.md](./FEATURES_ROADMAP.md)** — What's Next
- Planned features, priorities, effort estimates
- Use when deciding what to build

### **[.github/copilot-instructions.md](./.github/copilot-instructions.md)** — GitHub Copilot Config
- Copilot-specific instructions
- Only relevant if using Copilot

---

## 🎯 **Quick Decision Tree**

```
"I'm new to the project"
  → GETTING_STARTED.md (5 min) → docs/DEVELOPMENT.md

"I need to commit code"
  → docs/COMMIT_GUIDE.md (format) + docs/COMMIT_WORKFLOW.md (flow)

"I don't understand how X works"
  → docs/ARCHITECTURE.md (deep dive)

"I need to debug something"
  → docs/DEVELOPMENT.md (debugging section) + docs/AI_WORKFLOW.md (use AI)

"I need to publish a stream"
  → streaming/QUICK_REFERENCE.md (commands) or streaming/PUBLISH_EXAMPLES.md (details)

"I need to deploy to a new machine"
  → docs/DEPLOYMENT.md

"I want to use AI to help"
  → docs/AI_WORKFLOW.md

"I'm setting up Claude Code"
  → .claude/SETUP.md

"I need to write Swift code"
  → .claude/instructions/swift-style.md + docs/ARCHITECTURE.md
```

---

## 📊 **Folder Structure Overview**

```
steam/
├── DOCUMENTATION.md              ← YOU ARE HERE (master index)
├── GETTING_STARTED.md            ← Start here for new people
├── README.md                     ← Project overview
├── FEATURES_ROADMAP.md           ← Planned features
├── CLAUDE.md                     ← AI context
│
├── docs/                         ← Main documentation
│   ├── DEVELOPMENT.md            ← Local dev guide
│   ├── ARCHITECTURE.md           ← Deep dive into MVVM
│   ├── DEPLOYMENT.md             ← Deploy to production
│   ├── COMMIT_GUIDE.md           ← Commit message format
│   ├── COMMIT_WORKFLOW.md        ← Commit workflow
│   └── AI_WORKFLOW.md            ← Working with AI tools
│
├── streaming/
│   ├── QUICK_REFERENCE.md        ← MediaMTX commands
│   └── PUBLISH_EXAMPLES.md       ← Publish stream examples
│
├── .claude/                      ← AI-specific docs
│   ├── SETUP.md                  ← Antigravity setup
│   ├── markdown-header-rule.md   ← Header standard
│   ├── instructions/
│   │   └── swift-style.md        ← Code style
│   └── agents/
│       ├── swift-ios-expert.md   ← Expert agent
│       └── streaming-expert.md   ← Expert agent
│
├── .github/
│   └── copilot-instructions.md
```

---

## ✨ **Tips for Documentation**

1. **Every .md file must start with:** 
   ```
   Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME
   ```
   See [.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md)

2. **Links to docs are relative** — works everywhere:
   ```markdown
   See [DEPLOYMENT.md](./docs/DEPLOYMENT.md) for details
   ```

3. **AI reads this file automatically** when understanding the project structure

4. **When adding a new doc:**
   - Put it in the right folder (docs/, streaming/, .claude/)
   - Add link to DOCUMENTATION.md
   - Add the header (Last Modified, etc.)
