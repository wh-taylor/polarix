local lexer = require "lexer"
local parser = require "parser"

function read_file(file)
    local f = io.open(file, "rb")
    if f == nil then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

function run(file_name)
    local code = read_file(file_name)
    if code == nil then return nil end

    local tokens = lexer.lex(file_name, code)

    local tree, err = parser.parse(tokens)
    if err ~= nil then print("polarix: " .. err.context.tokens[err.context.index].file_name .. ":" .. err.context.tokens[err.context.index].line .. ":" .. err.context.tokens[err.context.index].col .. ": " .. err.name .. ", found '" .. err.context.tokens[err.context.index].value .. "'") end
end

function main()
    if arg[1] == nil then
        print("File name must be provided")
        return
    end

    run(arg[1])
end

main()

