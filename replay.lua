-- replay.lua
replay = {}

-- udlrzx
local function encodeInput(inp)
    if not inp then return "000000" end
    return (inp.up and "1" or "0") .. (inp.down and "1" or "0") ..
           (inp.left and "1" or "0") .. (inp.right and "1" or "0") ..
           (inp.b1 and "1" or "0") .. (inp.b2 and "1" or "0")
end

local function decodeInput(str)
    return {
        up    = str:sub(1,1) == "1", down  = str:sub(2,2) == "1",
        left  = str:sub(3,3) == "1", right = str:sub(4,4) == "1",
        b1    = str:sub(5,5) == "1", b2    = str:sub(6,6) == "1"
    }
end

function replay.save(stageIdx, seed, playerData, finalFrame)
    love.filesystem.createDirectory("replays")
    local filename = "replays/replay_" .. os.time() .. ".txt"

    -- meta data
    local p1 = playerData[1]
    local p2 = playerData[2]
    local data = tostring(stageIdx) .. "\n"
    data = data .. tostring(seed) .. "," .. p1.char .. "," .. p1.skin .. "," .. p1.username .. "\n"
    data = data .. p2.id .. "," .. p2.char .. "," .. p2.skin .. "," .. p2.username .. "\n"

    -- inputs
    local src1 = inputSource.getInputSource(p1.id)
    local src2 = inputSource.getInputSource(p2.id)
    for f = 1, finalFrame do
        data = data .. encodeInput(src1.record[f]) .. "|" .. encodeInput(src2.record[f]) .. "\n"
    end

    love.filesystem.write(filename, data)
end

function replay.load(filename)
    local contents = love.filesystem.read(filename)
    return replay.loadFromString(contents)
end

function replay.loadFromString(contents)
    if not contents or contents == "" then return nil end

    local lines = {}
    for s in contents:gmatch("[^\r\n]+") do table.insert(lines, s) end

    -- metadata
    if #lines < 3 then return nil end -- not enough metadata
    local stageIdx = tonumber(lines[1])
    if not stageIdx then return nil end -- stage idx not a number
    local p1_parts = {}; for part in string.gmatch(lines[2], '([^,]+)') do table.insert(p1_parts, part) end
    local p2_parts = {}; for part in string.gmatch(lines[3], '([^,]+)') do table.insert(p2_parts, part) end
    if #p1_parts < 4 or #p2_parts < 4 then return nil end -- player data missing
    local p1_id = tonumber(p1_parts[1])
    local p2_id = tonumber(p2_parts[1])
    local p1_skin = tonumber(p1_parts[3])
    local p2_skin = tonumber(p2_parts[3])
    if not p1_id or not p2_id or not p1_skin or not p2_skin then return nil end -- player data are numbers
    local p1 = {id = p1_id, char = p1_parts[2], skin = p1_skin, username = p1_parts[4]}
    local p2 = {id = p2_id, char = p2_parts[2], skin = p2_skin, username = p2_parts[4]}

    -- inputs
    local inputs = { [p1.id] = {}, [p2.id] = {} }
    for i = 4, #lines do
        local f = i - 3
        local sep = lines[i]:find("|")
        if not sep then return nil end -- missing delimeter
        local p1_str = lines[i]:sub(1, sep-1)
        local p2_str = lines[i]:sub(sep+1)
        if #p1_str ~= 6 or #p2_str ~= 6 then return nil end -- all buttons there
        inputs[p1.id][f] = decodeInput(p1_str)
        inputs[p2.id][f] = decodeInput(p2_str)
    end

    return {stageIdx = stageIdx, playerData = {p1, p2}, inputs = inputs}
end