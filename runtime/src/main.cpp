#include "value.hpp"
#include <iostream>
#include <chrono>

namespace axon {
namespace runtime {
    void registerStdLib(std::unordered_map<std::string, ValuePtr>& global_env);
}
}

int main(int argc, char** argv) {
    std::cout << "Axon Native Runtime v1.0.0 (x86_64/arm64)" << std::endl;
    std::cout << "High-performance execution engine for typed Hack federated graph kernels." << std::endl;

    std::unordered_map<std::string, axon::runtime::ValuePtr> env;
    axon::runtime::registerStdLib(env);

    if (argc > 1) {
        std::string mode = argv[1];
        if (mode == "bench") {
            int iterations = 1000000;
            std::cout << "Executing native memory allocation and hash index benchmark ("
                      << iterations << " iterations)..." << std::endl;
            auto start = std::chrono::high_resolution_clock::now();

            std::unordered_map<std::string, axon::runtime::ValuePtr> map;
            for (int i = 0; i < iterations; i++) {
                map["key_" + std::to_string(i % 10000)] = axon::runtime::Value::intVal(i);
            }

            auto end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double> diff = end - start;
            std::cout << "Completed in " << diff.count() << " seconds ("
                      << static_cast<double>(iterations) / diff.count() << " ops/sec)" << std::endl;
            return 0;
        }

        if (mode == "version") {
            std::cout << "Axon Native Runtime 1.0.0" << std::endl;
            return 0;
        }
    }

    std::cout << "Ready. Use 'axon --help' or 'bin/axon' for interactive orchestration." << std::endl;
    return 0;
}
