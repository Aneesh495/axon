#pragma once

#include "axon_runtime.hpp"

namespace axon {
namespace runtime {

using CallableFunc = std::function<ValuePtr(const std::vector<ValuePtr>&)>;

class Value {
private:
    ValueType type_;
    bool bool_val_{false};
    int64_t int_val_{0};
    double float_val_{0.0};
    std::string str_val_;
    std::vector<ValuePtr> vec_val_;
    std::unordered_map<std::string, ValuePtr> dict_val_;
    std::unordered_set<std::string> keyset_val_;
    ObjectPtr obj_val_{nullptr};
    CallableFunc func_val_;

public:
    Value() : type_(ValueType::Null) {}
    explicit Value(bool b) : type_(ValueType::Bool), bool_val_(b) {}
    explicit Value(int64_t i) : type_(ValueType::Int), int_val_(i) {}
    explicit Value(double f) : type_(ValueType::Float), float_val_(f) {}
    explicit Value(const std::string& s) : type_(ValueType::String), str_val_(s) {}
    explicit Value(const char* s) : type_(ValueType::String), str_val_(s) {}
    explicit Value(const std::vector<ValuePtr>& v) : type_(ValueType::Vec), vec_val_(v) {}
    explicit Value(const std::unordered_map<std::string, ValuePtr>& d) : type_(ValueType::Dict), dict_val_(d) {}
    explicit Value(const std::unordered_set<std::string>& k) : type_(ValueType::Keyset), keyset_val_(k) {}
    explicit Value(ObjectPtr obj) : type_(ValueType::Object), obj_val_(std::move(obj)) {}
    explicit Value(CallableFunc fn) : type_(ValueType::Callable), func_val_(std::move(fn)) {}

    ValueType type() const { return type_; }
    bool isNull() const { return type_ == ValueType::Null; }
    bool isBool() const { return type_ == ValueType::Bool; }
    bool isInt() const { return type_ == ValueType::Int; }
    bool isFloat() const { return type_ == ValueType::Float; }
    bool isString() const { return type_ == ValueType::String; }
    bool isVec() const { return type_ == ValueType::Vec; }
    bool isDict() const { return type_ == ValueType::Dict; }
    bool isKeyset() const { return type_ == ValueType::Keyset; }
    bool isObject() const { return type_ == ValueType::Object; }
    bool isCallable() const { return type_ == ValueType::Callable; }

    bool asBool() const { return bool_val_; }
    int64_t asInt() const { return int_val_; }
    double asFloat() const { return float_val_; }
    const std::string& asString() const { return str_val_; }
    const std::vector<ValuePtr>& asVec() const { return vec_val_; }
    std::vector<ValuePtr>& asVec() { return vec_val_; }
    const std::unordered_map<std::string, ValuePtr>& asDict() const { return dict_val_; }
    std::unordered_map<std::string, ValuePtr>& asDict() { return dict_val_; }
    const std::unordered_set<std::string>& asKeyset() const { return keyset_val_; }
    ObjectPtr asObject() const { return obj_val_; }

    ValuePtr call(const std::vector<ValuePtr>& args) const {
        if (!func_val_) {
            throw std::runtime_error("Attempted to invoke non-callable value");
        }
        return func_val_(args);
    }

    std::string toString() const {
        switch (type_) {
            case ValueType::Null: return "null";
            case ValueType::Bool: return bool_val_ ? "true" : "false";
            case ValueType::Int: return std::to_string(int_val_);
            case ValueType::Float: return std::to_string(float_val_);
            case ValueType::String: return str_val_;
            case ValueType::Vec: {
                std::stringstream ss;
                ss << "vec[";
                for (size_t i = 0; i < vec_val_.size(); i++) {
                    if (i > 0) ss << ", ";
                    ss << (vec_val_[i] ? vec_val_[i]->toString() : "null");
                }
                ss << "]";
                return ss.str();
            }
            case ValueType::Dict: {
                std::stringstream ss;
                ss << "dict[";
                bool first = true;
                for (const auto& kv : dict_val_) {
                    if (!first) ss << ", ";
                    first = false;
                    ss << "'" << kv.first << "' => " << (kv.second ? kv.second->toString() : "null");
                }
                ss << "]";
                return ss.str();
            }
            case ValueType::Keyset: {
                std::stringstream ss;
                ss << "keyset[";
                bool first = true;
                for (const auto& k : keyset_val_) {
                    if (!first) ss << ", ";
                    first = false;
                    ss << "'" << k << "'";
                }
                ss << "]";
                return ss.str();
            }
            case ValueType::Object: return "<object>";
            case ValueType::Callable: return "<closure>";
        }
        return "<unknown>";
    }

    static ValuePtr nullVal() { return std::make_shared<Value>(); }
    static ValuePtr boolVal(bool b) { return std::make_shared<Value>(b); }
    static ValuePtr intVal(int64_t i) { return std::make_shared<Value>(i); }
    static ValuePtr floatVal(double f) { return std::make_shared<Value>(f); }
    static ValuePtr stringVal(const std::string& s) { return std::make_shared<Value>(s); }
    static ValuePtr vecVal(const std::vector<ValuePtr>& v = {}) { return std::make_shared<Value>(v); }
    static ValuePtr dictVal(const std::unordered_map<std::string, ValuePtr>& d = {}) { return std::make_shared<Value>(d); }
    static ValuePtr keysetVal(const std::unordered_set<std::string>& k = {}) { return std::make_shared<Value>(k); }
    static ValuePtr objVal(ObjectPtr obj) { return std::make_shared<Value>(std::move(obj)); }
    static ValuePtr callableVal(CallableFunc fn) { return std::make_shared<Value>(std::move(fn)); }
};

class ObjectInstance {
private:
    std::string class_name_;
    std::unordered_map<std::string, ValuePtr> fields_;

public:
    explicit ObjectInstance(std::string name) : class_name_(std::move(name)) {}

    const std::string& className() const { return class_name_; }

    ValuePtr getField(const std::string& field) const {
        auto it = fields_.find(field);
        return it != fields_.end() ? it->second : Value::nullVal();
    }

    void setField(const std::string& field, ValuePtr val) {
        fields_[field] = std::move(val);
    }

    bool hasField(const std::string& field) const {
        return fields_.find(field) != fields_.end();
    }
};

} // namespace runtime
} // namespace axon
