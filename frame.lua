local sep = ":"

local function save(fname, model, projection, bounding)
    local frm = io.open(fname, "w")
    frm:write("type", sep, model.type, "\n")
    if model.type == "ellipsoid" then
        frm:write("a", sep, model.a, "\n")
        frm:write("b", sep, model.b, "\n")
        frm:write("e", sep, model.e, "\n")
        frm:write("f", sep, model.f, "\n")
    elseif model.type == "sphere" then
        frm:write("r", sep, model.r, "\n")
    end
    frm:write("proj", sep, projection.name, "\n")
    frm:write("lon", sep, projection.lon, "\n")
    frm:write("lat", sep, projection.lat, "\n")
    frm:write("x0", sep, bounding.x0, "\n")
    frm:write("y0", sep, bounding.y0, "\n")
    frm:write("x1", sep, bounding.x1, "\n")
    frm:write("y1", sep, bounding.y1, "\n")
    frm:close()
end

local function load(fname)
    local frm = io.open(fname, "r")
    local function get(field)
        local line = frm:read()
        local got = line:sub(1, #field)
        assert(got == field, "expected field "..field.." but got "..got)
        return line:sub(#field+#sep+1)
    end
    local model = {}
    model.type = get "type"
    if model.type == "ellipsoid" then
        model.a = tonumber(get "a")
        model.b = tonumber(get "b")
        model.e = tonumber(get "e")
        model.f = tonumber(get "f")
    elseif model.type == "sphere" then
        model.r = tonumber(get "r")
    end
    local projection = {}
    projection.name = get "proj"
    projection.lon = tonumber(get "lon")
    projection.lat = tonumber(get "lat")
    local bounding = {}
    bounding.x0 = tonumber(get "x0")
    bounding.y0 = tonumber(get "y0")
    bounding.x1 = tonumber(get "x1")
    bounding.y1 = tonumber(get "y1")
    frm:close()
    return model, projection, bounding
end

return {save=save, load=load}

--~ local model = {type="sphere", r=6378137}
--~ local projection = {name="AzimuthalEqualArea", lon=-45, lat=-23}
--~ local bounding = {x0=-2000, y0=-2500, x1=1500, y1=1000}
--~ 
--~ save("test.frm", model, projection, bounding)

--~ local m, p, b = load "test.frm"
--~ print(p.lon)
