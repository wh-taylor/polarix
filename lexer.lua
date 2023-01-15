local lexer = {}

function lexer.lex(code)
    local result = {
        code = code,
        index = 1,
        tokens = {},
        char = function(self)
            return self.code:sub(self.index, self.index)
        end,
        increment = function(self)
            self.index = self.index + 1
        end,
    }
    
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
