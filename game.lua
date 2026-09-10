-- In-game root

require("objectSystem")
require("inputSource")
require("hitbox")
require("stage")
require("camera")
require("cpu")
require("replay")
local config = require("config")

INPUT_DELAY = tonumber(config["input_delay"])
SYNC_TOLERANCE = tonumber(config["sync_tolerance"])

MATCH_LENGTH = 9000

frontierFrame = 1
frameCounter = 1

objects = {}
hitboxes = {}
history = {}

--
-- particles_fg, particles_mg, particles_bg = nil
--

matchState = "STARTING" -- STARTING, PLAYING, GAMEOVER
gameOverTimer = 60
gameStartTimer = 60
gameQuitTimer = 43
winner = nil

-- intercept calls to global table.insert function and redirect calls to the metatable wrapper
-- // hacky, but for an unofficial fix this avoids making a ton of edits wherever the particle tables are updated
local default_table_insert = table.insert

table.insert = function(t, ...)
    local mt = getmetatable(t)
    if mt and mt.__is_unique_keys_table then
        local args = {...}
        local value = args[1]  -- breaks on calls to table.insert(t, key, val)
        return t:insert(value)
    end
    return default_table_insert(t, ...)
end

-- metatable wrapper for table that ensures
--   1) every value has a unique key, and
--   2) keys are not reused if a value is removed
--      => if every particle has a unique key, we can use the keys to track particles and avoid deep copying entire tables into history
function unique_keys_table()
    local data = {}      -- actual table where values are stored
    local curr_key = 1   --
    local new_keys = {}  --
    
    local methods = {
        insert = function(self, value)
            if value == nil then return nil end
            new_keys[#new_keys + 1] = curr_key
            data[curr_key] = value
            curr_key = curr_key + 1
        end,
        
        remove = function(self, key)
            if key == nil then return nil end
            local temp = data[key]
            if temp ~= nil then
                data[key] = nil
            end
            return temp
        end,
        
        --
        all = function(self)
            return next, data, nil
        end,
        
        reset_new_keys = function(self)
            local temp, temp_size = new_keys, #new_keys
            new_keys = {}
            return temp
        end,
    }
    
    local proxy = {}
    
    local metatable = {
        __is_unique_keys_table = true,
        
        -- __newindex = function(self, key, value)  -- not sure if needed?
            -- if data[key] ~= nil then
                -- error("unsupported operation")
            -- end
            -- data[key] = value
        -- end,
        
        __index = function(t, key)
            if methods[key] then
                return methods[key]
            end
            return data[key]
        end,
    }
    
    return setmetatable(proxy, metatable)
end

game = {
    mode = "ONLINE",
    remoteFrame = 0,
    playbackSpeed = 1,

    init = function(stageIdx, playerData, matchMode, replayData)
        game.mode = matchMode or "ONLINE"
        game.stageIdx = stageIdx
        game.playerData = playerData

        game.pendingRollback = nil
        game.remoteFrame = 0

        objects = {}
        hitboxes = {}
        history = {}
        particles_bg = unique_keys_table()
        particles_mg = unique_keys_table()  -- particles_mg placed here for the goldstool's beam effect, as it needs to happen in front of background elements but behind players
        particles_fg = unique_keys_table()

        frameCounter = 1
        frontierFrame = 1

        matchState = "STARTING"
        gameOverTimer = 60
        gameStartTimer = 60
        gameQuitTimer = 43
        winner = nil

        if not game.entityCanvas then
            game.entityCanvas = love.graphics.newCanvas(GAME_WIDTH, GAME_HEIGHT)
        end

        overlay.setInputDisplay("")
        love.audio.play("readysetgo", "static")

        stage.init(stageIdx)

        inputSource.resetInputSources()
        for i, p in ipairs(playerData) do
            inputSource.createInputSource(p.id)
            local source = inputSource.getInputSource(p.id)
            for j = 1, INPUT_DELAY do
                source.record[j] = {up=false, down=false, left=false, right=false, b1=false, b2=false}
            end
        end

        if game.mode == "REPLAY" and replayData then
            local p1_id = playerData[1].id
            local p2_id = playerData[2].id
            inputSource.getInputSource(p1_id).record = replayData.inputs[p1_id]
            inputSource.getInputSource(p2_id).record = replayData.inputs[p2_id]
        end

        game.loadObjects(playerData,stage.spawnDist)
        game.saveFrame()
    end,
    update = function()
        
        if game.startupDelay and game.startupDelay > 0 then
            game.startupDelay = game.startupDelay - 1
            return
        end

        if game.pendingRollback then
            game.handleRollback(game.pendingRollback)
            game.pendingRollback = nil
        end

        if matchState == "PLAYING" or matchState == "STARTING" then 
            local escapeHeld = false
            if love.keyboard.isDown("escape") or controllerInput("back") then
                if gameQuitTimer > 0 then
                    gameQuitTimer = gameQuitTimer - 1
                    if gameQuitTimer == 0 then
                        if game.mode == "TRAINING" then
                            gameController.enterCSS(game.mode)
                        elseif game.mode == "REPLAY" then
                            gameController.enterTitle("replay_browser")
                        else
                            network.sendMessage("MATCHEND|FORFEIT", "reliable")
                            gameController.enterTitle()
                            return
                        end
                    end
                end
            else
                gameQuitTimer = 43
            end
        end

        if game.mode == "ONLINE" and game.remoteFrame > 0 then
            local isStalling = false

            if matchState ~= "GAMEOVER" then
                -- stall if running too far ahead
                if frontierFrame > game.remoteFrame - INPUT_DELAY + SYNC_TOLERANCE then
                    isStalling = true
                end
            end

            if isStalling then
                local targetFrame = frontierFrame + INPUT_DELAY
                local source = inputSource.getInputSource(tonumber(connectionID))
                local inp = source.record[targetFrame] or {up=false, down=false, left=false, right=false, b1=false, b2=false}
                
                network.sendInput(inp, targetFrame)
                return
            end
        end

        game.playbackSpeed = 1
        if game.mode == "REPLAY" then
            if input.checkDown("right") and not input.checkDown("left") then
                game.playbackSpeed = 4
            elseif input.checkDown("left") and not input.checkDown("right") then
                game.playbackSpeed = -4
            end
        end
        if game.playbackSpeed > 0 then
            for i = 1, game.playbackSpeed do
                game.advanceFrame()
            end
        else
            local target = math.max(1, frameCounter + game.playbackSpeed)
            game.jumpToFrame(target)
        end

        for key, p in particles_bg:all() do
            if p:update() then
                particles_bg:remove(key)
            end
        end
        for key, p in particles_mg:all() do
            if p:update() then
                particles_mg:remove(key)
            end
        end
        for key, p in particles_fg:all() do
            if p:update() then
                particles_fg:remove(key)
            end
        end
    end,
    -- In game.lua
    draw = function()
        love.graphics.clear(0, 0, 0, 1)

        if stage.bgColor then
            love.graphics.setColor(stage.bgColor)
            love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        end

        for _,p in particles_bg:all() do p:draw() end
        stage.draw_bg()
        for _,p in particles_mg:all() do p:draw() end

        local previous_canvas = love.graphics.getCanvas()

        love.graphics.setCanvas(game.entityCanvas)
        love.graphics.clear(0, 0, 0, 0)

        local draw_queue = {}
        for i, o in ipairs(objects) do draw_queue[i] = o end
        table.sort(draw_queue, function(a, b) return (a.layer or 0) < (b.layer or 0) end)
        for _, o in ipairs(draw_queue) do o.type.draw(o) end

        love.graphics.setCanvas(previous_canvas)

        love.graphics.setBlendMode("alpha", "premultiplied")

        love.graphics.setShader(silhouetteShader)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.draw(game.entityCanvas, -1, 0)
        love.graphics.draw(game.entityCanvas, 1, 0)
        love.graphics.draw(game.entityCanvas, 0, -1)
        love.graphics.draw(game.entityCanvas, 0, 1)

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(game.entityCanvas, 0, 0)

        love.graphics.setBlendMode("alpha", "alphamultiply")

        stage.draw_fg()
        for _,p in particles_fg:all() do p:draw() end

        hitbox.drawAll()
    end,
    spawnExplosion = function(x, y, side, color)
        if network.moddedConnection or ((not network.moddedConnection) and (game.mode == "REPLAY" or frameCounter >= frontierFrame)) then
            local sparks = {}
            for i = 1,15 do
                table.insert(sparks, {
                    a = love.math.random() * math.pi * 2,
                    v = love.math.random() * 8 + 2,
                    s = love.math.random() * 2 + 1
                })
            end
            table.insert(particles_fg, {
                x = x,
                y = y,
                side = side,
                color = color,
                timer = 0,
                duration = 35,
                sparks = sparks,
                update = function(p)
                    p.timer = p.timer + 1
                    for _, s in ipairs(p.sparks) do
                        s.v = s.v* 0.9
                    end
                    if p.timer >= p.duration then
                        return true
                    end
                end,
                draw = function(p)
                    local k = p.timer / p.duration
                    local k_inv = 1 - k
                    local fade = math.sqrt(k)

                    love.graphics.setBlendMode("add", "alphamultiply")

                    local stepped_alpha = math.ceil(k_inv * 4) / 4
                    love.graphics.setColor(p.color[1], p.color[2], p.color[3], stepped_alpha * 0.8)

                    local px, py = math.floor(p.x), math.floor(p.y)

                    -- outer circle
                    local r1 = math.floor(fade * 60)
                    for dy = -r1, r1 do
                        local w = math.floor(0.5 + math.sqrt(r1*r1 - dy*dy))
                        if w > 0 then
                            love.graphics.rectangle("fill", px - w, py + dy, w * 2, 1)
                        end
                    end

                    -- triangle bedam
                    local bw = math.floor(k_inv * 60)
                    local bl = math.floor(fade * 240)
                    if bl > 0 then
                        for d = 0, bl do
                            local current_w = math.floor(bw * (1 - (d / bl)))
                            if current_w > 0 then
                                local half_w = math.floor(current_w / 2)
                                if p.side == "top" then
                                    love.graphics.rectangle("fill", px - half_w, py + d, current_w, 1)
                                elseif p.side == "bottom" then
                                    love.graphics.rectangle("fill", px - half_w, py - d, current_w, 1)
                                elseif p.side == "left" then
                                    love.graphics.rectangle("fill", px + d, py - half_w, 1, current_w)
                                elseif p.side == "right" then
                                    love.graphics.rectangle("fill", px - d, py - half_w, 1, current_w)
                                end
                            end
                        end
                    end

                    -- sparks
                    for _, s in ipairs(p.sparks) do
                        local sx = math.floor(p.x + math.cos(s.a) * (fade * s.v * 15))
                        local sy = math.floor(p.y + math.sin(s.a) * (fade * s.v * 15))
                        local size = math.max(1, math.floor(s.s * k_inv))
                        love.graphics.rectangle("fill", sx - math.floor(size / 2), sy - math.floor(size / 2), size, size)
                    end

                    -- inner circle
                    love.graphics.setColor(1, 1, 1, stepped_alpha)
                    local r2 = math.floor(fade * 30)
                    for dy = -r2, r2 do
                        local w = math.floor(0.5 + math.sqrt(r2*r2 - dy*dy))
                        if w > 0 then
                            love.graphics.rectangle("fill", px - w, py + dy, w * 2, 1)
                        end
                    end

                    love.graphics.setBlendMode("alpha", "alphamultiply")
                    love.graphics.setColor(1, 1, 1, 1)
                end,
            })
        end
    end,
    init_smoke = function(x, y)
        if network.moddedConnection or ((not network.moddedConnection) and (game.mode == "REPLAY" or frameCounter >= frontierFrame)) then
            table.insert(particles_fg, {
                x = x + love.math.random() * 2 - 1,
                y = y + love.math.random() * 2 - 1,
                vx = love.math.random() * 0.6 - 0.3,
                vy = -0.1 - love.math.random() * 0.2,
                timer = 0,
                duration = 15,
                flipX = love.math.random() > 0.5 and -1 or 1,
                flipY = love.math.random() > 0.5 and -1 or 1,
                update = function(p)
                    p.x = p.x + p.vx
                    p.y = p.y + p.vy
                    p.timer = p.timer + 1
                    if p.timer >= p.duration then
                        return true
                    end
                end,
                draw = function(p)
                    local frame = math.floor(p.timer / p.duration * 3) + 1
                    if frame > 3 then frame = 3 end
                    local dx, dy = math.floor(p.x), math.floor(p.y)
                    sprites.draw(sprites.smoke[frame], p.flipX == -1 and dx + 8 or dx, p.flipY == -1 and dy + 8 or dy, 0, p.flipX, p.flipY, 0, 0)
                end,
            })
        end
    end,
    drawUI = function()
        local font = love.graphics.getFont()

        local actualFrame = frameCounter
        if matchState == "GAMEOVER" then
            actualFrame = frameCounter - (30 - gameOverTimer)
        end

        local displayFrames = math.max(0, MATCH_LENGTH - math.max(0, actualFrame - 30))
        local totalSeconds = math.ceil(displayFrames / 30)
        local m = math.floor(totalSeconds / 60)
        local s = totalSeconds % 60
        local timeStr = string.format("%d:%02d", m, s)

        local tw = font:getWidth(timeStr)
        local tx = math.floor(GAME_WIDTH / 2 - tw / 2)
        local ty = 8

        love.graphics.setColor(util.color(0))
        love.graphics.print(timeStr, tx + 1, ty + 1)

        love.graphics.setColor(util.color(7))
        love.graphics.print(timeStr, tx, ty)
        love.graphics.setColor(1, 1, 1, 1)

        for i, o in ipairs(objects) do
            if o.stocks and (o.active or o.stocks > 0) then
                local isMe
                if game.mode == "REPLAY" then
                    isMe = (o.playerNum == 1)
                else
                    isMe = o.connectionID and o.connectionID == connectionID
                end

                local base_x = GAME_WIDTH / 2 + (isMe and -40 or 40)
                local stock_spacing = 9
                local stock_width = 3 * stock_spacing
                local start_x = base_x - math.floor(stock_width / 2)
                local sy = 2

                local name = o.username

                love.graphics.setColor(util.color(0))
                love.graphics.print(name, base_x - font:getWidth(name)/2 + 1, sy+1)
                love.graphics.setColor(util.color(7))
                love.graphics.print(name, base_x - font:getWidth(name)/2, sy)

                for s = 1, o.stocks do
                    local sx = start_x + (s - 1) * stock_spacing
                    sprites.draw(sprites["heart"], sx, sy+7)
                end

                local dmg_str = o.damage .. "%"
                local scale = 1.5
                local text_w = font:getWidth(dmg_str) * scale
                local text_x = base_x - math.floor(text_w / 2)
                local text_y = sy + 18

                local dmg_color = o.damage > 80 and 8 or o.damage > 40 and 9 or 7

                love.graphics.setColor(util.color(0))
                love.graphics.print(dmg_str, text_x + 1, text_y + 1, 0, scale, scale)

                love.graphics.setColor(util.color(dmg_color))
                love.graphics.print(dmg_str, text_x, text_y, 0, scale, scale)
            end
        end

        if matchState == "GAMEOVER" then
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT) -- Scaled to 512
            love.graphics.setColor(1, 1, 1, 1)

            sprites.draw(sprites["ko"], GAME_WIDTH/2 - sprites["ko"]:getPixelWidth()/2, GAME_HEIGHT/2 - sprites["ko"]:getPixelHeight()/2)

            if winner == "DRAW" then
                love.graphics.print("DRAW!", 184, 240)
            elseif tonumber(winner) == tonumber(connectionID) then
                love.graphics.setColor(0, 1, 0)
                love.graphics.print("YOU WIN!", 152, 240)
            else
                love.graphics.setColor(1, 0, 0)
                love.graphics.print("YOU LOSE!", 144, 240)
            end
            love.graphics.setColor(1, 1, 1)
        elseif gameQuitTimer < 43 then
            love.graphics.setColor(util.color(0))
            love.graphics.print("Quit match?", 5, 5)
            love.graphics.setColor(util.color(7))
            love.graphics.print("Quit match?", 4, 4)

            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", 5, 12, 43, 4)
            love.graphics.setColor(util.color(8))

            local x = math.max(0, gameQuitTimer) / 43
            love.graphics.rectangle("fill", 4, 11, (1 - (1 - x) * (1 - x)) * 43, 4)
            love.graphics.setColor(1, 1, 1)
        end

        if frameCounter < 90 then
            local spr = sprites[frameCounter<30 and "ready" or frameCounter<60 and "set" or "go"]
            sprites.draw(spr, GAME_WIDTH/2 - spr:getPixelWidth()/2, GAME_HEIGHT/2 - spr:getPixelHeight())
        end

        if game.mode == "REPLAY" then
            if game.playbackSpeed ~= 1 then
                local prefix = game.playbackSpeed > 0 and ">> " or "<< "
                local speedText = prefix .. math.abs(game.playbackSpeed) .. "x"
                love.graphics.setColor(util.color(0))
                love.graphics.print(speedText, 212 + 1, 8 + 1)
                love.graphics.setColor(util.color(11))
                love.graphics.print(speedText, 212, 8)
            end
            local text = "R replay"
            local tw = font:getWidth(text)
            local tx = math.floor(GAME_WIDTH / 2 - tw / 2)
            local ty = GAME_HEIGHT - 10
            if math.floor(frameCounter / 30) % 2 == 0 then
                love.graphics.setColor(util.color(0))
                love.graphics.print(text, tx - 1, ty)
                love.graphics.print(text, tx + 1, ty)
                love.graphics.print(text, tx, ty - 1)
                love.graphics.print(text, tx, ty + 1)
                love.graphics.setColor(util.color(7)) 
                love.graphics.print(text, tx, ty)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
    end,

    advanceFrame = function()
        frameCounter = frameCounter + 1
        if frameCounter > frontierFrame then
            frontierFrame = frameCounter
            game.recordInput()
        end

        if matchState == "PLAYING" then
            -- music on go
            if frameCounter == 90 and frameCounter == frontierFrame then
                game.playMusic()
            end

            local alivePlayers = {}
            for _, o in ipairs(objects) do
                if o.stocks and o.stocks > 0 then
                    table.insert(alivePlayers, o)
                end
            end

            local timeRemaining = MATCH_LENGTH - (frameCounter - 60)
            local isTimeOut = timeRemaining <= 0

            if #alivePlayers <= 1 or isTimeOut then
                matchState = "GAMEOVER"
                -- stop music on ko
                if game.mode == "REPLAY" or frameCounter == frontierFrame then
                    love.audio.play("ko", "static")
                    stopBGM()
                end
                if #alivePlayers == 1 then
                    winner = alivePlayers[1].connectionID
                elseif #alivePlayers == 0 then
                    winner = "DRAW"
                elseif isTimeOut then
                    local p1, p2
                    for _, o in ipairs(objects) do
                        if o.playerNum == 1 then p1 = o end
                        if o.playerNum == 2 then p2 = o end
                    end
                    if p1 and p2 then
                        -- break ties on stocks
                        if p1.stocks > p2.stocks then
                            winner = p1.connectionID
                        elseif p2.stocks > p1.stocks then
                            winner = p2.connectionID
                        else
                            -- break stock ties on damage
                            if p1.damage < p2.damage then
                                winner = p1.connectionID
                            elseif p2.damage < p1.damage then
                                winner = p2.connectionID
                            else
                                winner = "DRAW"
                            end
                        end
                    else
                        winner = "DRAW"
                    end
                end
            end
        end

        if matchState == "PLAYING" or matchState == "STARTING" then
            for _,o in ipairs(objects) do o.type.update(o) end
            hitbox.updateAll()
        end

        if matchState == "GAMEOVER" then
            if gameOverTimer > 0 then
                gameOverTimer = gameOverTimer - 1
                if gameOverTimer == 0 then
                    if game.mode == "TRAINING" then
                        replay.save(game.stageIdx, game.playerData, frontierFrame)
                        gameController.enterCSS(game.mode)
                    elseif game.mode == "REPLAY" then
                        gameController.enterTitle("replay_browser")
                    else
                        network.sendMessage("MATCHEND|" .. tostring(winner), "reliable")
                        replay.save(game.stageIdx, game.playerData, frontierFrame)
                    end
                end
            end
        elseif matchState == "STARTING" then
            if frameCounter > 60 then
                matchState = "PLAYING"
            end
        end

        game.saveFrame()
    end,

    recordInput = function()
        if game.mode == "REPLAY" then return end
        local targetFrame = frontierFrame + INPUT_DELAY
        local source = inputSource.getInputSource(tonumber(connectionID))
        if matchState ~= "PLAYING" then
            local nobtns = {up=false, down=false, left=false, right=false, b1=false, b2=false}
            source:recordInputForFrame(targetFrame, nobtns)
            network.sendInput(nobtns, targetFrame)
            return
        end
        local inp = source:recordLocalInputForFrame(targetFrame)
        network.sendInput(inp, targetFrame)

        if game.mode == "TRAINING" and cpuID ~= -1 then
            local cpuSource = inputSource.getInputSource(tonumber(cpuID))
            cpuSource:recordInputForFrame(targetFrame, cpu.getInputForFrame(game.playerData[2].char))
        end
    end,

    saveFrame = function()
        history[frameCounter] = util.deepcopy({
            objects = objects,
            hitboxes = hitboxes,
            particles_bg_new = particles_bg:reset_new_keys(),
            particles_mg_new = particles_mg:reset_new_keys(),
            particles_fg_new = particles_fg:reset_new_keys(),
            matchState = matchState,
            gameOverTimer = gameOverTimer,
            gameStartTimer = gameStartTimer,
            winner = winner
        })
        assert(#history == frameCounter, "Error: History size " .. #history .. "but frame counter " .. frameCounter)
    end,
    jumpToFrame = function(frame)
        assert(not (frame < 1 or history[frame] == nil), "Error: attempting to jump to frame " .. frame)

        while frameCounter > frame do
            print("test : "..#particles_fg)
            -- cull any particles that were created after the frame that we're rolling back to
            -- // particles can't cause desync so no need to maintain an alternate logic path for modded connections
            for _, key in pairs(history[frameCounter].particles_bg_new) do
                particles_bg:remove(key)
            end
            for _, key in pairs(history[frameCounter].particles_mg_new) do
                particles_mg:remove(key)
            end
            for _, key in pairs(history[frameCounter].particles_fg_new) do
                particles_fg:remove(key)
            end
            table.remove(history)
            frameCounter = frameCounter - 1
        end

        local state = util.deepcopy(history[frameCounter])
        objects = state.objects
        hitboxes = state.hitboxes
        matchState = state.matchState
        gameOverTimer = state.gameOverTimer
        gameStartTimer = state.gameStartTimer
        winner = state.winner
    end,

    handleRollback = function(frame)
        if frame >= frontierFrame then return end

        game.jumpToFrame(frame)
        while frameCounter < frontierFrame do
            game.advanceFrame()
        end

        -- fix music on rollback?? (ruby help)
        if matchState == "PLAYING" and frameCounter >= 90 then
            if bgMusic and not bgMusic:isPlaying() then
                game.playMusic()
            end
        end
    end,

    loadObjects = function(playerData, spawnDist)
        spawnDist = spawnDist or 40
        for i, p in ipairs(playerData) do
            local character = _G[p.char]
            local obj = objectSystem.createObject(character, i == 1 and 120 - spawnDist or 120 + spawnDist, 50, p.skin)
            obj:move(obj.x - obj:hmid(), 0)
            obj.connectionID = p.id
            obj.char = p.char
            obj.username = p.username
            obj.playerNum = i
            if i == 2 then obj.facing = -1 end
        end
    end,

    -- playMusic function replaces the playBGM calls within the file to allow for editable stage tracks
    playMusic = function()
        if stage.music ~= nil then playBGM(stage.music)
        else playBGM("music/fight_theme.ogg") end
    end
}
