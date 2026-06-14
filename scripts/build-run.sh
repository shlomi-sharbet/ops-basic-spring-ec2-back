#!/bin/bash
# Automate compilation, dockerization, and multi-container run

# Since we are using a Docker Multi-Stage build, the compilation and packaging
# are handled entirely inside the Docker engine, eliminating host-side Maven dependencies.

echo "🐳 Step 1: Building Docker image (compilation happens inside container)..."
docker build . -t shlomisharbat/backend:latest

echo "🚀 Step 2: Starting services with Docker Compose..."
docker-compose up -d

echo "📊 Step 3: Displaying running containers..."
docker ps
