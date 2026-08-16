Last Modified: 08/17/2026 (1786922418) by amonrit

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
- **NEW (Phase 11):** Modern patterns (StateActor, RetryOrchestrator, APIClientProvider)
- Complete architecture diagram
- Testing strategy

**When to use:** Understanding "why" before changing code, learning new patterns

---

### 2b. **[docs/REFACTORING_GUIDE.md](./docs/REFACTORING_GUIDE.md)** — Modernizing Code with New Patterns
**For:** Refactoring legacy code, learning how to use StateActor, RetryOrchestrator, APIClientProvider  
**Contains:**
- Pattern 1: StateActor for thread-safe state
- Pattern 2: RetryOrchestrator for resilience
- Pattern 3: APIClientProvider for dependency injection
- Pattern 4: Structured concurrency with tasks
- Common refactoring scenarios with before/after examples
- Testing patterns
- Rollback strategy

**When to use:** Refactoring code, adding new features, code review

---

### 2c. **[docs/MIGRATION_GUIDE.md](./docs/MIGRATION_GUIDE.md)** — Adopting Modern Patterns
**For:** Migrating existing code to use modern patterns, planning refactoring work  
**Contains:**
- Quick decision tree for choosing patterns
- Migration checklist for each pattern
- Common patterns to replace (with grep commands)
- Complete service modernization example
- View refactoring example
- Testing patterns
- Rollout strategy
- Common pitfalls
- Success metrics

**When to use:** Planning refactoring, migrating a service, onboarding new developers

---

### 2d. **[docs/adr/](./docs/adr/)** — Architecture Decision Records
**For:** Understanding design decisions, learning rationale, future reference  
**Contains:**
- **ADR-001: Structured Concurrency** — Why StateActor instead of @Published
- **ADR-002: Retry Orchestrator** — Why centralized retry logic
- **ADR-003: Dependency Injection** — Why APIClientProvider for testability
- Status, context, decision, consequences, alternatives for each

**When to use:** Understanding "why" decisions were made, code review discussions, architecture reviews

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

## 🔒 **Security**

### **[docs/SECURITY_AUDIT_2026-08-17.md](./docs/SECURITY_AUDIT_2026-08-17.md)** — Security Audit Report
**For:** Understanding security vulnerabilities, compliance, remediation  
**Contains:**
- 4 CRITICAL vulnerabilities (hardcoded credentials, unauthenticated publishing, CORS misconfiguration)
- 6 HIGH/MEDIUM severity findings
- Detailed exploit scenarios for each issue
- Recommendations and remediation steps
- Priority 1, 2, 3 action items
- Compliance notes (OWASP, CWE, SANS)

**When to use:** Before deploying to production, when fixing security issues, compliance reviews

---

### **[docs/CREDENTIAL_MANAGEMENT.md](./docs/CREDENTIAL_MANAGEMENT.md)** — Credential Lifecycle Strategy
**For:** Understanding how credentials flow from generation to storage (environment → Keychain)  
**Contains:**
- 4-phase credential lifecycle (generation → environment → storage)
- Environment vs. Keychain storage strategy
- Classification of credentials (what must be environment-loaded)
- Implementation guidelines for server & iOS
- .env.example validation checklist
- Pre-commit security validation

**When to use:** Setting up credentials, code review for security, implementing Keychain storage

---

### **[docs/CREDENTIAL_ROTATION.md](./docs/CREDENTIAL_ROTATION.md)** — Credential Rotation Guide
**For:** Rotating credentials safely in development and production  
**Contains:**
- Quick reference table (who rotates what, frequency)
- Local development rotation steps
- Production rotation procedures
- Emergency credential revocation process
- iOS app re-authentication flow
- Rotation audit trail & logging
- Troubleshooting common issues
- Best practices & anti-patterns

**When to use:** Rotating credentials quarterly or after compromise, or following deployment changes

---

### **[docs/CREDENTIAL_SETUP.md](./docs/CREDENTIAL_SETUP.md)** — Credential Setup (Quick Start)
**For:** Setting up .env.local on first run as a developer  
**Contains:**
- 5-minute first-time setup
- How to generate strong passwords
- Security rules (DO's and DON'Ts)
- Troubleshooting common issues
- Links to detailed docs

**When to use:** First time cloning the project, or setting up on a new machine

---

### **[docs/KEYCHAIN_SETUP.md](./docs/KEYCHAIN_SETUP.md)** — Keychain Setup & iOS Simulator
**For:** Using Keychain for credential storage, testing on iOS Simulator  
**Contains:**
- Keychain overview & storage hierarchy
- iOS Simulator Keychain support
- Entitlements configuration
- Setting up credentials (environment variables vs. Keychain)
- Testing Keychain operations
- Troubleshooting (Keychain errors, persistence issues)
- Security notes & credential rotation

**When to use:** Setting up app for first run, configuring Keychain for development, running tests on simulator

---

## 🌐 **Streaming Server**

### **[streaming/QUICK_REFERENCE.md](./streaming/QUICK_REFERENCE.md)** — MediaMTX Cheatsheet
**For:** Quick commands, common operations  
**Contains:**
- Start/stop/restart commands
- Quick publish examples (FFmpeg, OBS)
- Quick view examples (VLC, FFplay)
- All protocol URLs (RTMP, RTSP, HLS, WebRTC, SRT)
- FFmpeg publish examples

**When to use:** Need a command, forgot the syntax, or want to publish a stream

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

"I want to refactor code using new patterns"
  → docs/REFACTORING_GUIDE.md (StateActor, RetryOrchestrator, APIClientProvider)

"I need to migrate legacy code"
  → docs/MIGRATION_GUIDE.md (step-by-step examples)

"Why was decision X made?"
  → docs/adr/ (ADRs explain rationale)

"I need to debug something"
  → docs/DEVELOPMENT.md (debugging section) + docs/AI_WORKFLOW.md (use AI)

"I need to publish a stream"
  → streaming/QUICK_REFERENCE.md (commands + examples)

"I need to deploy to a new machine"
  → docs/DEPLOYMENT.md

"I want to use AI to help"
  → docs/AI_WORKFLOW.md

"I'm setting up Claude Code"
  → .claude/SETUP.md

"I need to write Swift code"
  → .claude/instructions/swift-style.md + docs/ARCHITECTURE.md

"I need to understand security vulnerabilities"
  → docs/SECURITY_AUDIT_2026-08-17.md (findings + remediation)

"I need to fix security issues"
  → docs/SECURITY_AUDIT_2026-08-17.md (priority actions + recommendations)

"I'm setting up credentials for the first time"
  → docs/CREDENTIAL_SETUP.md (5-minute setup)

"I need to understand the credential strategy"
  → docs/CREDENTIAL_MANAGEMENT.md (lifecycle & storage)

"I need to rotate credentials"
  → docs/CREDENTIAL_ROTATION.md (procedures & best practices)

"I'm setting up the iOS app with Keychain"
  → docs/KEYCHAIN_SETUP.md (iOS Simulator, entitlements, testing)

"Keychain isn't working in the simulator"
  → docs/KEYCHAIN_SETUP.md (Troubleshooting section)
```

---

## 📊 **Folder Structure Overview**

```
steam/
├── DOCUMENTATION.md              ← YOU ARE HERE (master index)
├── GETTING_STARTED.md            ← Start here for new people
├── README.md                     ← Project overview
├── CLAUDE.md                     ← AI context
│
├── docs/                         ← Main documentation
│   ├── DEVELOPMENT.md            ← Local dev guide
│   ├── ARCHITECTURE.md           ← Deep dive into MVVM + modern patterns
│   ├── REFACTORING_GUIDE.md      ← How to use new patterns (Phase 11)
│   ├── MIGRATION_GUIDE.md        ← How to migrate code (Phase 11)
│   ├── adr/                      ← Architecture Decision Records (Phase 11)
│   │   ├── ADR-001-structured-concurrency.md
│   │   ├── ADR-002-retry-orchestrator.md
│   │   └── ADR-003-dependency-injection.md
│   ├── DEPLOYMENT.md             ← Deploy to production
│   ├── COMMIT_GUIDE.md           ← Commit message format
│   ├── COMMIT_WORKFLOW.md        ← Commit workflow
│   ├── AI_WORKFLOW.md            ← Working with AI tools
│   ├── CREDENTIAL_MANAGEMENT.md  ← Credential lifecycle strategy
│   ├── CREDENTIAL_SETUP.md       ← First-time credential setup
│   ├── CREDENTIAL_ROTATION.md    ← Rotate credentials safely
│   ├── KEYCHAIN_SETUP.md         ← iOS Keychain & Simulator config
│   └── SECURITY_AUDIT_2026-08-17.md ← Security findings & remediation
│
├── streaming/
│   ├── FFMPEG_SETUP.md           ← FFmpeg transcoding setup
│   ├── QUICK_REFERENCE.md        ← MediaMTX commands & examples
│   ├── START.md                  ← Quick server start
│   └── TESTING_FFMPEG_TRANSCODING.md ← Test the transcoding
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
