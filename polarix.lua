local lexer = require "lexer"
local parser = require "parser"
local interpreter = require "interpreter"

local inspect = require "inspect"

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

    local tokens, err = lexer.lex(file_name, code)
    if err ~= nil then
        print("polarix: "
            .. err.ctx.file_name
            .. ":" .. err.ctx.line
            .. ":" .. err.ctx.col
            .. ": " .. err.err)
        return
    end

    local tree, err = parser.parse(tokens)
    if err ~= nil then
        print("polarix: "
            .. err.ctx.tokens[err.ctx.index].file_name
            .. ":" .. err.ctx.tokens[err.ctx.index].line
            .. ":" .. err.ctx.tokens[err.ctx.index].col
            .. ": " .. err.err .. ", found '"
            .. err.ctx.tokens[err.ctx.index].value .. "'")
        return
    end

    local value, err = interpreter.interpret(tree)
    if err ~= nil then
        print("polarix: " .. err)
    end
end

function main()
    if arg[1] == nil then
        print("File name must be provided")
        return
    end

    run(arg[1])
end

main()
