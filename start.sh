#!/bin/bash

# Ghostphish Quick Start Script

echo "╔════════════════════════════════════════╗"
echo "║     Ghostphish OTP Phishing Tool       ║"
echo "║            Red Team Edition            ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[!] Docker not found. Installing Docker dependencies..."
    echo "[*] Make sure Docker and Docker Compose are installed"
    echo "[*] Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "[!] Docker daemon not running"
    echo "[*] Start Docker and try again"
    exit 1
fi

echo "[+] Docker found"
echo ""

# Build and start
echo "[*] Building Docker image..."
docker-compose build

if [ $? -ne 0 ]; then
    echo "[!] Build failed"
    exit 1
fi

echo ""
echo "[*] Starting Ghostphish..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "[!] Failed to start container"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     ✓ Ghostphish is Running!           ║"
echo "╠════════════════════════════════════════╣"
echo "║                                        ║"
echo "║  🔗 Phishing Page:                    ║"
echo "║     http://localhost:8000             ║"
echo "║                                        ║"
echo "║  📊 Captured Data:                     ║"
echo "║     curl http://localhost:8000/admin/captures"
echo "║                                        ║"
echo "║  📁 Database:                          ║"
echo "║     ./data/captures.db                ║"
echo "║                                        ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "To stop: docker-compose down"
echo "To view logs: docker logs ghostphish"
echo "To export data: python export_captures.py [json|csv|stats]"
echo ""
