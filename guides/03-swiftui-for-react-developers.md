# SwiftUI for React/Next.js Developers: A Comprehensive Guide

This guide maps SwiftUI concepts to React/Next.js patterns, helping JavaScript developers understand iOS development through familiar paradigms. We'll use real examples from the Any Distance codebase to illustrate these concepts.

## Table of Contents
1. [Views as Components](#views-as-components)
2. [State Management](#state-management)
3. [Props and Data Flow](#props-and-data-flow)
4. [Styling and Modifiers](#styling-and-modifiers)
5. [Component Lifecycle](#component-lifecycle)
6. [Navigation Patterns](#navigation-patterns)
7. [Forms and User Input](#forms-and-user-input)
8. [Lists and Performance](#lists-and-performance)
9. [Animations and Transitions](#animations-and-transitions)
10. [Real-World Examples](#real-world-examples)

## Views as Components

### React Component
```jsx
// React Component
const ProfileCard = ({ user, onEdit }) => {
  return (
    <div className="profile-card">
      <img src={user.avatar} alt={user.name} />
      <h2>{user.name}</h2>
      <button onClick={onEdit}>Edit Profile</button>
    </div>
  );
};
```

### SwiftUI View
```swift
// SwiftUI View (from ProfileView.swift)
struct ProfileCard: View {
    let user: ADUser
    let onEdit: () -> Void
    
    var body: some View {
        VStack {
            AsyncImage(url: user.avatar) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 100, height: 100)
            
            Text(user.name)
                .font(.title2)
            
            Button("Edit Profile") {
                onEdit()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
```

**Key Differences:**
- SwiftUI uses `struct` instead of `function` or `class`
- The `body` property returns the view hierarchy
- No JSX - Swift's declarative syntax is built into the language
- Components are called "Views" in SwiftUI

## State Management

### @State vs useState

**React useState:**
```jsx
const [count, setCount] = useState(0);
const [isLoading, setIsLoading] = useState(false);
```

**SwiftUI @State:**
```swift
// From DataEntryView.swift
@State var data: Double
@State private var isLoading = false
```

### @StateObject/@ObservedObject vs useContext/Redux

**React Context/Redux:**
```jsx
// React Context
const UserContext = createContext();

const ProfileScreen = () => {
  const { user, updateUser } = useContext(UserContext);
  // or with Redux
  const user = useSelector(state => state.user);
  const dispatch = useDispatch();
};
```

**SwiftUI ObservableObject:**
```swift
// From ProfileViewModel.swift
class ProfileViewModel: NSObject, ObservableObject {
    @Published var posts: [Post] = []
    @Published var namePendingEdit: String = ""
    @Published var isEditing: Bool = false
    
    var user: ADUser
    
    func saveUser() {
        // Update logic
    }
}

// In the View
struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    // or for ownership
    @StateObject private var model = ProfileViewModel()
}
```

**Real Example from RecordingView.swift:**
```swift
fileprivate struct MapView: UIViewRepresentable {
    @ObservedObject var model: RecordingViewModel
    
    // The view automatically re-renders when model changes
}
```

### @Environment vs React Context

**React:**
```jsx
const theme = useContext(ThemeContext);
```

**SwiftUI:**
```swift
// From DataEntryView.swift
@Environment(\.presentationMode) var presentationMode
```

## Props and Data Flow

### @Binding vs Props

**React Props with Callback:**
```jsx
const InputField = ({ value, onChange }) => (
  <input value={value} onChange={(e) => onChange(e.target.value)} />
);

// Parent
const [text, setText] = useState('');
<InputField value={text} onChange={setText} />
```

**SwiftUI @Binding:**
```swift
// From DataEntryView.swift
struct DataEntryCell: View {
    @Binding var data: Double
    
    var body: some View {
        TextField("Enter value", value: $data, format: .number)
    }
}

// Parent
@State private var distance: Double = 0
DataEntryCell(data: $distance)
```

## Styling and Modifiers

### CSS/Styled-Components vs ViewModifiers

**React with CSS/Styled-Components:**
```jsx
// CSS-in-JS
const StyledButton = styled.button`
  background: white;
  padding: 12px 24px;
  border-radius: 8px;
  opacity: ${props => props.disabled ? 0.5 : 1};
`;

// Tailwind
<button className="bg-white px-6 py-3 rounded-lg opacity-50">
```

**SwiftUI ViewModifiers:**
```swift
// From ProfileView.swift
Text("Hello")
    .font(.system(size: 16, weight: .medium))
    .foregroundColor(.white)
    .padding()
    .background(Color.black)
    .cornerRadius(12)
    .opacity(isDisabled ? 0.5 : 1)
```

**Custom ViewModifier from ProfileView.swift:**
```swift
struct EditingAnimationBorder: ViewModifier {
    var cornerRadius: CGFloat = 8.0
    @State var editingAnimation: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(editingAnimation ? Color.white : Color.white.opacity(0.5))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    editingAnimation.toggle()
                }
            }
    }
}
```

## Component Lifecycle

### React Lifecycle/Hooks vs SwiftUI

**React:**
```jsx
useEffect(() => {
  // Component mounted
  loadData();
  
  return () => {
    // Cleanup
  };
}, []);

useEffect(() => {
  // When userId changes
}, [userId]);
```

**SwiftUI:**
```swift
// From ProfileViewModel.swift
.onAppear {
    loadPosts()
}
.onDisappear {
    // Cleanup
}
.onChange(of: userId) { newValue in
    // React to changes
}
```

**Real Example with Combine (similar to useEffect dependencies):**
```swift
// From ProfileViewModel.swift
PostCache.shared.postCachedPublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in
        self?.posts = PostCache.shared.posts(forUserID: self?.user.id)
    }
    .store(in: &subscribers)
```

## Navigation Patterns

### Next.js Routing vs SwiftUI Navigation

**Next.js:**
```jsx
import { useRouter } from 'next/router';

const router = useRouter();
router.push('/profile/123');

// or with Link
<Link href="/profile/123">View Profile</Link>
```

**SwiftUI Navigation:**
```swift
// From ProfileView.swift - Programmatic navigation
Button {
    let vc = SettingsViewController()
    vc.modalPresentationStyle = .overFullScreen
    UIApplication.shared.topViewController?.present(vc, animated: true)
} label: {
    Image(systemName: "gear")
}

// Sheet presentation (modal)
.sheet(isPresented: $showingSettings) {
    SettingsView()
}

// NavigationLink (not found in Any Distance, but common pattern)
NavigationLink(destination: DetailView()) {
    Text("Show Detail")
}
```

## Forms and User Input

### React Forms vs SwiftUI Forms

**React:**
```jsx
const [formData, setFormData] = useState({ name: '', email: '' });

<form onSubmit={handleSubmit}>
  <input 
    value={formData.name}
    onChange={(e) => setFormData({...formData, name: e.target.value})}
  />
</form>
```

**SwiftUI from DataEntryView.swift:**
```swift
struct DataEntryView: View {
    @State var data: Double
    let updateDataHandler: (Double) -> ()
    
    var body: some View {
        VStack {
            Text(description)
                .font(.system(size: 16))
            
            DataEntryCell(title: inputTitle, data: $data)
            
            Button {
                updateDataHandler(data)
                presentationMode.dismiss()
            } label: {
                Text(confirmButtonTitle)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
}
```

## Lists and Performance

### React Virtualization vs SwiftUI Lists

**React with Virtualization:**
```jsx
import { FixedSizeList } from 'react-window';

<FixedSizeList
  height={600}
  itemCount={items.length}
  itemSize={80}
>
  {({ index, style }) => (
    <div style={style}>
      {items[index].name}
    </div>
  )}
</FixedSizeList>
```

**SwiftUI Lists from ProfileView.swift:**
```swift
// LazyVStack for performance (similar to virtualization)
LazyVStack(spacing: 12) {
    ForEach(model.postCellModels, id: \.post.id) { model in
        PostCell(model: model)
            .modifier(BlurOpacityTransition(speed: 1.5))
    }
}
.padding([.leading, .trailing], 15)

// From ReadableScrollView.swift
ScrollView {
    LazyVStack {
        content
    }
}
```

**Key Points:**
- `LazyVStack`/`LazyHStack` provide automatic virtualization
- `ForEach` is like `map()` but SwiftUI-optimized
- `id` parameter helps with diffing (like React's `key`)

## Animations and Transitions

### React Animations vs SwiftUI

**React with Framer Motion:**
```jsx
<motion.div
  animate={{ opacity: 1, scale: 1 }}
  initial={{ opacity: 0, scale: 0.8 }}
  transition={{ duration: 0.5 }}
>
  Content
</motion.div>
```

**SwiftUI Animations from ProfileView.swift:**
```swift
// Implicit animation
.onAppear {
    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
        editingAnimation = !editingAnimation
    }
}

// Animation modifier
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRefreshing)

// Custom transition from SwiftUIExtensions.swift
.transition(.modifier(
    active: BlurModifier(radius: 8),
    identity: BlurModifier(radius: 0)
))
```

## Real-World Examples

### 1. Component with State and Props

**React Version:**
```jsx
const ActivityCell = ({ activity, onTap }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [graphImage, setGraphImage] = useState(null);
  
  useEffect(() => {
    loadGraphImage();
  }, [activity.id]);
  
  return (
    <div onClick={onTap} className="activity-cell">
      {isLoading ? <Spinner /> : <img src={graphImage} />}
      <h3>{activity.distance} km</h3>
    </div>
  );
};
```

**SwiftUI Version from ProfileView.swift:**
```swift
struct ActivityCell: View {
    @StateObject var user = ADUser.current
    var activity: Activity
    var onTap: (() -> Void)?
    @State private var graphImage: UIImage?
    @State private var bigLabelString: String = ""
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack {
                if let graphImage = graphImage {
                    Image(uiImage: graphImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
                
                Text(bigLabelString)
                    .font(.headline)
            }
        }
        .onAppear {
            computeBigLabelString()
        }
    }
}
```

### 2. Form with Validation

**React:**
```jsx
const [email, setEmail] = useState('');
const [error, setError] = useState('');

const validate = () => {
  if (!email.includes('@')) {
    setError('Invalid email');
    return false;
  }
  return true;
};
```

**SwiftUI Pattern:**
```swift
@State private var email = ""
@State private var showError = false

var isValidEmail: Bool {
    email.contains("@")
}

TextField("Email", text: $email)
    .onChange(of: email) { _ in
        showError = !isValidEmail && !email.isEmpty
    }

if showError {
    Text("Invalid email")
        .foregroundColor(.red)
}
```

### 3. API Integration

**React:**
```jsx
const [posts, setPosts] = useState([]);

useEffect(() => {
  fetchPosts().then(setPosts);
}, [userId]);
```

**SwiftUI from ProfileViewModel.swift:**
```swift
@Published var posts: [Post] = []

func loadPosts() {
    Task(priority: .background) {
        do {
            let newPosts = try await PostManager.shared.getUserPosts(
                for: user.id,
                startDate: Date(timeIntervalSince1970: 0),
                perPage: 50
            )
            DispatchQueue.main.async {
                self.posts = newPosts
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
```

## Key Takeaways

1. **Declarative Syntax**: Both React and SwiftUI use declarative UI, but SwiftUI's is built into Swift
2. **State Management**: SwiftUI's `@State`, `@StateObject`, and `@ObservedObject` map closely to React's hooks
3. **Component Composition**: Both encourage small, reusable components (Views in SwiftUI)
4. **Performance**: SwiftUI's `Lazy` views provide automatic virtualization
5. **Navigation**: SwiftUI navigation is more imperative, similar to React Navigation rather than Next.js
6. **Styling**: ViewModifiers chain like CSS-in-JS but are type-safe
7. **Animations**: SwiftUI animations are more integrated into the framework

The Any Distance codebase shows mature SwiftUI patterns including:
- Complex state management with Combine
- Custom view modifiers for reusable styling
- Performance optimizations with lazy loading
- Integration with UIKit when needed
- Reactive data flow patterns similar to React

This mental model should help you translate React concepts to SwiftUI as you work on the Any Distance iOS app.