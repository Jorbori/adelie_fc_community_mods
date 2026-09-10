util = {
    deepcopy = function(tbl, visited)
        if type(tbl) ~= "table" then return tbl end
        if visited and visited[tbl] then return visited[tbl] end

        local vis = visited or {}
        local res = {}
        vis[tbl] = res
        for k, v in pairs(tbl) do res[util.deepcopy(k, vis)] = util.deepcopy(v, vis) end
        return setmetatable(res, getmetatable(tbl))
    end,
    split = function(inputstr, sep)
        if sep == nil then
            sep = "%s+" -- Default to splitting by one or more whitespace characters
        end
        if inputstr == nil then
            return {}
        end
        local t={}
        local i = 1
        for str in string.gmatch(inputstr, "([^"..sep.."]*)") do
            if str ~= "" or sep == "" then -- Handle empty strings when sep is empty, or non-empty strings
                t[i] = str
                i = i + 1
            end
        end
        return t
    end,
    sign = function(v) return v > 0 and 1 or (v < 0 and -1 or 0) end,
    appr = function(val, target, amount)
        if val > target then return math.max(val - amount, target) end
        return math.min(val + amount, target)
    end,
    color = function(i)
        colors = {
            -- p8 default palette
            [0] = {0, 0, 0},
            [1] = {29, 43, 83},
            [2] = {126, 37, 83},
            [3] = {0, 135, 81},
            [4] = {171, 82, 54},
            [5] = {95, 87, 79},
            [6] = {194, 195, 199},
            [7] = {255, 241, 232},
            [8] = {255, 0, 77},
            [9] = {255, 163, 0},
            [10] = {255, 236, 39},
            [11] = {0, 228, 54},
            [12] = {41, 173, 255},
            [13] = {131, 118, 156},
            [14] = {255, 119, 168},
            [15] = {255, 204, 170},
            -- p8 secret palette
            [128] = {41, 24, 20},
            [129] = {17, 29, 53},
            [130] = {66, 33, 54},
            [131] = {18, 83, 89},
            [132] = {116, 47, 41},
            [133] = {73, 51, 59},
            [134] = {162, 136, 121},
            [135] = {243, 239, 125},
            [136] = {190, 18, 80},
            [137] = {255, 108, 36},
            [138] = {168, 231, 46},
            [139] = {0, 181, 67},
            [140] = {6, 90, 181},
            [141] = {117, 70, 101},
            [142] = {255, 110, 89},
            [143] = {255, 157, 129}
        }
        return colors[i][1]/255, colors[i][2]/255, colors[i][3]/255
    end
}