# 🐳 Docker Setup Guide

## Quick Start

### Option 1: Using docker-compose (Recommended)

```bash
# Make scripts executable
chmod +x docker-run.sh docker-stop.sh

# Start the server
./docker-run.sh

# Server runs at http://localhost:8000
```

### Option 2: Using docker-compose directly

```bash
# Build the image
docker-compose build

# Start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

### Option 3: Using Docker CLI directly

```bash
# Build the image
docker build -t causality-model .

# Run the container
docker run -p 8000:8000 causality-model

# Run in detached mode
docker run -d -p 8000:8000 --name causality-app causality-model

# View logs
docker logs -f causality-app

# Stop the container
docker stop causality-app
docker rm causality-app
```

## Features

✅ **Python 3.11** - Stable and compatible with all dependencies
✅ **All dependencies pre-installed** - No environment issues
✅ **Volume mounts** - Data and test files accessible
✅ **Port mapping** - Access at `http://localhost:8000`
✅ **Auto-restart** - Container restarts unless manually stopped

## File Structure

- `Dockerfile` - Container definition
- `docker-compose.yml` - Multi-container orchestration
- `.dockerignore` - Excludes unnecessary files from build
- `docker-run.sh` - Convenience script to start
- `docker-stop.sh` - Convenience script to stop

## Advantages over Local Python

- ✅ No Python version conflicts
- ✅ No virtual environment setup needed
- ✅ Works consistently across all machines
- ✅ Easy to share and deploy
- ✅ Isolated dependencies
