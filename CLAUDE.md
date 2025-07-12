# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Any Distance** - 2023 Apple Design Award winner for Visuals & Graphics. An iOS fitness tracking app with advanced 3D route visualization and social features.

## Common Commands

```bash
# Dependency Installation (REQUIRED before opening project)
pod install

# Building
xcodebuild -workspace ADAC.xcworkspace -scheme ADAC -configuration Debug build
xcodebuild -workspace ADAC.xcworkspace -scheme ADAC -configuration Release build

# Testing
xcodebuild -workspace ADAC.xcworkspace -scheme ADAC test

# Run on Simulator
xcodebuild -workspace ADAC.xcworkspace -scheme ADAC -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build
xcodebuild -workspace ADAC.xcworkspace -scheme ADAC clean
```

## Critical Development Notes

### Workspace Setup
- **ALWAYS use `ADAC.xcworkspace`** (not ADAC.xcodeproj)
- Run `pod install` before opening the project
- API keys can be left blank for basic development

### Architecture & Code Organization

The app uses a hybrid UIKit/SwiftUI architecture:

**Core Components:**
- `Activity Recording/` - GPS tracking with Kalman filtering, activity state management
- `Data Stores/` - HealthKit, Garmin, Wahoo integrations with repository pattern
- `Route Rendering/` - SceneKit-based 3D visualization and video generation
- `Edge API/` - Backend API client for social features and data sync
- `Screens/` - Mix of UIKit ViewControllers and SwiftUI Views

**Data Flow:**
1. Activity data sources: HealthKit (primary), Garmin, Wahoo (via OAuth)
2. CloudKit for user data sync and invite codes
3. Edge API for social features (posts, clubs, friends)

**Key Patterns:**
- MVVM for SwiftUI views (see `ActivityDesignViewModel`)
- Repository pattern for data stores (`ActivitiesData`, `GarminStore`, etc.)
- Coordinator pattern in some navigation flows
- Heavy use of Combine for reactive updates

### Testing Approach
- Unit tests in `ADACTests/` target
- Test files follow naming: `[Feature]Tests.swift`
- Use XCTest framework
- Limited test coverage - focus on data models and view models

### External Service Integration

**OAuth Integrations:**
- Garmin Connect: `GarminStore.swift` - handles activity sync
- Wahoo Fitness: `WahooStore.swift` - handles device data sync
- Both use OAuthSwift with custom fork from Any-Distance org

**3D/AR Features:**
- SceneKit for 3D route visualization
- AR medal viewing with ARKit
- Video generation using ffmpeg-kit-ios

### Development Guidelines

**When modifying activity recording:**
- Check `ActivityRecordingViewModel` for state management
- Verify GPS permissions and background mode settings
- Test with real device for accurate GPS data

**When working with 3D features:**
- Resources in `Resources/3D Models/` (.usdz, .scn files)
- Route rendering logic in `Route Rendering/`
- Performance sensitive - test on older devices

**When updating UI:**
- Prefer SwiftUI for new features
- Follow existing patterns in `SwiftUI Utilities/`
- Maintain compatibility with iOS 14.0+

**Data Store Updates:**
- Always handle offline scenarios
- Sync logic should be idempotent
- Check `ActivitiesData` for the central data repository

### Missing Components
The following were removed from the open-source version:
- API keys (use cocoapods-keys to add your own)
- Licensed fonts (Presicav, Greed, NeueMatic, etc.)
- HipstaKit photo filter SDK
- Backend API endpoints

### Build Configurations
- **Debug**: Development builds with logging
- **Release**: Production builds with optimizations
- **Schemes**: ADAC (main app), ADACTests, Widget, WatchKit Extension

### Common Issues & Solutions
- **"No such module" errors**: Run `pod install`
- **Signing errors**: Update team ID in project settings
- **API key prompts**: Enter blank values for development
- **CloudKit errors**: Requires valid Apple Developer account