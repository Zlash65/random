#!/bin/bash

# MCP Development Environment Installer
# Automated installation script for Node.js, Python, and MCP prerequisites
# Works on macOS and Linux with comprehensive error handling

# Disable strict error mode for graceful handling
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for tracking
ERRORS=()
WARNINGS=()
INSTALLED_TOOLS=()
FAILED_TOOLS=()

# Logging function
log_error() {
    ERRORS+=("$1")
    echo -e "${RED}❌ Error: $1${NC}"
}

log_warning() {
    WARNINGS+=("$1")
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

log_success() {
    INSTALLED_TOOLS+=("$1")
    echo -e "${GREEN}✓ $1${NC}"
}

log_failure() {
    FAILED_TOOLS+=("$1")
    echo -e "${RED}❌ Failed: $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check internet connectivity
check_internet() {
    if ! curl -s --connect-timeout 5 https://google.com >/dev/null 2>&1; then
        if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}

# Detect OS with more precision
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Check macOS version
        local version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
        echo "macos-$version"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check Linux distribution
        if [ -f /etc/os-release ]; then
            local distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
            echo "linux-$distro"
        else
            echo "linux-unknown"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unsupported-$OSTYPE"
    fi
}

# Version comparison function with error handling
version_compare() {
    local ver1="$1"
    local ver2="$2"
    
    if [[ -z "$ver1" || -z "$ver2" ]]; then
        echo "0"
        return
    fi
    
    # Clean version strings
    ver1=$(echo "$ver1" | sed 's/[^0-9.]//g')
    ver2=$(echo "$ver2" | sed 's/[^0-9.]//g')
    
    # Compare using sort -V if available
    if command_exists sort && sort --version-sort </dev/null >/dev/null 2>&1; then
        if [ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)" = "$ver2" ]; then
            echo "1"  # ver1 >= ver2
        else
            echo "0"  # ver1 < ver2
        fi
    else
        # Fallback comparison
        echo "$ver1 $ver2" | awk '{
            split($1, a, ".")
            split($2, b, ".")
            for(i=1; i<=4; i++) {
                if(!a[i]) a[i]=0
                if(!b[i]) b[i]=0
                if(a[i] > b[i]) { print 1; exit }
                if(a[i] < b[i]) { print 0; exit }
            }
            print 1
        }'
    fi
}

# Safe reload shell environment
reload_shell() {
    echo -e "${BLUE}Reloading shell environment...${NC}"
    
    # Load shell configuration files safely
    if [ -n "$BASH_VERSION" ]; then
        [ -f ~/.bashrc ] && source ~/.bashrc 2>/dev/null || true
        [ -f ~/.bash_profile ] && source ~/.bash_profile 2>/dev/null || true
        [ -f ~/.profile ] && source ~/.profile 2>/dev/null || true
    elif [ -n "$ZSH_VERSION" ]; then
        [ -f ~/.zshrc ] && source ~/.zshrc 2>/dev/null || true
        [ -f ~/.zprofile ] && source ~/.zprofile 2>/dev/null || true
    fi
    
    # Load nvm if available
    if [ -d "$HOME/.nvm" ]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 2>/dev/null || true
    fi
    
    # Add common paths safely
    [ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"
    [ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
    [ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"
    [ -d "/usr/local/bin" ] && export PATH="/usr/local/bin:$PATH"
    
    echo -e "${GREEN}✓ Shell environment reloaded${NC}"
}

print_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                          ║${NC}"
    echo -e "${PURPLE}║           ${CYAN}MCP Development Environment Installer${PURPLE}          ║${NC}"
    echo -e "${PURPLE}║                                                          ║${NC}"
    echo -e "${PURPLE}║  ${YELLOW}This script will install:${PURPLE}                               ║${NC}"
    echo -e "${PURPLE}║  ${GREEN}• Package Managers (Homebrew/apt)${PURPLE}                       ║${NC}"
    echo -e "${PURPLE}║  ${GREEN}• Node.js & npm (via nvm)${PURPLE}                               ║${NC}"
    echo -e "${PURPLE}║  ${GREEN}• Python 3 & pip3${PURPLE}                                       ║${NC}"
    echo -e "${PURPLE}║  ${GREEN}• uv (Modern Python package manager)${PURPLE}                    ║${NC}"
    echo -e "${PURPLE}║                                                          ║${NC}"
    echo -e "${PURPLE}║  ${BLUE}With comprehensive error handling and recovery${PURPLE}          ║${NC}"
    echo -e "${PURPLE}║                                                          ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${BLUE}Checking system prerequisites...${NC}"
    
    # Check internet connectivity
    if ! check_internet; then
        log_error "No internet connection. Please check your network and try again."
        return 1
    fi
    log_success "Internet connectivity verified"
    
    # Detect OS
    OS_FULL=$(detect_os)
    OS=$(echo "$OS_FULL" | cut -d'-' -f1)
    
    case "$OS" in
        "macos")
            log_success "Operating System: macOS ($(echo "$OS_FULL" | cut -d'-' -f2))"
            ;;
        "linux")
            log_success "Operating System: Linux ($(echo "$OS_FULL" | cut -d'-' -f2))"
            ;;
        "windows")
            log_error "Windows is not supported. Please use WSL (Windows Subsystem for Linux)."
            return 1
            ;;
        *)
            log_error "Unsupported operating system: $OS_FULL"
            return 1
            ;;
    esac
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Some installations may not work correctly."
        echo -e "${YELLOW}It's recommended to run this script as a regular user.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installation cancelled.${NC}"
            return 1
        fi
    fi
    
    # Check available disk space (at least 2GB)
    if command_exists df; then
        local available_kb=$(df "$HOME" | tail -1 | awk '{print $4}')
        local available_gb=$((available_kb / 1024 / 1024))
        if [ "$available_gb" -lt 2 ]; then
            log_warning "Low disk space: ${available_gb}GB available. Installation may fail."
        else
            log_success "Disk space: ${available_gb}GB available"
        fi
    fi
    
    # Check for required system tools
    local required_tools=("curl" "bash")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_error "Required tool '$tool' is not installed"
            return 1
        fi
    done
    
    return 0
}

install_package_managers() {
    echo -e "\n${CYAN}═══ Step 1: Package Managers ═══${NC}"
    
    if [ "$OS" = "macos" ]; then
        # Install Homebrew
        if command_exists brew; then
            log_success "Homebrew already installed ($(brew --version | head -n1))"
        else
            echo -e "${YELLOW}Installing Homebrew...${NC}"
            if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                # Add Homebrew to PATH for current session
                if [[ -f "/opt/homebrew/bin/brew" ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [[ -f "/usr/local/bin/brew" ]]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                log_success "Homebrew installed successfully"
            else
                log_failure "Homebrew installation failed"
                log_warning "You can install packages manually or try installing Homebrew separately"
            fi
        fi
        
        # Install Xcode Command Line Tools
        if xcode-select -p >/dev/null 2>&1; then
            log_success "Xcode Command Line Tools already installed"
        else
            echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
            if xcode-select --install 2>/dev/null; then
                echo -e "${YELLOW}Please complete the Xcode installation in the popup window.${NC}"
                echo -e "${YELLOW}This may take several minutes...${NC}"
                read -p "Press Enter when installation is complete (or Ctrl+C to skip)..."
                
                if xcode-select -p >/dev/null 2>&1; then
                    log_success "Xcode Command Line Tools installed"
                else
                    log_warning "Xcode Command Line Tools installation may not be complete"
                fi
            else
                log_warning "Xcode Command Line Tools installation failed or already in progress"
            fi
        fi
        
    elif [ "$OS" = "linux" ]; then
        # Update package lists
        echo -e "${YELLOW}Updating package lists...${NC}"
        if sudo apt update 2>/dev/null; then
            log_success "Package lists updated"
        else
            log_warning "Failed to update package lists. Continuing anyway."
        fi
        
        # Install build essentials
        local missing_packages=()
        if ! command_exists curl; then
            missing_packages+=("curl")
        fi
        if ! dpkg -l | grep -q "build-essential" 2>/dev/null; then
            missing_packages+=("build-essential")
        fi
        
        if [ ${#missing_packages[@]} -gt 0 ]; then
            echo -e "${YELLOW}Installing essential packages: ${missing_packages[*]}${NC}"
            if sudo apt install -y "${missing_packages[@]}" 2>/dev/null; then
                log_success "Essential packages installed"
            else
                log_failure "Failed to install some essential packages"
                log_warning "Some features may not work correctly"
            fi
        else
            log_success "All essential packages already installed"
        fi
    fi
    
    reload_shell
    return 0
}

install_nodejs() {
    echo -e "\n${CYAN}═══ Step 2: Node.js & npm ═══${NC}"
    
    # Check if nvm is installed
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log_success "nvm already installed"
    else
        echo -e "${YELLOW}Installing nvm (Node Version Manager)...${NC}"
        
        # Try multiple nvm installation methods
        if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash 2>/dev/null; then
            log_success "nvm installed via curl"
        elif wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash 2>/dev/null; then
            log_success "nvm installed via wget"
        else
            log_failure "nvm installation failed"
            log_warning "You can install Node.js manually from nodejs.org"
            return 1
        fi
    fi
    
    # Reload shell to make nvm available
    reload_shell
    
    # Load nvm for this session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null
    
    # Check if nvm command is available
    if ! command -v nvm >/dev/null 2>&1; then
        log_warning "nvm requires a new terminal session to be fully loaded"
        log_warning "After this script completes, open a new terminal and run:"
        echo -e "${CYAN}  nvm install --lts${NC}"
        echo -e "${CYAN}  nvm use --lts${NC}"
        return 0
    fi
    
    # Install Node.js LTS
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null | sed 's/v//')
        local required_version="18.0.0"
        
        if [ -n "$node_version" ] && [ "$(version_compare "$node_version" "$required_version")" = "1" ]; then
            log_success "Node.js $node_version already installed (meets requirements)"
        else
            echo -e "${YELLOW}Updating Node.js to latest LTS...${NC}"
            if nvm install --lts 2>/dev/null && nvm use --lts 2>/dev/null; then
                local new_version=$(node --version 2>/dev/null | sed 's/v//')
                log_success "Node.js updated to $new_version"
            else
                log_failure "Failed to update Node.js"
            fi
        fi
    else
        echo -e "${YELLOW}Installing Node.js LTS...${NC}"
        if nvm install --lts 2>/dev/null && nvm use --lts 2>/dev/null; then
            if command_exists node; then
                local node_version=$(node --version 2>/dev/null | sed 's/v//')
                log_success "Node.js $node_version installed"
            else
                log_warning "Node.js installed but not available in current session"
            fi
        else
            log_failure "Node.js installation failed"
            log_warning "You can install Node.js manually from nodejs.org"
        fi
    fi
    
    reload_shell
    return 0
}

install_python() {
    echo -e "\n${CYAN}═══ Step 3: Python 3 & pip3 ═══${NC}"
    
    if [ "$OS" = "macos" ]; then
        if command_exists python3; then
            local python_version=$(python3 --version 2>/dev/null | cut -d' ' -f2)
            log_success "Python $python_version already installed"
        else
            echo -e "${YELLOW}Installing Python 3...${NC}"
            if command_exists brew; then
                if brew install python3 2>/dev/null; then
                    log_success "Python 3 installed via Homebrew"
                else
                    log_failure "Failed to install Python 3 via Homebrew"
                    log_warning "Please install Python 3 manually from python.org"
                fi
            else
                log_warning "Homebrew not available. Please install Python 3 manually from python.org"
            fi
        fi
        
    elif [ "$OS" = "linux" ]; then
        if command_exists python3; then
            local python_version=$(python3 --version 2>/dev/null | cut -d' ' -f2)
            log_success "Python $python_version already installed"
        else
            echo -e "${YELLOW}Installing Python 3...${NC}"
            if sudo apt install -y python3 python3-pip 2>/dev/null; then
                log_success "Python 3 installed via apt"
            else
                log_failure "Failed to install Python 3 via apt"
                log_warning "Please install Python 3 manually"
            fi
        fi
    fi
    
    # Verify pip3 is available
    if command_exists pip3; then
        local pip_version=$(pip3 --version 2>/dev/null | cut -d' ' -f2)
        log_success "pip3 $pip_version available"
    else
        log_warning "pip3 not available. Some Python package installations may fail"
    fi
    
    reload_shell
    return 0
}

install_uv() {
    echo -e "\n${CYAN}═══ Step 4: uv (Python Package Manager) ═══${NC}"
    
    if command_exists uv; then
        local uv_version=$(uv --version 2>/dev/null | cut -d' ' -f2)
        log_success "uv $uv_version already installed"
        return 0
    fi
    
    echo -e "${YELLOW}Installing uv...${NC}"
    
    # Try multiple installation methods
    if curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; then
        log_success "uv installed via official installer"
    elif command_exists pip3 && pip3 install uv 2>/dev/null; then
        log_success "uv installed via pip3"
    elif command_exists cargo && cargo install --git https://github.com/astral-sh/uv uv 2>/dev/null; then
        log_success "uv installed via cargo"
    else
        log_failure "All uv installation methods failed"
        log_warning "You can install uv manually from https://github.com/astral-sh/uv"
        return 1
    fi
    
    reload_shell
    return 0
}

verify_installations() {
    echo -e "\n${CYAN}═══ Verification ═══${NC}"
    echo -e "${BLUE}Verifying all installations...${NC}"
    
    # Final reload to ensure everything is available
    reload_shell
    
    echo ""
    local verification_results=()
    
    # Verify Node.js
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null)
        verification_results+=("Node.js: $node_version ✓")
        echo -e "${GREEN}✓ Node.js: $node_version${NC}"
    else
        verification_results+=("Node.js: Not available in current session")
        echo -e "${YELLOW}⚠️  Node.js: Not available in current session (may need new terminal)${NC}"
    fi
    
    # Verify npm
    if command_exists npm; then
        local npm_version=$(npm --version 2>/dev/null)
        verification_results+=("npm: $npm_version ✓")
        echo -e "${GREEN}✓ npm: $npm_version${NC}"
    else
        verification_results+=("npm: Not available in current session")
        echo -e "${YELLOW}⚠️  npm: Not available in current session (may need new terminal)${NC}"
    fi
    
    # Verify npx
    if command_exists npx; then
        local npx_version=$(npx --version 2>/dev/null)
        verification_results+=("npx: $npx_version ✓")
        echo -e "${GREEN}✓ npx: $npx_version${NC}"
    else
        verification_results+=("npx: Not available in current session")
        echo -e "${YELLOW}⚠️  npx: Not available in current session (may need new terminal)${NC}"
    fi
    
    # Verify Python
    if command_exists python3; then
        local python_version=$(python3 --version 2>/dev/null)
        verification_results+=("Python: $python_version ✓")
        echo -e "${GREEN}✓ Python: $python_version${NC}"
    else
        verification_results+=("Python 3: Not found ❌")
        echo -e "${RED}❌ Python 3 not found${NC}"
    fi
    
    # Verify pip3
    if command_exists pip3; then
        local pip_version=$(pip3 --version 2>/dev/null | cut -d' ' -f2)
        verification_results+=("pip3: $pip_version ✓")
        echo -e "${GREEN}✓ pip3: $pip_version${NC}"
    else
        verification_results+=("pip3: Not found ❌")
        echo -e "${RED}❌ pip3 not found${NC}"
    fi
    
    # Verify uv
    if command_exists uv; then
        local uv_version=$(uv --version 2>/dev/null)
        verification_results+=("uv: $uv_version ✓")
        echo -e "${GREEN}✓ uv: $uv_version${NC}"
    else
        verification_results+=("uv: Not available in current session")
        echo -e "${YELLOW}⚠️  uv: Not available in current session (may need new terminal)${NC}"
    fi
    
    return 0
}

show_completion_message() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                           ║${NC}"
    echo -e "${PURPLE}║                    ${GREEN}Installation Summary${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║                                                           ║${NC}"
    
    # Show successful installations
    if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
        echo -e "${PURPLE}║  ${GREEN}Successfully installed:${PURPLE}                                  ║${NC}"
        for tool in "${INSTALLED_TOOLS[@]}"; do
            printf "${PURPLE}║  ${GREEN}• %-54s${PURPLE} ║${NC}\n" "$tool"
        done
        echo -e "${PURPLE}║                                                           ║${NC}"
    fi
    
    # Show failed installations
    if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
        echo -e "${PURPLE}║  ${RED}Failed installations:${PURPLE}                                ║${NC}"
        for tool in "${FAILED_TOOLS[@]}"; do
            printf "${PURPLE}║  ${RED}• %-50s${PURPLE} ║${NC}\n" "$tool"
        done
        echo -e "${PURPLE}║                                                          ║${NC}"
    fi
    
    # Show warnings
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "${PURPLE}║  ${YELLOW}Warnings (${#WARNINGS[@]}):${PURPLE}                                        ║${NC}"
        echo -e "${PURPLE}║  ${YELLOW}Some tools may need a new terminal session${PURPLE}              ║${NC}"
        echo -e "${PURPLE}║                                                          ║${NC}"
    fi
    
    echo -e "${PURPLE}║  ${CYAN}Next Steps:${PURPLE}                                              ║${NC}"
    echo -e "${PURPLE}║  ${YELLOW}1. Open a NEW terminal${PURPLE}                                   ║${NC}"
    echo -e "${PURPLE}║  ${YELLOW}2. Verify installations:${PURPLE}                                 ║${NC}"
    echo -e "${PURPLE}║     ${CYAN}node --version && npm --version${PURPLE}                       ║${NC}"
    echo -e "${PURPLE}║     ${CYAN}python3 --version && pip3 --version${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║     ${CYAN}uv --version${PURPLE}                                          ║${NC}"
    echo -e "${PURPLE}║                                                           ║${NC}"
    
    if [ ${#FAILED_TOOLS[@]} -eq 0 ] && [ ${#ERRORS[@]} -eq 0 ]; then
        echo -e "${PURPLE}║  ${GREEN}🎉 MCP development environment ready!${PURPLE}                    ║${NC}"
    else
        echo -e "${PURPLE}║  ${YELLOW}⚠️  Some tools failed. Check manual installation${PURPLE}       ║${NC}"
    fi
    
    echo -e "${PURPLE}║                                                           ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    # Show detailed error log if there were errors
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Detailed Error Log:${NC}"
        for error in "${ERRORS[@]}"; do
            echo -e "${RED}  • $error${NC}"
        done
    fi
}

# Cleanup function for graceful exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Installation interrupted. Cleaning up...${NC}"
    show_completion_message
    exit 130
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    print_header
    
    echo -e "${YELLOW}This script will install the MCP development environment with error handling.${NC}"
    echo -e "${BLUE}If any installation fails, the script will continue with other components.${NC}"
    echo ""
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    
    # Run installations with error handling
    if ! check_prerequisites; then
        echo -e "${RED}Prerequisites check failed. Exiting.${NC}"
        exit 1
    fi
    
    install_package_managers || true
    install_nodejs || true
    install_python || true
    install_uv || true
    verify_installations || true
    show_completion_message
    
    # Exit with appropriate code
    if [ ${#ERRORS[@]} -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main
