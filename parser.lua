local inspect = require "inspect"

local parser = {}

function new_error(name, context)
    return {
        name = name,
        context = context,
    }
end

function new_parse_context(tokens)
    local context = {
        tokens = tokens,
        index = 1,
    }

    function context:current_token()
        return self.tokens[self.index]
    end

    function context:increment()
        self.index = self.index + 1
    end

    function context:search_type()
        local newtype = {
            name = nil,
            inner_name = {},
        }

        if self:current_token().label ~= "word" then return nil, new_error("expected type", self) end
        newtype.name = self:current_token().value
        self:increment()

        if self:current_token():match("op", "<") then
            self:increment()
            newtype.inner_name = self:search_type()
            if not self:current_token():match("op", ">") then return nil, new_error("expected '>'", self) end
            self:increment()
        end

        while true do
            if self:current_token():match("op", "?") then
                newtype = {
                    name = "Option",
                    inner_name = {newtype},
                }
            elseif self:current_token():match("op", "!") then
                newtype = {
                    name = "Result",
                    inner_name = {newtype, "Error"},
                }
            elseif self:current_token():match("op", "*") then
                newtype = {
                    name = "Pointer",
                    inner_name = {newtype},
                }
            else
                break
            end
            self:increment()
        end

        return newtype, nil
    end

    function context:search_atom()
        if self:current_token():match("op", "(") then
            self:increment()
            local expression = self:search_expression()

            if not self:current_token():match("op", ")") then return nil, new_error("expected ')'", self) end
            self:increment()

            return expression
        end

        if self:current_token().label == "num" then
            local number = self:current_token().value
            self:increment()

            if self:current_token().label == "unit" then
                local unit = self:current_token().value
                self:increment()

                return {
                    name = "unitNumber",
                    value = number,
                    unit = unit,
                }
            end

            return {
                name = "number",
                value = number,
            }
        end
    end

    function context:search_exp_operation()
        local left, err = context:search_atom()
        if err ~= nil then return nil, err end

        while self:current_token():match("op", "^") do
            self:increment()

            local right, err = context:search_atom()
            if err ~= nil then return nil, err end

            left = {
                name = "exponent",
                left = left,
                right = right,
            }
        end

        return left
    end

    function context:search_mult_operation()
        local left, err = context:search_atom()
        if err ~= nil then return nil, err end

        while self:current_token():match("op", "*")
          or self:current_token():match("op", "/")
          or self:current_token():match("op", "%") do
            self:increment()

            local right, err = context:search_atom()
            if err ~= nil then return nil, err end

            left = {
                name = "mult",
                left = left,
                right = right,
            }
        end

        return left
    end

    function context:search_add_operation()
        local left, err = context:search_atom()
        if err ~= nil then return nil, err end

        while self:current_token():match("op", "+")
          or self:current_token():match("op", "-") do
            self:increment()

            local right, err = context:search_mult_operation()
            if err ~= nil then return nil, err end

            left = {
                name = "add",
                left = left,
                right = right,
            }
        end

        return left
    end

    function context:search_negative_operation()
        if not self:current_token():match("op", "-") then
            return context:search_add_operation()
        end

        self:increment()

        local expression, err = context:search_add_operation()
        if err ~= nil then return nil, err end

        return {
            name = "negative",
            left = expression,
        }
    end

    function context:search_expression()
        if self:current_token():match("word", "while") then
            self:increment()
            local condition, err = self:search_expression()
            if err ~= nil then return nil, err end

            local block, err = self:search_block()
            if err ~= nil then return nil, err end

            return {
                name = "while",
                condition = condition,
                block = block,
            }
        elseif self:current_token():match("word", "if") then
            self:increment()
        elseif self:current_token():match("word", "for") then
            self:increment()
        elseif self:current_token():match("word", "loop") then
            self:increment()
        elseif self:current_token():match("word", "match") then
            self:increment()
        else
            return self:search_negative_operation()
        end
    end

    function context:search_block()
        if not self:current_token():match("op", "{") then return nil, new_error("expected '{'", self) end
        self:increment()

        local statements = {}

        while not self:current_token():match("op", "}") do
            -- block
            local expression, err = self:search_expression()
            if err ~= nil then return nil, err end

            if self:current_token():match("op", "}") then
                table.insert(statements, { name = "expression", value = expression })
            elseif self:current_token():match("op", ";") then
                table.insert(statements, expression)
                self:increment()
            else
                return nil, new_error("expected ';' or '}'", self)
            end
        end

        return statements
    end

    function context:search_function()
        if not self:current_token():match("word", "func") then return {} end
        self:increment()
        
        -- Get function name
        if self:current_token().label ~= "word" then return nil, new_error("expected identifier", self) end
        local name = self:current_token().value
        self:increment()

        if not self:current_token():match("op", "(") then return nil, new_error("expected '('", self) end
        self:increment()
        
        -- Get parameters
        local parameters = {}
        while not self:current_token():match("op", ")") do
            if self:current_token().label ~= "word" then return nil, new_error("expected identifier", self) end
            local name = self:current_token().value
            self:increment()

            if not self:current_token():match("op", ":") then return nil, new_error("expected ':'", self) end
            self:increment()

            local paramtype, err = self:search_type()
            if err ~= nil then return nil, err end

            table.insert(parameters, {name = name, paramtype = paramtype})
        end

        self:increment()

        local returntype = "void"

        if self:current_token():match("op", "->") then
            self:increment()

            returntype, err = self:search_type()
            if err ~= nil then return nil, err end
        end

        local block = {}

        if self:current_token():match("op", "=") then
            self:increment()

            -- Search expression
        end
        
        if self:current_token():match("op", "{") then
            -- Search block
            local err
            block, err = self:search_block()
            if err ~= nil then return nil, err end
        end

        return {
            label = "function",
            name = name,
            parameters = parameters,
            returntype = returntype,
            block = block,
        }
    end

    return context
end

function parser.parse(tokens)
    local context = new_parse_context(tokens)
    local tree = {}

    while context:current_token() ~= nil do
        local func, err = context:search_function()
        if err ~= nil then return nil, err end

        table.insert(tree, func)
        context:increment()
    end

    print(inspect(tree))
end

return parser
