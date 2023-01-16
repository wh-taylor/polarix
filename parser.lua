local parser = {}

local ctx = {
    tokens = nil,
    index = nil,
}

-- expr ::= scoper
function ctx:parse_expr()
    return self:parse_exp_expr()
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
            local items = self:parse_comma_brackets("(", ")")
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
    local items = ctx:parse_comma_brackets("[", "]")
    self:next()
    return { a = "array", items = items }
end

-- Auxiliary contextual functions
function ctx:parse_comma_brackets(left, right)
    if not self:match("op", left) then return self:err("expected '" .. left .. "'") end
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
    return ctx:parse_expr()
end

return parser
