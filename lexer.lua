local lexer = {}

local operators = {
    ["("] = true,
    [")"] = true,
    ["{"] = true,
    ["}"] = true,
    ["["] = true,
    ["]"] = true,
    ["\""] = true,
    ["'"] = true,
    ["."] = true,
    [","] = true,
    ["/"] = true,
    ["\\"] = true,
    ["+"] = true,
    ["-"] = true,
    ["="] = true,
    ["!"] = true,
    ["@"] = true,
    ["#"] = true,
    ["$"] = true,
    ["%"] = true,
    ["^"] = true,
    ["&"] = true,
    ["*"] = true,
    ["`"] = true,
    ["~"] = true,
    ["?"] = true,
    ["<"] = true,
    [">"] = true,
    [":"] = true,
    [";"] = true,
    ["|"] = true,
    ["->"] = true,
    ["=>"] = true,
    [">="] = true,
    ["<="] = true,
    ["=="] = true,
    ["+="] = true,
    ["-="] = true,
    ["*="] = true,
    ["/="] = true,
    ["^="] = true,
    ["%="] = true,
    ["::"] = true,
}

function new_token(label, value, context)
    local token = {
        label = label,
        value = value,
        file_name = context.file_name,
        code = context.code,
        line = context.line,
        col = context.col,
    }

    return token
end

function new_context(file_name, code)
    local context = {
        file_name = file_name,
        code = code,
        index = 1,
        line = 1,
        col = 1,
        tokens = {},
    }

    function context:char()
        return self.code:sub(self.index, self.index)
    end

    function context:increment()
        self.index = self.index + 1
        self.col = self.col + 1
        
        if self:char() == "\n" then
            self.col = 1
            self.line = self.line + 1
        end
    end

    function context:is_index_valid()
        return self.index <= #self.code
    end

    function context:lex_number()
        local num = ""
        while self:is_index_valid() do
            if not self:char():match("[%d.]")
              or (self:char() == "." and num:match("[.]")) then
                table.insert(self.tokens, new_token("num", num, self))
                return
            end

            num = num .. self:char()
            self:increment()
        end
    end
    
    function context:lex_operator()
        local sym = ""
        while self:is_index_valid() do
            if not self:char():match("%p") then
                break
            end

            sym = sym .. self:char()
            self:increment()
        end

        for i = #sym, 1, -1 do
            if operators[sym:sub(1, i)] then
                table.insert(self.tokens, new_token("op", sym:sub(1, i), self))
                self.index = self.index - #sym + i
                return
            end
        end
    end

    function context:lex_word()
        local word = ""
        while self:is_index_valid() do
            if self:char():match("[%p \n\t\r]") then
                table.insert(self.tokens, new_token("word", word, self))
                return
            end

            word = word .. self:char()
            self:increment()
        end
    end

    return context
end

function lexer.lex(file_name, code)
    local context = new_context(file_name, code)
    
    while context:is_index_valid() do
        local char = context:char()
        
        if char:match("%d") then
            -- Lex number
            context:lex_number()
        elseif char:match("[ \n\t\r]") then
            -- Do nothing!
            context:increment()
        elseif char:match("%p") then
            -- Lex punctuation
            context:lex_operator()
        else
            -- Lex word
            context:lex_word()
        end
    end

    for i = 1, #context.tokens do
        print(i .. " => [" .. context.tokens[i].label .. ": " .. context.tokens[i].value .. "]")
    end

    return context.tokens
end

return lexer
