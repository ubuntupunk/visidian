#!/bin/bash

# Create test vault directory
TEST_VAULT="test/test_vault"
IMPORT_DIR="$TEST_VAULT/import"

# Create main vault directory if it doesn't exist
mkdir -p "$TEST_VAULT"

# Create PARA directories
mkdir -p "$TEST_VAULT/projects"
mkdir -p "$TEST_VAULT/areas"
mkdir -p "$TEST_VAULT/resources"
mkdir -p "$TEST_VAULT/archives"

# Create import directory for unsorted files
mkdir -p "$IMPORT_DIR"

# Move all existing markdown files to import directory
mv "$TEST_VAULT"/*.md "$IMPORT_DIR/"

echo "Test vault structure created:"
echo "- $TEST_VAULT/"
echo "  ├── projects/"
echo "  ├── areas/"
echo "  ├── resources/"
echo "  ├── archives/"
echo "  └── import/    <- Your unsorted files are here"
echo ""
echo "To test in Vim:"
echo "1. Start Vim"
echo "2. Set vault path: let g:visidian_vault_path = '$(pwd)/$TEST_VAULT/'"
echo "3. Run sort: call visidian#sort#sort()"
