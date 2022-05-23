#pragma once

#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <memory>
#include <functional>
#include <sstream>
#include <stdexcept>
#include <chrono>
#include <cstdint>

namespace axon {
namespace runtime {

enum class ValueType {
    Null,
    Bool,
    Int,
    Float,
    String,
    Vec,
    Dict,
    Keyset,
    Object,
    Callable
};

class Value;
using ValuePtr = std::shared_ptr<Value>;

class ObjectInstance;
using ObjectPtr = std::shared_ptr<ObjectInstance>;

} // namespace runtime
} // namespace axon
