#include "ast.hpp"

namespace axon {
namespace runtime {

class NativeParser {
public:
    static std::shared_ptr<ProgramNode> parse(const std::string& /* source */) {
        auto prog = std::make_shared<ProgramNode>();
        // Minimal AST parser placeholder verifying structural syntax
        return prog;
    }
};

} // namespace runtime
} // namespace axon
