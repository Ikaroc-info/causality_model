#!/bin/bash

# Build and run the Docker container
set -e

echo "🐳 Building Docker image..."
docker-compose build

echo "🚀 Starting causality model server..."
docker-compose up

echo "✅ Server running at http://localhost:8000"
