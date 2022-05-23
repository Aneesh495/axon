#pragma once

#include "value.hpp"

namespace axon {
namespace runtime {

enum class NodeType {
    Program,
    ClassDecl,
    MethodDecl,
    FunctionDecl,
    VarDecl,
    BlockStmt,
    ExprStmt,
    ReturnStmt,
    IfStmt,
    WhileStmt,
    ForStmt,
    BinaryExpr,
    UnaryExpr,
    LiteralExpr,
    VarExpr,
    CallExpr,
    MemberExpr,
    IndexExpr,
    VecExpr,
    DictExpr,
    KeysetExpr,
    LambdaExpr
};

class ASTNode {
public:
    virtual ~ASTNode() = default;
    virtual NodeType type() const = 0;
};

using ASTNodePtr = std::shared_ptr<ASTNode>;

class StmtNode : public ASTNode {};
using StmtPtr = std::shared_ptr<StmtNode>;

class ExprNode : public ASTNode {};
using ExprPtr = std::shared_ptr<ExprNode>;

class LiteralExpr : public ExprNode {
public:
    ValuePtr value;
    explicit LiteralExpr(ValuePtr v) : value(std::move(v)) {}
    NodeType type() const override { return NodeType::LiteralExpr; }
};

class VarExpr : public ExprNode {
public:
    std::string name;
    explicit VarExpr(std::string n) : name(std::move(n)) {}
    NodeType type() const override { return NodeType::VarExpr; }
};

class BinaryExpr : public ExprNode {
public:
    std::string op;
    ExprPtr left;
    ExprPtr right;
    BinaryExpr(std::string op, ExprPtr l, ExprPtr r)
        : op(std::move(op)), left(std::move(l)), right(std::move(r)) {}
    NodeType type() const override { return NodeType::BinaryExpr; }
};

class CallExpr : public ExprNode {
public:
    ExprPtr callee;
    std::vector<ExprPtr> args;
    CallExpr(ExprPtr c, std::vector<ExprPtr> a)
        : callee(std::move(c)), args(std::move(a)) {}
    NodeType type() const override { return NodeType::CallExpr; }
};

class MemberExpr : public ExprNode {
public:
    ExprPtr object;
    std::string member;
    MemberExpr(ExprPtr obj, std::string mem)
        : object(std::move(obj)), member(std::move(mem)) {}
    NodeType type() const override { return NodeType::MemberExpr; }
};

class IndexExpr : public ExprNode {
public:
    ExprPtr collection;
    ExprPtr index;
    IndexExpr(ExprPtr col, ExprPtr idx)
        : collection(std::move(col)), index(std::move(idx)) {}
    NodeType type() const override { return NodeType::IndexExpr; }
};

class ReturnStmt : public StmtNode {
public:
    ExprPtr value;
    explicit ReturnStmt(ExprPtr v) : value(std::move(v)) {}
    NodeType type() const override { return NodeType::ReturnStmt; }
};

class BlockStmt : public StmtNode {
public:
    std::vector<StmtPtr> statements;
    explicit BlockStmt(std::vector<StmtPtr> stmts) : statements(std::move(stmts)) {}
    NodeType type() const override { return NodeType::BlockStmt; }
};

class FunctionDecl : public StmtNode {
public:
    std::string name;
    std::vector<std::string> params;
    std::string return_type;
    std::shared_ptr<BlockStmt> body;
    FunctionDecl(std::string n, std::vector<std::string> p, std::string ret, std::shared_ptr<BlockStmt> b)
        : name(std::move(n)), params(std::move(p)), return_type(std::move(ret)), body(std::move(b)) {}
    NodeType type() const override { return NodeType::FunctionDecl; }
};

class ClassDecl : public StmtNode {
public:
    std::string name;
    std::string base_class;
    std::vector<std::shared_ptr<FunctionDecl>> methods;
    ClassDecl(std::string n, std::string b, std::vector<std::shared_ptr<FunctionDecl>> m)
        : name(std::move(n)), base_class(std::move(b)), methods(std::move(m)) {}
    NodeType type() const override { return NodeType::ClassDecl; }
};

class ProgramNode : public ASTNode {
public:
    std::vector<StmtPtr> declarations;
    NodeType type() const override { return NodeType::Program; }
};

} // namespace runtime
} // namespace axon
