Last Modified: 08/17/2026 (1786916495) by amonrit

# Phase 2: Domain Layer & Data Layer Implementation

## ✅ Completed

### 1. Playback Feature - Domain Layer Use Cases

**LoadStreamUseCase** — Features/Playback/Domain/UseCases/
- ✅ Validate stream URL
- ✅ Check URL against whitelist
- ✅ Create AVAsset from URL
- ✅ Custom StreamError types

**RetryPlaybackUseCase** — Features/Playback/Domain/UseCases/
- ✅ Track retry attempts
- ✅ Exponential backoff calculation (1s, 2s, 4s → max 5s)
- ✅ Jitter to prevent thundering herd
- ✅ Reset retry counter

**GetViewerCountUseCase** — Features/Playback/Domain/UseCases/
- ✅ Fetch viewer count from repository
- ✅ Error handling with ViewerCountError
- ✅ Async/await implementation

### 2. Playback Feature - Data Layer

**StreamRepositoryImpl** — Features/Playback/Data/Repositories/
- ✅ Implements StreamRepository protocol
- ✅ Coordinates remote and local data sources
- ✅ Stream loading logic
- ✅ Stream listing
- ✅ Viewer count fetching

**StreamRemoteDataSourceImpl** — Features/Playback/Data/DataSources/
- ✅ Protocol-based design
- ✅ Uses MediaMTXAPIClient for API calls
- ✅ Fetch streams from API
- ✅ Fetch viewer count
- ✅ Sample streams as fallback

### 3. StreamAdmin Feature - Domain Layer

**StreamAdminRepository** — Features/StreamAdmin/Domain/Repositories/
- ✅ Protocol for stream admin operations
- ✅ Get paths, start stream, stop stream
- ✅ Get path configuration

### 4. StreamAdmin Feature - Data Layer

**StreamAdminRepositoryImpl** — Features/StreamAdmin/Data/Repositories/
- ✅ Concrete implementation of StreamAdminRepository
- ✅ Coordinates with remote data source

**StreamAdminRemoteDataSourceImpl** — Features/StreamAdmin/Data/DataSources/
- ✅ Protocol-based remote operations
- ✅ MediaMTX API integration
- ✅ Path management (fetch, start, stop)

### 5. Dependency Injection Container

**DIContainer** — Core/DI/DIContainer.swift
- ✅ Singleton pattern
- ✅ Lazy initialization of all services
- ✅ Wire PlaybackViewModel dependencies
- ✅ Wire StreamAdmin dependencies
- ✅ Wire Use Cases
- ✅ Wire Repositories
- ✅ Wire Core services (URLValidator, MediaMTXAPIClient)

```
DIContainer (creates dependencies)
  ├── Core Services
  │   ├── URLValidator
  │   └── MediaMTXAPIClient
  ├── Repositories
  │   ├── StreamRepository (via StreamRemoteDataSourceImpl)
  │   └── StreamAdminRepository (via StreamAdminRemoteDataSourceImpl)
  └── Use Cases
      ├── LoadStreamUseCase
      ├── RetryPlaybackUseCase
      └── GetViewerCountUseCase
```

## 📊 Layer Architecture Summary

```
┌─────────────────────────────────────────┐
│ Presentation Layer (Views & ViewModels) │  
│                                         │
│ ✅ PlaybackViewModel (existing)         │
│ ✅ StreamAdminViewModel (existing)      │
│ ✅ Views (VideoPlayerView, etc.)        │
└──────────────┬──────────────────────────┘
               │ uses
               ↓
┌─────────────────────────────────────────┐
│ Domain Layer (Use Cases & Repositories) │
│                                         │
│ ✅ LoadStreamUseCase                   │
│ ✅ RetryPlaybackUseCase                │
│ ✅ GetViewerCountUseCase               │
│ ✅ StreamRepository (protocol)          │
│ ✅ StreamAdminRepository (protocol)     │
└──────────────┬──────────────────────────┘
               │ depends on
               ↓
┌─────────────────────────────────────────┐
│ Data Layer (Repositories & DataSources) │
│                                         │
│ ✅ StreamRepositoryImpl                 │
│ ✅ StreamRemoteDataSourceImpl           │
│ ✅ StreamAdminRepositoryImpl            │
│ ✅ StreamAdminRemoteDataSourceImpl      │
└──────────────┬──────────────────────────┘
               │ uses
               ↓
┌─────────────────────────────────────────┐
│ Core/External Layer (APIs & Utilities)  │
│                                         │
│ ✅ MediaMTXAPIClient                   │
│ ✅ URLValidator                        │
└─────────────────────────────────────────┘
```

## 🔄 Dependency Injection Flow

```
DIContainer.shared.makePlaybackViewModel()
    ↓
PlaybackViewModel (with dependencies injected)
    ├── Can use: DIContainer.shared.getLoadStreamUseCase()
    ├── Can use: DIContainer.shared.getRetryPlaybackUseCase()
    └── Can use: DIContainer.shared.getStreamRepository()
```

## 📋 Next Steps: Phase 2 Continued

### 2.1 Update Xcode Project File
- [ ] Reference new file locations in .pbxproj
- [ ] Remove old file references
- [ ] Update target membership for new files

### 2.2 Test Use Cases
- [ ] Create unit tests for LoadStreamUseCase
- [ ] Create unit tests for RetryPlaybackUseCase
- [ ] Create unit tests for GetViewerCountUseCase
- [ ] Mock repository for testing

### 2.3 Integrate Use Cases into ViewModels
- [ ] Update PlaybackViewModel to use injected use cases
- [ ] Update StreamAdminViewModel with repository
- [ ] Remove duplicate retry logic from ViewModel

### 2.4 Update Views Layer
- [ ] Views should only reference their ViewModel
- [ ] No direct domain imports in Views

## 📁 File Structure Created

```
Features/
├── Playback/
│   ├── Domain/
│   │   ├── Entities/
│   │   │   ├── PlaybackState.swift ✅
│   │   │   └── VideoStream.swift ✅
│   │   ├── Repositories/
│   │   │   └── StreamRepository.swift ✅
│   │   └── UseCases/
│   │       ├── LoadStreamUseCase.swift ✅
│   │       ├── RetryPlaybackUseCase.swift ✅
│   │       └── GetViewerCountUseCase.swift ✅
│   ├── Data/
│   │   ├── DataSources/
│   │   │   └── StreamRemoteDataSource.swift ✅
│   │   └── Repositories/
│   │       └── StreamRepositoryImpl.swift ✅
│   └── Presentation/
│       ├── PlaybackViewModel.swift
│       ├── VideoPlayerView.swift
│       ├── VideoStreamListView.swift
│       ├── FullScreenPlayerView.swift
│       └── VideoPlayerWorker.swift
│
├── StreamAdmin/
│   ├── Domain/
│   │   ├── MediaMTXConfig.swift
│   │   ├── MediaMTXPath.swift
│   │   └── Repositories/
│   │       └── StreamAdminRepository.swift ✅
│   ├── Data/
│   │   ├── DataSources/
│   │   │   └── StreamAdminRemoteDataSource.swift ✅
│   │   └── Repositories/
│   │       └── StreamAdminRepositoryImpl.swift ✅
│   └── Presentation/
│       ├── StreamAdminView.swift
│       └── StreamAdminViewModel.swift
│
├── Settings/
│   ├── Domain/
│   ├── Data/
│   └── Presentation/
│       └── SettingsView.swift
│
└── Home/
    ├── Domain/
    ├── Data/
    └── Presentation/
        └── HomeView.swift
```

## 🚨 Import Errors (Expected)

These will be resolved once Xcode project is updated:
- `Cannot find type 'VideoStream' in scope` — Swift module boundaries
- `Cannot find type 'StreamRepository' in scope` — Cross-module references
- These are expected and will resolve after project file update

## ✨ Key Achievements

✅ **Separation of Concerns**
- Domain layer is independent of frameworks
- Data layer handles all API/local data access
- Presentation layer only knows about ViewModels

✅ **Testability**
- Use cases can be unit tested with mocked repositories
- Repositories can be mocked in ViewModel tests
- No AVPlayer logic in repositories

✅ **Dependency Inversion**
- Presentation depends on Domain
- Domain is independent
- Data depends on Domain (implements protocols)

✅ **SOLID Principles**
- Single Responsibility: each layer has one job
- Open/Closed: easy to extend with new data sources
- Liskov Substitution: repository implementations are interchangeable
- Interface Segregation: repositories define specific contracts
- Dependency Inversion: high-level modules don't depend on low-level

## 📝 Notes

### Why Use Cases?
- Encapsulate business logic
- Easy to unit test
- Can be reused across ViewModels
- Can implement complex workflows with multiple steps

### Why Protocols?
- Enable dependency injection
- Allow mocking in tests
- Support multiple implementations
- Decouple layers

### DIContainer Pattern
- Single place to create all dependencies
- Easy to switch implementations (for testing)
- Lazy initialization = better startup time
- Singleton = shared across app
