# Design Document — RAMPART Chat

## 1. System Overview & Goal

RAMPART Chat is a lightweight, real-time ephemeral messaging application designed for quick, disposable conversations without requiring user authentication. Users can instantly join or create chat rooms, exchange text-only messages, and leave with no persistent identity or history beyond the session.

The core goal is to provide a frictionless chat experience where the barrier to entry is zero — no sign-up, no profile, no persistent identity — enabling rapid, transient communication.

## 2. Architecture & Tech Stack

### 2.1. Framework & Rendering

- **Next.js App Router** (`app/` directory) handles server-side routing, layout nesting, and API route definitions. The application uses a client-heavy model for real-time interactivity but leverages the App Router for top-level layout structure and metadata management.
- **React Client Components** declared with `"use client"` enable real-time state and Firebase listener hooks within the interactive portions of the UI.

### 2.2. Styling

- **Tailwind CSS** provides utility-first custom dynamic styling. All visual theming (color palettes, spacing, typography) is expressed through Tailwind classes, enabling rapid UI iteration without leaving markup. Dark/light mode toggling is managed via Tailwind's `darkMode` class strategy coupled with a React context provider.

### 2.3. Real-Time Backend

- **Firebase Firestore** serves as the real-time data layer. Firestore's document-snapshot listeners (`onSnapshot`) propagate message and room changes to all connected clients instantly, eliminating the need for a custom WebSocket server.
- **Firebase Anonymous Authentication** enables the ephemeral identity model. Users are assigned a temporary anonymous UID on first visit, allowing Firestore security rules to enforce rate limits and message ownership without requiring persistent credentials.

### 2.4. Deployment

- The application is deployed as a static export or on a Node.js runtime (Vercel, Firebase Hosting) depending on the need for server-side features. API routes are limited; the vast majority of logic runs on the client and directly against Firestore.

---

## 3. Data Models & Schema

Firestore is organized into three top-level collections: `rooms`, `categories`, and `messages`.

### 3.1. Rooms Collection

```
/rooms/{roomId}
```

| Field        | Type     | Description                                         |
|--------------|----------|-----------------------------------------------------|
| `id`         | string   | Auto-generated document ID                          |
| `name`       | string   | Human-readable room name or title                   |
| `slug`       | string   | URL-friendly identifier for route matching          |
| `categoryId` | string   | Foreign-key reference to `/categories/{categoryId}` |
| `createdAt`  | Timestamp| Firestore server timestamp of room creation         |
| `lastActive` | Timestamp| Updated on each new message (used for sorting)      |
| `messageCount` | number | Approximate count of messages (updated periodically)|
| `createdBy`  | string   | Anonymous UID of the creator                        |

**Indexes:** Composite index on `categoryId + lastActive DESC` for category-scoped room listing.

### 3.2. Categories Collection

```
/categories/{categoryId}
```

| Field        | Type     | Description                                  |
|--------------|----------|----------------------------------------------|
| `id`         | string   | Auto-generated document ID                   |
| `name`       | string   | Display name (e.g., "General", "Tech")       |
| `slug`       | string   | URL-friendly identifier                      |
| `icon`       | string   | Optional emoji or icon name for the UI       |
| `order`      | number   | Sort order for category listing              |
| `createdAt`  | Timestamp| Firestore server timestamp                   |

### 3.3. Messages Collection

Messages are stored in a top-level collection (or optionally subcollections under rooms for larger scale).

```
/messages/{messageId}
```

| Field        | Type     | Description                                        |
|--------------|----------|----------------------------------------------------|
| `id`         | string   | Auto-generated document ID                         |
| `roomId`     | string   | Foreign-key reference to `/rooms/{roomId}`         |
| `text`       | string   | Plain text content (no rich media, no file attachments) |
| `senderId`   | string   | Anonymous UID of the sender                        |
| `senderName` | string   | Ephemeral display name chosen for the session      |
| `createdAt`  | Timestamp| Firestore server timestamp; used for ordering      |
| `editedAt`   | Timestamp| Firestore server timestamp of last edit (nullable) |

**Constraints:**

- `text` is limited to 2000 characters (enforced client-side and via Firestore `validate()` function in security rules).
- No file attachments, images, or embedded media are permitted.
- Messages are text-only to maintain the lightweight, ephemeral ethos.

**Indexes:**

- Composite index on `roomId + createdAt ASC` for chronological message retrieval.
- Composite index on `senderId + createdAt DESC` for user-scoped history (when available).

### 3.4. Firestore Security Rules (Summary)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow anonymous read/write with rate limits
    match /rooms/{roomId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.name is string
                    && request.resource.data.name.size() <= 100;
      allow update: if request.auth != null
                    && request.resource.data.name == resource.data.name;
      allow delete: if request.auth.uid == resource.data.createdBy;
    }

    match /messages/{messageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.text is string
                    && request.resource.data.text.size() <= 2000;
      allow update: if request.auth.uid == resource.data.senderId;
      allow delete: if request.auth.uid == resource.data.senderId
                    && request.time - resource.data.createdAt < duration.value(5, 'm');
    }

    match /categories/{categoryId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin-only via Firebase Console or Admin SDK
    }
  }
}
```

---

## 4. Client-Side State Management

### 4.1. Theme Context Controller

A React Context provider (`ThemeContext`) wraps the application at the root layout level.

```typescript
interface ThemeContextValue {
  mode: 'light' | 'dark';
  toggle: () => void;
}
```

- The controller persists the user's preference to `localStorage` under the key `theme-mode`.
- On initial load, the controller reads the stored preference; if none exists, it falls back to the system `prefers-color-scheme` media query.
- Toggling the theme applies a `dark` class to the root `<html>` element, which Tailwind CSS uses to activate `dark:` variant classes.
- All components consume the theme through the `useTheme()` hook, ensuring a consistent and reactive styling experience across the application.

### 4.2. Active Chat State

Active room and message state is managed through a dedicated React Context (`ChatContext`) to avoid prop drilling through deeply nested route segments.

```typescript
interface ChatState {
  activeRoom: Room | null;
  messages: Message[];
  loading: boolean;
  error: string | null;
}

interface ChatContextValue extends ChatState {
  selectRoom: (room: Room) => void;
  sendMessage: (text: string) => Promise<void>;
  loadMore: () => Promise<void>;
}
```

**Data flow:**

1. `selectRoom(room)` sets `activeRoom` and attaches a Firestore `onSnapshot` listener on `/messages` filtered by `roomId`, ordered by `createdAt ASC`.
2. The snapshot callback dispatches a reducer action to merge incoming document changes into the `messages` array.
3. `sendMessage(text)` writes a new document to `/messages` with the current anonymous UID, room ID, and a server timestamp placeholder.
4. `loadMore()` paginates backward using Firestore cursor queries (`startAfter` or `endBefore` depending on sort direction) to support infinite scroll for historical message retrieval.
5. When `activeRoom` changes, the previous listener is unsubscribed automatically via a `useEffect` cleanup function, preventing stale listeners and memory leaks.

### 4.3. Identity & Session State

Anonymous authentication state is tracked via the Firebase Auth `onAuthStateChanged` observer and stored in a lightweight `AuthContext`:

```typescript
interface AuthContextValue {
  user: User | null;        // Firebase anonymous user
  loading: boolean;
  displayName: string;      // Ephemeral name chosen on first join
  setDisplayName: (name: string) => void;
}
```

- On app mount, `signInAnonymously()` is called if no anonymous session exists.
- The anonymous UID persists across page reloads within the same browser session (Firebase SDK handles token refresh).
- `displayName` is stored in `sessionStorage` so it resets on tab close, reinforcing the ephemeral nature of the application.

---

## 5. Route Structure (Next.js App Router)

```
/app
  /layout.tsx          — Root layout: wraps ThemeProvider, AuthProvider, ChatProvider
  /page.tsx            — Landing page: category grid, room listing
  /room
    /[slug]/page.tsx   — Chat view: message list, input bar, room metadata
  /layout.tsx          — (Optional) Secondary layout for chat pages
```

- `/` renders the category and room browser. Selecting a room navigates to `/room/[slug]`.
- `/room/[slug]` reads the room slug, resolves it against the Firestore `rooms` collection, and renders the message interface.
- Navigation between rooms unsubscribes the previous Firestore listener and subscribes to the new room's message stream within the `ChatContext`.

---

## 6. Performance & Scaling Considerations

- **Listener hygiene:** ChatContext ensures at most one active Firestore `onSnapshot` listener at any time. Leaving a room immediately tears down the listener.
- **Pagination:** `loadMore()` uses Firestore cursor-based pagination with a page size of 50 messages. The message list is virtualized (via `react-window` or `@tanstack/react-virtual`) to keep DOM nodes proportional to the viewport.
- **Rate limiting:** Security rules and client-side debouncing (300 ms throttle on `sendMessage`) prevent accidental or malicious message floods.
- **Anonymous auth limits:** Firebase Anonymous Authentication is subject to a per-project quota. A cleanup Cloud Function periodically purges stale anonymous accounts and their associated orphaned messages (messages older than 24 hours in rooms with no recent activity).

---

## 7. Future Considerations

- **Ephemeral message expiry:** Optional automatic deletion of messages after a configurable TTL (e.g., 1 hour, 24 hours) via a Firestore `onWrite` Cloud Function.
- **Room moderation:** Simple moderation tools (report message, block anonymous UID) using a Firestore `reports` collection and a moderation dashboard.
- **PWA support:** Next.js built-in PWA configuration for offline-capable message viewing and install prompt.
