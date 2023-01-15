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
        if self:char() == "\n" then
            self.col = 0
            self.line = self.line + 1
        end

        self.index = self.index + 1
        self.col = self.col + 1
    end

    function context:is_index_valid()
        return self.index <= #self.code
    end

    function context:copy()
        return {
            file_name = self.file_name,
            code = self.code,
            index = self.index,
            line = self.line,
            col = self.col,
            tokens = self.tokens,
        }
    end

    function context:lex_number()
        local num = ""
        local ctx = self:copy()
        local dot_ctx = nil
        while self:is_index_valid() do
            if not self:char():match("[%d.]")
              or (self:char() == "." and num:match("[.]")) then
                if num:sub(-1) == "." then
                    table.insert(self.tokens, new_token("num", num:sub(1,-2), ctx))
                    table.insert(self.tokens, new_token("op", ".", dot_ctx))
                    return
                end
                table.insert(self.tokens, new_token("num", num, ctx))
                return
            end

            if self:char() == "." then
                dot_ctx = self:copy()
            end

            num = num .. self:char()
            self:increment()
        end
    end

    function context:lex_escape_sequence()
        self:increment()
        
        if self:char() == "a" then return "\a" end
        if self:char() == "b" then return "\b" end
        if self:char() == "f" then return "\f" end
        if self:char() == "n" then return "\n" end
        if self:char() == "r" then return "\r" end
        if self:char() == "t" then return "\t" end
        if self:char() == "v" then return "\v" end
        if self:char() == "\\" then return "\\" end
        if self:char() == "\"" then return "\"" end
        if self:char() == "\'" then return "\'" end
        
        -- Octal escape sequence
        if self:char():match("%d") then
            local num = nil
            local num_str = nil
            for i = 2, 0, -1 do
                num_str = self.code:sub(self.index, self.index + i)
                num = tonumber(num_str, 8)
                if num ~= nil then break end
            end
            if num == nil then return "\\" end
            for i = 2, #num_str do
                self:increment()
            end
            return string.char(num)
        end

        return "\\"
    end

    function context:lex_string()
        local str = ""
        local ctx = self:copy()
        self:increment()
        while self:is_index_valid() do
            if self:char() == "\"" then
                table.insert(self.tokens, new_token("str", str, ctx))
                self:increment()
                return
            end
            
            if self:char() == "\\" then
                str = str .. self:lex_escape_sequence()
            else
                str = str .. self:char()
            end
            
            self:increment()
        end
    end
    
    function context:lex_operator()
        local sym = ""
        local ctx = self:copy()
        while self:is_index_valid() do
            -- Comments
            if sym == "//" then
                while self:char() ~= "\n" do
                    self:increment()
                end
                return
            end
            if sym == "/*" then
                while true do
                    if self:char() == "*" then
                        self:increment()
                        if self:char() == "/" then
                            self:increment()
                            return
                        end
                    else
                        self:increment()
                    end
                end
                return
            end

            if not self:char():match("%p") then
                break
            end

            sym = sym .. self:char()
            self:increment()
        end

        for i = #sym, 1, -1 do
            if operators[sym:sub(1, i)] then
                table.insert(self.tokens, new_token("op", sym:sub(1, i), ctx))
                self.index = self.index - #sym + i
                self.col = self.col - #sym + i
                return
            end
        end
    end

    function context:lex_word()
        local word = ""
        local ctx = self:copy()
        while self:is_index_valid() do
            if self:char():match("[%p \n\t\r]") then
                table.insert(self.tokens, new_token("word", word, ctx))
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
        elseif char == "\"" then
            -- Lex string
            context:lex_string()
        elseif char:match("%p") then
            -- Lex punctuation
            context:lex_operator()
        else
            -- Lex word
            context:lex_word()
        end
    end

    for i = 1, #context.tokens do
        print(i .. " => [" .. context.tokens[i].label .. ": " .. context.tokens[i].value .. "] col = " .. context.tokens[i].col)
    end

    return context.tokens
end

return lexer
