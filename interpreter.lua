local inspect = require "inspect"

local interpreter = {}

local ctx = {}

local function maketype(name, subtypes)
    if subtypes == nil then subtypes = {} end
    return { a = "type", name = name, subtypes = subtypes }
end

function ctx:scope_in()
    table.insert(ctx.locals, {})
end

function ctx:scope_out()
    ctx.locals[#ctx.locals] = nil
end

function ctx:new_variable(name, value, type)
    ctx.locals[#ctx.locals][name] = { value = value, type = type }
end

function ctx:get_var(name)
    for scope = #ctx.locals, 1, -1 do
        if ctx.locals[scope][name] then
            return ctx.locals[scope][name]
        end
    end
    return nil, "variable has not been initialized"
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
            local value, err = ctx:walk_function(tree[i], {})
            if err then return nil, err end
            break
        end
    end
end

function ctx:walk_function(node, parameters)
    self:scope_in()
    local value, err = ctx:walk_expr(node.block.expr)
    print(inspect(value))
    self:scope_out()
    return value, err
end

function ctx:walk_expr(node)
    return ctx:walk_var(node)
end

function ctx:walk_var(node)
    if node.a ~= "id" then return self:walk_num(node) end
    local var, err = self:get_var(node.id)
    if err then return nil, err end
    return self:value(var.value, var.type)
end

function ctx:walk_num(node)
    if node.a ~= "num" then return self:walk_string(node) end
    return self:value(node.num, maketype("Num"))
end

function ctx:walk_string(node)
    if node.a ~= "str" then return self:walk_char(node) end
    return self:value(node.str, { a = "type", name = "String", subtypes = {} })
end

function ctx:walk_char(node)
    if node.a ~= "char" then return nil end
    return self:value(node.char, { a = "type", name = "char", subtypes = {} })
end

return interpreter