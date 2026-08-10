.PHONY: help dev-server dev-app dev-all stop restart logs test clean build-app

# Colors for terminal output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help:
	@echo "$(BLUE)Steam - iOS Video Streaming App$(NC)"
	@echo ""
	@echo "$(GREEN)Streaming Server Commands:$(NC)"
	@echo "  make dev-server       Start MediaMTX streaming server"
	@echo "  make server-stop      Stop streaming server"
	@echo "  make server-restart   Restart streaming server"
	@echo "  make server-logs      View live server logs"
	@echo "  make server-test      Run server verification tests"
	@echo "  make server-status    Check server status"
	@echo ""
	@echo "$(GREEN)iOS App Commands:$(NC)"
	@echo "  make dev-app          Open iOS project in Xcode"
	@echo "  make build-app        Build iOS app for simulator"
	@echo "  make test-app         Run iOS unit tests"
	@echo ""
	@echo "$(GREEN)Combined Commands:$(NC)"
	@echo "  make dev-all          Start server + open iOS project"
	@echo "  make stop             Stop all services (server)"
	@echo "  make clean            Clean build artifacts"
	@echo ""
	@echo "$(YELLOW)Note:$(NC) Run 'make dev-all' for complete development environment"

# ============================================================================
# Streaming Server Commands
# ============================================================================

dev-server:
	@echo "$(BLUE)Starting MediaMTX streaming server...$(NC)"
	@./streaming.sh start
	@echo "$(GREEN)✓ Streaming server started!$(NC)"
	@echo "  RTMP:  rtmp://localhost:1935/live/mystream"
	@echo "  HLS:   http://localhost:8888/live/mystream/index.m3u8"
	@echo "  RTSP:  rtsp://localhost:8554/live/mystream"

server-stop:
	@echo "$(BLUE)Stopping streaming server...$(NC)"
	@./streaming.sh stop
	@echo "$(GREEN)✓ Server stopped$(NC)"

server-restart:
	@echo "$(BLUE)Restarting streaming server...$(NC)"
	@./streaming.sh restart
	@echo "$(GREEN)✓ Server restarted$(NC)"

server-logs:
	@echo "$(BLUE)Streaming server logs (Ctrl+C to exit)$(NC)"
	@./streaming.sh logs

server-test:
	@echo "$(BLUE)Running server verification tests...$(NC)"
	@./streaming.sh test

server-status:
	@echo "$(BLUE)Checking server status...$(NC)"
	@./streaming.sh status

# ============================================================================
# iOS App Commands
# ============================================================================

dev-app:
	@echo "$(BLUE)Opening iOS project in Xcode...$(NC)"
	open steam.xcodeproj

build-app:
	@echo "$(BLUE)Building iOS app for simulator...$(NC)"
	xcodebuild -scheme steam \
		-destination 'generic/platform=iOS Simulator' \
		build
	@echo "$(GREEN)✓ Build complete$(NC)"

test-app:
	@echo "$(BLUE)Running iOS unit tests...$(NC)"
	xcodebuild -scheme steam \
		-destination 'generic/platform=iOS Simulator' \
		test
	@echo "$(GREEN)✓ Tests complete$(NC)"

# ============================================================================
# Combined Commands
# ============================================================================

dev-all: dev-server dev-app
	@echo "$(GREEN)✓ Development environment ready!$(NC)"
	@echo "  - Streaming server running"
	@echo "  - Xcode opening with iOS project"

# ============================================================================
# Utility Commands
# ============================================================================

stop:
	@echo "$(BLUE)Stopping all services...$(NC)"
	@./streaming.sh stop
	@echo "$(GREEN)✓ All services stopped$(NC)"

clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf build/ DerivedData/ .build/
	@find . -name "*.xcuserstate" -delete
	@find . -name "*.xcuserdata" -type d -delete
	@echo "$(GREEN)✓ Clean complete$(NC)"

# ============================================================================
# Help & Info
# ============================================================================

info:
	@echo "$(BLUE)Project Information$(NC)"
	@echo ""
	@echo "Steam - iOS Video Streaming App"
	@echo ""
	@echo "Components:"
	@echo "  1. iOS App       - SwiftUI + MVVM architecture"
	@echo "  2. Streaming Server - Docker + MediaMTX v1.20"
	@echo ""
	@echo "Quick Links:"
	@echo "  Documentation:   ./README.md"
	@echo "  Architecture:    ./ARCHITECTURE.md"
	@echo "  Development:     ./CLAUDE.md"
	@echo "  Deployment:      ./DEPLOYMENT_GUIDE.md"
	@echo "  Features:        ./FEATURES_ROADMAP.md"
	@echo ""
	@echo "Get Started:"
	@echo "  $$ make dev-all          # Start server + open Xcode"
	@echo "  $$ make server-logs      # Watch server output"
	@echo ""

# ============================================================================
# Default Target
# ============================================================================

.DEFAULT_GOAL := help
