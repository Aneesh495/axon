#include "value.hpp"
#include <cctype>

namespace axon {
namespace runtime {

enum class LexTokenType {
    Eof,
    Identifier,
    StringLiteral,
    IntLiteral,
    FloatLiteral,
    KwClass,
    KwFunction,
    KwAsync,
    KwPublic,
    KwPrivate,
    KwProtected,
    KwReturn,
    KwIf,
    KwElse,
    KwVec,
    KwDict,
    KwKeyset,
    LBrace,
    RBrace,
    LParen,
    RParen,
    LBracket,
    RBracket,
    Semicolon,
    Colon,
    Comma,
    Arrow,
    DoubleArrow,
    Dot,
    Plus,
    Minus,
    Star,
    Slash,
    Equal,
    EqualEqual,
    NotEqual
};

struct LexToken {
    LexTokenType type;
    std::string text;
    int line;
    int column;
};

class NativeLexer {
private:
    std::string src_;
    size_t pos_{0};
    int line_{1};
    int col_{1};

public:
    explicit NativeLexer(std::string src) : src_(std::move(src)) {}

    std::vector<LexToken> tokenize() {
        std::vector<LexToken> tokens;
        while (pos_ < src_.length()) {
            char c = src_[pos_];

            if (c == ' ' || c == '\t' || c == '\r') {
                advance(1);
                continue;
            }
            if (c == '\n') {
                advance(1);
                line_++;
                col_ = 1;
                continue;
            }

            // Line comments
            if (c == '/' && pos_ + 1 < src_.length() && src_[pos_ + 1] == '/') {
                while (pos_ < src_.length() && src_[pos_] != '\n') {
                    advance(1);
                }
                continue;
            }

            // Block comments
            if (c == '/' && pos_ + 1 < src_.length() && src_[pos_ + 1] == '*') {
                advance(2);
                while (pos_ + 1 < src_.length() && !(src_[pos_] == '*' && src_[pos_ + 1] == '/')) {
                    if (src_[pos_] == '\n') { line_++; col_ = 1; }
                    advance(1);
                }
                advance(2);
                continue;
            }

            int start_line = line_;
            int start_col = col_;

            if (c == '{') { tokens.push_back({LexTokenType::LBrace, "{", start_line, start_col}); advance(1); continue; }
            if (c == '}') { tokens.push_back({LexTokenType::RBrace, "}", start_line, start_col}); advance(1); continue; }
            if (c == '(') { tokens.push_back({LexTokenType::LParen, "(", start_line, start_col}); advance(1); continue; }
            if (c == ')') { tokens.push_back({LexTokenType::RParen, ")", start_line, start_col}); advance(1); continue; }
            if (c == '[') { tokens.push_back({LexTokenType::LBracket, "[", start_line, start_col}); advance(1); continue; }
            if (c == ']') { tokens.push_back({LexTokenType::RBracket, "]", start_line, start_col}); advance(1); continue; }
            if (c == ';') { tokens.push_back({LexTokenType::Semicolon, ";", start_line, start_col}); advance(1); continue; }
            if (c == ':') { tokens.push_back({LexTokenType::Colon, ":", start_line, start_col}); advance(1); continue; }
            if (c == ',') { tokens.push_back({LexTokenType::Comma, ",", start_line, start_col}); advance(1); continue; }

            if (c == '=' && pos_ + 1 < src_.length() && src_[pos_ + 1] == '>') {
                tokens.push_back({LexTokenType::DoubleArrow, "=>", start_line, start_col});
                advance(2);
                continue;
            }

            if (c == '-' && pos_ + 1 < src_.length() && src_[pos_ + 1] == '>') {
                tokens.push_back({LexTokenType::Arrow, "->", start_line, start_col});
                advance(2);
                continue;
            }

            if (c == '=' && pos_ + 1 < src_.length() && src_[pos_ + 1] == '=') {
                tokens.push_back({LexTokenType::EqualEqual, "==", start_line, start_col});
                advance(2);
                continue;
            }

            if (c == '=') { tokens.push_back({LexTokenType::Equal, "=", start_line, start_col}); advance(1); continue; }
            if (c == '+') { tokens.push_back({LexTokenType::Plus, "+", start_line, start_col}); advance(1); continue; }
            if (c == '-') { tokens.push_back({LexTokenType::Minus, "-", start_line, start_col}); advance(1); continue; }
            if (c == '*') { tokens.push_back({LexTokenType::Star, "*", start_line, start_col}); advance(1); continue; }
            if (c == '/') { tokens.push_back({LexTokenType::Slash, "/", start_line, start_col}); advance(1); continue; }

            // Strings
            if (c == '"' || c == '\'') {
                char quote = c;
                advance(1);
                std::string s;
                while (pos_ < src_.length() && src_[pos_] != quote) {
                    if (src_[pos_] == '\\' && pos_ + 1 < src_.length()) {
                        advance(1);
                        s += src_[pos_];
                    } else {
                        s += src_[pos_];
                    }
                    advance(1);
                }
                advance(1);
                tokens.push_back({LexTokenType::StringLiteral, s, start_line, start_col});
                continue;
            }

            // Identifiers / Keywords
            if (std::isalpha(c) || c == '_' || c == '$') {
                std::string ident;
                while (pos_ < src_.length() && (std::isalnum(src_[pos_]) || src_[pos_] == '_' || src_[pos_] == '$' || src_[pos_] == '\\')) {
                    ident += src_[pos_];
                    advance(1);
                }

                LexTokenType kt = LexTokenType::Identifier;
                if (ident == "class") kt = LexTokenType::KwClass;
                else if (ident == "function") kt = LexTokenType::KwFunction;
                else if (ident == "async") kt = LexTokenType::KwAsync;
                else if (ident == "public") kt = LexTokenType::KwPublic;
                else if (ident == "private") kt = LexTokenType::KwPrivate;
                else if (ident == "protected") kt = LexTokenType::KwProtected;
                else if (ident == "return") kt = LexTokenType::KwReturn;
                else if (ident == "if") kt = LexTokenType::KwIf;
                else if (ident == "else") kt = LexTokenType::KwElse;
                else if (ident == "vec") kt = LexTokenType::KwVec;
                else if (ident == "dict") kt = LexTokenType::KwDict;
                else if (ident == "keyset") kt = LexTokenType::KwKeyset;

                tokens.push_back({kt, ident, start_line, start_col});
                continue;
            }

            // Numbers
            if (std::isdigit(c)) {
                std::string num;
                bool is_float = false;
                while (pos_ < src_.length() && (std::isdigit(src_[pos_]) || src_[pos_] == '.')) {
                    if (src_[pos_] == '.') is_float = true;
                    num += src_[pos_];
                    advance(1);
                }
                tokens.push_back({is_float ? LexTokenType::FloatLiteral : LexTokenType::IntLiteral, num, start_line, start_col});
                continue;
            }

            advance(1);
        }

        tokens.push_back({LexTokenType::Eof, "", line_, col_});
        return tokens;
    }

private:
    void advance(size_t n) {
        pos_ += n;
        col_ += static_cast<int>(n);
    }
};

} // namespace runtime
} // namespace axon
