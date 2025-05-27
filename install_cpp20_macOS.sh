#!/bin/bash

echo "🚀 Setting up modern C++20 environment on macOS..."

# 1. Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Install essential tools
echo "🔧 Installing development tools..."
brew install cmake ninja pkg-config llvm gcc

# 3. Configure useful aliases
echo "⚙️ Configuring aliases..."
cat >> ~/.zshrc << 'EOF'

# C++20 Aliases
alias cpp20='clang++ -std=c++20 -stdlib=libc++'
alias cpp20-debug='clang++ -std=c++20 -stdlib=libc++ -g -O0 -Wall -Wextra'
alias cpp20-release='clang++ -std=c++20 -stdlib=libc++ -O3 -DNDEBUG'

# Function to quickly compile and run
function cpprun() {
    clang++ -std=c++20 -stdlib=libc++ -O2 "$1" -o "${1%.*}" && "./${1%.*}"
}
EOF

# 4. Install vcpkg
echo "📚 Setting up vcpkg..."
if [ ! -d "$HOME/vcpkg" ]; then
    git clone https://github.com/Microsoft/vcpkg.git "$HOME/vcpkg"
    cd "$HOME/vcpkg"
    ./bootstrap-vcpkg.sh
    ./vcpkg integrate install
fi

# 5. Install Conan
echo "🐍 Installing Conan..."
pip3 install conan
conan profile detect --force

echo "✅ Environment configured successfully!"
echo "💡 Restart your terminal or run: source ~/.zshrc"
echo ""
echo "🎯 Test your configuration:"
echo "  cpp20 --version"
echo "  cmake --version"
echo "  conan --version"