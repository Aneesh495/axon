#include "value.hpp"
#include <chrono>
#include <cmath>
#include <random>

namespace axon {
namespace runtime {

void registerStdLib(std::unordered_map<std::string, ValuePtr>& global_env) {
    // microtime(true)
    global_env["microtime"] = Value::callableVal([](const std::vector<ValuePtr>&) -> ValuePtr {
        auto now = std::chrono::system_clock::now();
        auto duration = now.time_since_epoch();
        double micros = std::chrono::duration_cast<std::chrono::microseconds>(duration).count();
        return Value::floatVal(micros / 1000000.0);
    });

    // time()
    global_env["time"] = Value::callableVal([](const std::vector<ValuePtr>&) -> ValuePtr {
        auto now = std::chrono::system_clock::now();
        auto secs = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
        return Value::intVal(secs);
    });

    // strlen(string)
    global_env["strlen"] = Value::callableVal([](const std::vector<ValuePtr>& args) -> ValuePtr {
        if (args.empty() || !args[0]->isString()) return Value::intVal(0);
        return Value::intVal(static_cast<int64_t>(args[0]->asString().length()));
    });

    // substr(string, start, len)
    global_env["substr"] = Value::callableVal([](const std::vector<ValuePtr>& args) -> ValuePtr {
        if (args.empty() || !args[0]->isString()) return Value::stringVal("");
        const std::string& str = args[0]->asString();
        size_t start = args.size() > 1 && args[1]->isInt() ? static_cast<size_t>(args[1]->asInt()) : 0;
        if (start >= str.length()) return Value::stringVal("");
        if (args.size() > 2 && args[2]->isInt()) {
            size_t len = static_cast<size_t>(args[2]->asInt());
            return Value::stringVal(str.substr(start, len));
        }
        return Value::stringVal(str.substr(start));
    });

    // strpos(haystack, needle)
    global_env["strpos"] = Value::callableVal([](const std::vector<ValuePtr>& args) -> ValuePtr {
        if (args.size() < 2 || !args[0]->isString() || !args[1]->isString()) return Value::boolVal(false);
        auto pos = args[0]->asString().find(args[1]->asString());
        if (pos == std::string::npos) return Value::boolVal(false);
        return Value::intVal(static_cast<int64_t>(pos));
    });

    // count(vec or dict or keyset)
    global_env["count"] = Value::callableVal([](const std::vector<ValuePtr>& args) -> ValuePtr {
        if (args.empty() || args[0]->isNull()) return Value::intVal(0);
        if (args[0]->isVec()) return Value::intVal(static_cast<int64_t>(args[0]->asVec().size()));
        if (args[0]->isDict()) return Value::intVal(static_cast<int64_t>(args[0]->asDict().size()));
        if (args[0]->isKeyset()) return Value::intVal(static_cast<int64_t>(args[0]->asKeyset().size()));
        return Value::intVal(1);
    });

    // random_int(min, max)
    global_env["random_int"] = Value::callableVal([](const std::vector<ValuePtr>& args) -> ValuePtr {
        static std::mt19937_64 rng(std::random_device{}());
        int64_t min = args.size() > 0 && args[0]->isInt() ? args[0]->asInt() : 0;
        int64_t max = args.size() > 1 && args[1]->isInt() ? args[1]->asInt() : 0x7FFFFFFF;
        std::uniform_int_distribution<int64_t> dist(min, max);
        return Value::intVal(dist(rng));
    });
}

} // namespace runtime
} // namespace axon
