local function parse(path, index, sep, comm)
    sep = sep or ","
    comm = comm or "#"
    local tab = {}
    local keys = {}
    local ii
    for line in io.lines(path) do
        local s, e = line:find("%s*"..comm)
        local line = line:sub(1, (s or 0) - 1)
        if line ~= "" then
            if #keys == 0 then
                local i = 1
                for key in line:gmatch("([^"..sep.."]+)") do
                    if key == index then
                        ii = i
                    else
                        keys[i] = key
                    end
                    i = i + 1
                end
            else
                local row = {}
                local i = 1
                local id
                for val in line:gmatch("([^"..sep.."]+)") do
                    if i == ii then
                        id = val
                    else
                        row[keys[i]] = val
                    end
                    i = i + 1
                end
                if id == nil then
                    table.insert(tab, row)
                else
                    tab[id] = row
                end
            end
        end
    end
    return tab
end

return {parse=parse}
