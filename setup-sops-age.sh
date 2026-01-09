#!/bin/bash

#
# SOPS + age environment setup script
#
# This script automates the setup of SOPS with age encryption
# for secure environment variable management.
#
# Usage:
#   ./setup-sops-age.sh [--new-installation|--restore-from-backup]
#

set -e  # Exit on error

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No colour

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${GREEN}==>${NC} $1"
}

# Check if running on macOS or Linux
OS="$(uname -s)"
print_info "Detected OS: $OS"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install packages
install_packages() {
    print_step "Installing required packages: age, sops, keepassxc-cli"

    if [[ "$OS" == "Darwin" ]]; then
        # macOS with Homebrew
        if ! command_exists brew; then
            print_error "Homebrew not found. Please install Homebrew first: https://brew.sh"
            exit 1
        fi

        print_info "Installing via Homebrew..."
        brew install age sops keepassxc

    elif [[ "$OS" == "Linux" ]]; then
        # Linux - detect package manager
        if command_exists apt; then
            print_info "Installing via apt..."
            sudo apt update
            sudo apt install -y age sops keepassxc
        elif command_exists dnf; then
            print_info "Installing via dnf..."
            sudo dnf install -y age sops keepassxc
        elif command_exists yum; then
            print_info "Installing via yum..."
            sudo yum install -y age sops keepassxc
        else
            print_error "No supported package manager found (apt/dnf/yum)"
            exit 1
        fi
    else
        print_error "Unsupported operating system: $OS"
        exit 1
    fi

    print_info "Packages installed successfully"
}

# Function to verify installations
verify_installations() {
    print_step "Verifying installations"

    local all_installed=true

    for cmd in age sops keepassxc-cli; do
        if command_exists "$cmd"; then
            print_info "✓ $cmd is installed"
        else
            print_error "✗ $cmd is NOT installed"
            all_installed=false
        fi
    done

    if [[ "$all_installed" == false ]]; then
        print_error "Some packages are missing. Please install them manually."
        exit 1
    fi
}

# Function to generate new age key
generate_age_key() {
    print_step "Generating new age encryption key"

    # Create age directory
    mkdir -p ~/.age

    # Generate key
    age-keygen -o ~/.age/key.txt
    chmod 600 ~/.age/key.txt

    print_info "Age key generated at: ~/.age/key.txt"
    echo
    cat ~/.age/key.txt
    echo

    # Extract public key
    PUBLIC_KEY=$(grep "public key:" ~/.age/key.txt | cut -d' ' -f3)
    print_warning "Save this public key: $PUBLIC_KEY"
}

# Function to restore age key from KeePassXC
restore_age_key() {
    print_step "Restoring age key from KeePassXC"

    # Check if KeePassXC database exists
    if [[ ! -f ~/.secrets/keepass/secrets.kdbx ]]; then
        print_error "KeePassXC database not found at: ~/.secrets/keepass/secrets.kdbx"
        print_info "Please ensure your KeePassXC database is in the correct location"
        exit 1
    fi

    # Create age directory
    mkdir -p ~/.age

    # Export age key from KeePassXC
    print_info "Please enter your KeePassXC master password:"
    keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
        "SOPS-age-encryption-key" \
        "age-key.txt" \
        ~/.age/key.txt

    chmod 600 ~/.age/key.txt

    print_info "Age key restored from KeePassXC"
}

# Function to configure SOPS
configure_sops() {
    print_step "Configuring SOPS"

    # Create secrets directory
    mkdir -p ~/.secrets

    # Extract public key from age key
    PUBLIC_KEY=$(grep "public key:" ~/.age/key.txt | cut -d' ' -f3)

    # Create SOPS configuration
    cat > ~/.secrets/.sops.yaml << EOF
creation_rules:
  - age: $PUBLIC_KEY
EOF

    print_info "SOPS configuration created at: ~/.secrets/.sops.yaml"
}

# Function to create encrypted secrets file
create_secrets_file() {
    print_step "Creating encrypted secrets file"

    if [[ -f ~/.secrets/web3-ethereum-defi.env ]]; then
        print_warning "Encrypted secrets file already exists at: ~/.secrets/web3-ethereum-defi.env"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping secrets file creation"
            return
        fi
    fi

    # Create plaintext template
    cat > ~/.secrets/web3-ethereum-defi-plain.env << 'EOF'
# Web3 Ethereum DeFi Secrets
# Replace these with your actual values

# RPC URLs (space-separated fallback format)
JSON_RPC_ETHEREUM=https://your-ethereum-rpc-url-here
JSON_RPC_ARBITRUM=https://your-arbitrum-rpc-url-here
JSON_RPC_POLYGON=https://your-polygon-rpc-url-here

# Private keys (if needed for testing)
PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000

# API keys (add as needed)
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
ARBISCAN_API_KEY=YOUR_ARBISCAN_API_KEY
EOF

    # Encrypt the file
    export SOPS_AGE_KEY_FILE=~/.age/key.txt
    cd ~/.secrets
    sops --encrypt --input-type dotenv --output-type dotenv web3-ethereum-defi-plain.env > web3-ethereum-defi.env

    # Delete plaintext file
    rm web3-ethereum-defi-plain.env

    print_info "Encrypted secrets file created at: ~/.secrets/web3-ethereum-defi.env"
    print_warning "Remember to edit this file and add your actual secrets:"
    print_warning "  export SOPS_AGE_KEY_FILE=~/.age/key.txt"
    print_warning "  sops ~/.secrets/web3-ethereum-defi.env"
}

# Function to backup age key to KeePassXC
backup_to_keepassxc() {
    print_step "Backing up age key to KeePassXC"

    # Create KeePassXC directory
    mkdir -p ~/.secrets/keepass

    # Check if database exists
    if [[ ! -f ~/.secrets/keepass/secrets.kdbx ]]; then
        print_info "Creating new KeePassXC database..."
        print_info "Please enter a master password for your KeePassXC database:"
        keepassxc-cli db-create ~/.secrets/keepass/secrets.kdbx
    fi

    # Backup age key as attachment
    print_info "Please enter your KeePassXC master password to backup the age key:"
    keepassxc-cli attachment-import ~/.secrets/keepass/secrets.kdbx \
        "SOPS-age-encryption-key" \
        "age-key.txt" \
        ~/.age/key.txt

    print_info "Age key backed up to KeePassXC"
}

# Function to create project configuration template
create_project_template() {
    print_step "Creating project configuration template"

    cat > ~/sops-project-template.env << 'EOF'
# Set SOPS age key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

# Decrypt and export all environment variables from encrypted file
eval "$(SOPS_AGE_KEY_FILE=~/.age/key.txt sops --decrypt --input-type dotenv --output-type dotenv ~/.secrets/web3-ethereum-defi.env | sed 's/^/export /')"
EOF

    print_info "Project configuration template created at: ~/sops-project-template.env"
    print_info "Copy this to your project's .local-test.env:"
    print_info "  cp ~/sops-project-template.env /path/to/project/.local-test.env"
}

# Function to test the setup
test_setup() {
    print_step "Testing the setup"

    export SOPS_AGE_KEY_FILE=~/.age/key.txt

    print_info "Attempting to decrypt secrets file..."
    if sops --decrypt --input-type dotenv --output-type dotenv ~/.secrets/web3-ethereum-defi.env > /dev/null 2>&1; then
        print_info "✓ Decryption successful!"
    else
        print_error "✗ Decryption failed!"
        exit 1
    fi

    print_info "Setup test completed successfully"
}

# Main function
main() {
    echo
    echo "=========================================="
    echo "  SOPS + age Environment Setup Script"
    echo "=========================================="
    echo

    # Parse arguments
    MODE="new"
    if [[ "$1" == "--restore-from-backup" ]]; then
        MODE="restore"
    elif [[ "$1" == "--new-installation" ]]; then
        MODE="new"
    fi

    # Check if tools are already installed
    if command_exists age && command_exists sops && command_exists keepassxc-cli; then
        print_info "All required packages are already installed"
    else
        install_packages
    fi

    verify_installations

    if [[ "$MODE" == "new" ]]; then
        print_info "Running new installation setup"
        generate_age_key
        configure_sops
        create_secrets_file
        backup_to_keepassxc
    else
        print_info "Running restoration from backup"
        restore_age_key
        configure_sops
        print_info "Encrypted secrets file should already exist or be restored from backup"
    fi

    create_project_template
    test_setup

    print_step "Setup complete!"
    echo
    print_info "Next steps:"
    echo "  1. Edit your encrypted secrets file:"
    echo "     export SOPS_AGE_KEY_FILE=~/.age/key.txt"
    echo "     sops ~/.secrets/web3-ethereum-defi.env"
    echo
    echo "  2. Copy the project template to your project:"
    echo "     cp ~/sops-project-template.env /path/to/project/.local-test.env"
    echo
    echo "  3. Use in your project:"
    echo "     source .local-test.env && poetry run python script.py"
    echo
    print_warning "IMPORTANT: Keep your age key safe! It's backed up in KeePassXC."
    echo
}

# Run main function
main "$@"
