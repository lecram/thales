local abs = math.abs
local rad = math.rad
local deg = math.deg
local cos = math.cos
local sin = math.sin
local tan = math.tan
local acos = math.acos
local asin = math.asin
local atan = math.atan
local atan2 = math.atan2
local sqrt = math.sqrt
local pi = math.pi
local huge = math.huge

-- Lambert Azimuthal Equal-Area Projection for the Spherical Earth.

local AzimuthalEqualArea = {}
AzimuthalEqualArea.__index = AzimuthalEqualArea

function AzimuthalEqualArea:map(lon, lat)
    lon, lat = rad(lon), rad(lat)
    lon = lon - self.lon0
    local k, x, y
    k = sqrt(2 / (1 + sin(self.lat0) * sin(lat) + cos(self.lat0) * cos(lat) * cos(lon)))
    x = self.r * k * cos(lat) * sin(lon)
    y = self.r * k * (cos(self.lat0) * sin(lat) - sin(self.lat0) * cos(lat) * cos(lon))
    return x, y
end

function AzimuthalEqualArea:inv(x, y)
    local p = sqrt(x*x + y*y)
    local c = 2 * asin(p / (2 * self.r))
    local lon, lat
    -- FIXME: In the formulas below, should it be atan or atan2?
    if self.lat0 == pi / 2 then
        -- North Polar Aspect.
        lon = self.lon0 + atan(x/(-y))
    elseif self.lat0 == -pi / 2 then
        -- South Polar Aspect.
        lon = self.lon0 + atan(x/y)
    else
        -- Any other Oblique Aspect.
        local den = p * cos(self.lat0) * cos(c) - y * sin(self.lat0) * sin(c)
        lon = self.lon0 + atan(x * sin(c) / den)
    end
    lat = asin(cos(c) * sin(self.lat0) + y * sin(c) * cos(self.lat0) / p)
    lon, lat = deg(lon), deg(lat)
    return lon, lat
end

local projs = {
    AzimuthalEqualArea=AzimuthalEqualArea
}

-- Generic interface.

local function Proj(name, origin, radius)
    local proj = {}
    proj.lon0, proj.lat0 = unpack(origin or {0, 0})
    proj.lon0, proj.lat0 = rad(proj.lon0), rad(proj.lat0)
    proj.r = radius or 6378137
    return setmetatable(proj, projs[name])
end

-- Utilities.

-- region is a list of polygons in geographic coordinates.

local function bbox(region)
    local x0, y0, x1, y1 = huge, huge, -huge, -huge
    for i = 1, #region do
        local points = region[i]
        for j = 1, #points do
            local x, y = unpack(points[j])
            x0 = x < x0 and x or x0
            y0 = y < y0 and y or y0
            x1 = x > x1 and x or x1
            y1 = y > y1 and y or y1
        end
    end
    return x0, y0, x1, y1
end

local function centroid(region)
    local epsilon = 1e-10
    local x0, y0, x1, y1 = bbox(region)
    local lon0 = (x0 + x1) / 2
    local lat0 = (y0 + y1) / 2
    local lon1, lat1
    while true do
        local prj = Proj("AzimuthalEqualArea", {lon0, lat0})
        local cw = {}
        for i = 1, #region do
            local points = region[i]
            local xys = {}
            for j = 1, #points do
                xys[j] = {prj:map(unpack(points[j]))}
            end
            if xys[#xys][0] ~= xys[1][0] or xys[#xys][1] ~= xys[1][1] then
                xys[#xys+1] = xys[1]
            end
            -- http://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
            local cx, cy, sa = 0, 0, 0
            for j = 1, #xys-1 do
                local x0, y0 = unpack(xys[j])
                local x1, y1 = unpack(xys[j+1])
                local f = x0 * y1 - x1 * y0
                cx = cx + (x0 + x1) * f
                cy = cy + (y0 + y1) * f
                sa = sa + f
            end
            cx = cx / (3 * sa)
            cy = cy / (3 * sa)
            cw[#cw+1] = {cx, cy, sa}
        end
        local cx, cy, sw = 0, 0, 0
        for i = 1, #cw do
            local x, y, w = unpack(cw[i])
            cx = cx + x * w
            cy = cy + y * w
            sw = sw + w
        end
        cx = cx / sw
        cy = cy / sw
        lon1, lat1 = prj:inv(cx, cy)
        if abs(lon1-lon0) <= epsilon and abs(lat1-lat0) <= epsilon then
            break
        end
        lon0, lat0 = lon1, lat1
    end
    return lon1, lat1
end

return {Proj=Proj, bbox=bbox, centroid=centroid}
