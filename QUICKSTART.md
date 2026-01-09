# Quick start guide

## TL;DR - Common commands

### Edit secrets
```bash
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops ~/.secrets/web3-ethereum-defi.env
```

### Use secrets in project
```bash
source .local-test.env && poetry run python script.py
```

### View secrets (without editing)
```bash
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops --decrypt ~/.secrets/web3-ethereum-defi.env
```

### Restore age key from KeePassXC
```bash
keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  ~/.age/key.txt
chmod 600 ~/.age/key.txt
```

### Backup age key to KeePassXC
```bash
keepassxc-cli attachment-import ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  ~/.age/key.txt
```

## Setup on new machine

### Option 1: Automated setup
```bash
./setup-sops-age.sh --restore-from-backup
```

### Option 2: Manual setup
```bash
# 1. Install tools
brew install age sops keepassxc

# 2. Restore age key from KeePassXC
mkdir -p ~/.age
keepassxc-cli attachment-export ~/.secrets/keepass/secrets.kdbx \
  "SOPS-age-encryption-key" \
  "age-key.txt" \
  ~/.age/key.txt
chmod 600 ~/.age/key.txt

# 3. Copy encrypted secrets (from backup or git)
mkdir -p ~/.secrets
# ... copy your encrypted file here ...

# 4. Test
export SOPS_AGE_KEY_FILE=~/.age/key.txt
sops --decrypt ~/.secrets/web3-ethereum-defi.env
```

## What gets backed up?

| Item | Location | Backup method |
|------|----------|---------------|
| Age key | `~/.age/key.txt` | KeePassXC attachment |
| Encrypted secrets | `~/.secrets/web3-ethereum-defi.env` | Git or file backup |
| KeePassXC DB | `~/.secrets/keepass/secrets.kdbx` | External backup |

## File structure

```
~/.age/
  └── key.txt                    # Age encryption key (backed up in KeePassXC)

~/.secrets/
  ├── .sops.yaml                 # SOPS configuration
  ├── web3-ethereum-defi.env     # Encrypted secrets
  └── keepass/
      └── secrets.kdbx           # KeePassXC database

/path/to/project/
  └── .local-test.env            # Project-specific loader (gitignored)
```

## Emergency recovery

If you lose everything except your KeePassXC database:

1. Install tools: `brew install age sops keepassxc`
2. Restore age key from KeePassXC (see commands above)
3. Restore encrypted secrets from backup or git
4. Configure SOPS (the setup script can do this)
5. Test decryption

## Troubleshooting

**Cannot decrypt secrets:**
```bash
# Set the key location
export SOPS_AGE_KEY_FILE=~/.age/key.txt

# Verify key exists and is readable
ls -lh ~/.age/key.txt
cat ~/.age/key.txt
```

**KeePassXC attachment commands fail:**
- Ensure you're using the correct entry name: `SOPS-age-encryption-key`
- Ensure you're using the correct attachment name: `age-key.txt`
- Try listing entries: `keepassxc-cli ls ~/.secrets/keepass/secrets.kdbx`

**"Command not found" errors:**
```bash
# Verify installations
which age sops keepassxc-cli

# Reinstall if missing
brew install age sops keepassxc
```

For detailed information, see [README.md](README.md).
