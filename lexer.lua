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

    function result:lex_word()
        print(self.index)
    end

    return result
end

function lexer.lex(code)
    local result = new_result(code)
    
    while result.index <= #code do
        local char = result:char()
        
        if char:match("%d") then
            print(char .. ": DIGIT")
        elseif char:match("[ \n\t\r]") then
            print(char .. ": WHITESPACE")
        elseif char:match("%p") then
            print(char .. ": PUNCTUATION")
        else
            print(char .. ": LETTER")
        end

        result:increment()
    end
end

return lexer
