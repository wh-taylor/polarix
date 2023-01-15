function read_file(file)
    local f = io.open(file, "rb")
    if f == nil then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

function main()
    print(read_file(arg[1]))
end

main()

