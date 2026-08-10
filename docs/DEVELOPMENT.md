Last Modified: 08/10/2026 (1786366014) by amonrit

# Development Guide

This guide explains the project structure and where to make changes.

---

## Project Structure

Understanding where things are:

```
steam/
├── steam/                           ← iOS App Source
│   ├── steamApp.swift               Entry point
│   ├── Models/
│   │   ├── VideoStream.swift        (URL, title, thumbnail)
│   │   └── PlaybackState.swift      (Enum: idle, loading, playing, etc.)
│   ├── ViewModels/
│   │   └── PlaybackViewModel.swift  ← CORE LOGIC (start here)
│   ├── Views/
│   │   ├── HomeView.swift           Home menu & navigation
│   │   ├── VideoStreamListView.swift Stream list & playback
│   │   ├── VideoPlayerView.swift    Player UI
│   │   └── FullScreenPlayerView.swift Fullscreen mode
│   └── Workers/
│       └── VideoPlayerWorker.swift  KVO observers, format extraction
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

---

## Where to Make Changes

| Task | Location | Notes |
|------|----------|-------|
| **Fix/Add UI** | `steam/Views/` | Edit + rebuild in Xcode |
| **Fix business logic** | `steam/ViewModels/PlaybackViewModel.swift` | Edit + rebuild |
| **Fix data model** | `steam/Models/` | Edit + rebuild |
| **Fix server config** | `streaming/mediamtx.yml` | Edit + restart |
| **Fix worker utility** | `steam/Workers/` | Edit + rebuild |

---

## Key Files

**Most important to understand:**
- `steam/ViewModels/PlaybackViewModel.swift` — If changing logic
- `steam/Views/VideoStreamListView.swift` — If changing playback UI
- `steam/Views/HomeView.swift` — If changing navigation menu
- `steam/Views/VideoPlayerView.swift` — If changing player UI
- `steam/Workers/VideoPlayerWorker.swift` — If changing observers

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
