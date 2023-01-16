local parser = {}

local ctx = {
    tokens = nil,
    index = nil,
}

-- expr ::= or_expr
function ctx:parse_expr()
    return self:parse_closure()
end

-- initialize ::= ('let' | 'const') destructure '=' expr
function ctx:parse_initialize()
    if not (self:match("word", "let") or self:match("word", "const")) then return self:parse_expr() end
    local word = self:current_token().value
    self:next()
    local lvalue = self:parse_destructure()
    if not self:match("op", "=") then return self:err("expected '='") end
    self:next()
    local expr = self:parse_expr()
    return { a = word, lvalue = lvalue, expr = expr }
end

-- destructure ::= '(' (IDENTIFIER | destructure) (',' (IDENTIFIER | destructure))* ')'
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
    if self:current_token().label ~= "word" then return self:err("expected identifier") end
    local name = self:current_token().value
    local subtypes = {}
    self:next()
    if self:match("op", "<") then
        self:next()
        while not self:match("op", ">") do
            table.insert(subtypes, self:parse_type())
            if not (self:match("op", ">") or self:match("op", ",")) then return self:err("expected '>' or ','") end
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
        if self:current_token().label ~= "word" then return self:err("expected identifier") end
        local name = self:current_token().value
        self:next()

        if not self:match("op", ":") then return self:err("expected ':'") end
        self:next()
        
        local type = self:parse_type()
        table.insert(parameters, { name = name, type = type })

        if not (self:match("op", ",") or self:match("op", "|")) then return self:err("expected ',' or '|'") end
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
    while self:match("op", "==")
      or self:match("op", "!=")
      or self:match("op", ">")
      or self:match("op", "<")
      or self:match("op", ">=")
      or self:match("op", "<=") do
        local operator
        if self:current_token().value == "==" then operator = "eq"
        elseif self:current_token().value == "!=" then operator = "neq"
        elseif self:current_token().value == ">" then operator = "gt"
        elseif self:current_token().value == "<" then operator = "lt"
        elseif self:current_token().value == ">=" then operator = "gteq"
        elseif self:current_token().value == "<=" then operator = "lteq" end
        self:next()
        local right = self:parse_add_expr()
        left = { a = operator, left = left, right = right }
    end
    return left
end

-- add_expr ::= mult_expr (('+' | '-') mult_expr)*
function ctx:parse_add_expr()
    local left = self:parse_mult_expr()
    while self:match("op", "+") or self:match("op", "-") do
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
    while self:match("op", "*") or self:match("op", "/") or self:match("op", "%") do
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

-- call_index ::= (atom | call_index) ('[' expr ']' | '(' (expr (',' expr)*)? ')')*
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
            if not self:match("op", "]") then return ctx:err("expected ']'") end
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

-- array ::= '[' (expr (',' expr)*)? ']'
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

function ctx:current_token() return self.tokens[self.index] end
function ctx:match(label, value) return self:current_token():match(label, value) end
function ctx:next() self.index = self.index + 1 end
function ctx:err(err) return nil, {err = err, ctx = self} end

function parser.parse(tokens)
    ctx.tokens = tokens
    ctx.index = 1
    return ctx:parse_initialize()
end

return parser
