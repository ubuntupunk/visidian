#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Cleaning test environment...${NC}"
rm -rf test/test_vault/*

echo -e "${BLUE}Step 2: Generating test files...${NC}"
./test/generate_test_files.py test/test_vault

echo -e "${BLUE}Step 3: Setting up PARA structure...${NC}"
./test/setup_test_vault.sh

echo -e "${BLUE}Step 4: Current structure before sorting:${NC}"
tree test/test_vault/

echo -e "${GREEN}Test environment is ready!${NC}"
echo -e "${GREEN}Now:${NC}"
echo "1. Open a new terminal"
echo "2. Start vim"
echo "3. Run these commands in vim:"
echo -e "${BLUE}   :let g:visidian_vault_path = '$(pwd)/test/test_vault/'${NC}"
echo -e "${BLUE}   :let g:visidian_debug_level = 'DEBUG'${NC}"
echo -e "${BLUE}   :let g:visidian_debug_categories = ['PARA', 'CORE']${NC}"
echo -e "${BLUE}   :call visidian#sort#sort()${NC}"
echo ""
echo "After sorting is complete, come back to this terminal and press Enter to verify results..."

read -p "Press Enter to verify sorting results..."

echo -e "${BLUE}Structure after sorting:${NC}"
tree test/test_vault/

echo -e "${BLUE}Running verification...${NC}"
./test/verify_sort.py test/test_vault
