local inspect = require "inspect"

local parser = {}

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

        if self:current_token().label ~= "word" then return nil, 0 end
        newtype.name = self:current_token().value
        self:increment()

        if self:current_token():match("op", "<") then
            self:increment()
            newtype.inner_name = self:search_type()
            if not self:current_token():match("op", ">") then return nil, 0 end
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

    function context:search_function()
        if self:current_token():match("word", "func") then
            self:increment()
            
            -- Get function name
            if self:current_token().label ~= "word" then return nil, 0 end
            local name = self:current_token().value
            self:increment()

            if not self:current_token():match("op", "(") then return nil, 0 end
            self:increment()
            
            -- Get parameters
            local parameters = {}
            while not self:current_token():match("op", ")") do
                if self:current_token().label ~= "word" then return nil, 0 end
                local name = self:current_token().value
                self:increment()

                if not self:current_token():match("op", ":") then return nil, 0 end
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

            if self:current_token():match("op", "=") then
                self:increment()

                -- Search expression
            end
            
            if self:current_token():match("op", "{") then
                self:increment()
                
                -- Search block
            end

            return {
                label = "function",
                name = name,
                parameters = parameters,
                returntype = returntype,
            }, nil
        end
    end

    return context
end

function parser.parse(tokens)
    local context = new_parse_context(tokens)
    local tree = {}

    --while context:current_token() ~= nil do
        local func, err = context:search_function()
        if err ~= nil then return nil, err end

        table.insert(tree, func)
        context:increment()
    --end

    print(inspect(tree))
end

return parser
