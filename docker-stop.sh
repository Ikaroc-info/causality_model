#!/bin/bash

# Stop and remove the Docker container
echo "🛑 Stopping Docker containers..."
docker-compose down

echo "✅ Docker containers stopped and removed"
