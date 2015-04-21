local function get_nums(str)
    local nums = {}
    for s in string.gmatch(str, "-?%d+") do
        nums[#nums+1] = tonumber(s)
    end
    return unpack(nums)
end

local function bytes2num(str)
    local num = 0
    for i = 1, #str do
        num = num * 256
        num = num + str:byte(i, i)
    end
    return num
end

local function utf8to32(utf8str)
    assert(type(utf8str) == "string")
    local res, seq, val = {}, 0, nil
    for i = 1, #utf8str do
        local c = string.byte(utf8str, i)
        if seq == 0 then
            table.insert(res, val)
            seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or
                  c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or
                  error("invalid UTF-8 character sequence")
            val = bit.band(c, 2^(8-seq) - 1)
        else
            val = bit.bor(bit.lshift(val, 6), bit.band(c, 0x3F))
        end
        seq = seq - 1
    end
    table.insert(res, val)
    return res
end

local BDF = {}
BDF.__index = BDF

local function open(fname)
    local fp = io.open(fname)
    if fp == nil then
        return nil
    else
        local bdf = setmetatable({fp=fp}, BDF)
        bdf:_get_info()
        bdf:_build_index()
        return bdf
    end
end

function BDF:_get_val(key)
    for line in self.fp:lines() do
        local cur_key, cur_val = line:match("(%S+)%s*(.*)")
        if cur_key == key then
            return cur_val
        end
    end
end

function BDF:_get_info()
    if self:_get_val("STARTFONT") == nil then
        error("not a BDF file")
    end
    self.w, self.h, self.x, self.y = get_nums(self:_get_val("FONTBOUNDINGBOX"))
    self.n = tonumber(self:_get_val("CHARS"))
end

function BDF:_build_index()
    local index = {}
    while true do
        local cur_pos = self.fp:seek()
        local cur_code_str = self:_get_val("ENCODING")
        if cur_code_str == nil then
            break
        end
        local cur_code = tonumber(cur_code_str)
        self:_get_val("ENDCHAR")
        index[cur_code] = cur_pos
    end
    self.index = index
end

function BDF:get_glyph(code)
    local pos = self.index[code] or self.index[0]
    self.fp:seek("set", pos)
    local w, h, x, y = get_nums(self:_get_val("BBX"))
    self:_get_val("BITMAP")
    local bitmap = ""
    for i = 1, h do
        for j = 1, math.ceil(w / 8) do
            local byte = string.char(tonumber(self.fp:read(2), 16))
            bitmap = bitmap .. byte
        end
        self.fp:read() -- '\n'
    end
    return {w=w, h=h, x=x, y=y, bitmap=bitmap}
end

function BDF:get_bitmap(code, con, coff, sep)
    local glyph = self:get_glyph(code)
    local pad_left = glyph.x - self.x
    local pad_right = self.w - glyph.w - pad_left
    local pad_bottom = glyph.y - self.y
    local pad_top = self.h - glyph.h - pad_bottom
    local bytes_per_row = math.ceil(glyph.w / 8)
    local bit_pad = bytes_per_row * 8 - glyph.w
    local nums = {}
    for i = 1, pad_top do
        nums[i] = 0
    end
    local s = 1
    for i = 1, glyph.h do
        local e = s + bytes_per_row
        local num = bytes2num(glyph.bitmap:sub(s, e-1))
        nums[pad_top+i] = math.floor(num / 2 ^ bit_pad)
        s = e
    end
    for j = 1, pad_bottom do
        nums[pad_top+glyph.h+j] = 0
    end
    local rows = {}
    for j = 1, self.h do
        local row = coff:rep(pad_left)
        local num = nums[j]
        for k = 1, glyph.w do
            row = (num % 2 == 1 and con or coff) .. row
            num = math.floor(num / 2)
        end
        row = row .. coff:rep(pad_right)
        rows[j] = row
    end
    return table.concat(rows, sep)
end

function BDF:putchar(image, code, x, y, r, g, b)
    local bitmap = self:get_bitmap(code, "#", " ", "")
    local data = image.img.data
    local row_offset = (y * image.width + x) * 4
    local bitidx = 1
    for i = 1, self.h do
        local offset = row_offset
        for j = 1, self.w do
            local bit = bitmap:sub(bitidx, bitidx)
            if bit == "#" then
                data[offset]   = r
                data[offset+1] = g
                data[offset+2] = b
                data[offset+3] = 255
            end
            bitidx = bitidx + 1
            offset = offset + 4
        end
        row_offset = row_offset + image.width * 4
    end
end

function BDF:print(image, codes, x, y, r, g, b)
    for i, c in ipairs(codes) do
        self:putchar(image, c, x+(i-1)*self.w, y, r, g, b)
    end
end

return {open=open, utf8to32=utf8to32}

--local bdf = open("t0-16i-uni.bdf")
--local bdf = open("unifont-7.0.06.bdf")
--print(bdf:get_bitmap(0x263A, "#", " ", "\n"))
--print(bdf:get_bitmap(0x263B, "#", " ", "\n"))
