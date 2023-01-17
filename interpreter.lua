local inspect = require "inspect"

local interpreter = {}

local ctx = {}

function ctx:scope_in()
    table.insert(ctx.locals, {})
end

function ctx:scope_out()
    ctx.locals[#ctx.locals] = nil
end

function ctx:new_variable(name, value, type)
    ctx.locals[#ctx.locals][name] = { value = value, type = type }
end

function ctx:get_variable_value(name)
    for scope = #ctx.locals, 1, -1 do
        if ctx.locals[scope][name] then
            return ctx.locals[scope][name]
        end
    end
end

function ctx:value(value, type)
    return { value = value, type = type }
end

function interpreter.interpret(tree)
    ctx.tree = tree
    ctx.namespaces = {}
    ctx.locals = {}

    for i = 1, #tree do
        if tree[i].a == "function" and tree[i].name.id == "main" then
            ctx:walk_function(tree[i], {})
            break
        end
    end
end

function ctx:walk_function(node, parameters)
    self:scope_in()
    local value = ctx:walk_expr(node.block.expr)
    print(inspect(value))
    self:scope_out()
    return value
end

function ctx:walk_expr(node)
    return ctx:walk_string(node)
end

function ctx:walk_string(node)
    if node.a ~= "str" then return nil end
    return self:value(node.str, { a = "type", name = "String", subtypes = {} })
end

return interpreter