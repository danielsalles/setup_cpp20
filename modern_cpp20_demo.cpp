#include <iostream>
#include <vector>
#include <ranges>
#include <algorithm>
#include <string>
#include <format>

// C++20 Concepts example
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
auto square(T value) -> T {
    return value * value;
}

int main() {
    std::cout << "🚀 Modern C++20 Demo\n";
    std::cout << "====================\n\n";

    // C++20 Ranges example
    std::vector<int> numbers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    std::cout << "📊 Original numbers: ";
    for (const auto& num : numbers) {
        std::cout << num << " ";
    }
    std::cout << "\n";

    // Using ranges to filter and transform
    auto even_squares = numbers 
        | std::views::filter([](int n) { return n % 2 == 0; })
        | std::views::transform([](int n) { return square(n); });

    std::cout << "🔢 Even numbers squared: ";
    for (const auto& num : even_squares) {
        std::cout << num << " ";
    }
    std::cout << "\n";

    // C++20 Format library (if available)
    try {
        std::string formatted = std::format("✨ C++20 is {} awesome!", "really");
        std::cout << formatted << "\n";
    } catch (...) {
        std::cout << "✨ C++20 is really awesome! (format not available)\n";
    }

    // C++20 Concepts in action
    std::cout << "\n🧮 Concepts demo:\n";
    std::cout << "Square of 5: " << square(5) << "\n";
    std::cout << "Square of 3.14: " << square(3.14) << "\n";

    // Platform detection from CMake
    std::cout << "\n🖥️  Platform: ";
    #ifdef APPLE_PLATFORM
        std::cout << "macOS (Apple Silicon or Intel)";
    #elif defined(LINUX_PLATFORM)
        std::cout << "Linux";
    #elif defined(WIN32_PLATFORM)
        std::cout << "Windows";
    #else
        std::cout << "Unknown";
    #endif
    std::cout << "\n";

    std::cout << "\n✅ C++20 demo completed successfully!\n";
    return 0;
} 