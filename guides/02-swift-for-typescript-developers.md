# Swift for TypeScript Developers

This guide helps TypeScript developers understand Swift by drawing parallels between the two languages. Both are modern, type-safe languages with many similar concepts, making the transition smoother than you might expect.

## Table of Contents
1. [Type System Comparison](#type-system-comparison)
2. [Optionals vs null/undefined](#optionals-vs-nullundefined)
3. [Protocols vs Interfaces](#protocols-vs-interfaces)
4. [Extensions vs Prototype Extensions](#extensions-vs-prototype-extensions)
5. [Generics Comparison](#generics-comparison)
6. [Error Handling](#error-handling)
7. [Common Patterns Translation](#common-patterns-translation)
8. [Swift-Specific Features](#swift-specific-features)
9. [Practical Examples](#practical-examples)

## Type System Comparison

Both Swift and TypeScript are strongly typed languages, but Swift's type system is more strict and doesn't allow implicit type conversions.

### Basic Types

```typescript
// TypeScript
let name: string = "John"
let age: number = 30
let isActive: boolean = true
let items: number[] = [1, 2, 3]
let tuple: [string, number] = ["hello", 42]
```

```swift
// Swift
let name: String = "John"
let age: Int = 30
let isActive: Bool = true
let items: [Int] = [1, 2, 3]
let tuple: (String, Int) = ("hello", 42)
```

### Type Inference

Both languages support type inference:

```typescript
// TypeScript
let message = "Hello" // inferred as string
let count = 42 // inferred as number
```

```swift
// Swift
let message = "Hello" // inferred as String
let count = 42 // inferred as Int
```

### Union Types vs Enums

TypeScript's union types are often replaced with Swift enums:

```typescript
// TypeScript
type Status = "pending" | "approved" | "rejected"
type Result = string | number

function processStatus(status: Status) {
    switch(status) {
        case "pending": // ...
        case "approved": // ...
        case "rejected": // ...
    }
}
```

```swift
// Swift
enum Status {
    case pending
    case approved
    case rejected
}

enum Result {
    case text(String)
    case number(Int)
}

func processStatus(status: Status) {
    switch status {
    case .pending: // ...
    case .approved: // ...
    case .rejected: // ...
    }
}
```

## Optionals vs null/undefined

Swift's optionals are more explicit than TypeScript's null/undefined handling:

```typescript
// TypeScript
let name: string | null = null
let age: number | undefined = undefined

// Checking for null/undefined
if (name !== null && name !== undefined) {
    console.log(name.toUpperCase())
}

// Optional chaining
const length = name?.length
```

```swift
// Swift
var name: String? = nil
var age: Int? = nil

// Unwrapping optionals
if let name = name {
    print(name.uppercased())
}

// Optional chaining
let length = name?.count

// Nil-coalescing
let displayName = name ?? "Anonymous"
```

### Force Unwrapping

```typescript
// TypeScript (non-null assertion)
const length = name!.length // Runtime error if null
```

```swift
// Swift (force unwrapping)
let length = name!.count // Runtime crash if nil
```

## Protocols vs Interfaces

Swift protocols are similar to TypeScript interfaces but more powerful:

```typescript
// TypeScript
interface Drawable {
    color: string
    draw(): void
}

interface Resizable {
    resize(width: number, height: number): void
}

class Circle implements Drawable, Resizable {
    color = "red"
    
    draw() {
        console.log("Drawing circle")
    }
    
    resize(width: number, height: number) {
        // ...
    }
}
```

```swift
// Swift
protocol Drawable {
    var color: String { get }
    func draw()
}

protocol Resizable {
    func resize(width: Double, height: Double)
}

class Circle: Drawable, Resizable {
    let color = "red"
    
    func draw() {
        print("Drawing circle")
    }
    
    func resize(width: Double, height: Double) {
        // ...
    }
}
```

### Protocol Extensions (Protocol-Oriented Programming)

Swift allows adding default implementations to protocols:

```swift
// Swift
protocol Greetable {
    var name: String { get }
}

extension Greetable {
    func greet() {
        print("Hello, \(name)!")
    }
}

struct Person: Greetable {
    let name: String
    // Gets greet() for free
}
```

## Extensions vs Prototype Extensions

### TypeScript Prototype Extensions

```typescript
// TypeScript (not recommended)
interface String {
    reverse(): string
}

String.prototype.reverse = function() {
    return this.split('').reverse().join('')
}

"hello".reverse() // "olleh"
```

### Swift Extensions

```swift
// Swift
extension String {
    func reversed() -> String {
        return String(self.reversed())
    }
    
    var wordCount: Int {
        return self.split(separator: " ").count
    }
}

"hello".reversed() // "olleh"
"hello world".wordCount // 2
```

## Generics Comparison

Both languages support generics with similar syntax:

```typescript
// TypeScript
function identity<T>(value: T): T {
    return value
}

class Box<T> {
    constructor(private value: T) {}
    
    getValue(): T {
        return this.value
    }
}

interface Container<T> {
    items: T[]
    add(item: T): void
}
```

```swift
// Swift
func identity<T>(_ value: T) -> T {
    return value
}

class Box<T> {
    private let value: T
    
    init(value: T) {
        self.value = value
    }
    
    func getValue() -> T {
        return value
    }
}

protocol Container {
    associatedtype Item
    var items: [Item] { get }
    mutating func add(_ item: Item)
}
```

### Generic Constraints

```typescript
// TypeScript
interface Comparable {
    compareTo(other: this): number
}

function max<T extends Comparable>(a: T, b: T): T {
    return a.compareTo(b) > 0 ? a : b
}
```

```swift
// Swift
func max<T: Comparable>(_ a: T, _ b: T) -> T {
    return a > b ? a : b
}
```

## Error Handling

### TypeScript Try-Catch

```typescript
// TypeScript
async function fetchData(url: string): Promise<any> {
    try {
        const response = await fetch(url)
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`)
        }
        return await response.json()
    } catch (error) {
        console.error("Failed to fetch:", error)
        throw error
    }
}
```

### Swift Do-Try-Catch

```swift
// Swift
enum NetworkError: Error {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError
}

func fetchData(from urlString: String) async throws -> Data {
    guard let url = URL(string: urlString) else {
        throw NetworkError.invalidURL
    }
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return data
    } catch {
        print("Failed to fetch: \(error)")
        throw error
    }
}
```

## Common Patterns Translation

### Array Methods

```typescript
// TypeScript
const numbers = [1, 2, 3, 4, 5]

// Map
const doubled = numbers.map(n => n * 2)

// Filter
const evens = numbers.filter(n => n % 2 === 0)

// Reduce
const sum = numbers.reduce((acc, n) => acc + n, 0)

// Find
const firstEven = numbers.find(n => n % 2 === 0)

// Some/Every
const hasEven = numbers.some(n => n % 2 === 0)
const allPositive = numbers.every(n => n > 0)
```

```swift
// Swift
let numbers = [1, 2, 3, 4, 5]

// Map
let doubled = numbers.map { $0 * 2 }

// Filter
let evens = numbers.filter { $0 % 2 == 0 }

// Reduce
let sum = numbers.reduce(0) { $0 + $1 }
// or more concisely:
let sum2 = numbers.reduce(0, +)

// First (equivalent to find)
let firstEven = numbers.first { $0 % 2 == 0 }

// Contains (similar to some)
let hasEven = numbers.contains { $0 % 2 == 0 }
// AllSatisfy (equivalent to every)
let allPositive = numbers.allSatisfy { $0 > 0 }
```

### Async/Await

Both languages support async/await with similar syntax:

```typescript
// TypeScript
async function fetchUser(id: string): Promise<User> {
    const response = await fetch(`/api/users/${id}`)
    return await response.json()
}

async function fetchMultipleUsers(ids: string[]): Promise<User[]> {
    const promises = ids.map(id => fetchUser(id))
    return await Promise.all(promises)
}
```

```swift
// Swift
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

func fetchMultipleUsers(ids: [String]) async throws -> [User] {
    return try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await fetchUser(id: id)
            }
        }
        
        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}
```

### Closures vs Arrow Functions

```typescript
// TypeScript
const add = (a: number, b: number): number => a + b
const greet = (name: string) => console.log(`Hello, ${name}`)

// In array methods
[1, 2, 3].map(n => n * 2)

// Capturing variables
const multiplier = 10
const multiply = (n: number) => n * multiplier
```

```swift
// Swift
let add = { (a: Int, b: Int) -> Int in
    return a + b
}
// or with type inference:
let add2: (Int, Int) -> Int = { $0 + $1 }

let greet = { (name: String) in
    print("Hello, \(name)")
}

// In array methods (trailing closure syntax)
[1, 2, 3].map { n in n * 2 }
// or with shorthand:
[1, 2, 3].map { $0 * 2 }

// Capturing variables
let multiplier = 10
let multiply = { (n: Int) in n * multiplier }
```

### Structs vs Classes vs Objects

```typescript
// TypeScript
// Object literal
const point = {
    x: 10,
    y: 20
}

// Class
class Rectangle {
    constructor(
        public width: number,
        public height: number
    ) {}
    
    get area(): number {
        return this.width * this.height
    }
}

// Interface for structure
interface Point {
    x: number
    y: number
}
```

```swift
// Swift
// Struct (value type - preferred for data)
struct Point {
    let x: Int
    let y: Int
}

// Class (reference type - for identity/inheritance)
class Rectangle {
    let width: Double
    let height: Double
    
    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    var area: Double {
        return width * height
    }
}

// Creating instances
let point = Point(x: 10, y: 20)
let rect = Rectangle(width: 100, height: 50)
```

## Swift-Specific Features

### Property Wrappers

Property wrappers in Swift are similar to decorators in TypeScript but are built into the language:

```swift
// Swift - SwiftUI
struct ContentView: View {
    @State private var count = 0
    @Binding var username: String
    @Published var items: [Item] = []
    
    var body: some View {
        Button("Count: \(count)") {
            count += 1
        }
    }
}

// Custom property wrapper
@propertyWrapper
struct Capitalized {
    private var value = ""
    
    var wrappedValue: String {
        get { value }
        set { value = newValue.capitalized }
    }
}

struct User {
    @Capitalized var name: String
}
```

TypeScript doesn't have built-in property wrappers, but decorators provide similar functionality:

```typescript
// TypeScript (experimental decorators)
function capitalized(target: any, propertyKey: string) {
    let value = target[propertyKey];
    
    const getter = () => value;
    const setter = (newVal: string) => {
        value = newVal.charAt(0).toUpperCase() + newVal.slice(1);
    };
    
    Object.defineProperty(target, propertyKey, {
        get: getter,
        set: setter
    });
}
```

### Computed Properties

```swift
// Swift
struct Circle {
    var radius: Double
    
    var diameter: Double {
        get { radius * 2 }
        set { radius = newValue / 2 }
    }
    
    var area: Double {
        .pi * radius * radius
    }
}
```

```typescript
// TypeScript
class Circle {
    constructor(public radius: number) {}
    
    get diameter(): number {
        return this.radius * 2
    }
    
    set diameter(value: number) {
        this.radius = value / 2
    }
    
    get area(): number {
        return Math.PI * this.radius * this.radius
    }
}
```

### Guard Statements

Guard statements in Swift provide early exit from functions:

```swift
// Swift
func processUser(_ user: User?) {
    guard let user = user else {
        print("No user provided")
        return
    }
    
    guard user.age >= 18 else {
        print("User is too young")
        return
    }
    
    // user is now unwrapped and validated
    print("Processing user: \(user.name)")
}
```

```typescript
// TypeScript equivalent
function processUser(user: User | null) {
    if (!user) {
        console.log("No user provided")
        return
    }
    
    if (user.age < 18) {
        console.log("User is too young")
        return
    }
    
    // user is now validated
    console.log(`Processing user: ${user.name}`)
}
```

### Switch Expressions

Swift's switch is more powerful than TypeScript's:

```swift
// Swift
let value = 42

let description = switch value {
case 0:
    "zero"
case 1...10:
    "small"
case 11...100:
    "medium"
case let x where x > 100:
    "large: \(x)"
default:
    "negative"
}

// Pattern matching with enums
enum Response {
    case success(data: String)
    case failure(error: Error)
}

func handleResponse(_ response: Response) {
    switch response {
    case .success(let data):
        print("Got data: \(data)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

```typescript
// TypeScript
const value = 42

// No direct equivalent to Swift's pattern matching
let description: string
if (value === 0) {
    description = "zero"
} else if (value >= 1 && value <= 10) {
    description = "small"
} else if (value >= 11 && value <= 100) {
    description = "medium"
} else if (value > 100) {
    description = `large: ${value}`
} else {
    description = "negative"
}

// Discriminated unions for similar pattern matching
type Response = 
    | { type: 'success'; data: string }
    | { type: 'failure'; error: Error }

function handleResponse(response: Response) {
    switch (response.type) {
        case 'success':
            console.log(`Got data: ${response.data}`)
            break
        case 'failure':
            console.log(`Error: ${response.error}`)
            break
    }
}
```

## Practical Examples

### 1. Data Model Translation

```typescript
// TypeScript
interface User {
    id: string
    name: string
    email: string
    age?: number
    roles: string[]
    metadata: Record<string, any>
}

class UserService {
    private users: Map<string, User> = new Map()
    
    async getUser(id: string): Promise<User | undefined> {
        return this.users.get(id)
    }
    
    async createUser(data: Omit<User, 'id'>): Promise<User> {
        const user: User = {
            id: crypto.randomUUID(),
            ...data
        }
        this.users.set(user.id, user)
        return user
    }
}
```

```swift
// Swift
struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let age: Int?
    let roles: [String]
    let metadata: [String: Any]
    
    // Codable with Any requires custom implementation
    enum CodingKeys: String, CodingKey {
        case id, name, email, age, roles, metadata
    }
}

class UserService {
    private var users: [String: User] = [:]
    
    func getUser(id: String) async -> User? {
        return users[id]
    }
    
    func createUser(name: String, email: String, age: Int?, roles: [String], metadata: [String: Any]) async -> User {
        let user = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            age: age,
            roles: roles,
            metadata: metadata
        )
        users[user.id] = user
        return user
    }
}
```

### 2. API Client Translation

```typescript
// TypeScript
class APIClient {
    constructor(private baseURL: string) {}
    
    async request<T>(
        endpoint: string,
        options?: RequestInit
    ): Promise<T> {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            headers: {
                'Content-Type': 'application/json',
                ...options?.headers
            },
            ...options
        })
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`)
        }
        
        return response.json()
    }
    
    get<T>(endpoint: string): Promise<T> {
        return this.request<T>(endpoint, { method: 'GET' })
    }
    
    post<T>(endpoint: string, body: any): Promise<T> {
        return this.request<T>(endpoint, {
            method: 'POST',
            body: JSON.stringify(body)
        })
    }
}
```

```swift
// Swift
class APIClient {
    private let baseURL: String
    private let session = URLSession.shared
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func request<T: Decodable>(
        _ type: T.Type,
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    func get<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        return try await request(type, endpoint: endpoint)
    }
    
    func post<T: Decodable, U: Encodable>(
        _ type: T.Type,
        endpoint: String,
        body: U
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await request(type, endpoint: endpoint, method: "POST", body: bodyData)
    }
}
```

### 3. State Management Pattern

```typescript
// TypeScript - Redux-like pattern
type Action = 
    | { type: 'INCREMENT' }
    | { type: 'DECREMENT' }
    | { type: 'SET'; value: number }

interface State {
    count: number
}

function reducer(state: State, action: Action): State {
    switch (action.type) {
        case 'INCREMENT':
            return { count: state.count + 1 }
        case 'DECREMENT':
            return { count: state.count - 1 }
        case 'SET':
            return { count: action.value }
    }
}
```

```swift
// Swift - Similar pattern
enum Action {
    case increment
    case decrement
    case set(value: Int)
}

struct State {
    var count: Int
}

func reducer(state: State, action: Action) -> State {
    var newState = state
    
    switch action {
    case .increment:
        newState.count += 1
    case .decrement:
        newState.count -= 1
    case .set(let value):
        newState.count = value
    }
    
    return newState
}

// SwiftUI Observable pattern
class CounterViewModel: ObservableObject {
    @Published var count = 0
    
    func increment() {
        count += 1
    }
    
    func decrement() {
        count -= 1
    }
    
    func set(to value: Int) {
        count = value
    }
}
```

## Key Takeaways

1. **Type Safety**: Swift is more strict about types than TypeScript. No implicit conversions.

2. **Optionals**: Swift's optional system is more explicit than TypeScript's null/undefined.

3. **Value vs Reference Types**: Swift distinguishes between structs (value) and classes (reference), while TypeScript only has reference types.

4. **Protocol-Oriented**: Swift emphasizes protocols and extensions over inheritance.

5. **Pattern Matching**: Swift's switch statements and enum associated values provide powerful pattern matching.

6. **Memory Management**: Swift uses ARC (Automatic Reference Counting), while TypeScript/JavaScript uses garbage collection.

7. **Immutability**: Swift encourages immutability with `let` vs `var`, similar to TypeScript's `const` vs `let`.

8. **Error Handling**: Swift's throws/try/catch is more explicit about which functions can throw errors.

Remember that while the syntax and some concepts differ, the fundamental programming principles remain the same. Focus on understanding Swift's approach to safety, clarity, and performance, and you'll find many of your TypeScript skills transfer well to Swift development.