package main

import "core:mem"
import "core:strings"

Lexer :: struct {
    buf: string,
    pos: u64,
    allocator: mem.Allocator
}

Eof :: struct {}
Lparen :: struct {}
Rparen :: struct {}
Comma :: struct {}
Asterisk :: struct {}
Period :: struct {}
Select :: struct {}
From :: struct {}
Identifier :: struct {value: string}

Token :: union {
    Eof,
    Lparen,
    Rparen,
    Comma,
    Asterisk,
    Period,
    Select,
    From,
    Identifier
}

UnrecognizedToken :: struct {
    token: u8,
}

LexerError :: union {
    UnrecognizedToken
}

lex :: proc (lexer: ^Lexer) -> (tokens: [dynamic]Token, err: LexerError) {
    tokens = make([dynamic]Token, context.allocator)

    for {
        parse_whitespace(lexer)

        // Make sure we're not at the end of the input
        c, ok := peek(lexer)
        if !ok {
            append(&tokens, Eof{})
            break
        }

        // Lex single characters
        switch c {
        case '(':
            lexer.pos += 1
            append(&tokens, Lparen{})
            continue
        case ')':
            lexer.pos += 1
            append(&tokens, Rparen{})
            continue
        case ',':
            lexer.pos += 1
            append(&tokens, Comma{})
            continue
        case '*':
            lexer.pos += 1
            append(&tokens, Asterisk{})
            continue
        case '.':
            lexer.pos += 1
            append(&tokens, Period{})
            continue
        }

        if is_identifier_start(c) {
            // Extract the identifier
            start := lexer.pos
            for lexer.pos < u64(len(lexer.buf)) {
                c := lexer.buf[lexer.pos]
                if !is_alphanumeric(c) && c != '.' && c != '_' && c != '-' && c != '/' {
                    break
                }
                lexer.pos += 1
            }

            // Check if the identifier is a keyword
            identifier := lexer.buf[start:lexer.pos]
            if strings.equal_fold(identifier, "SELECT") {
                append(&tokens, Select{})
                continue
            } else if strings.equal_fold(identifier, "FROM") {
                append(&tokens, From{})
                continue
            }

            append(&tokens, Identifier{ value = identifier })
            continue
        }

        return nil, UnrecognizedToken{ token = c }
    }

    return tokens, nil
}

// Returns the next token from the input stream and a flag
// indicating there are more tokens in the stream.
peek :: proc (lexer: ^Lexer) -> (u8, b8) {
    if lexer.pos >= u64(len(lexer.buf)) {
        return 0, false
    }

    return lexer.buf[lexer.pos], true
}

is_alphanumeric :: proc (c: u8) -> b8 {
    return (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9')
}

is_identifier_start :: proc (c: u8) -> b8 {
    return is_alphanumeric(c) || c == '_' || c == '-' || c == '/'
}

is_whitespace :: proc (c: u8) -> b8 {
    return c == ' '
}

parse_whitespace :: proc (lexer: ^Lexer) {
    for {
        if c, ok := peek(lexer); ok && is_whitespace(c) {
            lexer.pos += 1
        } else {
            break
        }
    }
}
