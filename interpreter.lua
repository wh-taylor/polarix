local inspect = require "inspect"

local interpreter = {}

local ctx = {}

local function maketype(name, subtypes)
    if subtypes == nil then subtypes = {} end
    return { _title = "type", name = name, subtypes = subtypes }
end

local function types_match(type1, type2)
    if type1._title ~= type2._title then return false end
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
    ctx.types = {}

    ctx:scope_in()
    for i = 1, #tree do
        if tree[i]._title == "enum" then
            table.insert(ctx.types, tree[i].mocktype)
            ctx.namespaces[tree[i].mocktype.name.id] = {}
            for j = 1, #tree[i].fields do
                ctx.namespaces
                    [tree[i].mocktype.name.id]
                    [tree[i].fields[j].name.id] = tree[i].fields[j]
            end
        end

        if tree[i]._title == "function" then
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
        if tree[i]._title == "function" and tree[i].name.id == "main" then
            local value, err = ctx:walk_function(tree[i], {})
            if err then return nil, err end
            -- for testing purposes
            if value then
                print(value.value)
            else
                print("No output value")
            end
            break
        end
    end
    ctx:scope_out()
end

function ctx:walk_closure_call(node, parameters)
    self:scope_in()
    for i = 1, #parameters do
        local param = self:walk_expr(parameters[i])
        self:new_variable(node.parameters[i].name.id, param.value, param.type)
    end

    local value, err = self:walk_expr(node.expr)
    self:scope_out()
    return value, err
end

function ctx:walk_function(node, parameters)
    self:scope_in()
    for i = 1, #parameters do
        local param = self:walk_expr(parameters[i])
        -- check if parameter type matches argument type
        if not types_match(node.parameters[i].type, param.type) then
            return nil, "parameter and argument types do not match"
        end
        -- load parameter to locals
        self:new_variable(node.parameters[i].name.id, param.value, param.type)
    end

    local value, err = ctx:walk_block(node.block)
    self:scope_out()
    return value, err
end

function ctx:walk_block(node)
    for i = 1, #node.statements do
        local value, err = self:walk_statement(node.statements[i])
    end
    if node.expr then return self:walk_expr(node.expr) end
end

function ctx:walk_statement(node)
    return ctx:walk_let(node)
end

function ctx:walk_let(node)
    if node._title ~= "let" then return self:walk_expr(node) end
    local expr = self:walk_expr(node.expr)
    self:new_variable(node.lvalue.id, expr.value, expr.type)
end

function ctx:walk_expr(node)
    return ctx:walk_closure(node)
end

function ctx:walk_closure(node)
    if node._title ~= "closure" then return self:walk_try(node) end
    local paramtypes = {}
    for i = 1, #node.parameters do
        table.insert(paramtypes, node.parameters[i].type)
    end
    return self:value(node, maketype("Closure", paramtypes))
end

function ctx:walk_try(node)
    if node._title ~= "try" then return self:walk_catch(node) end
    -- need to implement Result first
    return nil
end

function ctx:walk_catch(node)
    if node._title ~= "catch" then return self:walk_or(node) end
    -- need to implement Result first
    return nil
end

function ctx:walk_or(node)
    if node._title ~= "or" then return self:walk_and(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value or right.value, maketype("boolean"))
end

function ctx:walk_and(node)
    if node._title ~= "and" then return self:walk_not(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value and right.value, maketype("boolean"))
end

function ctx:walk_not(node)
    if node._title ~= "not" then return self:walk_gt(node) end
    local value = self:walk_expr(node.value)
    return self:value(not value.value, maketype("boolean"))
end

function ctx:walk_gt(node)
    if node._title ~= "gt" then return self:walk_lt(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value > right.value, maketype("boolean"))
end

function ctx:walk_lt(node)
    if node._title ~= "lt" then return self:walk_gteq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value < right.value, maketype("boolean"))
end

function ctx:walk_gteq(node)
    if node._title ~= "gteq" then return self:walk_lteq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value >= right.value, maketype("boolean"))
end

function ctx:walk_lteq(node)
    if node._title ~= "lteq" then return self:walk_eq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value <= right.value, maketype("boolean"))
end

function ctx:walk_eq(node)
    if node._title ~= "eq" then return self:walk_neq(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value == right.value, maketype("boolean"))
end

function ctx:walk_neq(node)
    if node._title ~= "neq" then return self:walk_mod(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value ~= right.value, maketype("boolean"))
end

function ctx:walk_mod(node)
    if node._title ~= "mod" then return self:walk_div(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(math.fmod(left.value, right.value), left.type)
end

function ctx:walk_div(node)
    if node._title ~= "div" then return self:walk_mult(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value / right.value, left.type)
end

function ctx:walk_mult(node)
    if node._title ~= "mult" then return self:walk_sub(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value * right.value, left.type)
end

function ctx:walk_sub(node)
    if node._title ~= "sub" then return self:walk_add(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value - right.value, left.type)
end

function ctx:walk_add(node)
    if node._title ~= "add" then return self:walk_exp(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value + right.value, left.type)
end

function ctx:walk_exp(node)
    if node._title ~= "exp" then return self:walk_neg(node) end
    local left = self:walk_expr(node.left)
    local right = self:walk_expr(node.right)
    return self:value(left.value ^ right.value, left.type)
end

function ctx:walk_neg(node)
    if node._title ~= "neg" then return self:walk_scoper(node) end
    local value = self:walk_expr(node.value)
    return self:value(-value.value, value.type)
end

function ctx:walk_scoper(node)
    if node._title ~= "scoper" then return self:walk_call(node) end
    -- NEEDS TESTING
    local function scoper(node, scope)
        if node.member._title == "scoper" then
            return scoper(node.member, scope[node.scope.id])
        end
        return scope[node.member.id]
    end

    return self:walk_expr(scoper(node, self.namespaces[node.scope.id]))
end

function ctx:walk_call(node)
    if node._title ~= "call" then return self:walk_index(node) end
    local called, err = self:walk_expr(node.called)
    if called.type.name == "Fn" then
        return self:walk_function(called.value, node.args) end
    if called.type.name == "Closure" then
        return self:walk_closure_call(called.value, node.args) end
end

function ctx:walk_index(node)
    if node._title ~= "index" then return self:walk_bool(node) end
    local indexed, err = self:walk_expr(node.indexed)
    return indexed.value[tonumber(self:walk_expr(node.arg).value)]
end

function ctx:walk_bool(node)
    if not node._title == "id" then return self:walk_var(node) end
    if node.id == "true" then
        return self:value(true, maketype("boolean")) end
    if node.id == "false" then
        return self:value(false, maketype("boolean")) end
    return self:walk_var(node)
end

function ctx:walk_var(node)
    if node._title ~= "id" then return self:walk_num(node) end
    local var, err = self:get_var(node.id)
    if err then return nil, err end
    return self:value(var.value, var.type)
end

function ctx:walk_num(node)
    if node._title ~= "num" then return self:walk_string(node) end
    return self:value(tonumber(node.num), maketype("Num"))
end

function ctx:walk_string(node)
    if node._title ~= "str" then return self:walk_char(node) end
    return self:value(node.str, maketype("String"))
end

function ctx:walk_char(node)
    if node._title ~= "char" then return self:walk_array(node) end
    return self:value(node.char, maketype("char"))
end

function ctx:walk_array(node)
    if node._title ~= "array" then return nil end
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