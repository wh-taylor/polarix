local lexer = {}

function string.char_at(str, index)
    return str:sub(index, index)
end

function lexer.lex(code)
    local result = {
        code = code,
        index = 1,
        tokens = {},
    }
    
    while result.index <= #code do
        local char = code:char_at(result.index)
        
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
