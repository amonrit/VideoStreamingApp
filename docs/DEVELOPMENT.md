Last Modified: 08/24/2026 (1787587709) by amonrit

# Development Guide

This guide explains the project structure and where to make changes.

---

## Project Structure

Understanding where things are:

```
steam/
├── steam/                                        ← iOS App Source
│   ├── App/
│   │   ├── steamApp.swift                        Entry point
│   │   ├── AppCoordinator.swift                  ← Navigation + DI (start here to add a screen)
│   │   └── Navigation/AppRoute.swift              Navigation destinations
│   ├── Core/
│   │   ├── Architecture/StateActor.swift          Generic thread-safe state base
│   │   ├── DI/ (APIClientProvider.swift, DIContainer.swift)
│   │   ├── Managers/ (KeychainManager.swift, ThemeManager.swift — actor/@Observable)
│   │   ├── Networking/MediaMTXAPIClient.swift
│   │   └── Utils/ (RetryStrategy, PollingService, URLValidator, PlaybackConfiguration)
│   ├── Features/
│   │   ├── Home/Presentation/HomeView.swift       Home menu & navigation
│   │   ├── Playback/
│   │   │   ├── Domain/                           Entities, PlaybackStateActor, RetryOrchestrator
│   │   │   └── Presentation/
│   │   │       ├── PlaybackViewModel.swift        ← CORE LOGIC (start here)
│   │   │       ├── VideoStreamListView.swift      Stream list & playback
│   │   │       ├── VideoPlayerView.swift          Player UI
│   │   │       ├── VideoPlayerWorker.swift        KVO observers, format extraction
│   │   │       └── FullScreenPlayerView.swift     Fullscreen mode
│   │   ├── StreamAdmin/                          Stream/viewer monitoring (mirrors Playback's shape)
│   │   └── Settings/Presentation/SettingsView.swift
│   ├── DesignSystem/                              Shared UI styling
│   └── Resources/
│
├── streaming/                       ← Streaming Server (Docker)
│   ├── docker-compose.yml           Container definition
│   ├── mediamtx.yml                 Server configuration
│   ├── .env.example                 Environment template
│   └── recordings/                  Recorded streams
│
├── Makefile                         Development shortcuts
├── .editorconfig                    Code style rules
└── .claude/                         AI configuration
```

There is no `Repository`/`DataSource` layer — it was scaffolded early on, never wired up, and
has since been removed. ViewModels call `MediaMTXAPIClient` directly through `APIClientProvider`.

---

## Where to Make Changes

| Task | Location | Notes |
|------|----------|-------|
| **Fix/Add UI** | `steam/Features/*/Presentation/` | Edit + rebuild in Xcode |
| **Fix business logic** | `steam/Features/Playback/Presentation/PlaybackViewModel.swift` | Edit + rebuild |
| **Add a screen / change navigation** | `steam/App/AppCoordinator.swift`, `steam/App/Navigation/AppRoute.swift` | New route + a `DIContainer` factory method |
| **Fix a data entity** | `steam/Features/*/Domain/Entities/` | Edit + rebuild |
| **Fix server config** | `streaming/mediamtx.yml` | Edit + `make server-restart` |
| **Fix worker utility** | `steam/Features/Playback/Presentation/VideoPlayerWorker.swift` | Edit + rebuild |

---

## Key Files

**Most important to understand:**
- `steam/App/AppCoordinator.swift` — If adding a screen or changing navigation/DI
- `steam/Features/Playback/Presentation/PlaybackViewModel.swift` — If changing playback logic
- `steam/Features/Playback/Presentation/VideoStreamListView.swift` — If changing playback UI
- `steam/Features/Home/Presentation/HomeView.swift` — If changing the navigation menu
- `steam/Features/Playback/Presentation/VideoPlayerView.swift` — If changing player UI
- `steam/Features/Playback/Presentation/VideoPlayerWorker.swift` — If changing observers
- `docs/PATTERN-CHEAT-SHEET.md` — If unsure how StateActor/RetryOrchestrator/APIClientProvider/Coordinator fit together

---

## Quick Start (2 minutes)

```bash
# Start everything
make dev-all

# Or separately:
make dev-server    # Start streaming server
make dev-app       # Open iOS app in Xcode
```

**In Xcode:**
- Press `Cmd+R` to run in simulator
- `Cmd+B` to rebuild
- View → Debug Area → Show Console for logs
