package main

import "core:flags"
import "core:fmt"
import "core:os/os2"
import "core:strings"

Options :: struct {
    raw: bool `usage:"Do not pretty print the results or headers"`,
    command: string `args:"pos=0,required" usage:"Statement to be executed"`
}

main :: proc() {
    opt: Options
    flags.parse_or_exit(&opt, os2.args, .Odin)

    lexer := Lexer{
        buf = opt.command,
        allocator = context.allocator
    }

    tokens, lexer_err := lex(&lexer)
    if lexer_err != nil {
        fmt.eprintfln("Token error: %v\n", lexer_err)
        os2.exit(1)
    }
    defer delete(tokens)

    statement, err := parse_statement(&tokens)
    if err != nil {
        fmt.eprintfln("Parser error: %v\n", err)
        os2.exit(1)
    }

    // NOTE: This will not always be a select statement.
    select_statement := statement.(SelectStatement)
    available_columns := [?]string{
        "name",
        "inode",
        "size",
        "mode",
        "type",
        "creation_time",
        "modification_time",
        "access_time"
    }
    final_columns := make([dynamic]string)

    // Check to make sure each column in the select_statement is valid.
    for col in select_statement.columns {
        if col == "*" {
            for ac in available_columns {
                append(&final_columns, ac)
            }
        } else {
            valid := false
            for ac in available_columns {
                if ac == col {
                    valid = true
                    break;
                }
            }
            if valid {
                append(&final_columns, col)
            } else {
                fmt.eprintfln("Column \"%v\" not found in directory", col)
            }
        }
    }

    // Open the working directory
    f, open_err := os2.open(select_statement.directory)
    if open_err != nil {
        fmt.eprintfln("Could not open directory for reading %v\n", open_err)
        os2.exit(1)
    }
    defer os2.close(f)

    // Read the contents of the directory
    fis: []os2.File_Info
    defer os2.file_info_slice_delete(fis, context.allocator)
    read_err: os2.Error
    fis, read_err = os2.read_dir(f, -1, context.allocator) // -1 reads all file infos
    if read_err != nil {
        fmt.eprintfln("Could not read directory: %v\n", read_err)
        os2.exit(2)
    }

    // If we're not pretty printing, then just dump the results and exit.
    if opt.raw {
        for fi in fis {
            for col in final_columns {
                switch col {
                case "name": 
                    fmt.printf("%v ", fi.name)
                case "inode":
                    fmt.printf("%v ", fi.inode)
                case "size":
                    fmt.printf("%M ", fi.size)
                case "mode":
                    defer free_all(context.temp_allocator) // clean up `to_permission_string`
                    fmt.printf("%s ", to_permission_string(fi.mode))
                case "type":
                    fmt.printf("%v ", fi.type)
                case "creation_time":
                    fmt.printf("%v ", fi.creation_time)
                case "modification_time":
                    fmt.printf("%v ", fi.modification_time)
                case "access_time":
                    fmt.printf("%v ", fi.access_time)
                }
            }
            fmt.printf("\n")
        }
        os2.exit(0)
    }

    // Find the largest length for each column while printing the header.
    lengths := make(map[string]int)
    fmt.printf("|") // header start
    for col in final_columns {
        max_col_len: int = 0
        switch col {
        case "mode":
            max_col_len = 9
        case "inode":
            fallthrough
        case "size":
            fallthrough
        case "type":
            max_col_len = 32
        case "creation_time":
            fallthrough
        case "modification_time":
            fallthrough
        case "access_time":
            max_col_len = 39
        case "name":
            // For 'name', we have to loop through the results and calculate it.
            for fi in fis {
                max_col_len = max(max_col_len, len(fi.name))
            }
        }

        fmt.printf(" %-*s |", max_col_len, col)
        lengths[col] = max_col_len
    }

    // Print a spacer between the header and the directory results.
    fmt.println()
    fmt.printf("|")
    for col in final_columns {
        width := lengths[col]
        i := 0
        for i <= width {
            fmt.print("-")
            i += 1
        }
        fmt.print("-|")
    }
    fmt.println()

    // Pretty print the contents of the directory.
    for fi in fis {
        fmt.printf("|")
        for col in final_columns {
            switch col {
            case "name": 
                fmt.printf(" %-*v |", lengths[col], fi.name)
            case "inode":
                fmt.printf(" %- *v |", lengths[col], fi.inode)
            case "size":
                fmt.printf(" %- *M |", lengths[col], fi.size)
            case "mode":
                defer free_all(context.temp_allocator) // clean up `to_permission_string`
                fmt.printf(" %-*s |", lengths[col], to_permission_string(fi.mode))
            case "type":
                fmt.printf(" %-*v |", lengths[col], fi.type)
            case "creation_time":
                fmt.printf(" %-*v |", lengths[col], fi.creation_time)
            case "modification_time":
                fmt.printf(" %-*v |", lengths[col], fi.modification_time)
            case "access_time":
                fmt.printf(" %-*v |", lengths[col], fi.access_time)
            }
        }
        fmt.printf("\n")
    }
}

to_permission_string :: proc(permissions: os2.Permissions) -> string {
    builder: strings.Builder
    strings.builder_init(&builder, context.temp_allocator)

    // Owner permissions
    if os2.Permission_Flag.Read_User in permissions {
        strings.write_byte(&builder, 'r')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Write_User in permissions {
        strings.write_byte(&builder, 'w')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Execute_User in permissions {
        strings.write_byte(&builder, 'x')
    } else {
        strings.write_byte(&builder, '-')
    }

    // Group permissions
    if os2.Permission_Flag.Read_Group in permissions {
        strings.write_byte(&builder, 'r')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Write_Group in permissions {
        strings.write_byte(&builder, 'w')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Execute_Group in permissions {
        strings.write_byte(&builder, 'x')
    } else {
        strings.write_byte(&builder, '-')
    }

    // Other permissions
    if os2.Permission_Flag.Read_Other in permissions {
        strings.write_byte(&builder, 'r')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Write_Other in permissions {
        strings.write_byte(&builder, 'w')
    } else {
        strings.write_byte(&builder, '-')
    }
    if os2.Permission_Flag.Execute_Other in permissions {
        strings.write_byte(&builder, 'x')
    } else {
        strings.write_byte(&builder, '-')
    }

    return strings.to_string(builder)
}
