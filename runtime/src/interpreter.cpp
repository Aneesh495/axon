#include "ast.hpp"

namespace axon {
namespace runtime {

class NativeInterpreter {
private:
    std::unordered_map<std::string, ValuePtr> env_;

public:
    NativeInterpreter() = default;

    ValuePtr evaluate(const ExprPtr& expr) {
        if (!expr) return Value::nullVal();
        if (expr->type() == NodeType::LiteralExpr) {
            auto lit = std::static_pointer_cast<LiteralExpr>(expr);
            return lit->value;
        }
        return Value::nullVal();
    }
};

} // namespace runtime
} // namespace axon
