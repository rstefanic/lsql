# lsql

Small test to see how ergonomic it would be to query a directory using SQL.

The name comes from combining `ls` and `sql`.

## Usage

```
lsql command [-raw]
Flags:
        -command:<string>, required  | Statement to be executed
                                     |
        -raw                         | Do not pretty print the results or headers
```

#### Fields Available

- name
- inode
- size
- mode
- type
- creation_time
- modification_time
- access_time

## Examples

Query a directory

```shell
# Query the current directory
lsql "SELECT * FROM ."

# Query the temp directory
lsql "SELECT * FROM /tmp"
```

Just return the name of the files in the current directory if you're in this repo.

```
lsql "SELECT name FROM ."

| name        |
|-------------|
| main.odin   |
| lexer.odin  |
| .envrc      |
| flake.lock  |
| lsql        |
| README.md   |
| parser.odin |
| .gitignore  |
| flake.nix   |
| .git        |
| .direnv     |
```
