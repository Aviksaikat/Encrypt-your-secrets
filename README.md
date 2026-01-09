# Secure environment variable management with SOPS + age

This document describes the setup and usage of SOPS (Secrets OPerationS) with age encryption for managing sensitive environment variables securely.

## Overview

This setup allows you to:
- Store API keys, private keys, and other secrets encrypted at rest
- Decrypt secrets only when needed (in memory)
- Avoid storing plaintext credentials on disk
- Backup encryption keys securely in KeePassXC
- Version control encrypted files safely (optional)

## Setup Methods

This guide offers two approaches:

### Standard Method (Easier)
- Age key stored at `~/.age/key.txt`
- Quick setup, simpler workflow
- Good for: personal projects, single-user systems
- Security: Key is backed up in KeePassXC but also on disk

### Enhanced Security Method (Recommended for sensitive data)
- Age key stored **only** in encrypted KeePassXC database
- Key never touches disk in plaintext
- Requires KeePassXC password to decrypt secrets
- Good for: shared systems, sensitive projects, compliance requirements
- Security: Maximum protection - key exists only encrypted at rest

**Choose the standard method** if you want simplicity and are the only user.
**Choose the enhanced method** if your system might be compromised or you need defense-in-depth.

## Architecture

### Standard Setup (Age key on disk)

```
┌─────────────────────────────────────────────────────────────┐
│ ~/.age/key.txt                                              │
│ (age encryption key - backed up in KeePassXC)               │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ encrypts/decrypts ─┐
                  │                      │
                  ▼                      ▼
┌─────────────────────────────┐  ┌──────────────────────────┐
│ ~/.secrets/                 │  │ Project: .local-test.env │
│ web3-ethereum-defi.env      │  │ (sources encrypted file) │
│ (encrypted secrets file)    │  │                          │
└─────────────────────────────┘  └──────────────────────────┘
                                           │
                                           ▼
                                  ┌──────────────────────┐
                                  │ Runtime: decrypted   │
                                  │ env vars in memory   │
                                  └──────────────────────┘
```

### Enhanced Security Setup (Age key in KeePassXC only)

```
┌──────────────────────────────────────────────────────────┐
│ KeePassXC Database                                       │
│ ~/.secrets/keepass/secrets.kdbx                          │
│ Contains: age encryption key (encrypted at rest)         │
└─────────────┬────────────────────────────────────────────┘
              │
              │ load-secrets script fetches key
              │ (prompts for password)
              ▼
┌──────────────────────────┐         ┌──────────────────────┐
│ Temporary key in memory  │────────>│ ~/.secrets/          │
│ (auto-deleted after use) │ decrypt │ web3-ethereum-defi   │
└──────────────────────────┘         │ .env (encrypted)     │
                                     └──────────────────────┘
                                              │
                                              ▼
                                     ┌──────────────────────┐
                                     │ Runtime: decrypted   │
                                     │ env vars in memory   │
                                     └──────────────────────┘
```

## Tools required

- **[age](https://github.com/FiloSottile/age)**: A simple, modern, and secure file encryption tool, format, and Go library. age uses ChaCha20-Poly1305 for encryption and provides a simple command-line interface for encrypting and decrypting files with small explicit keys.

- **[sops](https://github.com/mozilla/sops)**: Secrets OPerationS (SOPS) is an editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY formats and encrypts with AWS KMS, GCP KMS, Azure Key Vault, age, and PGP. SOPS allows you to encrypt only the values in your files while keeping the keys in plaintext, making it ideal for version control.

- **[keepassxc-cli](https://github.com/keepassxreboot/keepassxc)**: Command-line interface for KeePassXC, a cross-platform password manager. Used here to securely backup and restore the age encryption key as an attachment in an encrypted KeePassXC database.

## Installation

```bash
# macOS (Homebrew)
brew install age sops keepassxc-cli

# Linux (Debian/Ubuntu)
sudo apt install age sops keepassxc

# Linux (Fedora)
sudo dnf install age sops keepassxc
```

## Initial setup process

### 1. Generate age encryption key

```bash
# Create age directory
mkdir -p ~/.age

# Generate key pair
age-keygen -o ~/.age/key.txt

# View your public key
cat ~/.age/key.txt
```

**Output example:**
```
# created: 2026-01-09T11:40:37+05:30
# public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AGE-SECRET-KEY-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**⚠️ SECURITY WARNING:** Never commit or share your actual age key! The example above shows placeholder values only.

### 2. Configure SOPS to use age

```bash
# Create secrets directory
mkdir -p ~/.secrets

# Create SOPS configuration
cat > ~/.secrets/.sops.yaml << 'EOF'
creation_rules:
  - age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
```

**Important:** Replace `age1xxx...` with your actual public key from step 1.

### 3. Create encrypted secrets file

```bash
# Set the age key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

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
cd ~/.secrets
sops --encrypt --input-type dotenv --output-type dotenv web3-ethereum-defi-plain.env > web3-ethereum-defi.env

# Delete plaintext file
rm web3-ethereum-defi-plain.env
```

### 4. Configure project to decrypt secrets

In your project repository, create `.local-test.env` (this file should be gitignored):

```bash
# Set SOPS age key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

# Decrypt and export all environment variables from encrypted file
eval "$(SOPS_AGE_KEY_FILE=~/.age/key.txt sops --decrypt --input-type dotenv --output-type dotenv ~/.secrets/web3-ethereum-defi.env | sed 's/^/export /')"
```

### 5. Backup age key to KeePassXC

```bash
# Create KeePassXC database (if not exists)
mkdir -p ~/.secrets/keepass
keepassxc-cli db-create ~/.secrets/keepass/secrets.kdbx

# Backup age key as attachment
keepassxc-cli attachment-import ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  ~/.age/key.txt
```

This stores the age key as an attachment in your KeePassXC database under the entry "SOPS-age-encryption-key".

### 6. (Optional) Enhanced Security: Remove plaintext age key from disk

For maximum security, you can configure your system to fetch the age key from KeePassXC on-demand instead of storing it on disk. This prevents the key from being exposed if your disk is compromised.

**Create secure wrapper script:**

```bash
# Create wrapper script directory
mkdir -p ~/.local/bin

# Create load-secrets wrapper
cat > ~/.local/bin/load-secrets << 'EOF'
#!/bin/bash
#
# Load encrypted secrets into environment variables
# Fetches age key from KeePassXC on-the-fly
#

set -e

KEEPASS_DB="$HOME/.secrets/keepass/secrets.kdbx"
KEY_ENTRY="SOPS-age-encryption-key"
SECRETS_FILE="${1:-$HOME/.secrets/web3-ethereum-defi.env}"

# Check if secrets file exists
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "Error: Secrets file not found at $SECRETS_FILE" >&2
    exit 1
fi

# Create temporary file in memory
TEMP_KEY=$(mktemp)
trap "rm -f $TEMP_KEY" EXIT

# Fetch age key from KeePassXC to temporary file
# Password prompt will appear for KeePassXC database
keepassxc-cli attachment-export "$KEEPASS_DB" "$KEY_ENTRY" "age-key.txt" "$TEMP_KEY" >&2

# Use the key to decrypt secrets
export SOPS_AGE_KEY_FILE="$TEMP_KEY"
sops --decrypt --input-type dotenv --output-type dotenv "$SECRETS_FILE"

# Cleanup happens automatically via trap
EOF

chmod +x ~/.local/bin/load-secrets

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Create secure project template:**

```bash
cat > ~/sops-project-template-secure.env << 'EOF'
#!/bin/bash
#
# Secure SOPS project template
# Age key is fetched from KeePassXC on-the-fly and cleaned up automatically
#

# Decrypt and export all environment variables
# You'll be prompted for KeePassXC password once
eval "$(load-secrets ~/.secrets/web3-ethereum-defi.env | sed 's/^/export /')"

echo "✓ Secrets loaded from KeePassXC"
EOF

chmod +x ~/sops-project-template-secure.env
```

**Remove plaintext age key from disk (ONLY after confirming wrappers work):**

```bash
# Test the wrapper first
load-secrets ~/.secrets/web3-ethereum-defi.env | head -n 5

# If it works, remove the plaintext key
rm -P ~/.age/key.txt  # macOS
# or: shred -u ~/.age/key.txt  # Linux

echo "✓ Plaintext age key removed - now only exists in KeePassXC"
```

## Daily usage

### Using secrets in projects

**Standard method (age key on disk):**

```bash
# Source the environment file
source .local-test.env

# Run your commands with decrypted secrets
poetry run python script.py

# Or combine them
source .local-test.env && poetry run pytest tests/
```

**Secure method (age key in KeePassXC only):**

```bash
# Option A: Source the secure template
source ~/sops-project-template-secure.env && poetry run python script.py

# Option B: Load secrets directly
eval "$(load-secrets)" && poetry run python script.py

# Option C: View secrets only
load-secrets ~/.secrets/web3-ethereum-defi.env
```

You'll be prompted for your KeePassXC password once, then secrets are available for the session.

### Editing encrypted secrets

```bash
# Set the key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

# Edit encrypted file (opens in your default editor)
sops ~/.secrets/web3-ethereum-defi.env
```

The file will be decrypted in memory, opened in your editor, and re-encrypted when you save and exit.

### Viewing encrypted secrets

**Standard method (age key on disk):**

```bash
# Decrypt and view (without editing)
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops --decrypt ~/.secrets/web3-ethereum-defi.env
```

**Secure method (age key in KeePassXC only):**

```bash
# View secrets (prompts for KeePassXC password)
load-secrets ~/.secrets/web3-ethereum-defi.env
```

### Adding new secrets

```bash
# Option 1: Edit the file directly
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops ~/.secrets/web3-ethereum-defi.env
# Add your new variables, save and exit

# Option 2: Use sops set command
sops --set '["NEW_API_KEY"] "your-new-api-key-value"' ~/.secrets/web3-ethereum-defi.env
```

## Backup and recovery

### Backup your age key

Your age key is stored in KeePassXC. To verify:

```bash
# List attachments in the entry
keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  /tmp/age-key-backup.txt

# View the exported key
cat /tmp/age-key-backup.txt

# Securely delete the temporary file
shred -u /tmp/age-key-backup.txt  # Linux
# or
rm -P /tmp/age-key-backup.txt     # macOS
```

### Restore age key from KeePassXC

If you lose your `~/.age/key.txt`, restore it from KeePassXC:

```bash
# Export from KeePassXC
keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  ~/.age/key.txt

# Set correct permissions
chmod 600 ~/.age/key.txt
```

### Backup encrypted secrets file

The encrypted file `~/.secrets/web3-ethereum-defi.env` can be safely backed up or version controlled:

```bash
# Copy to backup location
cp ~/.secrets/web3-ethereum-defi.env ~/Backups/

# Or commit to a private git repository
cd ~/.secrets
git init
git add web3-ethereum-defi.env .sops.yaml
git commit -m "Add encrypted secrets"
git remote add origin git@github.com:yourusername/secrets.git
git push -u origin main
```

## Replicating this environment on a new machine

### Quick setup

Use the setup script:

```bash
./setup-sops-age.sh
```

### Manual setup

1. **Install tools:**
   ```bash
   brew install age sops keepassxc-cli  # macOS
   ```

2. **Restore age key from KeePassXC:**
   ```bash
   mkdir -p ~/.age
   keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
     "SOPS-age-encryption-key" \
     "age-key.txt" \
     ~/.age/key.txt
   chmod 600 ~/.age/key.txt
   ```

3. **Copy encrypted secrets file:**
   ```bash
   mkdir -p ~/.secrets
   # Copy from backup or git clone
   ```

4. **Configure project:**
  ```bash
  cd /path/to/project
  cat > .local-test.env << 'EOF' 
  export SOPS_AGE_KEY_FILE=~/.age/key.txt
  eval "$(SOPS_AGE_KEY_FILE=~/.age/key.txt sops --decrypt --input-type dotenv --output-type dotenv ~/.secrets/web3-ethereum-defi.env | sed 's/^/export /')"
  EOF
  ```

5. **Test:**
   ```bash
   source .local-test.env
   env | grep JSON_RPC
   ```

## Security best practices

### File permissions

```bash
# Restrict access to age key (if using standard method)
chmod 600 ~/.age/key.txt

# Restrict access to KeePassXC database
chmod 600 ~/.secrets/keepass/secrets.kdbx

# Restrict access to wrapper scripts
chmod 700 ~/.local/bin/load-secrets
```

### Enhanced security with KeePassXC-only workflow

For maximum security, remove the plaintext age key from disk entirely:

**Benefits:**
- Age key only exists encrypted in KeePassXC
- Malware cannot steal plaintext key from disk
- Disk backups don't contain unencrypted keys
- Single password protects all secrets

**How to enable:**
1. Set up the `load-secrets` wrapper script (see section 6 above)
2. Test that it works: `load-secrets ~/.secrets/web3-ethereum-defi.env`
3. Remove plaintext key: `rm -P ~/.age/key.txt` (macOS) or `shred -u ~/.age/key.txt` (Linux)
4. Use `load-secrets` or the secure project template for all operations

### gitignore patterns

Add to your project's `.gitignore`:

```
.local-test.env
.env
.env.local
*.key
*.pem
```

### Key rotation

To rotate your age key:

```bash
# Generate new key
age-keygen -o ~/.age/key-new.txt

# Update SOPS config with new public key
# Edit ~/.secrets/.sops.yaml

# Re-encrypt secrets with new key
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops --rotate --add-age <NEW_PUBLIC_KEY> ~/.secrets/web3-ethereum-defi.env

# Backup new key to KeePassXC
keepassxc-cli attachment-import ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key-new" \
  "age-key-new.txt" \
  ~/.age/key-new.txt

# Replace old key
mv ~/.age/key-new.txt ~/.age/key.txt
```

## Troubleshooting

### "SOPS not found" error

```bash
which sops
# If not found, install: brew install sops
```

### "Failed to get data key" error

This means SOPS cannot find your age key. Set the environment variable:

```bash
export SOPS_AGE_KEY_FILE=~/.age/key.txt
```

### "Invalid credentials" when using KeePassXC

Ensure you're entering the correct master password for your KeePassXC database.

### Decryption fails

**Standard method:**
Verify your age key is correct:

```bash
cat ~/.age/key.txt
# Should show the age secret key
```

**Secure method:**
Verify the key is in KeePassXC:

```bash
keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  /dev/stdout
```

### "load-secrets: command not found"

The wrapper script directory isn't in your PATH:

```bash
# Add to PATH temporarily
export PATH="$HOME/.local/bin:$PATH"

# Add permanently
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## File locations reference

| File | Location | Purpose | Backup? |
|------|----------|---------|---------|
| Age key | `~/.age/key.txt` | Encryption key (standard method) | ✅ In KeePassXC |
| SOPS config | `~/.secrets/.sops.yaml` | SOPS settings | ✅ Optional |
| Encrypted secrets | `~/.secrets/web3-ethereum-defi.env` | Encrypted env vars | ✅ Yes |
| KeePassXC DB | `~/.secrets/keepass/secrets.kdbx` | Key backup (encrypted) | ✅ Yes |
| Project loader | `.local-test.env` | Per-project file (standard) | ❌ Gitignored |
| Secure loader | `~/.local/bin/load-secrets` | Wrapper script (secure method) | ✅ Optional |
| Secure template | `~/sops-project-template-secure.env` | Secure project template | ✅ Optional |

## Additional resources

- [SOPS GitHub Repository & Documentation](https://github.com/mozilla/sops)
- [age GitHub Repository & Documentation](https://github.com/FiloSottile/age)
- [KeePassXC GitHub Repository](https://github.com/keepassxreboot/keepassxc)
- [KeePassXC Official Documentation](https://keepassxc.org/docs/)

## Changelog

- **2026-01-09**:
  - Initial setup with SOPS + age + KeePassXC
  - Added enhanced security workflow using `load-secrets` wrapper
  - Age key can now be stored exclusively in KeePassXC (never on disk)
  - Replaced exposed example keys with placeholder values
  - Updated documentation with both standard and secure workflows
