Last Modified: 08/24/2026 (1787587709) by amonrit

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

**Phase Status:** Phase 9 (Clean View Layer) COMPLETE. Since then: the Repository/DataSource scaffold was removed (see note below), `KeychainManager`/`URLLogger` became actors, and navigation/DI moved to a Coordinator pattern (`AppCoordinator` + `DIContainer`, see [ADR-004](./docs/adr/ADR-004-coordinator-navigation.md)). See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for the current architecture.

---

## Architecture: Modern MVVM + Structured Concurrency

The iOS app uses **State Actors** for thread-safe state management and **RetryOrchestrator** for resilient networking. For deep dive, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

**Quick structure:**
```
AppCoordinator (@Observable, owns NavigationStack path + DIContainer)
  ↓ builds & injects
Views (SwiftUI - Pure Presentation)
  ↓ observe via @Observable (NOT @Published/ObservableObject)
PlaybackViewModel / StreamAdminViewModel (MVVM - Coordinates logic)
  ├─ Uses StateActor for thread-safe state (mirrored into an @Observable property)
  ├─ Owns AVPlayer instance (Playback) / polls MediaMTX (StreamAdmin)
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
  ├─ DIContainer — factory for ViewModels, owned by AppCoordinator
  ├─ KeychainManager / URLLogger — actor-isolated secure storage & logging
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
| `steam/App/AppCoordinator.swift` | Owns navigation state; only place that constructs feature ViewModels |
| `steam/Core/DI/DIContainer.swift` | ViewModel/service factory, owned by `AppCoordinator` |
| `steam/Features/Playback/Presentation/PlaybackViewModel.swift` | Core MVVM logic with StateActor |
| `steam/Features/Playback/Domain/Services/RetryOrchestrator.swift` | Retry logic with exponential backoff |
| `steam/Features/Home/Presentation/HomeView.swift` | Home menu & navigation hub |
| `steam/Features/Playback/Presentation/VideoStreamListView.swift` | Stream list & playback UI |
| `steam/Features/Playback/Presentation/VideoPlayerView.swift` | Player UI & overlays (pure presentation) |
| `steam/Features/Playback/Presentation/VideoPlayerWorker.swift` | KVO observers & formatting |
| `steam/Features/StreamAdmin/Presentation/StreamAdminViewModel.swift` | Stream monitoring/admin logic with StateActor |
| `streaming/docker-compose.yml` | Docker service config |
| `streaming/mediamtx.yml` | MediaMTX configuration |

---

## Key Documentation

| Document | Purpose | Read When |
|----------|---------|-----------|
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Master index of all docs | First! Choose what you need |
| [GETTING_STARTED.md](./GETTING_STARTED.md) | 5-minute setup guide | New to project |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Deep dive into modern patterns | Understanding system design |
| [docs/PATTERN-CHEAT-SHEET.md](./docs/PATTERN-CHEAT-SHEET.md) | How to use StateActor, RetryOrchestrator, APIClientProvider, Coordinator | Writing or reviewing feature code |
| [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) | Local dev workflows & debugging | Daily development |
| [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Production setup & deployment | Setting up on new machine |
| [docs/adr/](./docs/adr/) | Architecture Decision Records | Understanding "why" decisions |

---

## Markdown Header Rule

**Documentation files (`.md` only) MUST start with:**
```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

[Document content...]
```

**Note:** Swift (`.swift`) files do NOT require headers. This rule applies to Markdown documentation only.

Update whenever you edit a `.md` file. See [.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md) for details.
