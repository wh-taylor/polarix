local parser = {}

local ctx = {
    tokens = nil,
    index = nil,
}

local function is_one_of(self, values)
    for i = 1, #values do
        if self == values[i] then return true end
    end
end

function parser.parse(tokens)
    ctx.tokens = tokens
    ctx.index = 1

    local tree = {}
    while not ctx:match("eof", "eof") do
        local func, err = ctx:parse_import()
        if err ~= nil then return nil, err end
        table.insert(tree, func)
    end
    return tree
end

-- import ::= 'import' IDENTIFIER ';'
function ctx:parse_import()
    if not self:match("word", "import") then return self:parse_trait() end
    self:next()
    local imported, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    if not self:match("op", ";") then return self:err("expected ';'") end
    self:next()
    return { a = "import", imported = imported }
end

-- trait ::= 'trait' mocktype '{' ((function_header | type_header) ';'), '}'
function ctx:parse_trait()
    if not self:match("word", "trait") then return self:parse_instance() end
    self:next()
    local trait, err = self:parse_mocktype()
    if err ~= nil then return nil, err end

    if self:match("op", ";") then
        self:next()
        return { a = "trait", trait = trait }
    end

    if not self:match("op", "{") then
        return self:err("expected '{' or ';'")
    end
    self:next()

    local fields = {}
    while not self:match("op", "}") do
        local field, err
        if self:match("word", "fn") then
            field, err = self:parse_function_header()
            if err ~= nil then return nil, err end
        elseif self:match("word", "type") then
            field, err = self:parse_typedef_header()
            if err ~= nil then return nil, err end
        else
            return self:err("expected 'fn' or 'type'")
        end
        table.insert(fields, field)
        if not self:match("op", ";") then self:err("expected ';'") end
        self:next()
    end
    self:next()
    return { a = "trait", trait = trait, fields = fields }
end

-- instance ::= 'instance' mocktype type '{' (function | typedef)* '}'
function ctx:parse_instance()
    if not self:match("word", "instance") then return self:parse_enum() end
    self:next()
    local trait, err = self:parse_mocktype()
    if err ~= nil then return nil, err end
    local type, err = self:parse_type()
    if err ~= nil then return nil, err end

    if self:match("op", ";") then
        self:next()
        return { a = "instance", trait = trait, type = type }
    end

    if not self:match("op", "{") then
        return self:err("expected '{' or ';'")
    end
    self:next()

    local fields = {}
    while not self:match("op", "}") do
        local field, err
        if self:match("word", "fn") then
            field, err = self:parse_function()
            if err ~= nil then return nil, err end
        elseif self:match("word", "type") then
            field, err = self:parse_typedef()
            if err ~= nil then return nil, err end
        else
            return self:err("expected 'fn' or 'type'")
        end
        table.insert(fields, field)
    end
    self:next()
    return { a = "instance", trait = trait, type = type, fields = fields }
end

-- enum ::= 'enum' type_def '{' enum_field, '}'
function ctx:parse_enum()
    if not self:match("word", "enum") then return self:parse_struct() end
    self:next()
    local mocktype, err = self:parse_mocktype()
    if err ~= nil then return nil, err end

    if not self:match("op", "{") then return self:err("expected '{'") end
    self:next()

    local fields = {}
    while not self:match("op", "}") do
        table.insert(fields, self:parse_enum_field())
        if not (self:match("op", "}") or self:match("op", ",")) then
            return self:err("expected '}' or ','") end
        if self:match("op", ",") then self:next() end
    end
    self:next()
    if #fields == 0 then
        return self:err("expected at least one enum field") end
    return { a = "enum", mocktype = mocktype, fields = fields }
end

-- enum_field ::= IDENTIFIER ('(' type, ')')?
function ctx:parse_enum_field()
    local name, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    local types = {}
    if self:match("op", "(") then
        self:next()
        while not self:match("op", ")") do
            table.insert(types, self:parse_type())
            if not (self:match("op", ")") or self:match("op", ",")) then
                return self:err("expected ')' or ','") end
            if self:match("op", ",") then self:next() end
        end
        self:next()
        if #types == 0 then return self:err("expected type") end
    end
    return { a = "enum_field", name = name, types = types }
end

-- struct ::= 'struct' mocktype ('{' field, '}' | ';')
function ctx:parse_struct()
    if not self:match("word", "struct") then return self:parse_function() end
    self:next()
    local mocktype, err = self:parse_mocktype()
    if err ~= nil then return nil, err end

    if self:match("op", ";") then
        self:next()
        return { a = "struct", mocktype = mocktype }
    end

    if not self:match("op", "{") then
        return self:err("expected '{' or ';'")
    end
    self:next()

    local fields = {}
    while not self:match("op", "}") do
        table.insert(fields, self:parse_field())
        if not (self:match("op", "}") or self:match("op", ",")) then
            return self:err("expected '}' or ','") end
        if self:match("op", ",") then self:next() end
    end
    self:next()
    return { a = "struct", mocktype = mocktype, fields = fields }
end

-- mocktype ::= IDENTIFIER ('<' IDENTIFIER, '>')?
function ctx:parse_mocktype()
    local name, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    local subtypes = {}
    if self:match("op", "<") then
        self:next()
        while not self:match("op", ">") do
            table.insert(subtypes, self:parse_identifier())
            if not (self:match("op", ">") or self:match("op", ",")) then
                return self:err("expected '>' or ','") end
            if self:match("op", ",") then self:next() end
        end
        self:next()
    end
    return { a = "mocktype", name = name, subtypes = subtypes }
end

-- function ::= function_header (block | '=' expr ';')
function ctx:parse_function()
    local function_header, err = self:parse_function_header()
    if err ~= nil then return nil, err end
    local block, err
    if self:match("op", "{") then
        block, err = self:parse_block()
        if err ~= nil then return nil, err end
    elseif self:match("op", "=") then
        self:next()
        local expr, err = self:parse_expr()
        if err ~= nil then return nil, err end
        block = { a = "block", statements = {}, expr = expr }
        if not self:match("op", ";") then return self:err("expected ';'") end
        self:next()
    end
    return {
        a = "function",
        name = function_header.name,
        parameters = function_header.parameters,
        returntype = function_header.returntype,
        block = block
    }
end

-- function_header ::= 'fn' IDENTIFIER '(' field, ')' type_affix?
function ctx:parse_function_header()
    if not self:match("word", "fn") then return self:parse_type() end
    self:next()
    local name, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    if not self:match("op", "(") then return self:err("expected '('") end
    self:next()

    local parameters = {}
    while not self:match("op", ")") do
        local field, err = self:parse_field()
        if err ~= nil then return nil, err end
        table.insert(parameters, { name = field.name, type = field.type })

        if not (self:match("op", ",") or self:match("op", ")")) then
            return self:err("expected ',' or ')'") end
        if self:match("op", ",") then self:next() end
    end
    self:next()

    local returntype = { a = "type", name = "void", subtypes = {} }
    if self:match("op", ":") then
        returntype, err = self:parse_type_affix()
        if err ~= nil then return nil, err end
    end

    return {
        a = "function_header",
        name = name,
        parameters = parameters,
        returntype = returntype,
    }
end

-- typedef ::= 'type' IDENTIFIER '=' type ';'
function ctx:parse_typedef()
    local typedef_header, err = self:parse_typedef_header()
    if err ~= nil then return nil, err end
    if not self:match("op", "=") then return self:err("expected '='") end
    self:next()
    local definition, err = self:parse_type()
    if err ~= nil then return nil, err end
    if not self:match("op", ";") then return self:err("expected ';'") end
    self:next()
    return { a = "typedef", type = typedef_header, definition = definition }
end

function ctx:parse_typedef_header()
    if not self:match("word", "type") then
        return self:err(
            "expected 'fn', 'struct', 'enum', 'trait', 'instance', or 'import'"
        )
    end
    self:next()
    local type, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    return { a = "typedef_header", type = type }
end

-- field ::= IDENTIFIER type_affix
function ctx:parse_field()
    local name, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    local type, err = self:parse_type_affix()
    if err ~= nil then return nil, err end
    return { name = name, type = type }
end

-- type_affix ::= ':' type
function ctx:parse_type_affix()
    if not self:match("op", ":") then return self:err("expected ':'") end
    self:next()
    local type, err = self:parse_type()
    if err ~= nil then return nil, err end
    return type
end

-- block ::= '{' (statement ';')* expr? '}'
function ctx:parse_block()
    if not self:match("op", "{") then return self:err("expected '{'") end
    self:next()
    local statements = {}
    local expr = nil
    while not self:match("op", "}") do
        local statement, err = self:parse_statement()
        if err ~= nil then return nil, err end

        if is_one_of(statement.a, { "for", "if", "while", "loop" }) then
            if statement.block.expr ~= nil then
                expr = statement
            else
                table.insert(statements, statement)
            end
        else
            if not (self:match("op", ";") or self:match("op", "}")) then
                return self:err("expected ';' or '}'") end
            if self:match("op", ";") then
                table.insert(statements, statement)
                self:next()
            else
                expr = statement
            end
        end
    end
    self:next()
    return { a = "block", statements = statements, expr = expr }
end

-- statement ::= assert
function ctx:parse_statement()
    return self:parse_assert()
end

-- expr ::= or_expr
function ctx:parse_expr()
    if self:match("op", ";") then return nil end
    if self:match("op", "{") then return self:parse_block() end
    return self:parse_for()
end

-- for ::= 'for' destructure 'in' expr block
function ctx:parse_for()
    if not self:match("word", "for") then return self:parse_if() end
    self:next()
    local lvalue, err = self:parse_destructure()
    if err ~= nil then return nil, err end
    if not self:match("word", "in") then return self:err("expected 'in'") end
    self:next()
    local iterable, err = self:parse_expr()
    if err ~= nil then return nil, err end
    local block, err = self:parse_block()
    if err ~= nil then return nil, err end
    return { a = "for", lvalue = lvalue, iterable = iterable, block = block }
end

-- if ::= 'if' expr block ('else' 'if' expr block)* ('else' block)?
function ctx:parse_if()
    if not self:match("word", "if") then return self:parse_while() end
    self:next()
    local condition, err = self:parse_expr()
    if err ~= nil then return nil, err end
    local block, err = self:parse_block()
    if err ~= nil then return nil, err end
    local elseblock = {}
    if self:match("word", "else") then
        self:next()
        if self:match("op", "{") then
            elseblock, err = self:parse_block()
        elseif self:match("word", "if") then
            elseblock, err = self:parse_if()
        end
        if err ~= nil then return nil, err end
    end
    return {
        a = "if",
        condition = condition,
        block = block,
        elseblock = elseblock
    }
end

-- while ::= 'while' expr block
function ctx:parse_while()
    if not self:match("word", "while") then return self:parse_loop() end
    self:next()
    local condition, err = self:parse_expr()
    if err ~= nil then return nil, err end
    local block, err = self:parse_block()
    if err ~= nil then return nil, err end
    return { a = "while", condition = condition, block = block }
end

-- loop ::= 'loop' block
function ctx:parse_loop()
    if not self:match("word", "loop") then return self:parse_closure() end
    self:next()
    local block, err = self:parse_block()
    if err ~= nil then return nil, err end
    return { a = "loop", block = block }
end

-- assert ::= 'assert' expr (',' expr)?
function ctx:parse_assert()
    if not self:match("word", "assert") then return self:parse_continue() end
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    local result
    if self:match("op", ",") then
        self:next()
        result, err = self:parse_expr()
        if err ~= nil then return nil, err end
    end
    return { a = "assert", expr = expr, result = result }
end

-- continue ::= 'continue'
function ctx:parse_continue()
    if not self:match("word", "continue") then return self:parse_break() end
    self:next()
    return { a = "continue" }
end

-- break ::= 'break' expr?
function ctx:parse_break()
    if not self:match("word", "break") then return self:parse_return() end
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = "break", expr = expr }
end

-- return ::= 'return' expr?
function ctx:parse_return()
    if not self:match("word", "return") then return self:parse_initialize() end
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = "return", expr = expr }
end

-- initialize ::= ('let' | 'const') destructure '=' expr
function ctx:parse_initialize()
    if not (self:match("word", "let") or self:match("word", "const")) then
        return self:parse_assign() end
    local word = self:current_token().value
    self:next()
    local lvalue, err = self:parse_destructure()
    if err ~= nil then return nil, err end
    local type
    if self:match("op", ":") then
        type, err = self:parse_type_affix()
        if err ~= nil then return nil, err end
    end
    if not self:match("op", "=") then return self:err("expected '='") end
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = word, lvalue = lvalue, type = type, expr = expr }
end

-- assign ::= id ('=' | '+=' | '-=' | '*=' | '/=' | '%=' | '^=' ) expr
function ctx:parse_assign()
    if self:current_token().label ~= "word" then return self:parse_expr() end
    local variable, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    if not (self:is_one_of({ "=", "+=", "-=", "*=", "/=", "%=", "^=" })) then
        self.index = self.index - 1
        return self:parse_expr()
    end
    local op = self:current_token().value
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = op, id = variable, expr = expr }
end

-- destructure ::= '(' (IDENTIFIER | destructure), ')'
function ctx:parse_destructure()
    if not self:match("op", "(") then return self:parse_identifier() end;
    self:next()
    local items = {}
    while not self:match("op", ")") do
        local expression, err = self:parse_destructure()
        if err ~= nil then return nil, err end
        table.insert(items, expression)
        if self:match("op", ",") then
            self:next()
        elseif not self:match("op", ")") then
            return self:err("expected ','")
        end
    end
    self:next()
    return items
end

-- type ::= IDENTIFIER ('<' type '>')? | '[' type ']'
function ctx:parse_type()
    if self:match("op", "[") then
        self:next()
        local type, err = self:parse_type()
        if err ~= nil then return nil, err end
        if not self:match("op", "]") then return self:err("expected ']'") end
        self:next()
        return { a = "type", name = "Array", subtypes = { type } }
    end
    if self:current_token().label ~= "word" then
        return self:err("expected identifier") end
    local name = self:current_token().value
    local subtypes = {}
    self:next()
    if self:match("op", "<") then
        self:next()
        while not self:match("op", ">") do
            table.insert(subtypes, self:parse_type())
            if not (self:match("op", ">") or self:match("op", ",")) then
                return self:err("expected '>' or ','") end
            if self:match("op", ",") then self:next() end
        end
        self:next()
    end
    return { a = "type", name = name, subtypes = subtypes }
end

-- closure :: '|' (IDENTIFIER ':' type)* '|' expr
function ctx:parse_closure()
    if not self:match("op", "|") then return self:parse_try_expr() end
    self:next()
    local parameters = {}
    while not self:match("op", "|") do
        if self:current_token().label ~= "word" then
            return self:err("expected identifier") end
        local name = self:current_token().value
        self:next()

        if not self:match("op", ":") then return self:err("expected ':'") end
        self:next()
        
        local type, err = self:parse_type()
        if err ~= nil then return nil, err end
        table.insert(parameters, { name = name, type = type })

        if not (self:match("op", ",") or self:match("op", "|")) then
            return self:err("expected ',' or '|'") end
        if self:match("op", ",") then self:next() end
    end
    self:next()
    local expr, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = "closure", parameters = parameters, expr = expr }
end

-- try ::= 'try' expr
function ctx:parse_try_expr()
    if not self:match("word", "try") then return self:parse_catch_expr() end
    self:next()
    local expression, err = self:parse_expr()
    if err ~= nil then return nil, err end
    return { a = "try", expr = expression }
end

-- catch ::= expr 'catch' expr
function ctx:parse_catch_expr()
    local left, err = self:parse_or_expr()
    if err ~= nil then return nil, err end
    if self:match("word", "catch") then
        self:next()
        local right, err = self:parse_or_expr()
        if err ~= nil then return nil, err end
        left = { a = "catch", expr = left, result = right }
    end
    return left
end

-- or_expr ::= and_expr ('or' and_expr)*
function ctx:parse_or_expr()
    local left, err = self:parse_and_expr()
    if err ~= nil then return nil, err end
    while self:match("word", "or") do
        self:next()
        local right, err = self:parse_and_expr()
        if err ~= nil then return nil, err end
        left = { a = "or", left = left, right = right }
    end
    return left
end

-- and_expr ::= not_expr ('and' not_expr)*
function ctx:parse_and_expr()
    local left, err = self:parse_not_expr()
    if err ~= nil then return nil, err end
    while self:match("word", "and") do
        self:next()
        local right, err = self:parse_not_expr()
        if err ~= nil then return nil, err end
        left = { a = "and", left = left, right = right }
    end
    return left
end

-- not_expr ::= 'not'? cmp_expr
function ctx:parse_not_expr()
    if not self:match("word", "not") then return self:parse_cmp_expr() end
    self:next()
    local expression, err = self:parse_not_expr()
    if err ~= nil then return nil, err end
    return { a = "not", value = expression }
end

-- cmp_expr ::= add_expr (('==' | '!=' | '>' | '<' | '>=' | '<=') add_expr)*
function ctx:parse_cmp_expr()
    local left, err = self:parse_add_expr()
    if err ~= nil then return nil, err end
    while self:is_one_of({ "==", "!=", ">", "<", ">=", "<=" }) do
        local operator = ({
            ["=="] = "eq", ["!="] = "neq", [">"] = "gt",
            ["<"] = "lt", [">="] = "gteq", ["<="] = "lteq",
        })[self:current_token().value]
        self:next()
        local right, err = self:parse_add_expr()
        if err ~= nil then return nil, err end
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- add_expr ::= mult_expr (('+' | '-') mult_expr)*
function ctx:parse_add_expr()
    local left, err = self:parse_mult_expr()
    if err ~= nil then return nil, err end
    while self:is_one_of({ "+", "-" }) do
        local operator = ({
            ["+"] = "add", ["-"] = "sub",
        })[self:current_token().value]
        self:next()
        local right, err = self:parse_mult_expr()
        if err ~= nil then return nil, err end
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- mult_expr ::= exp_expr (('*' | '/' | '%') exp_expr)*
function ctx:parse_mult_expr()
    local left, err = self:parse_exp_expr()
    if err ~= nil then return nil, err end
    while self:is_one_of({ "*", "/", "%" }) do
        local operator = ({
            ["*"] = "mult", ["/"] = "div", ["%"] = "mod",
        })[self:current_token().value]

        self:next()
        local right, err = self:parse_exp_expr()
        if err ~= nil then return nil, err end
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- exp_expr ::= neg_expr ('^' neg_expr)*
function ctx:parse_exp_expr()
    local left, err = self:parse_neg_expr()
    if err ~= nil then return nil, err end
    if self:match("op", "^") then
        self:next()
        local right, err = self:parse_exp_expr()
        if err ~= nil then return nil, err end
        left = { a = "exp", left = left, right = right }
    end
    return left
end

-- neg_expr ::= '-' (dot | neg_expr)
function ctx:parse_neg_expr()
    if not self:match("op", "-") then return self:parse_dot() end
    self:next()
    local expression, err = self:parse_neg_expr()
    if err ~= nil then return nil, err end
    return { a = "neg", value = expression }
end

-- dot ::= (call_index | dot) '.' call_index
function ctx:parse_dot()
    local source, err = self:parse_call_index()
    if err ~= nil then return nil, err end
    while self:match("op", ".") do
        self:next()
        local postdot, err = self:parse_call_index()
        if err ~= nil then return nil, err end
        source = { a = "dot", source = source, postdot = postdot }
    end
    return source
end

-- call_index ::= (scoper | call_index) ('[' expr ']' | '(' expr, ')')*
function ctx:parse_call_index()
    local called, err = self:parse_scoper()
    if err ~= nil then return nil, err end
    while self:match("op", "(") or ctx:match("op", "[") do
        if self:match("op", "(") then
            local items, err = self:parse_comma_brackets(")")
            if err ~= nil then return nil, err end
            self:next()
            called = { a = "call", called = called, args = items }
        elseif self:match("op", "[") then
            self:next()
            local expression, err = self:parse_expr()
            if err ~= nil then return nil, err end
            if not self:match("op", "]") then
                return ctx:err("expected ']'") end
            self:next()
            called = { a = "index", indexed = called, arg = expression }
        end
    end
    return called
end

-- scoper ::= (atom | scoper) '::' atom
function ctx:parse_scoper()
    if self:current_token().label ~= "word" then return self:parse_atom() end
    local scope, err = self:parse_identifier()
    if err ~= nil then return nil, err end
    if not self:match("op", "::") then
        self.index = self.index - 1
        return self:parse_atom()
    end
    if self:match("op", "::") then
        self:next()
        local member, err = self:parse_scoper()
        if err ~= nil then return nil, err end
        scope = { a = "scoper", scope = scope, member = member }
    end
    return scope
end

-- atom ::= IDENTIFIER | NUMBER | STRING | CHAR | parentheses
function ctx:parse_atom()
    if self:current_token().label == "word" then
        return self:parse_identifier()
    end

    if self:current_token().label == "num" then
        local name = self:current_token().value
        self:next()
        return { a = "num", num = name }
    end

    if self:current_token().label == "str" then
        local name = self:current_token().value
        self:next()
        return { a = "str", str = name }
    end

    if self:current_token().label == "char" then
        local name = self:current_token().value
        self:next()
        return { a = "char", char = name }
    end

    return self:parse_parentheses()
end

function ctx:parse_identifier()
    if self:current_token().label ~= "word" then
        return self:err("expected identifier") end
    local name = self:current_token().value
    self:next()
    return { a = "id", id = name }
end

-- parentheses ::= '(' expr ')' | array
function ctx:parse_parentheses()
    if not self:match("op", "(") then return self:parse_array() end
    self:next()
    local expression, err = self:parse_expr()
    if err ~= nil then return nil, err end
    if not self:match("op", ")") then return self:err("expected ')'") end
    self:next()
    return expression
end

-- array ::= '[' expr, ']'
function ctx:parse_array()
    if not self:match("op", '[') then return self:parse_expr() end
    local items = ctx:parse_comma_brackets("]")
    self:next()
    return { a = "array", items = items }
end

-- Auxiliary contextual functions
function ctx:parse_comma_brackets(right)
    self:next()
    local items = {}
    while not self:match("op", right) do
        local expression, err = self:parse_expr()
        if err ~= nil then return nil, err end
        table.insert(items, expression)
        if self:match("op", ",") then
            self:next()
        elseif not self:match("op", right) then
            return self:err("expected ','")
        end
    end
    return items
end

function ctx:is_one_of(values)
    for i = 1, #values do
        if self:current_token().value == values[i] then return true end
    end
end

function ctx:current_token()
    return self.tokens[self.index]
end

function ctx:match(label, value)
    return self:current_token():match(label, value)
end

function ctx:next()
    self.index = self.index + 1
end

function ctx:err(err)
    return nil, {err = err, ctx = self}
end

return parser
