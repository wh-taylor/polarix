local inspect = require "inspect"

local interpreter = {}

local ctx = {}

local function maketype(name, subtypes)
    if subtypes == nil then subtypes = {} end
    return { a = "type", name = name, subtypes = subtypes }
end

local function types_match(type1, type2)
    if type1.a ~= type2.a then return false end
    if type1.name ~= type2.name then return false end
    if #type1.subtypes ~= #type2.subtypes then return false end
    for i = 1, #type1.subtypes do
        if not types_match(type1.subtypes[i], type2.subtypes[i]) then
            return false
        end
    end
    return true
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

    ctx:scope_in()
    for i = 1, #tree do
        if tree[i].a == "function" then
            local paramtypes = {}
            for j = 1, #tree[i].parameters do
                table.insert(paramtypes, tree[i].parameters[j].type)
            end
            table.insert(paramtypes, tree[i].returntype)
            ctx:new_variable(tree[i].name.id, tree[i],
                maketype("Fn", paramtypes))
        end
    end

    for i = 1, #tree do
        if tree[i].a == "function" and tree[i].name.id == "main" then
            local value, err = ctx:walk_function(tree[i], {})
            if err then return nil, err end
            break
        end
    end
    ctx:scope_out()
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
    if node.a ~= "char" then return self:walk_array(node) end
    return self:value(node.char, { a = "type", name = "char", subtypes = {} })
end

function ctx:walk_array(node)
    if node.a ~= "array" then return nil end
    local elements = {}
    local type
    for i = 1, #node.items do
        local result = self:walk_expr(node.items[i])
        elements[i - 1] = result.value
        if type and not types_match(type, result.type) then
            return nil, "literal array types do not match"
        end
        if not type then type = result.type end
    end
    return self:value(elements, maketype("Array", { type }))
end

return interpreter