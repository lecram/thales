local function distance(lon1, lat1, lon2, lat2, r)
    r = r or 6378137
    local dlat = math.rad(lat2 - lat1)
    local dlon = math.rad(lon2 - lon1)
    lat1, lat2 = math.rad(lat1), math.rad(lat2)
    local a1, a2, a, c
    a1 = math.sin(dlat/2) * math.sin(dlat/2)
    a2 = math.sin(dlon/2) * math.sin(dlon/2) * math.cos(lat1) * math.cos(lat2)
    a = a1 + a2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return r * c
end

return {distance=distance}
