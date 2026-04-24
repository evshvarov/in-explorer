# Google Auth Frontend Contract

Base API URL: `/in-explorer/api`

This backend expects the frontend to use Google Identity Services (GIS) to obtain a Google ID token and then exchange it with the backend for an app session.

## Endpoints

### `POST /auth/google`

Request body:

```json
{
  "credential": "<google-id-token>",
  "csrfToken": "<g_csrf_token>"
}
```

Notes:
- `credential` is required
- `csrfToken` should be the GIS `g_csrf_token` value when present

Success response:

```json
{
  "authenticated": true,
  "sessionToken": "7f0d9d2e-...",
  "user": {
    "sub": "109876543210123456789",
    "email": "user@example.com",
    "name": "Jane Doe",
    "picture": "https://lh3.googleusercontent.com/...",
    "hd": "example.com"
  }
}
```

Failure:
- `400` invalid request or CSRF mismatch
- `401` invalid Google credential or email not allowed
- `500` server/configuration problem

Error detail is returned in the `X-Error` response header.

### `GET /auth/me`

Logged-in response:

```json
{
  "authenticated": true,
  "user": {
    "sub": "109876543210123456789",
    "email": "user@example.com",
    "name": "Jane Doe",
    "picture": "https://lh3.googleusercontent.com/...",
    "hd": "example.com",
    "expiresAt": 2123456789
  }
}
```

Logged-out response:

```json
{
  "authenticated": false,
  "user": null
}
```

### `POST /auth/logout`

Response:

```json
{
  "authenticated": false,
  "user": null
}
```

## Protected endpoints

These require authentication:

- `GET /connections`
- `POST /connections`
- `POST /connections/import-csv`
- `GET /connections/facets`
- `GET /connections/{id}`
- `PATCH /connections/{id}`
- `DELETE /connections/{id}`

If not authenticated:

- status `401`
- header `X-Error: Authentication required`

## Recommended frontend mode

Use the backend session cookie.

After `POST /auth/google`, the backend sets an `HttpOnly` cookie. Frontend should then call the API with:

```ts
credentials: "include"
```

This is the preferred mode because frontend does not need to store or manage tokens.

## Alternative mode

The backend also returns `sessionToken`. Frontend may send it as:

```http
Authorization: Bearer <sessionToken>
```

Use this only if the frontend cannot rely on cookies.

## Minimal GIS flow

1. Load Google Identity Services.
2. Render a Google sign-in button or use One Tap.
3. Receive `credential` from Google.
4. `POST /auth/google`.
5. On app startup, call `GET /auth/me`.
6. Call protected API routes with `credentials: "include"`.

## React example

This is a minimal example using cookie mode.

```tsx
import { useEffect, useRef, useState } from "react";

declare global {
  interface Window {
    google?: any;
  }
}

type AuthState = {
  authenticated: boolean;
  sessionToken?: string | null;
  user?: {
    sub: string;
    email?: string | null;
    name?: string | null;
    picture?: string | null;
    hd?: string | null;
    expiresAt?: number;
  } | null;
};

const API_BASE = "/in-explorer/api";
const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
    ...init,
  });

  if (!response.ok) {
    throw new Error(response.headers.get("X-Error") || `Request failed: ${response.status}`);
  }

  return response.json() as Promise<T>;
}

function readCookie(name: string): string {
  const cookies = document.cookie.split(";");
  for (const item of cookies) {
    const trimmed = item.trim();
    if (trimmed.startsWith(`${name}=`)) {
      return trimmed.slice(name.length + 1);
    }
  }
  return "";
}

export function GoogleLoginPanel() {
  const buttonRef = useRef<HTMLDivElement | null>(null);
  const [auth, setAuth] = useState<AuthState>({ authenticated: false });
  const [error, setError] = useState<string>("");

  useEffect(() => {
    void api<AuthState>("/auth/me")
      .then(setAuth)
      .catch((err) => setError(err instanceof Error ? err.message : "Unable to load auth state"));
  }, []);

  useEffect(() => {
    if (!window.google || !buttonRef.current || !GOOGLE_CLIENT_ID) return;

    window.google.accounts.id.initialize({
      client_id: GOOGLE_CLIENT_ID,
      callback: async (googleResponse: { credential: string }) => {
        try {
          setError("");
          const result = await api<AuthState>("/auth/google", {
            method: "POST",
            body: JSON.stringify({
              credential: googleResponse.credential,
              csrfToken: readCookie("g_csrf_token"),
            }),
          });
          setAuth(result);
        } catch (err) {
          setError(err instanceof Error ? err.message : "Sign-in failed");
        }
      },
    });

    window.google.accounts.id.renderButton(buttonRef.current, {
      theme: "outline",
      size: "large",
      shape: "pill",
    });
  }, []);

  async function handleLogout() {
    try {
      const result = await api<AuthState>("/auth/logout", { method: "POST" });
      setAuth(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Logout failed");
    }
  }

  if (auth.authenticated) {
    return (
      <div>
        <div>{auth.user?.email}</div>
        <button onClick={handleLogout}>Log out</button>
      </div>
    );
  }

  return (
    <div>
      <div ref={buttonRef} />
      {error ? <div>{error}</div> : null}
    </div>
  );
}
```

## Frontend environment

Frontend should expose:

```env
VITE_GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
```

Backend must be configured separately with:

```env
GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
GOOGLE_ALLOWED_EMAILS=alice@example.com,bob@example.com
```

Only emails from `GOOGLE_ALLOWED_EMAILS` can establish a backend session and access the protected `/in-explorer/api` endpoints.
