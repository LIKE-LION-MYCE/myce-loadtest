#!/bin/bash
# MYCE K6 Scripts Synchronization Tool
# Syncs k6 test scripts between local and server

set -e

# Configuration
LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
SERVER_HOST="43.200.221.200"
SERVER_USER="ubuntu"
SERVER_SCRIPTS_DIR="/opt/k6/scripts"
SSH_KEY="$HOME/.ssh/aws/likelion-terraform-key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check SSH key
    if [ ! -f "$SSH_KEY" ]; then
        print_error "SSH key not found: $SSH_KEY"
        exit 1
    fi
    
    # Check local scripts directory
    if [ ! -d "$LOCAL_SCRIPTS_DIR" ]; then
        print_error "Local scripts directory not found: $LOCAL_SCRIPTS_DIR"
        exit 1
    fi
    
    # Test server connection
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" "echo 'Connection test'" > /dev/null 2>&1; then
        print_error "Cannot connect to server: $SERVER_USER@$SERVER_HOST"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Show differences
show_diff() {
    print_info "Checking differences between local and server..."
    
    # Create temp directory for server files
    TEMP_DIR=$(mktemp -d)
    
    # Download server scripts
    rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "$SERVER_USER@$SERVER_HOST:$SERVER_SCRIPTS_DIR/" \
        "$TEMP_DIR/" > /dev/null 2>&1 || true
    
    # Compare directories
    if [ "$(ls -A "$TEMP_DIR")" ]; then
        echo
        print_info "Files comparison:"
        diff -r "$LOCAL_SCRIPTS_DIR" "$TEMP_DIR" || true
        echo
    else
        print_warning "Server scripts directory appears to be empty or inaccessible"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

# Sync from local to server
sync_to_server() {
    print_info "Syncing local scripts to server..."
    
    # Upload scripts to temp location first
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "$LOCAL_SCRIPTS_DIR/" \
        "$SERVER_USER@$SERVER_HOST:/tmp/k6-scripts-sync/"
    
    # Use sudo to move to final location
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" \
        "sudo cp -r /tmp/k6-scripts-sync/* $SERVER_SCRIPTS_DIR/ && sudo chown -R ubuntu:ubuntu $SERVER_SCRIPTS_DIR && rm -rf /tmp/k6-scripts-sync"
    
    print_status "Local → Server sync completed"
}

# Sync from server to local
sync_from_server() {
    print_info "Syncing server scripts to local..."
    
    # Backup local scripts first
    if [ "$(ls -A "$LOCAL_SCRIPTS_DIR" 2>/dev/null)" ]; then
        cp -r "$LOCAL_SCRIPTS_DIR" "$LOCAL_SCRIPTS_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Sync from server
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "$SERVER_USER@$SERVER_HOST:$SERVER_SCRIPTS_DIR/" \
        "$LOCAL_SCRIPTS_DIR/"
    
    print_status "Server → Local sync completed"
}

# List script files
list_scripts() {
    print_info "Local scripts:"
    ls -la "$LOCAL_SCRIPTS_DIR"/*.js 2>/dev/null || echo "  No .js files found"
    
    echo
    print_info "Server scripts:"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" \
        "ls -la $SERVER_SCRIPTS_DIR/*.js 2>/dev/null || echo '  No .js files found'"
}

# Test a script
test_script() {
    local script_name="$1"
    if [ -z "$script_name" ]; then
        print_error "Please specify a script name to test"
        exit 1
    fi
    
    print_info "Testing script: $script_name"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" \
        "timeout 30s k6 run $SERVER_SCRIPTS_DIR/$script_name --duration 5s --vus 1 || echo 'Test completed (may have hit timeout)'"
}

# Show usage
usage() {
    echo "MYCE K6 Scripts Synchronization Tool"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  push     - Sync local scripts TO server (local → server)"
    echo "  pull     - Sync server scripts TO local (server → local)" 
    echo "  diff     - Show differences between local and server"
    echo "  list     - List scripts on both local and server"
    echo "  test     - Test a script on server (usage: $0 test script.js)"
    echo "  help     - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 push                    # Upload local changes to server"
    echo "  $0 pull                    # Download server changes to local"
    echo "  $0 diff                    # See what's different"
    echo "  $0 test ramp-eks-demo.js   # Test specific script"
    echo
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "🔄 MYCE K6 Scripts Sync Tool"
    echo "=============================="
    echo -e "${NC}"
    
    case "${1:-help}" in
        "push")
            check_prerequisites
            sync_to_server
            ;;
        "pull") 
            check_prerequisites
            sync_from_server
            ;;
        "diff")
            check_prerequisites
            show_diff
            ;;
        "list")
            check_prerequisites
            list_scripts
            ;;
        "test")
            check_prerequisites
            test_script "$2"
            ;;
        "help"|"")
            usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"