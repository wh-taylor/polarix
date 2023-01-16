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
        local func, err = ctx:parse_function()
        if err ~= nil then return nil, err end
        table.insert(tree, func)
    end
    return tree
end

-- mocktype ::= IDENTIFIER ('<' IDENTIFIER, '>')?
function ctx:parse_mocktype()
    if self:current_token().label ~= "word" then
        return self:err("expected identifier") end
    local name = self:parse_identifier()
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
    local function_header = self:parse_function_header()
    local block
    if self:match("op", "{") then
        block = self:parse_block()
    elseif self:match("op", "=") then
        self:next()
        block = { a = "block", statements = {}, expr = self:parse_expr() }
        if not self:match("op", ";") then return self:err("expected ';'") end
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
    if not self:match("word", "fn") then return self:err("expected 'fn'") end
    self:next()
    local name = self:parse_identifier()
    if not self:match("op", "(") then return self:err("expected '('") end
    self:next()

    local parameters = {}
    while not self:match("op", ")") do
        local field = self:parse_field()
        table.insert(parameters, { name = field.name, type = field.type })

        if not (self:match("op", ",") or self:match("op", ")")) then
            return self:err("expected ',' or ')'") end
        if self:match("op", ",") then self:next() end
    end
    self:next()

    local returntype = { a = "type", name = "void", subtypes = {} }
    if self:match("op", ":") then returntype = self:parse_type_affix() end

    return {
        a = "function_header",
        name = name,
        parameters = parameters,
        returntype = returntype,
    }
end

-- field ::= IDENTIFIER type_affix
function ctx:parse_field()
    local name = self:parse_identifier()
    local type = self:parse_type_affix()
    return { name = name, type = type }
end

-- type_affix ::= ':' type
function ctx:parse_type_affix()
    if not self:match("op", ":") then return self:err("expected ':'") end
    self:next()
    local type = self:parse_type()
    return type
end

-- block ::= '{' (statement ';')* expr? '}'
function ctx:parse_block()
    if not self:match("op", "{") then return self:err("expected '{'") end
    self:next()
    local statements = {}
    local expr = nil
    while not self:match("op", "}") do
        local statement = self:parse_statement()

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
    local lvalue = self:parse_destructure()
    if not self:match("word", "in") then return self:err("expected 'in'") end
    self:next()
    local iterable = self:parse_expr()
    local block = self:parse_block()
    return { a = "for", lvalue = lvalue, iterable = iterable, block = block }
end

-- if ::= 'if' expr block ('else' 'if' expr block)* ('else' block)?
function ctx:parse_if()
    if not self:match("word", "if") then return self:parse_while() end
    self:next()
    local condition = self:parse_expr()
    local block = self:parse_block()
    local elseblock = {}
    if self:match("word", "else") then
        self:next()
        if self:match("op", "{") then
            elseblock = self:parse_block()
        elseif self:match("word", "if") then
            elseblock = self:parse_if()
        end
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
    local condition = self:parse_expr()
    local block = self:parse_block()
    return { a = "while", condition = condition, block = block }
end

-- loop ::= 'loop' block
function ctx:parse_loop()
    if not self:match("word", "loop") then return self:parse_closure() end
    self:next()
    local block = self:parse_block()
    return { a = "loop", block = block }
end

-- assert ::= 'assert' expr (',' expr)?
function ctx:parse_assert()
    if not self:match("word", "assert") then return self:parse_continue() end
    self:next()
    local expr = self:parse_expr()
    local result
    if self:match("op", ",") then
        self:next()
        result = self:parse_expr()
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
    local expr = self:parse_expr()
    return { a = "break", expr = expr }
end

-- return ::= 'return' expr?
function ctx:parse_return()
    if not self:match("word", "return") then return self:parse_initialize() end
    self:next()
    local expr = self:parse_expr()
    return { a = "return", expr = expr }
end

-- initialize ::= ('let' | 'const') destructure '=' expr
function ctx:parse_initialize()
    if not (self:match("word", "let") or self:match("word", "const")) then
        return self:parse_assign() end
    local word = self:current_token().value
    self:next()
    local lvalue = self:parse_destructure()
    local type
    if self:match("op", ":") then type = self:parse_type_affix() end
    if not self:match("op", "=") then return self:err("expected '='") end
    self:next()
    local expr = self:parse_expr()
    return { a = word, lvalue = lvalue, type = type, expr = expr }
end

-- assign ::= id ('=' | '+=' | '-=' | '*=' | '/=' | '%=' | '^=' ) expr
function ctx:parse_assign()
    local variable = self:parse_identifier()
    if not (self:is_one_of({ "=", "+=", "-=", "*=", "/=", "%=", "^=" })) then
        self.index = self.index - 1
        return self:parse_expr()
    end
    local op = self:current_token().value
    self:next()
    local expr = self:parse_expr()
    return { a = op, id = variable, expr = expr }
end

-- destructure ::= '(' (IDENTIFIER | destructure), ')'
function ctx:parse_destructure()
    if not self:match("op", "(") then return self:parse_identifier() end;
    self:next()
    local items = {}
    while not self:match("op", ")") do
        local expression = self:parse_destructure()
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

-- type ::= IDENTIFIER ('<' type '>')?
function ctx:parse_type()
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
        
        local type = self:parse_type()
        table.insert(parameters, { name = name, type = type })

        if not (self:match("op", ",") or self:match("op", "|")) then
            return self:err("expected ',' or '|'") end
        if self:match("op", ",") then self:next() end
    end
    self:next()
    local expr = self:parse_expr()
    return { a = "closure", parameters = parameters, expr = expr }
end

-- try ::= 'try' expr
function ctx:parse_try_expr()
    if not self:match("word", "try") then return self:parse_catch_expr() end
    self:next()
    local expression = self:parse_expr()
    return { a = "try", expr = expression }
end

-- catch ::= expr 'catch' expr
function ctx:parse_catch_expr()
    local left = self:parse_or_expr()
    if self:match("word", "catch") then
        self:next()
        local right = self:parse_or_expr()
        left = { a = "catch", expr = left, result = right }
    end
    return left
end

-- or_expr ::= and_expr ('or' and_expr)*
function ctx:parse_or_expr()
    local left = self:parse_and_expr()
    while self:match("word", "or") do
        self:next()
        local right = self:parse_and_expr()
        left = { a = "or", left = left, right = right }
    end
    return left
end

-- and_expr ::= not_expr ('and' not_expr)*
function ctx:parse_and_expr()
    local left = self:parse_not_expr()
    while self:match("word", "and") do
        self:next()
        local right = self:parse_not_expr()
        left = { a = "and", left = left, right = right }
    end
    return left
end

-- not_expr ::= 'not'? cmp_expr
function ctx:parse_not_expr()
    if not self:match("word", "not") then return self:parse_cmp_expr() end
    self:next()
    local expression = self:parse_not_expr()
    return { a = "not", value = expression }
end

-- cmp_expr ::= add_expr (('==' | '!=' | '>' | '<' | '>=' | '<=') add_expr)*
function ctx:parse_cmp_expr()
    local left = self:parse_add_expr()
    while self:is_one_of({ "==", "!=", ">", "<", ">=", "<=" }) do
        local operator = self:current_token().value
        self:next()
        local right = self:parse_add_expr()
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- add_expr ::= mult_expr (('+' | '-') mult_expr)*
function ctx:parse_add_expr()
    local left = self:parse_mult_expr()
    while self:is_one_of({ "+", "-" }) do
        local operator
        if self:current_token().value == "+" then operator = "add"
        elseif self:current_token().value == "-" then operator = "minus" end
        self:next()
        local right = self:parse_mult_expr()
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- mult_expr ::= exp_expr (('*' | '/' | '%') exp_expr)*
function ctx:parse_mult_expr()
    local left = self:parse_exp_expr()
    while self:is_one_of({ "*", "/", "%" }) do
        local operator
        if self:current_token().value == "*" then operator = "mult"
        elseif self:current_token().value == "/" then operator = "div"
        elseif self:current_token().value == "%" then operator = "mod" end
        self:next()
        local right = self:parse_exp_expr()
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- exp_expr ::= neg_expr ('^' neg_expr)*
function ctx:parse_exp_expr()
    local left = self:parse_neg_expr()
    if self:match("op", "^") then
        self:next()
        local right = self:parse_exp_expr()
        left = { a = "exp", left = left, right = right }
    end
    return left
end

-- neg_expr ::= '-' (scoper | neg_expr)
function ctx:parse_neg_expr()
    if not self:match("op", "-") then return self:parse_scoper() end
    self:next()
    local expression = self:parse_neg_expr()
    return { a = "neg", value = expression }
end

-- scoper ::= (id | scoper) '::' dot
function ctx:parse_scoper()
    local scope = self:parse_identifier()
    if not self:match("op", "::") then
        self.index = self.index - 1
        return self:parse_dot()
    end
    while self:match("op", "::") do
        self:next()
        local member = self:parse_dot()
        scope = { a = "scoper", scope = scope, member = member }
    end
    return scope
end

-- dot ::= (call_index | dot) '.' call_index
function ctx:parse_dot()
    local source = self:parse_call_index()
    while self:match("op", ".") do
        self:next()
        local postdot = self:parse_call_index()
        source = { a = "dot", source = source, postdot = postdot }
    end
    return source
end

-- call_index ::= (atom | call_index) ('[' expr ']' | '(' expr, ')')*
function ctx:parse_call_index()
    local called = self:parse_atom()
    while self:match("op", "(") or ctx:match("op", "[") do
        if self:match("op", "(") then
            local items = self:parse_comma_brackets(")")
            self:next()
            called = { a = "call", called = called, args = items }
        elseif self:match("op", "[") then
            self:next()
            local expression = self:parse_expr()
            if not self:match("op", "]") then
                return ctx:err("expected ']'") end
            self:next()
            called = { a = "index", indexed = called, arg = expression }
        end
    end
    return called
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

    return ctx:parse_parentheses()
end

function ctx:parse_identifier()
    local name = self:current_token().value
    self:next()
    return { a = "id", id = name }
end

-- parentheses ::= '(' expr ')' | array
function ctx:parse_parentheses()
    if not self:match("op", "(") then return self:parse_array() end
    self:next()
    local expression = self:parse_expr()
    if not self:match("op", ")") then return self:err("expected ')'") end
    self:next()
    return expression
end

-- array ::= '[' expr, ']'
function ctx:parse_array()
    if not self:match("op", left) then return self:parse_expr() end
    local items = ctx:parse_comma_brackets("]")
    self:next()
    return { a = "array", items = items }
end

-- Auxiliary contextual functions
function ctx:parse_comma_brackets(right)
    self:next()
    local items = {}
    while not self:match("op", right) do
        local expression = self:parse_expr()
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
