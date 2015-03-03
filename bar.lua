local size = 30

local function bar(n)
    return coroutine.wrap(
        function ()
            local lastdone = 0
            io.write("\r["..string.rep("-", size).."]")
            for i = 1, n do
                local done = math.floor(i * size / n)
                if done ~= lastdone then
                    io.write("\r["..string.rep("#", done))
                    io.flush()
                    lastdone = done
                end
                coroutine.yield(i)
            end
            io.write("\n")
        end
    )
end

return {bar = bar}
