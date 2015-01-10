local UMAX1 = 2^8-1
local UMAX2 = 2^16-1
local UMAX4 = 2^32-1
local UMAX8 = 2^64-1

local function uint(s)
    local x = 0
    for i = 1, #s do
        x = x * 256 + s:byte(i)
    end
    return x
end

local PF = {}
PF.__index = PF

function PF:uint(s)   return uint(self.fp:read(s)) end
function PF:uint8()   return uint(self.fp:read(1)) end
function PF:uint16()  return uint(self.fp:read(2)) end

function PF:vlv()
    local v = 0
    local d = self.fp:read(1):byte()
    while d >= 0x80 do
        v = (v * 0x80) + (d - 0x80)
        d = self.fp:read(1):byte()
    end
    return (v * 0x80) + d
end

function PF:str()
    local s = ""
    local c = self.fp:read(1)
    while c ~= "\x00" do
        s = s..c
        c = self.fp:read(1)
    end
    return s
end

function PF:get(name)
    local umax = 2^(self.size*8)-1
    local offset = self.datapos
    local idx
    for i = 1, self.nentities do
        if self.names[i] == name then
            idx = i
            break
        end
        local partlen = self.partlens[i]
        for j = 1, #partlen do
            offset = offset + partlen[j] * self.size * 2
        end
    end
    self.fp:seek("set", offset)
    local x0, x1, y0, y1 = unpack(self.bboxes[idx])
    local partlen = self.partlens[idx]
    local parts = {}
    for i = 1, #partlen do
        local points = {}
        for j = 1, partlen[i] do
            local ulon = self:uint(self.size)
            local ulat = self:uint(self.size)
            local lon = x0 + ulon * (x1 - x0) / umax
            local lat = y0 + ulat * (y1 - y0) / umax
            points[#points+1] = {lon, lat}
        end
        parts[#parts+1] = points
    end
    return parts, {x0, y0, x1, y1}
end

local function open(fname)
    local fp = io.open(fname, "r")
    local self = setmetatable({fp=fp}, PF)
    local sig = self.fp:read(2)
    assert(sig == "PF", "invalid signature: "..sig)
    local ver = self:uint8()
    assert(ver == 0, "invalid version: "..tostring(ver))
    local size = self:uint8()
    assert(size == 1 or size == 2 or size == 4 or size == 8,
        "invalid size: "..tostring(size))
    local nrows = self:vlv()
    local nentities = self:vlv()
    local names, bboxes, partlens = {}, {}, {}
    for i = 1, nentities do
        names[i] = self:str()
        local nparts = self:vlv()
        local x0 = self:uint16()
        local x1 = self:uint16()
        local y0 = self:uint16()
        local y1 = self:uint16()
        x0 = x0 * 360 / UMAX2 - 180
        x1 = x1 * 360 / UMAX2 - 180
        y0 = y0 * 180 / UMAX2 - 90
        y1 = y1 * 180 / UMAX2 - 90
        bboxes[i] = {x0, x1, y0, y1}
        local partlen = {}
        for j = 1, nparts do
            partlen[j] = self:vlv()
        end
        partlens[i] = partlen
    end
    self.nentities = nentities
    self.datapos = self.fp:seek()
    self.size = size
    self.bboxes = bboxes
    self.names = names
    self.partlens = partlens
    return self
end

return {open=open}
