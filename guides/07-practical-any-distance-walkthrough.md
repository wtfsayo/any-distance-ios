# Lesson 7: Practical Any Distance Walkthrough

## Table of Contents
1. [Understanding the Codebase Structure](#understanding-the-codebase-structure)
2. [Architecture Patterns in Any Distance](#architecture-patterns-in-any-distance)
3. [Common Tasks: Web to iOS Mapping](#common-tasks-web-to-ios-mapping)
4. [Adding a New Feature Walkthrough](#adding-a-new-feature-walkthrough)
5. [Debugging Techniques and Tools](#debugging-techniques-and-tools)
6. [Performance Optimization Tips](#performance-optimization-tips)
7. [Exercise: Building a Workout Statistics Feature](#exercise-building-a-workout-statistics-feature)

---

## Understanding the Codebase Structure

### Project Organization

The Any Distance iOS app follows a well-organized structure that separates concerns and promotes maintainability:

```
ADAC/ADAC/
├── Activity Designs/        # Custom activity card design system
├── Activity Recording/      # Core recording functionality
├── Assets.xcassets/        # Images, colors, and app icons
├── CloudKit/               # iCloud sync functionality
├── Collectibles/           # Achievement/medal system
├── Data Stores/            # Data persistence and management
├── Edge API/               # Backend API communication
├── External Services/      # Garmin, Wahoo integrations
├── Model/                  # Core data models
├── Screens/                # View controllers and SwiftUI views
├── SwiftUI Utilities/      # Reusable SwiftUI components
├── View - UIKit/           # UIKit views and components
└── Workouts/               # Activity/workout models and logic
```

### Key Architecture Decisions

1. **Hybrid UIKit/SwiftUI**: The app uses UIKit for navigation structure with SwiftUI views embedded via `UIHostingController`
2. **Protocol-Oriented Design**: Heavy use of protocols for extensibility (see `Activity` protocol)
3. **Async/Await**: Modern concurrency for data fetching and processing
4. **Combine Framework**: Reactive programming for state management

---

## Architecture Patterns in Any Distance

### 1. Scene-Based Navigation

The app uses `SceneDelegate` for managing the app lifecycle and deep linking:

```swift
// SceneDelegate.swift - Entry point configuration
if ADUser.current.hasFinishedOnboarding {
    let mainTabBar = UIStoryboard(name: "TabBar", bundle: nil)
        .instantiateViewController(withIdentifier: "mainTabBar") as? ADTabBarController
    mainTabBar?.setSelectedTab(.track)
    window.rootViewController = mainTabBar
} else {
    let vc = OnboardingViewController()
    window.rootViewController = vc
}
```

### 2. Data Store Pattern

The app uses specialized stores for different data types:

```swift
// Example: ActivitiesData.swift
class ActivitiesData {
    static let shared = ActivitiesData()
    
    // Manages activities from multiple sources
    private var healthKitStore = HealthKitActivitiesStore()
    private var garminStore = GarminActivitiesStore()
    private var wahooStore = WahooActivitiesStore()
}
```

### 3. View Model Pattern

SwiftUI views use ObservableObject view models:

```swift
// ProfileViewModel.swift pattern
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var postCellModels: [PostCellModel] = []
    
    func loadUserData() async {
        // Fetch and update published properties
    }
}
```

---

## Common Tasks: Web to iOS Mapping

### Adding a New Screen/Page

**Web Approach:**
```javascript
// Create new React component
function NewFeature() {
    return <div>New Feature</div>
}
// Add route
<Route path="/new-feature" component={NewFeature} />
```

**iOS Approach:**
```swift
// 1. Create SwiftUI View
// File: Screens/NewFeature/NewFeatureView.swift
struct NewFeatureView: View {
    @ObservedObject var viewModel: NewFeatureViewModel
    
    var body: some View {
        VStack {
            Text("New Feature")
        }
    }
}

// 2. Create ViewModel
// File: Screens/NewFeature/NewFeatureViewModel.swift
class NewFeatureViewModel: ObservableObject {
    @Published var data: [String] = []
}

// 3. Present the view
let view = NewFeatureView(viewModel: NewFeatureViewModel())
let hostingController = UIHostingController(rootView: view)
self.present(hostingController, animated: true)
```

### Fetching and Displaying Data

**Web Approach:**
```javascript
const [data, setData] = useState([]);
useEffect(() => {
    fetch('/api/data').then(res => res.json()).then(setData);
}, []);
```

**iOS Approach:**
```swift
// In ViewModel
@MainActor
class DataViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    
    func loadData() async {
        isLoading = true
        do {
            // Using Any Distance's Edge API pattern
            let response = try await Edge.shared.get("/api/data")
            items = try JSONDecoder().decode([Item].self, from: response)
        } catch {
            print("Error loading data: \(error)")
        }
        isLoading = false
    }
}
```

### Handling User Input

**Web Approach:**
```javascript
<input value={text} onChange={(e) => setText(e.target.value)} />
```

**iOS Approach:**
```swift
// SwiftUI approach used in Any Distance
struct InputView: View {
    @State private var text = ""
    
    var body: some View {
        TextField("Enter text", text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

// Any Distance uses custom components like TaggableTextField
TaggableTextField(
    text: $viewModel.caption,
    placeholder: "Add a caption...",
    onCommit: { viewModel.savePost() }
)
```

### Styling and Theming

**Web Approach:**
```css
.button { background: #007AFF; color: white; }
```

**iOS Approach:**
```swift
// Any Distance uses SwiftUI modifiers and custom styles
Button("Save") {
    // Action
}
.buttonStyle(ADWhiteButton()) // Custom button style

// Custom styles defined in SwiftUI Utilities
struct ADWhiteButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
```

---

## Adding a New Feature Walkthrough

Let's walk through adding a "Workout Insights" feature that shows statistics about recent workouts.

### Step 1: Create the Model

```swift
// File: Model/WorkoutInsight.swift
struct WorkoutInsight {
    let totalDistance: Float
    let totalTime: TimeInterval
    let averagePace: Float
    let activityCount: Int
    let favoriteActivityType: ActivityType
}
```

### Step 2: Create the Data Manager

```swift
// File: Data Stores/WorkoutInsightsManager.swift
class WorkoutInsightsManager: ObservableObject {
    static let shared = WorkoutInsightsManager()
    
    @Published var currentInsights: WorkoutInsight?
    
    func calculateInsights(for activities: [Activity]) async {
        // Calculate statistics
        let totalDistance = activities.reduce(0) { $0 + $1.distance }
        let totalTime = activities.reduce(0) { $0 + $1.movingTime }
        
        // Find favorite activity
        let activityTypes = activities.map { $0.activityType }
        let favoriteType = activityTypes.mostFrequent() ?? .run
        
        currentInsights = WorkoutInsight(
            totalDistance: totalDistance,
            totalTime: totalTime,
            averagePace: totalDistance / Float(totalTime),
            activityCount: activities.count,
            favoriteActivityType: favoriteType
        )
    }
}
```

### Step 3: Create the View

```swift
// File: Screens/Insights/WorkoutInsightsView.swift
struct WorkoutInsightsView: View {
    @StateObject private var insightsManager = WorkoutInsightsManager.shared
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let insights = insightsManager.currentInsights {
                VStack(spacing: 20) {
                    InsightCard(
                        title: "Total Distance",
                        value: insights.totalDistance.formattedDistance(),
                        icon: "figure.run"
                    )
                    
                    InsightCard(
                        title: "Activities",
                        value: "\(insights.activityCount)",
                        icon: "calendar"
                    )
                    
                    InsightCard(
                        title: "Favorite Activity",
                        value: insights.favoriteActivityType.name,
                        icon: insights.favoriteActivityType.iconName
                    )
                }
                .padding()
            }
        }
        .navigationTitle("Workout Insights")
        .task {
            await loadInsights()
        }
    }
    
    private func loadInsights() async {
        let activities = await ActivitiesData.shared.recentActivities(days: 30)
        await insightsManager.calculateInsights(for: activities)
        isLoading = false
    }
}

// Reusable component
struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
```

### Step 4: Add Navigation

```swift
// In existing navigation flow (e.g., ProfileView.swift)
NavigationLink(destination: WorkoutInsightsView()) {
    HStack {
        Image(systemName: "chart.bar.fill")
        Text("Workout Insights")
        Spacer()
        Image(systemName: "chevron.right")
    }
    .padding()
}
```

### Step 5: Add Tests

```swift
// File: ADACTests/WorkoutInsightsTests.swift
import XCTest
@testable import ADAC

class WorkoutInsightsTests: XCTestCase {
    func testInsightsCalculation() async {
        // Create test activities
        let activities = [
            TestActivity(distance: 5000, time: 1800, type: .run),
            TestActivity(distance: 3000, time: 1200, type: .run),
            TestActivity(distance: 10000, time: 3600, type: .ride)
        ]
        
        let manager = WorkoutInsightsManager()
        await manager.calculateInsights(for: activities)
        
        XCTAssertEqual(manager.currentInsights?.totalDistance, 18000)
        XCTAssertEqual(manager.currentInsights?.activityCount, 3)
        XCTAssertEqual(manager.currentInsights?.favoriteActivityType, .run)
    }
}
```

---

## Debugging Techniques and Tools

### 1. Using Xcode Debugger

```swift
// Add breakpoints by clicking line numbers
// Use lldb commands in console:
// po variableName  - print object
// p variableName   - print value
// bt              - backtrace
```

### 2. Debug Prints with Context

```swift
// Any Distance uses Analytics for tracking
Analytics.logEvent("Feature Used", "Workout Insights", .screenView)

// For development debugging
#if DEBUG
print("🏃 Loading activities: \(activities.count)")
#endif
```

### 3. View Hierarchy Debugging

```
// In Xcode:
// Debug > View Debugging > Capture View Hierarchy
// Inspect 3D view of your UI
```

### 4. Network Debugging

```swift
// Any Distance Edge API includes logging
extension Edge {
    func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("🌐 \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        if let body = request.httpBody {
            print("📦 Body: \(String(data: body, encoding: .utf8) ?? "")")
        }
        #endif
    }
}
```

---

## Performance Optimization Tips

### 1. Lazy Loading Views

```swift
// Use LazyVStack for long lists
LazyVStack {
    ForEach(activities) { activity in
        ActivityRow(activity: activity)
    }
}
```

### 2. Image Caching

```swift
// Any Distance uses SDWebImage
AsyncCachedImage(url: imageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    ProgressView()
}
```

### 3. Background Processing

```swift
// Move heavy work off main thread
Task.detached(priority: .background) {
    let processedData = await processLargeDataset()
    await MainActor.run {
        self.data = processedData
    }
}
```

### 4. Memory Management

```swift
// Use weak references in closures
activityRecorder.onUpdate = { [weak self] newData in
    self?.updateUI(with: newData)
}
```

---

## Exercise: Building a Workout Statistics Feature

### Goal
Add a feature that shows weekly workout statistics with a graph.

### Requirements
1. Display total distance per day for the last 7 days
2. Show a bar chart visualization
3. Allow switching between distance and time views
4. Cache results for performance

### Step-by-Step Implementation

#### 1. Create the Data Model

```swift
// File: Model/WeeklyStats.swift
struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let totalDistance: Float
    let totalTime: TimeInterval
    let activityCount: Int
}

struct WeeklyStats {
    let dailyStats: [DailyStats]
    let totalDistance: Float
    let totalTime: TimeInterval
}
```

#### 2. Create the Stats Calculator

```swift
// File: Data Stores/WeeklyStatsCalculator.swift
class WeeklyStatsCalculator {
    static func calculate(from activities: [Activity]) -> WeeklyStats {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        // Group activities by day
        let grouped = Dictionary(grouping: activities.filter { 
            $0.startDate >= weekAgo 
        }) { activity in
            calendar.startOfDay(for: activity.startDate)
        }
        
        // Calculate daily stats
        var dailyStats: [DailyStats] = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayStart = calendar.startOfDay(for: date)
            let dayActivities = grouped[dayStart] ?? []
            
            let stats = DailyStats(
                date: dayStart,
                totalDistance: dayActivities.reduce(0) { $0 + $1.distance },
                totalTime: dayActivities.reduce(0) { $0 + $1.movingTime },
                activityCount: dayActivities.count
            )
            dailyStats.append(stats)
        }
        
        return WeeklyStats(
            dailyStats: dailyStats.reversed(),
            totalDistance: dailyStats.reduce(0) { $0 + $1.totalDistance },
            totalTime: dailyStats.reduce(0) { $0 + $1.totalTime }
        )
    }
}
```

#### 3. Create the Chart View

```swift
// File: Screens/Stats/WeeklyStatsView.swift
import SwiftUI
import Charts // iOS 16+

struct WeeklyStatsView: View {
    @State private var stats: WeeklyStats?
    @State private var isLoading = true
    @State private var selectedMetric: Metric = .distance
    
    enum Metric: String, CaseIterable {
        case distance = "Distance"
        case time = "Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Metric Picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let stats = stats {
                    // Chart
                    Chart(stats.dailyStats) { stat in
                        BarMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value(
                                selectedMetric.rawValue,
                                selectedMetric == .distance 
                                    ? stat.totalDistance 
                                    : Float(stat.totalTime)
                            )
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                    
                    // Summary
                    HStack(spacing: 40) {
                        VStack {
                            Text("Total Distance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(stats.totalDistance.formattedDistance())
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack {
                            Text("Total Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(stats.totalTime.formattedDuration())
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    
                    // Daily breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily Breakdown")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(stats.dailyStats) { day in
                            DailyStatRow(stat: day)
                        }
                    }
                }
            }
        }
        .navigationTitle("Weekly Stats")
        .task {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        let activities = await ActivitiesData.shared.allActivities()
        stats = WeeklyStatsCalculator.calculate(from: activities)
        isLoading = false
    }
}

struct DailyStatRow: View {
    let stat: DailyStats
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    var body: some View {
        HStack {
            Text(dayFormatter.string(from: stat.date))
                .font(.subheadline)
                .frame(width: 40)
            
            if stat.activityCount > 0 {
                Text("\(stat.activityCount) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(stat.totalDistance.formattedDistance())
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text("Rest day")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
}
```

#### 4. Add Caching

```swift
// Extension to WeeklyStatsCalculator
extension WeeklyStatsCalculator {
    private static let cacheKey = "weeklyStatsCache"
    
    static func getCachedStats() -> WeeklyStats? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let stats = try? JSONDecoder().decode(WeeklyStats.self, from: data) else {
            return nil
        }
        return stats
    }
    
    static func cacheStats(_ stats: WeeklyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
```

#### 5. Integration Points

1. **Add to Tab Bar**: Update `ADTabBarController` to include stats
2. **Add Navigation**: Link from Profile or Activities screen
3. **Add Widget**: Create a Widget Extension for home screen
4. **Add Notifications**: Weekly summary notifications

### Testing Your Implementation

```swift
// File: ADACTests/WeeklyStatsTests.swift
class WeeklyStatsTests: XCTestCase {
    func testWeeklyCalculation() {
        let activities = createTestActivities()
        let stats = WeeklyStatsCalculator.calculate(from: activities)
        
        XCTAssertEqual(stats.dailyStats.count, 7)
        XCTAssertGreaterThan(stats.totalDistance, 0)
    }
    
    func testEmptyDays() {
        let stats = WeeklyStatsCalculator.calculate(from: [])
        XCTAssertEqual(stats.dailyStats.filter { $0.activityCount == 0 }.count, 7)
    }
}
```

### Performance Considerations

1. **Batch Loading**: Load activities in chunks
2. **Background Processing**: Calculate stats on background queue
3. **Incremental Updates**: Update only when new activities added
4. **Memory Management**: Don't keep all activities in memory

---

## Summary

This lesson covered:
- ✅ Understanding Any Distance's codebase structure
- ✅ Mapping web development concepts to iOS
- ✅ Step-by-step feature implementation
- ✅ Debugging and performance optimization
- ✅ Hands-on exercise building a statistics feature

Key takeaways:
1. Any Distance uses a hybrid UIKit/SwiftUI architecture
2. Follow existing patterns for consistency
3. Use protocols and extensions for clean code
4. Test early and often
5. Consider performance from the start

Next steps:
- Implement the weekly stats feature
- Add unit tests for your code
- Profile performance with Instruments
- Consider adding accessibility features