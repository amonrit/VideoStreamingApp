Last Modified: 08/19/2026 (1787140694) by amonrit

# CLAUDE.md

This file provides guidance to Claude Code and AI assistants when working with code in this repository.

---

## 🚀 Start Here

**New to the project?**
→ Read [GETTING_STARTED.md](./GETTING_STARTED.md) (5 minutes)

**All documentation:**
→ Read [DOCUMENTATION.md](./DOCUMENTATION.md) (master index)

---

## Project Overview

**Steam** is a dual-component iOS video streaming application:

1. **iOS App** — SwiftUI-based HLS video player with **modern MVVM + structured concurrency**
2. **Streaming Server** — Docker-based MediaMTX server for publishing and managing live streams

The project enables users to publish live video streams (via RTMP) and play them back (via HLS/RTSP/WebRTC) on iOS devices.

**Phase Status:** Phase 9 (Clean View Layer) COMPLETE — See [docs/PHASE-11-SUMMARY.md](./docs/PHASE-11-SUMMARY.md) for latest architecture.

---

## Architecture: Modern MVVM + Structured Concurrency

The iOS app uses **State Actors** for thread-safe state management and **RetryOrchestrator** for resilient networking. For deep dive, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

**Quick structure:**
```
Views (SwiftUI - Pure Presentation)
  ↓ observe via @Published
PlaybackViewModel (MVVM - Coordinates logic)
  ├─ Uses StateActor for thread-safe state
  ├─ Owns AVPlayer instance
  ├─ Manages stream loading, playback state, error handling
  └─ Delegates to Workers for KVO/Combine setup
  
Workers (Reusable Utilities)
  └─ VideoPlayerWorker — KVO observers, resolution/bitrate extraction

Domain Entities (Framework-independent data)
  └─ VideoStream, ConnectionStatus, RetryState, PlaybackState, MediaMTXPath, MediaMTXConfig

Networking (ViewModels call this directly — no Repository layer)
  ├─ APIClientProvider — creates MediaMTXAPIClient instances (DI seam for tests)
  └─ MediaMTXAPIClient — talks to the MediaMTX Control API

Core Services
  ├─ StateActor — Thread-safe state management
  ├─ RetryOrchestrator — Resilient error handling with exponential backoff
  ├─ APIClientProvider — Dependency injection
  └─ URLValidator — Stream URL validation
```

A Repository/Use-Case layer was scaffolded early on (`Domain/Repositories`, `Data/Repositories`,
`Data/DataSources`) but was never wired up — it only ever returned placeholder data — and has
since been removed. If a real need for it shows up later (a second data source to combine, or
business logic that needs to be shared outside a ViewModel), extract it from the working
ViewModel code at that point rather than re-scaffolding ahead of need.

**Key Patterns:**
- **StateActor** — Replaces @Published for thread-safe state
- **RetryOrchestrator** — Centralized retry logic with exponential backoff
- **APIClientProvider** — Dependency injection for testability
- **Structured Concurrency** — Async/await + Task management

---

## Important Files

| File | Purpose |
|------|---------|
| `steam/Features/Playback/Presentation/PlaybackViewModel.swift` | Core MVVM logic with StateActor |
| `steam/Features/Playback/Domain/Services/RetryOrchestrator.swift` | Retry logic with exponential backoff |
| `steam/Features/Home/Presentation/HomeView.swift` | Home menu & navigation hub |
| `steam/Features/Playback/Presentation/VideoStreamListView.swift` | Stream list & playback UI |
| `steam/Features/Playback/Presentation/VideoPlayerView.swift` | Player UI & overlays (pure presentation) |
| `steam/Features/Playback/Presentation/VideoPlayerWorker.swift` | KVO observers & formatting |
| `streaming/docker-compose.yml` | Docker service config |
| `streaming/mediamtx.yml` | MediaMTX configuration |

---

## Key Documentation

| Document | Purpose | Read When |
|----------|---------|-----------|
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Master index of all docs | First! Choose what you need |
| [GETTING_STARTED.md](./GETTING_STARTED.md) | 5-minute setup guide | New to project |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Deep dive into modern patterns | Understanding system design |
| [docs/REFACTORING_GUIDE.md](./docs/REFACTORING_GUIDE.md) | How to use StateActor, RetryOrchestrator, APIClientProvider | Modernizing code |
| [docs/MIGRATION_GUIDE.md](./docs/MIGRATION_GUIDE.md) | Step-by-step migration examples | Planning refactoring work |
| [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) | Local dev workflows & debugging | Daily development |
| [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Production setup & deployment | Setting up on new machine |
| [docs/adr/](./docs/adr/) | Architecture Decision Records | Understanding "why" decisions |
| [docs/PHASE-11-SUMMARY.md](./docs/PHASE-11-SUMMARY.md) | Latest phase completion & modern architecture | Current state overview |

---

## Markdown Header Rule

**Documentation files (`.md` only) MUST start with:**
```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

[Document content...]
```

**Note:** Swift (`.swift`) files do NOT require headers. This rule applies to Markdown documentation only.

Update whenever you edit a `.md` file. See [.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md) for details.
