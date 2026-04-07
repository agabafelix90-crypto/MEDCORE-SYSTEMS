Local Deployment using Docker Compose
=====================================

Overview
--------
This project provides a single-command local deployment using Docker Compose.
It runs:
- Redis (persistent named volume)
- Backend (Node.js/Express) bound to port 3000
- Frontend (Vite React) bound to port 5173
- Optional: nginx reverse proxy on port 80 (proxying frontend and backend)

Files created
- `docker-compose.yml` - Compose configuration for redis/backend/frontend/nginx
- `Dockerfile.backend` - Backend image (runs `dist/server.js`)
- `Dockerfile.frontend` - Frontend image (runs `npm run dev` for Vite)
- `deploy/nginx/nginx.conf` - Optional nginx proxy config

Prerequisites
- Docker Engine and Docker Compose (v2) installed
- Copy `.env.example` → `.env` and fill secret values (Supabase keys, SESSION_SECRET, etc.)

Minimum `.env` values you should set (local dev):
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (backend requires these)
- `SESSION_SECRET` (for express-session)
- `REDIS_URL` can be left to default (compose sets it to `redis://redis:6379`)

Quick start
-----------
1. Copy the example env and provide values:

```powershell
cd C:\Users\user\Desktop\MEDCORE
copy .env.example .env
# then edit .env in your editor and fill values
```

2. Start the full stack (build images first):

```powershell
docker compose up --build
# Builds images and runs services in foreground (uses production targets by default)
docker compose up --build
```

3. Start in background (detached):

```powershell
docker compose up -d --build
```

4. Stop and remove containers (keep volumes):

```powershell
docker compose down
```

5. Stop and remove containers + volumes:

```powershell
docker compose down -v
```

Logs
----
- Follow backend logs:

```powershell
docker compose logs -f backend
```

- Follow frontend logs:

```powershell
docker compose logs -f frontend
```

Rebuild a single service
------------------------
If you change Dockerfile for a service or native dependencies, rebuild that service:

```powershell
docker compose build --no-cache backend
docker compose up -d backend
```

Access URLs
-----------
- Frontend (Vite dev): http://localhost:5173
- Backend API: http://localhost:3000
- Redis (external client): redis://localhost:6379
- Optional nginx reverse proxy (if you enable/use it): http://localhost (port 80)

If you want a production-like single entrypoint (nginx proxy on :80) enable the `with-nginx` profile:

```powershell
# Start with nginx proxy enabled
docker compose --profile with-nginx up --build
```

Notes & tips
------------
- Hot-reload: Vite dev server runs inside the `frontend` container and will provide HMR by default.
- Backend hot-reload: The backend Dockerfile runs the compiled `dist/server.js`. If you change TypeScript sources,
  rebuild the compiled JS locally (`tsc`) or rebuild the container image. If you want a watch-mode backend,
  consider adding `ts-node-dev`/`nodemon` to `devDependencies` and updating the `backend` service command.
- The backend expects `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to be present (server will exit if missing).
  For simple local testing you can provide placeholder values, but many features (database lookups) will not work
  without a valid Supabase project.

Troubleshooting
---------------
- If Redis is not reachable the backend falls back to an in-memory store (suitable for local dev, not production).
- If the backend immediately exits on startup, check `docker compose logs backend` for missing env variables.

Backend hot-reload (development)
--------------------------------
The Compose override file (`docker-compose.override.yml`) is applied automatically by Docker Compose.
It builds the backend using the `development` build target and runs the `dev:backend` npm script
(which uses `ts-node-dev`), enabling hot-reload when editing TypeScript files.

If you need to explicitly run the development override (not needed normally):

```powershell
docker compose -f docker-compose.yml -f docker-compose.override.yml up --build
```

Enabling nginx for production-like testing
-----------------------------------------
By default nginx is part of the Compose file but placed under the `with-nginx` profile. Start with the
profile to run nginx in front of the Vite server and backend (useful to exercise routing and CORS behaviour):

```powershell
docker compose --profile with-nginx up --build
```

Remove containers and volumes (full cleanup)
-------------------------------------------
```powershell
docker compose down -v
```

Next steps (optional)
---------------------
- Add a `docker-compose.override.yml` for developer convenience (switching the backend to run with `ts-node-dev`).
- Add `docker-compose.ci.yml`/`docker-compose.prod.yml` to model production deployments and nginx static builds.
- Commit the compose files and add CI steps to lint/build images before merging.

Test the setup
--------------
- Ensure you copied `.env.example` to `.env` and filled required values.
- Development (hot-reload – override applied automatically):

```powershell
# From project root
docker compose up --build
# Frontend (Vite): http://localhost:5173
# Backend API: http://localhost:3000
```

- If you prefer an explicit override command (equivalent):

```powershell
docker compose -f docker-compose.yml -f docker-compose.override.yml up --build
```

- Production-like (enable nginx proxy to test routing through a single entrypoint):

```powershell
docker compose --profile with-nginx up --build
# App available at http://localhost
```

Health & quick checks
---------------------

```powershell
# Backend health endpoint (should return 200 OK)
curl http://localhost:3000/health

# Follow logs for troubleshooting
docker compose logs -f backend
docker compose logs -f frontend
```

Common issues
-------------
- Missing env vars: backend will log and may exit if `SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY` are not provided. For local development you can use placeholder values but expect some features to be limited.
- Port conflicts: adjust host ports in `docker-compose.override.yml` if 5173/3000/80 are in use.
- HMR not working: ensure `VITE_HOST=0.0.0.0` and `CHOKIDAR_USEPOLLING=true` are set in the override environment.

