local parser = {}

local ctx = {
    tokens = nil,
    index = nil,
}

-- expr ::= atom
function ctx:parse_expr()
    return self:parse_atom()
end

-- atom ::= IDENTIFIER | NUMBER | STRING | CHAR | parentheses
function ctx:parse_atom()
    if self:current_token().label == "word" then
        local name = self:current_token().value
        self:next()
        return { a = "id", id = name }
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
    if not self:match("op", "[") then return self:err("unexpected token") end
    self:next()
    local items = {}
    while not self:match("op", "]") do
        local expression = self:parse_expr()
        table.insert(items, expression)
        if self:match("op", ",") then
            self:next()
        elseif not self:match("op", "]") then
            return self:err("expected ','")
        end
    end
    self:next()
    return { a = "array", items = items }
end

-- Auxiliary contextual functions
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
