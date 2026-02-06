#!/usr/bin/env bash
set -e

echo "🔍 Lucee NixOS Module - Comprehensive Validation"
echo "================================================"

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo "    ✅ $1"
    else
        echo "    ❌ $1"
        exit 1
    fi
}

# Check if we're in the right directory
if [ ! -f "lucee.nix" ]; then
    echo "❌ Error: Please run this script from the lucee-nix project root"
    exit 1
fi

echo ""
echo "📝 Phase 1: Syntax Validation"
echo "-----------------------------"
for file in *.nix; do
    echo "  Checking $file..."
    nix-instantiate --parse "$file" > /dev/null 2>&1
    print_status "$file syntax"
done

echo ""
echo "🔧 Phase 2: Module Import Tests"
echo "-------------------------------"
echo "  Testing lucee.nix import..."
nix-instantiate --eval --expr "
  let pkgs = import <nixpkgs> {}; lib = pkgs.lib;
  in builtins.typeOf (import ./lucee.nix { inherit lib pkgs; })
" > /dev/null 2>&1
print_status "lucee.nix import"

echo "  Testing extensions.nix import..."
nix-instantiate --eval --expr "
  let pkgs = import <nixpkgs> {}; lib = pkgs.lib;
  in builtins.typeOf (import ./extensions.nix { inherit lib pkgs; })
" > /dev/null 2>&1
print_status "extensions.nix import"

echo ""
echo "📦 Phase 3: Example Configuration"
echo "---------------------------------"
echo "  Validating example.nix..."
nix-instantiate --eval example.nix > /dev/null 2>&1
print_status "example.nix evaluation"

echo ""
echo "🧪 Phase 4: Flake Validation"
echo "----------------------------"
if [ -f "flake.nix" ]; then
    echo "  Testing flake evaluation..."
    nix flake check --no-build 2>/dev/null
    print_status "flake structure"
    
    echo "  Testing devShell availability..."
    nix flake show 2>/dev/null | grep -q "devShells"
    print_status "devShell defined"
else
    echo "  ⚠️  No flake.nix found, skipping flake validation"
fi

echo ""
echo "🎉 All validations completed successfully!"
echo ""
echo "💡 Next steps:"
echo "   - Run 'nix develop' to enter the development environment"
echo "   - Use 'validate-all' from within the devShell for full testing"
echo "   - Try 'nix flake check' for additional validation"