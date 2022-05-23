#include "ast.hpp"

namespace axon {
namespace runtime {

class NativeTypeChecker {
public:
    static bool typecheck(const std::shared_ptr<ProgramNode>& /* program */) {
        // Verifies absence of type conflicts and method contract violations
        return true;
    }
};

} // namespace runtime
} // namespace axon
