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
            print(inspect(value)) -- for testing purposes
            if err then return nil, err end
            break
        end
    end
    ctx:scope_out()
end

function ctx:walk_function(node, parameters)
    self:scope_in()
    for i = 1, #parameters do
        local param = self:walk_expr(parameters[i])
        self:new_variable(node.parameters[i].name.id, param.value, param.type)
    end

    local value, err = ctx:walk_expr(node.block.expr)
    self:scope_out()
    return value, err
end

function ctx:walk_expr(node)
    return ctx:walk_not(node)
end

function ctx:walk_not(node)
    if node.a ~= "not" then return self:walk_gt(node) end
    local value = self:walk_expr(node.value)
    return self:value(not value.value, maketype("boolean", {}))
end

function ctx:walk_gt(node)
    if node.a ~= "gt" then return self:walk_lt(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value > right.value, maketype("boolean", {}))
end

function ctx:walk_lt(node)
    if node.a ~= "lt" then return self:walk_gteq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value < right.value, maketype("boolean", {}))
end

function ctx:walk_gteq(node)
    if node.a ~= "gteq" then return self:walk_lteq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value >= right.value, maketype("boolean", {}))
end

function ctx:walk_lteq(node)
    if node.a ~= "lteq" then return self:walk_eq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value <= right.value, maketype("boolean", {}))
end

function ctx:walk_eq(node)
    if node.a ~= "eq" then return self:walk_neq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value == right.value, maketype("boolean", {}))
end

function ctx:walk_neq(node)
    if node.a ~= "neq" then return self:walk_mod(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value ~= right.value, maketype("boolean", {}))
end

function ctx:walk_mod(node)
    if node.a ~= "mod" then return self:walk_div(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(math.fmod(left.value, right.value), left.type)
end

function ctx:walk_div(node)
    if node.a ~= "div" then return self:walk_mult(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value / right.value, left.type)
end

function ctx:walk_mult(node)
    if node.a ~= "mult" then return self:walk_sub(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value * right.value, left.type)
end

function ctx:walk_sub(node)
    if node.a ~= "sub" then return self:walk_add(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value - right.value, left.type)
end

function ctx:walk_add(node)
    if node.a ~= "add" then return self:walk_exp(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value + right.value, left.type)
end

function ctx:walk_exp(node)
    if node.a ~= "exp" then return self:walk_neg(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value ^ right.value, left.type)
end

function ctx:walk_neg(node)
    if node.a ~= "neg" then return self:walk_call(node) end
    local value = self:walk_expr(node.value)
    return self:value(-value.value, value.type)
end

function ctx:walk_call(node)
    if node.a ~= "call" then return self:walk_index(node) end
    local called, err = self:walk_expr(node.called)
    return self:walk_function(called.value, node.args)
end

function ctx:walk_index(node)
    if node.a ~= "index" then return self:walk_var(node) end
    local indexed, err = self:walk_expr(node.indexed)
    return indexed.value[tonumber(self:walk_expr(node.arg).value)]
end

function ctx:walk_var(node)
    if node.a ~= "id" then return self:walk_num(node) end
    local var, err = self:get_var(node.id)
    if err then return nil, err end
    return self:value(var.value, var.type)
end

function ctx:walk_num(node)
    if node.a ~= "num" then return self:walk_string(node) end
    return self:value(tonumber(node.num), maketype("Num"))
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