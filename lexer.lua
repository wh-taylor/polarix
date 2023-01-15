local lexer = {}

function new_result(code)
    local result = {
        code = code,
        index = 1,
        tokens = {},
    }

    function result:char()
        return self.code:sub(self.index, self.index)
    end

    function result:increment()
        self.index = self.index + 1
    end

    function result:is_index_valid()
        return self.index <= #self.code
    end

    function result:lex_word()
        local word = ""
        while self:is_index_valid() do
            if self:char():match("[%p \n\t\r]") then
                table.insert(self.tokens, word)
            end

            word = word .. self:char()
            self:increment()
        end
    end

    return result
end

function lexer.lex(code)
    local result = new_result(code)
    
    while result:is_index_valid() do
        local char = result:char()
        
        if char:match("%d") then
            -- Lex number
        elseif char:match("[ \n\t\r]") then
            -- Do nothing!
        elseif char:match("%p") then
            -- Lex punctuation
        else
            -- Lex word
            result:lex_word()
        end

        result:increment()
    end
end

return lexer
