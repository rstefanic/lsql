package main

import "core:mem"

// The parser returns a statement.
Statement :: union {
    SelectStatement
}
SelectStatement :: struct {
    allocator: mem.Allocator,
    columns: [dynamic]string,   // list of results
    directory: string           // name of directory to run on
}

// Error values the parser can return.
ParserError :: union {
    UnexpectedToken
}
UnexpectedToken :: struct {
    expected: string,
    actual: Token
}

parse_statement :: proc (tokens: ^[dynamic]Token) -> (Statement, ParserError) {
    pos: u64 = 0 // token position

    // Parse SELECT keyword
    if actual, ok := tokens[pos].(Select); !ok {
        return nil, UnexpectedToken {
            expected = "SELECT",
            actual = tokens[pos]
        }
    }
    pos += 1

    // Parse Identifier list
    columns := make([dynamic]string)
    for {
        // Try to first parse an asterisk
        if asterisk, ok := tokens[pos].(Asterisk); ok {
            append(&columns, "*")
        } else if identifier, ok := tokens[pos].(Identifier); ok {
            append(&columns, identifier.value)
        } else {
            return nil, UnexpectedToken{
                expected = "* or Identifier",
                actual = tokens[pos]
            }
        }
        pos += 1

        // If the next token is a comma, continue parsing the identifiers;
        // otherwise move onto the next part of the statement.
        if _, ok := tokens[pos].(Comma); !ok {
            break
        }
        pos += 1
    }

    // Parse FROM keyword
    if _, ok := tokens[pos].(From); !ok {
        return nil, UnexpectedToken {
            expected = "FROM",
            actual = tokens[pos]
        }
    }
    pos += 1


    // Parse directory
    directory := "."
    if _, ok := tokens[pos].(Period); ok {
        // This is our default value; Ok!
    } else if identifier, ok := tokens[pos].(Identifier); ok {
        directory = identifier.value
    } else {
        return nil, UnexpectedToken {
            expected = "Identifier (directory)",
            actual = tokens[pos]
        }
    }

    return SelectStatement{
        allocator = context.allocator,
        columns = columns,
        directory = directory
    }, nil
}
