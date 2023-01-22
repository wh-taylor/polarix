local lexer = {}

local ops = { "(", ")", "{", "}", "[", "]", ".", ",", "/", "\\", "+", "-", "=",
  "!", "@", "#", "$", "%", "^", "&", "*", "`", "~", "?", "<", ">", ":", ";",
  "|", "->", "=>", ">=", "<=", "==", "!=", "+=", "-=", "*=", "/=", "%=", "::" }

local operators = {}

for i = 1, #ops do
    operators[ops[i]] = true
end

function new_token(label, value, context)
    local token = {
        label = label,
        value = value,
        file_name = context.file_name,
        code = context.code,
        index = context.index,
        line = context.line,
        col = context.col,
    }

    function token:match(label, value)
        return self.label == label and self.value == value
    end

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
                    table.insert(self.tokens,
                        new_token("num", num:sub(1,-2), ctx))
                    table.insert(self.tokens, new_token("op", ".", dot_ctx))
                else
                    table.insert(self.tokens, new_token("num", num, ctx))
                end
                if not self:char():match("[%d%p \n\t\r]") then
                    local ctx = self:copy()
                    self:lex_word()
                    local name = self.tokens[#self.tokens].value
                    self.tokens[#self.tokens] = new_token("unit", name, ctx)
                end
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
        
        local single_char_sequences = {
            ["a"] = "\a",  ["b"] = "\b",
            ["f"] = "\f",  ["n"] = "\n",
            ["r"] = "\r",  ["t"] = "\t",
            ["v"] = "\v",  ["'"] = "'",
            ["\\"] = "\\", ["\""] = "\"",
        }
        if single_char_sequences[self:char()] then
            return single_char_sequences[self:char()] end
        
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

    function context:lex_char()
        local char = ""
        local ctx = self:copy()
        self:increment()
        while self:is_index_valid() do
            if self:char() == "'" then
                if #char > 1 then
                    return { ctx = ctx, err = "char too long" } end
                table.insert(self.tokens, new_token("char", char, ctx))
                self:increment()
                return
            end
            
            if self:char() == "\\" then
                char = char .. self:lex_escape_sequence()
            else
                char = char .. self:char()
            end
            
            self:increment()
        end
        return { ctx = ctx, err = "unclosed char" }
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
        return { ctx = ctx, err = "unclosed string" }
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
            if self:char():match("[%p \n\t\r]") and self:char() ~= "_" then
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
    local context = new_context(file_name, code .. "\n")
    
    while context:is_index_valid() do
        local char = context:char()
        local err
        
        if char:match("%d") then
            -- Lex number
            err = context:lex_number()
        elseif char:match("[ \n\t\r]") then
            -- Do nothing!
            err = context:increment()
        elseif char == "\"" then
            -- Lex string
            err = context:lex_string()
        elseif char == "'" then
            -- Lex string
            err = context:lex_char()
        elseif char:match("%p") then
            -- Lex punctuation
            err = context:lex_operator()
        else
            -- Lex word
            err = context:lex_word()
        end
        
        if err ~= nil then return nil, err end
    end

    table.insert(context.tokens, new_token("eof", "eof", context))
    return context.tokens
end

return lexer
