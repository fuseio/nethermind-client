#!/bin/bash

# Nethermind 1.32.2 Validator - Zero Dependency
# Usage: ./validate.sh [node-url] [--verbose]
# Returns: 0=pass, 1=warnings, 2=critical

# Parse arguments
NODE_URL="http://localhost:8545"
REFERENCE_URL=""
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            ;;
        --reference=*)
            REFERENCE_URL="${arg#*=}"
            ;;
        --help|-h)
            echo "Usage: $0 [node-url] [--verbose] [--reference=url]"
            echo "  node-url: RPC endpoint (default: http://localhost:8545)"
            echo "  --verbose: Show detailed RPC calls and responses"
            echo "  --reference=url: Public endpoint to compare block height"
            echo "Examples:"
            echo "  $0 http://localhost:8545"
            echo "  $0 http://localhost:8545 --reference=https://rpc.fusespark.io"
            echo "  $0 http://localhost:8545 --verbose --reference=https://eth.llamarpc.com"
            exit 0
            ;;
        http*)
            NODE_URL="$arg"
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}   Nethermind 1.32.2 Quick Validator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo "Node: $NODE_URL"
if [ "$VERBOSE" = "true" ]; then
    echo -e "${YELLOW}Verbose mode: ON (showing RPC calls)${NC}"
fi
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
CRITICAL=0

# Function to make RPC calls
rpc_call() {
    local method=$1
    local params=${2:-[]}
    local endpoint=${3:-$NODE_URL}
    local payload="{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}"
    
    # Log the RPC call if verbose mode is enabled
    if [ "$VERBOSE" = "true" ]; then
        echo "  → RPC: $method $params to $endpoint" >&2
    fi
    
    local response=$(curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --connect-timeout 5 \
        2>/dev/null)
    
    # Log the response if verbose mode is enabled
    if [ "$VERBOSE" = "true" ]; then
        echo "  ← Response: $(echo "$response" | cut -c1-100)..." >&2
    fi
    
    echo "$response"
}

# Test 1: Connectivity
echo -n "1. Connectivity: "
VERSION=$(rpc_call "web3_clientVersion" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
if [ ! -z "$VERSION" ]; then
    echo -e "${GREEN}✓${NC} Connected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cannot connect"
    ((TESTS_FAILED++))
    ((CRITICAL++))
    echo -e "\n${RED}CRITICAL: Cannot connect to node${NC}"
    exit 2
fi

# Test 2: Version (informational only)
echo -n "2. Version: "
echo -e "${BLUE}ℹ${NC} $VERSION"

# Test 3: Sync Status
echo -n "3. Sync Status: "
SYNC=$(rpc_call "eth_syncing")
if [[ $SYNC == *'"result":false'* ]]; then
    echo -e "${GREEN}✓${NC} Fully synced"
    ((TESTS_PASSED++))
else
    # Try to parse sync progress
    CURRENT=$(echo "$SYNC" | sed -n 's/.*"currentBlock":"0x\([^"]*\)".*/\1/p')
    HIGHEST=$(echo "$SYNC" | sed -n 's/.*"highestBlock":"0x\([^"]*\)".*/\1/p')
    
    if [ ! -z "$CURRENT" ] && [ ! -z "$HIGHEST" ]; then
        CURRENT_DEC=$((16#$CURRENT))
        HIGHEST_DEC=$((16#$HIGHEST))
        PROGRESS=$(awk "BEGIN {printf \"%.1f\", $CURRENT_DEC * 100 / $HIGHEST_DEC}")
        
        if (( $(awk "BEGIN {print ($PROGRESS > 95)}") )); then
            echo -e "${YELLOW}⚠${NC} Syncing: ${PROGRESS}%"
            ((TESTS_FAILED++))
        else
            echo -e "${RED}✗${NC} Syncing: ${PROGRESS}%"
            ((TESTS_FAILED++))
            ((CRITICAL++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} Still syncing"
        ((TESTS_FAILED++))
    fi
fi

# Test 4: Peer Count
echo -n "4. Peer Count: "
PEERS_HEX=$(rpc_call "net_peerCount" | sed -n 's/.*"result":"0x\([^"]*\)".*/\1/p')
if [ ! -z "$PEERS_HEX" ]; then
    PEERS=$((16#$PEERS_HEX))
    if [ $PEERS -ge 10 ]; then
        echo -e "${GREEN}✓${NC} $PEERS peers"
        ((TESTS_PASSED++))
    elif [ $PEERS -ge 3 ]; then
        echo -e "${YELLOW}⚠${NC} $PEERS peers (recommended: 10+)"
        ((TESTS_FAILED++))
    else
        echo -e "${RED}✗${NC} Only $PEERS peers"
        ((TESTS_FAILED++))
        ((CRITICAL++))
    fi
else
    echo -e "${RED}✗${NC} Cannot get peer count"
    ((TESTS_FAILED++))
fi

# Test 5: Latest Block
echo -n "5. Latest Block: "
BLOCK_HEX=$(rpc_call "eth_blockNumber" | sed -n 's/.*"result":"0x\([^"]*\)".*/\1/p')
if [ ! -z "$BLOCK_HEX" ]; then
    BLOCK=$((16#$BLOCK_HEX))
    BLOCK_DATA=$(rpc_call "eth_getBlockByNumber" "[\"0x${BLOCK_HEX}\",false]")
    TIMESTAMP_HEX=$(echo "$BLOCK_DATA" | sed -n 's/.*"timestamp":"0x\([^"]*\)".*/\1/p')
    
    # Check block age
    BLOCK_STATUS=""
    if [ ! -z "$TIMESTAMP_HEX" ]; then
        TIMESTAMP=$((16#$TIMESTAMP_HEX))
        NOW=$(date +%s)
        AGE=$((NOW - TIMESTAMP))
        
        if [ $AGE -lt 300 ]; then  # 5 minutes
            BLOCK_STATUS="${GREEN}✓${NC} Block #$BLOCK (${AGE}s old)"
        else
            MINUTES=$((AGE / 60))
            BLOCK_STATUS="${YELLOW}⚠${NC} Block #$BLOCK (${MINUTES}m old)"
        fi
    else
        BLOCK_STATUS="${GREEN}✓${NC} Block #$BLOCK"
    fi
    
    # Compare with reference endpoint if provided
    if [ ! -z "$REFERENCE_URL" ]; then
        REF_BLOCK_HEX=$(rpc_call "eth_blockNumber" "[]" "$REFERENCE_URL" | sed -n 's/.*"result":"0x\([^"]*\)".*/\1/p')
        if [ ! -z "$REF_BLOCK_HEX" ]; then
            REF_BLOCK=$((16#$REF_BLOCK_HEX))
            BLOCK_DIFF=$((REF_BLOCK - BLOCK))
            
            if [ $BLOCK_DIFF -lt 0 ]; then
                BLOCK_DIFF=$((-BLOCK_DIFF))
            fi
            
            if [ $BLOCK_DIFF -le 5 ]; then
                echo -e "$BLOCK_STATUS, ref: #$REF_BLOCK (±$BLOCK_DIFF)"
                ((TESTS_PASSED++))
            elif [ $BLOCK_DIFF -le 50 ]; then
                echo -e "${YELLOW}⚠${NC} Block #$BLOCK, ref: #$REF_BLOCK (±$BLOCK_DIFF blocks behind)"
                ((TESTS_FAILED++))
            else
                echo -e "${RED}✗${NC} Block #$BLOCK, ref: #$REF_BLOCK (±$BLOCK_DIFF blocks behind)"
                ((TESTS_FAILED++))
                ((CRITICAL++))
            fi
        else
            echo -e "$BLOCK_STATUS (ref endpoint failed)"
            if [ $AGE -lt 300 ]; then
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi
        fi
    else
        echo -e "$BLOCK_STATUS"
        if [ $AGE -lt 300 ]; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
else
    echo -e "${RED}✗${NC} Cannot get block"
    ((TESTS_FAILED++))
fi

# Test 6: Basic RPC Methods
echo -n "6. RPC Methods: "
RPC_PASS=0
RPC_FAIL=0

for method in "eth_chainId" "net_version" "eth_gasPrice"; do
    RESULT=$(rpc_call "$method")
    if [[ $RESULT == *'"result":'* ]] && [[ $RESULT != *'"error":'* ]]; then
        ((RPC_PASS++))
    else
        ((RPC_FAIL++))
    fi
done

if [ $RPC_FAIL -eq 0 ]; then
    echo -e "${GREEN}✓${NC} All working"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} $RPC_FAIL/3 failed"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo "Summary:"
echo "  Tests Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    echo "  Tests Failed: $TESTS_FAILED"
fi
if [ $CRITICAL -gt 0 ]; then
    echo -e "  ${RED}Critical Issues: $CRITICAL${NC}"
fi

# Determine exit code
if [ $CRITICAL -gt 0 ]; then
    echo -e "\n${RED}❌ CRITICAL ISSUES DETECTED${NC}"
    echo "DO NOT USE THIS NODE IN PRODUCTION"
    exit 2
elif [ $TESTS_FAILED -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  VALIDATION COMPLETED WITH WARNINGS${NC}"
    echo "Review issues before production use"
    exit 1
else
    echo -e "\n${GREEN}✅ ALL TESTS PASSED${NC}"
    echo "Node is ready for production"
    exit 0
fi
