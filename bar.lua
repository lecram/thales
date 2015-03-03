local size = 30

local function bar(n)
    return coroutine.wrap(
        function ()
            for i = 1, n do
                local done = math.floor(i * size / n)
                local rest = size - done
                io.write("\r["..string.rep("#", done)..string.rep("-", rest).."]")
                io.flush()
                coroutine.yield(i)
            end
            io.write("\n")
        end
    )
end

return {bar = bar}
