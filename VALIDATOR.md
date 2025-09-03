# Nethermind Node Validator

Simple validator for Nethermind nodes after updates.

## Usage

```bash
# Download and run
wget https://raw.githubusercontent.com/fuseio/nethermind-client/master/validate.sh
chmod +x validate.sh
./validate.sh https://rpc.fusespark.io

# With verbose logging (shows RPC calls)
./validate.sh https://rpc.fusespark.io --verbose

# Compare with reference endpoint
./validate.sh http://localhost:8545 --reference=https://rpc.fusespark.io

# Or one-liner with reference
curl -s https://raw.githubusercontent.com/fuseio/nethermind-client/master/validate.sh | bash -s https://rpc.fusespark.io --reference=https://rpc.fusespark.io
```

## What it checks

1. **Connectivity** - Node responds
2. **Version** - Shows version (info only)
3. **Sync Status** - Node is synced
4. **Peer Count** - Has enough peers (≥10)
5. **Latest Block** - Receiving new blocks (compares with reference if provided)
6. **RPC Methods** - Basic methods work

## Exit codes

- **0** = All tests passed ✅
- **1** = Warnings present ⚠️
- **2** = Critical issues ❌

## DevOps example

```bash
#!/bin/bash
# After node update

./validate.sh https://rpc.fusespark.io --verbose

if [ $? -eq 0 ]; then
    echo "Node ready for production"
else
    echo "Issues detected"
    exit 1
fi
```

Requirements: bash + curl (standard on all Linux systems)
