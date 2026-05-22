# Trucker Motor Task Manager - Project Documentation

## Architecture & State Management
This application employs a strict **Clean Architecture** combined with a **Feature-First** structure. 
- **Domain Layer:** Encapsulates core business rules (e.g., `TaskModel`, `UserModel`, `Failures`).
- **Data Layer:** Handles data fetching and caching (Repositories, Local/Remote Data Sources).
- **Presentation Layer:** Contains UI and State logic (BLoC for Tasks, GetX for Auth/Navigation).

### Why BLoC and GetX together?
- **BLoC (`flutter_bloc`):** Used exclusively for `TaskBloc`. The task management involves complex, stream-based state transitions such as searching, filtering, and the 5-second undo timer for task deletion. BLoC handles these predictably.
- **GetX (`get`):** Used for Authentication state, dependency injection, and routing. GetX allows us to keep navigation extremely simple without context drilling, making splash screens and protected routes cleaner.

## Packages Used & Why
| Package | Purpose & How it Works |
|---------|------------------------|
| **`firebase_auth` & `firebase_core`** | **Purpose:** Provides secure, production-ready authentication.<br>**How it works:** Replaced mock login logic with real Email/Password authentication. Stores a secure JWT token. Restricts access to verified users only. |
| **`flutter_bloc`** | **Purpose:** Manages task-related states.<br>**How it works:** Listens to user events (Add, Edit, Delete), processes the business logic, and emits states (`TaskLoaded`, `TaskError`) that the UI reacts to. |
| **`get`** | **Purpose:** State, Routing, and DI.<br>**How it works:** Secures routes via `AuthMiddleware`, injects dependencies globally via `Get.put()`, and presents Snackbars globally without `BuildContext`. |
| **`hive` & `hive_flutter`** | **Purpose:** Offline database and caching.<br>**How it works:** A blazing-fast local NoSQL database that saves task objects persistently. This powers the "Offline-First" capability. |
| **`dio`** | **Purpose:** HTTP Client for fetching remote data.<br>**How it works:** Makes API calls to `jsonplaceholder` to simulate syncing tasks. Includes interceptors for injecting Auth tokens dynamically. |
| **`flutter_local_notifications`** | **Purpose:** Displays on-device notifications.<br>**How it works:** Triggers a local notification immediately when tasks become overdue or are successfully created. |
| **`firebase_messaging`** | **Purpose:** Handles Push Notifications.<br>**How it works:** Connects to Firebase Cloud Messaging to receive remote commands (like forced logouts or sync triggers) even when the app is in the background. |
| **`flutter_background_service`** | **Purpose:** Background task execution.<br>**How it works:** Runs a headless Dart isolate every 15 minutes to sync tasks with the remote API, independent of the main app lifecycle. |

---

## App Screens (Pages) & Workflows

### 1. Splash Screen (`splash_screen.dart`)
- **Why:** To hold the UI while dependencies load and to verify the user's authentication token.
- **How it works:** Mounts an initialization listener. If `AuthController` finds a valid Firebase token in secure storage, it redirects to `Home`. If no token exists, it redirects to `Login`.

### 2. Login Screen (`login_screen.dart`)
- **Why:** Gateway for registered users.
- **How it works:** Collects Email and Password. Validates format. Dispatches to `FirebaseAuth` to authenticate. If successful, redirects to `/home`.

### 3. Register Screen (`register_screen.dart`)
- **Why:** Allows new users to create an account.
- **How it works:** Collects Full Name, Email, and Password. Creates a Firebase Auth profile. On success, it instantly logs the user out and redirects back to `LoginScreen` with a success Snackbar, requiring the user to log in manually as a security verification step.

### 4. Task List Screen (`task_list_screen.dart` - Home)
- **Why:** The main dashboard showing all tasks.
- **How it works:** Reads the `TaskBloc` state. It pulls all tasks (local Hive database merged with the API list). Allows sorting, filtering, and searching. Uses a `FloatingActionButton` to navigate to `AddEditTaskScreen`.

### 5. Add / Edit Task Screen (`add_edit_task_screen.dart`)
- **Why:** To create new tasks or modify existing ones.
- **How it works:** Reuses the same UI form for both Add and Edit operations. If an existing `TaskModel` is passed as arguments, it pre-fills the fields. Validates the title, ensures the due date is valid, and dispatches either `AddTask` or `UpdateTask` to the `TaskBloc`.

### 6. Task Detail Screen (`task_detail_screen.dart`)
- **Why:** To view full task information.
- **How it works:** Displays all task details in a read-only format. Includes actions to Edit or Delete the task directly from the view.

---

## Task Management & Features

### Fetching & Listing Tasks (Offline-First Sync)
1. When the app opens, `TaskBloc` dispatches `LoadTasks`.
2. `TaskRepositoryImpl.getTasks()` fetches the mock data from the JSONPlaceholder API.
3. Instead of overwriting your local tasks, it **merges** the remote API tasks into the local `Hive` database using `.putAll()`.
4. It reads the unified database (which includes the remote API tasks + locally created tasks) and displays them. Newest tasks appear at the top.

### Adding a Task
1. The user fills out the form in `AddEditTaskScreen`.
2. A `TaskModel` is generated (with a unique `uuid` since it is local).
3. The task is saved directly to the local Hive database.
4. A local push notification is triggered ("Task Created").

### Deleting a Task & The 5-Second Undo
1. When a user swipes to delete or hits the delete button, `TaskBloc` intercepts the `DeleteTask` event.
2. The task is immediately **removed from the UI list** to feel snappy, but it is **not deleted from the database yet**.
3. It is stored in memory as `lastDeletedTask`, and a 5-second `Timer` starts. A Snackbar appears with an "Undo" button.
4. **If the user clicks Undo:** The `UndoDeleteTask` event is dispatched. The timer is canceled, and the task is added back to the UI list.
5. **If 5 seconds pass:** The timer expires, triggering `ConfirmDelete`. The task is permanently wiped from the Hive database.
