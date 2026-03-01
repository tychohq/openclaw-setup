# Docker Desktop (macOS)

**Never read Docker Desktop config files directly.** The `~/Library/Group Containers/group.com.docker/` path hangs on reads while Docker is running (FUSE/special filesystem). Commands like `cat settings-store.json` get SIGKILL'd after timeout.

- **Use instead:** `docker info` (CPU/memory), `docker inspect` (container details), `docker stats` (live usage)
- **Find compose file path:** `docker inspect <name> --format '{{.Config.Labels}}'` → `com.docker.compose.project.config_files`
- **OpenObserve is distroless:** No shell, no `cat`, no `docker exec`. Inspect from host side only.
- **Compose resource limits** (`deploy.resources.limits`) cap the container, but the Docker Desktop VM RAM must be resized via GUI (Settings → Resources).

## Current Setup (Feb 17, 2026)

- Docker Desktop VM: resize to 2 GB RAM / 4 CPUs (was 8 GB / 10 CPUs)
- OpenObserve compose: `~/.openclaw/workspace/research/otel-observability-stack/openobserve/docker-compose.yml`
- Container limits: `memory: 2g`, `cpus: "4"` via `deploy.resources.limits`
- OpenObserve typical usage: ~300 MB RAM, <1% CPU
