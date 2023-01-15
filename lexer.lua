local lexer = {}

function lexer.lex(code)
    local index = 1
    
    while index <= #code do
        local char = code:sub(index, index)
        
        if char:match("%d") then
            print(char .. ": DIGIT")
        elseif char:match("[ \n\t\r]") then
            print(char .. ": WHITESPACE")
        elseif char:match("%p") then
            print(char .. ": PUNCTUATION")
        else
            print(char .. ": LETTER")
        end

        index = index + 1
    end
end

return lexer
