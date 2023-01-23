local inspect = require "inspect"

local interpreter = {}

local ctx = {}

local function maketype(name, subtypes)
    if subtypes == nil then subtypes = {} end
    return { _title = "type", name = name, subtypes = subtypes }
end

local function makemocktype(name, subtraits)
    if subtraits == nil then subtraits = {} end
    return { _title = "mocktype", name = name, subtraits = subtraits }
end

local function fits_mocktype(type, mocktype)
    if type.name ~= mocktype.name then return false end
    return true
end

function ctx:types_match(inner, outer)
    local function types_match(inner, outer)
        if inner._title ~= outer._title then return false end
        if inner.name ~= outer.name then return false end
        if #inner.subtypes ~= #outer.subtypes then return false end
        for i = 1, #inner.subtypes do
            if not types_match(inner.subtypes[i],
              outer.subtypes[i]) then
                return false
            end
        end
        return true
    end

    return types_match(inner.type, outer.type)
end

function ctx:scope_in()
    table.insert(ctx.locals, {})
end

function ctx:scope_out()
    ctx.locals[#ctx.locals] = nil
end

function ctx:new_variable(name, value, type)
    if ctx.locals[#ctx.locals][name] then
        return nil, "identifier already in locals" end
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

    for _, mocktype in ipairs({
        makemocktype("i8"),
        makemocktype("i16"),
        makemocktype("i32"),
        makemocktype("i64"),
        makemocktype("i128"),
        makemocktype("isize"),
        makemocktype("u8"),
        makemocktype("u16"),
        makemocktype("u32"),
        makemocktype("u64"),
        makemocktype("u128"),
        makemocktype("usize"),
        makemocktype("f32"),
        makemocktype("f64"),
        makemocktype("bool"),
        makemocktype("char"),
        makemocktype("fn"),
        makemocktype("closure"),
        makemocktype("String"),
        makemocktype("Array", {{}}),
        makemocktype("Vector", {{}}),
        makemocktype("Option", {{}}),
        makemocktype("Result", {{}, {}}),
    }) do table.insert(ctx.types, mocktype) end

    ctx:scope_in()
    for _, statement in ipairs(tree) do
        if statement._title == "enum" then
            table.insert(ctx.types, statement.mocktype)
            ctx.namespaces[statement.mocktype.name.id] = {}
            for _, field in ipairs(statement.fields) do
                if #field.types > 0 then
                    ctx.namespaces
                        [statement.mocktype.name.id]
                        [field.name.id] = {
                            _title = "enum_constructor",
                            mocktype = field.mocktype,
                            name = field.name,
                            types = field.types,
                        }
                else
                    ctx.namespaces
                        [statement.mocktype.name.id]
                        [field.name.id] = {
                            _title = "enum_field",
                            mocktype = field.mocktype,
                            name = field.name,
                        }
                end
            end
        end

        if statement._title == "struct" then
            local _, err = ctx:new_variable(statement.mocktype.name.id,
                statement)
            if err ~= nil then return nil, err end
        end

        if statement._title == "function" then
            local paramtypes = {}
            for _, parameter in ipairs(statement.parameters) do
                local has_type = false
                for _, type in ipairs(ctx.types) do
                    if fits_mocktype(parameter.type, type) then
                        has_type = true
                        break
                    end
                end
                if not has_type then return nil, "type does not exist" end
                table.insert(paramtypes, parameter.type)
            end
            table.insert(paramtypes, statement.returntype)
            local _, err = ctx:new_variable(statement.name.id, statement,
                maketype("fn", paramtypes))
            if err ~= nil then return nil, err end
        end
    end

    for _, statement in ipairs(tree) do
        if statement._title == "function" and statement.name.id == "main" then
            local value, err = ctx:walk_function(statement, {})
            if err then return nil, err end
            -- for testing purposes
            if value then
                print(inspect(value.value))
            else
                print("No output value")
            end
            break
        end
    end
    ctx:scope_out()
end

function ctx:walk_enum_constructor_call(node, parameters)
    node.value.args = {}
    if #parameters < #node.value.types then
        return nil, "enum constructor has too few arguments" end
    if #parameters > #node.value.types then
        return nil, "enum constructor has too many arguments" end
    for i, param in ipairs(parameters) do
        local expr, err = self:walk_expr(param)
        if err ~= nil then return nil, err end
        -- if not self:types_match(expr.type, node.value.types[i]) then
        --     return nil, "enum constructor types do not match" end
        table.insert(node.value.args, expr)
    end
    return node
end

function ctx:walk_closure_call(node, parameters)
    self:scope_in()
    for i = 1, #parameters do
        local param = self:walk_expr(parameters[i])
        local _, err = self:new_variable(node.parameters[i].name.id,
            param.value, param.type)
        if err ~= nil then return nil, err end
    end

    local value, err = self:walk_expr(node.expr)
    self:scope_out()
    return value, err
end

function ctx:walk_function(node, parameters)
    self:scope_in()
    for i = 1, #parameters do
        local param, err = self:walk_expr(parameters[i])
        if err ~= nil then return nil, err end
        -- check if parameter type matches argument type
        if not self:types_match(param, node.parameters[i]) then
            return nil, "parameter and argument types do not match"
        end
        -- load parameter to locals
        local _, err = self:new_variable(node.parameters[i].name.id,
            param.value, param.type)
        if err ~= nil then return nil, err end
    end

    local value, err = ctx:walk_block(node.block)
    self:scope_out()
    return value, err
end

function ctx:walk_block(node)
    for i = 1, #node.statements do
        local value, err = self:walk_statement(node.statements[i])
        if err ~= nil then return nil, err end
    end
    if node.expr then return self:walk_expr(node.expr) end
end

function ctx:walk_statement(node)
    return ctx:walk_let(node)
end

function ctx:walk_let(node)
    if node._title ~= "let" then return self:walk_expr(node) end
    local expr, err = self:walk_expr(node.expr)
    if err ~= nil then return nil, err end
    local _, err = self:new_variable(node.lvalue.id, expr.value, expr.type)
    if err ~= nil then return nil, err end
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
    return self:value(node, maketype("closure", paramtypes))
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
    if node._title ~= "neg" then return self:walk_dot(node) end
    local value = self:walk_expr(node.value)
    return self:value(-value.value, value.type)
end

function ctx:walk_dot(node)
    if node._title ~= "dot" then return self:walk_scoper(node) end
    if node.postdot._title == "call" then -- dot function chain
        node.postdot.args = { node.source, table.unpack(node.postdot.args) }
        local called, err = self:walk_call(node.postdot)
        if err ~= nil then return nil, err end
        return called
    end
    local source, err = self:walk_expr(node.source)
    if err ~= nil then return nil, err end
    if source.value and source.value.fields then -- struct accessing
        return source.value.fields[node.postdot.id]
    end
    return nil, "misuse of dot operator"
end

function ctx:walk_scoper(node)
    if node._title ~= "scoper" then return self:walk_call(node) end
    -- expand for multi-level scopes
    return self:walk_expr(self.namespaces[node.scope.id][node.member.id])
end

function ctx:walk_call(node)
    if node._title ~= "call" then return self:walk_index(node) end
    local called, err = self:walk_expr(node.called)
    if err ~= nil then return nil, err end
    if called.type.name == "fn" then
        return self:walk_function(called.value, node.args) end
    if called.type.name == "closure" then
        return self:walk_closure_call(called.value, node.args) end
    if called.value._title == "enum_constructor" then
        return self:walk_enum_constructor_call(called, node.args) end
    return nil, "value cannot be called"
end

function ctx:walk_index(node)
    if node._title ~= "index" then return self:walk_enum_constructor(node) end
    local indexed, err = self:walk_expr(node.indexed)
    return indexed.value[tonumber(self:walk_expr(node.arg).value)]
end

function ctx:walk_enum_constructor(node)
    if node._title ~= "enum_constructor" then
        return self:walk_enum_field(node) end
    return self:value(node, maketype(node.mocktype.name.id))
end

function ctx:walk_enum_field(node)
    if node._title ~= "enum_field" then return self:walk_constructor(node) end
    return self:value(node, maketype(node.mocktype.name.id))
end

function ctx:walk_constructor(node)
    if node._title ~= "constructor" then return self:walk_bool(node) end
    local struct, err = self:walk_var(node.struct)
    if err ~= nil then return nil, err end
    local fields = {}

    for i, field in ipairs(node.fields) do
        if field.name.id ~= struct.value.fields[i].name.id then
            return nil, "constructor field name does not match with struct"
        end
        local expr, err = self:walk_expr(field.value)
        if err ~= nil then return nil, err end
        if not self:types_match(expr, struct.value.fields[i]) then
            return nil, "constructor field type does not match with struct"
        end

        fields[field.name.id] = expr
    end

    return self:value({ name = struct.value.mocktype.name.id,
        fields = fields },
            maketype(struct.value.mocktype.name.id))
end

function ctx:walk_bool(node)
    if not node._title == "id" then return self:walk_var(node) end
    if node.id == "true" then
        return self:value(true, maketype("bool")) end
    if node.id == "false" then
        return self:value(false, maketype("bool")) end
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
    return self:value(tonumber(node.num), maketype("i32"))
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
    local first
    for i = 1, #node.items do
        local result = self:walk_expr(node.items[i])
        elements[i - 1] = result.value
        if first and not self:types_match(first, result) then
            return nil, "literal array types do not match"
        end
        if not first then first = result end
    end
    return self:value(elements, maketype("Array", { type }))
end

return interpreter