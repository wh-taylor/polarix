local lexer = {}

function lexer.lex(code)
    local result = {
        code = code,
        index = 1,
        tokens = {},
        char = function(self)
            return self.code:sub(self.index, self.index)
        end
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

        result.index = result.index + 1
    end
end

return lexer
