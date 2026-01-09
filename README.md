# Secure environment variable management with SOPS + age

This document describes the setup and usage of SOPS (Secrets OPerationS) with age encryption for managing sensitive environment variables securely.

## Overview

This setup allows you to:
- Store API keys, private keys, and other secrets encrypted at rest
- Decrypt secrets only when needed (in memory)
- Avoid storing plaintext credentials on disk
- Backup encryption keys securely in KeePassXC
- Version control encrypted files safely (optional)

## Architecture

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

## Tools required

- **age**: Modern encryption tool
- **sops**: Secrets management tool by Mozilla
- **keepassxc-cli**: KeePassXC command-line interface for key backup

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
# public key: age12ezrg2zd654krydl73lnu78sz0pcpkuvj3vwwz3dyef62c2fmynqjesdvv
AGE-SECRET-KEY-1Q5V957WLTUV5GDXG55R6QQ7AH3SLDSPCF3Z77P2SWPGHJ4ZHJFPQSGGK0S
```

### 2. Configure SOPS to use age

```bash
# Create secrets directory
mkdir -p ~/.secrets

# Create SOPS configuration
cat > ~/.secrets/.sops.yaml << 'EOF'
creation_rules:
  - age: age12ezrg2zd654krydl73lnu78sz0pcpkuvj3vwwz3dyef62c2fmynqjesdvv
EOF
```

**Important:** Replace the public key with your actual public key from step 1.

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

## Daily usage

### Using secrets in projects

```bash
# Source the environment file
source .local-test.env

# Run your commands with decrypted secrets
poetry run python script.py

# Or combine them
source .local-test.env && poetry run pytest tests/
```

### Editing encrypted secrets

```bash
# Set the key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

# Edit encrypted file (opens in your default editor)
sops ~/.secrets/web3-ethereum-defi.env
```

The file will be decrypted in memory, opened in your editor, and re-encrypted when you save and exit.

### Viewing encrypted secrets

```bash
# Decrypt and view (without editing)
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops --decrypt ~/.secrets/web3-ethereum-defi.env
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
# Restrict access to age key
chmod 600 ~/.age/key.txt

# Restrict access to KeePassXC database
chmod 600 ~/.secrets/keepass/secrets.kdbx
```

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

Verify your age key is correct:

```bash
cat ~/.age/key.txt
# Should show the age secret key
```

## File locations reference

| File | Location | Purpose | Backup? |
|------|----------|---------|---------|
| Age key | `~/.age/key.txt` | Encryption key | ✅ In KeePassXC |
| SOPS config | `~/.secrets/.sops.yaml` | SOPS settings | ✅ Optional |
| Encrypted secrets | `~/.secrets/web3-ethereum-defi.env` | Encrypted env vars | ✅ Yes |
| KeePassXC DB | `~/.secrets/keepass/secrets.kdbx` | Key backup | ✅ Yes |
| Project loader | `.local-test.env` | Per-project file | ❌ Gitignored |

## Additional resources

- [SOPS Documentation](https://github.com/mozilla/sops)
- [age Documentation](https://github.com/FiloSottile/age)
- [KeePassXC Documentation](https://keepassxc.org/docs/)

## Changelog

- **2026-01-09**: Initial setup with SOPS + age + KeePassXC
