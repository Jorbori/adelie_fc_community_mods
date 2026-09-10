-- css.lua
require("controller")
local config = require("config")

-- Mod Version Variable, used for authentication. Format is MajorVersion.MinorVersion.Hotfix => [FirstDigit][SecondDigit][ThirdDigit]
MOD_VERSION = 100
-- The Maximum Value that can be used as a seed
SEED_MAX = 9999

NUM_PLAYER_SKINS = {
    maddy = 4,
    gem_maddy = 4,
    heavy_maddy = 4,
    lani = 4,
    stepstools = 4,
    roundelie = 3  -- TODO: rosetta skin is temporarily disabled until it's reworked
}
AVAILABLE_CHARS = {"maddy", "gem_maddy", "heavy_maddy", "lani", "stepstools","roundelie"}
VANILLA_CHARS = {"maddy", "lani"}
CPU_CHARS = {"maddy", "gem_maddy", "heavy_maddy"}

css = {
    players = {},
    localReady = false,
    mode = "ONLINE",

    init = function(mode)
        css.mode = mode or "ONLINE"

        --css.players = {}
        css.localReady = false
        css.btnPressed = {}
        
        css.player_char = css.player_char or "maddy"
        css.char_idx = css.char_idx or 1
        css.player_skin = css.player_skin or 1

        css.cpu_char = css.cpu_char or "maddy"
        css.cpu_char_idx = css.cpu_char_idx or 1
        css.cpu_skin = css.cpu_skin or 2

        -- set modded skin selection
        css.modded_char = css.modded_char or css.player_char
        css.modded_idx = css.modded_idx or css.char_idx
        css.modded_skin = css.modded_skin or css.player_skin

        if css.mode == "ONLINE" and network and network.sendCSSReady then
            network.sendCSSReady(false)
        end

        -- modded send signal
        if css.mode == "ONLINE" and network and network.sendCSSSkin and network.moddedConnection ~= true then
            localRandom.player_seed = MOD_VERSION * (SEED_MAX + 1) + math.random(SEED_MAX)
            network.sendCSSSkin(localRandom.player_seed) -- Set the skin way out of bounds to signal modded client
            network.sendCSSSkin(css.player_skin)
        end

        overlay.setInputDisplay("O : ready | LR : character | UD : skin | X : leave")

        if css.mode == "TRAINING" then
            css.players = {
                {
                    id = connectionID,
                    char = css.player_char,
                    ready = "0",
                    wins = -1,
                    skin = css.player_skin,
                    username = config["username"] or "p1"
                },
                {
                    id = 2,
                    char = css.cpu_char,
                    ready = "0",
                    wins = -1,
                    skin = css.cpu_skin,
                    username = "cpu"
                }
            }

            -- set the local seed since the online process doesn't occur
            math.randomseed(os.time())
            localRandom.setSeed(math.random(SEED_MAX * 2))
        end
    end,

    update = function()
        -- confirm
        if input.checkPressed("b1") then
            css.localReady = not css.localReady

            if css.mode == "ONLINE" then
                network.sendCSSSkin(css.player_skin)
                network.sendCSSReady(css.localReady)
            else
                if css.players[1].ready == "0" then css.players[1].ready = css.localReady and "1" or "0"
                else
                    css.localReady = not css.localReady
                    css.players[2].ready = css.localReady and "1" or "0"
                end
                if css.players[2].ready == "1" and css.players[1].ready == "1" then
                    gameController.enterSSS(css.players, css.mode)
                end
            end

            love.audio.play("readyup", "static", false, false)
        end

        -- back
        if input.checkPressed("b2") then
            if css.mode == "ONLINE" then network.exitRoom() end
            css.players = {}
            gameController.enterTitle()
            love.audio.play("menu_back", "static")
        end

        if not css.localReady then
            local n_skins = NUM_PLAYER_SKINS[css.player_char]
            local character_set = (network.moddedConnection == true or css.mode == "TRAINING") and AVAILABLE_CHARS or VANILLA_CHARS
            local updated = false

            if input.checkPressed("up") then
                css.player_skin = css.player_skin % n_skins + 1
                updated = true
            end
            if input.checkPressed("down") then
                css.player_skin = (css.player_skin - 2) % n_skins + 1
                updated = true
            end
            if input.checkPressed("right") then
                css.char_idx = css.char_idx % #character_set + 1
                css.player_char = character_set[css.char_idx]
                css.player_skin = 1
                updated = true
            end
            if input.checkPressed("left") then
                css.char_idx = (css.char_idx - 2) % #character_set + 1
                css.player_char = character_set[css.char_idx]
                css.player_skin = 1
                updated = true
            end
            if updated then
                if css.mode == "ONLINE" then
                    network.sendCSSChar(css.player_char)
                    network.sendCSSSkin(css.player_skin)
                else
                    css.players[1].char = css.player_char
                    css.players[1].skin = css.player_skin
                end
            end
        elseif css.mode == "TRAINING" then
            local n_skins = NUM_PLAYER_SKINS[css.cpu_char]
            local character_set = CPU_CHARS
            local updated = false

            if input.checkPressed("up") then
                css.cpu_skin = css.cpu_skin % n_skins + 1
                updated = true
            end
            if input.checkPressed("down") then
                css.cpu_skin = (css.cpu_skin - 2) % n_skins + 1
                updated = true
            end
            if input.checkPressed("right") then
                css.cpu_char_idx = css.cpu_char_idx % #character_set + 1
                css.cpu_char = character_set[css.cpu_char_idx]
                css.cpu_skin = 2
                updated = true
            end
            if input.checkPressed("left") then
                css.cpu_char_idx = (css.cpu_char_idx - 2) % #character_set + 1
                css.cpu_char = character_set[css.cpu_char_idx]
                css.cpu_skin = 2
                updated = true
            end
            if updated then
                css.players[2].char = css.cpu_char
                css.players[2].skin = css.cpu_skin
            end
        end
    end,

    draw = function()
        -- bg shader
        love.graphics.setShader(cssBGShader)
        cssBGShader:send("t", love.timer.getTime())
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()

        -- darken
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

        -- header
        local title = "character select"
        love.graphics.setColor(util.color(0)) -- shadow
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2) + 1, 8 + 1)
        love.graphics.setColor(util.color(7)) -- white
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2), 8)

        -- mod notice
        local modNotice
        if network.moddedConnection == true or css.mode == "TRAINING" then
            modNotice = "mods enabled!"
            love.graphics.setColor(util.color(0)) -- shadow
            love.graphics.print(modNotice, GAME_WIDTH/2 - (#modNotice * 2) + 1, 8 + 1 + 7)
            love.graphics.setColor(util.color(11)) -- green
            love.graphics.print(modNotice, GAME_WIDTH/2 - (#modNotice * 2), 8 + 7)
        else
            modNotice = "mods disabled!"
            love.graphics.setColor(util.color(0)) -- shadow
            love.graphics.print(modNotice, GAME_WIDTH/2 - (#modNotice * 2) + 1, 8 + 1 + 7)
            love.graphics.setColor(util.color(8)) -- red
            love.graphics.print(modNotice, GAME_WIDTH/2 - (#modNotice * 2), 8 + 7)
        end

        -- vs
        local vs = "vs"
        love.graphics.setColor(util.color(0))
        love.graphics.print(vs, GAME_WIDTH/2 - (#vs * 2) + 1, 56 + 1)
        love.graphics.setColor(util.color(8)) -- Red
        love.graphics.print(vs, GAME_WIDTH/2 - (#vs * 2), 56)

        -- player panels
        for i, p in ipairs(css.players) do
            local isMe = (tonumber(p.id) == tonumber(connectionID))

            local panelWidth = 68
            local panelHeight = 90
            local panelX = GAME_WIDTH/2 + (isMe and -82 or 14)
            local panelCenter = panelX + (panelWidth / 2)
            local portraitX = GAME_WIDTH/2 + (isMe and -80 or 80)

            -- name tabs
            local playerText = p.username
            local tabW = (#playerText * 4) + 6
            local tabH = 10
            local tabX = isMe and (panelX + 4) or (panelX + panelWidth - tabW - 4)
            local tabY = 14

            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", tabX + 2, tabY + 2, tabW, tabH)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", tabX, tabY, tabW, tabH)

            love.graphics.setColor(util.color(6))
            love.graphics.print(playerText, tabX + 3, tabY + 2)

            -- drop shadow + border
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 2, 22 + 2, panelWidth, panelHeight)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", panelX, 22, panelWidth, panelHeight)

            -- portrait box
            love.graphics.setColor(util.color(5))
            love.graphics.rectangle("fill", panelX + 2, 24, 64, 64)

            -- portrait sprite
            love.graphics.setColor(1, 1, 1, 1)
            local portrait_name_skin = "ui/portrait_" .. p.char .. "_" .. p.skin

            -- fall back if skin doesn't exist (can have race condition)
            local portrait_spr = sprites[portrait_name_skin] or sprites["ui/portrait_" .. p.char .. "_1"]
            sprites.draw(portrait_spr, portraitX, 24, 0, isMe and 2 or -2, 2)

            -- name frame
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 6, 86, panelWidth - 8, 13)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", panelX + 4, 84, panelWidth - 8, 13)
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 5, 85, panelWidth - 10, 11)

            -- char name
            love.graphics.setColor(util.color(7))
            local charName = string.lower(string.gsub(p.char, "_", " ")) -- Modded alteration: replace underscores with spaces
            love.graphics.print(charName, panelCenter - (#charName * 2), 88)

            -- ready status
            local t = love.timer.getTime()
            if p.ready == "1" then
                love.graphics.setColor(util.color(0))
                love.graphics.print("ready!", panelX + 5 + 1, 100 + 1)
                love.graphics.setColor(util.color(11))
                love.graphics.print("ready!", panelX + 5, 100)
            else
                if math.floor(t * 2) % 2 == 0 then
                    love.graphics.setColor(util.color(0))
                    love.graphics.print("selecting", panelX + 5 + 1, 100 + 1)
                    love.graphics.setColor(util.color(5))
                    love.graphics.print("selecting", panelX + 5, 100)
                end
            end

            -- win counter
            if css.mode ~= "TRAINING" then
                love.graphics.setColor(util.color(10))
                local winsText = tostring(p.wins)
                local textX = panelX + panelWidth - 5 - (#winsText * 4)
                local textY = 100
                love.graphics.print(winsText, textX, textY)
                local starX = textX - 9
                local starY = textY
                love.graphics.rectangle("fill", starX + 3, starY + 0, 1, 1) -- p8 star
                love.graphics.rectangle("fill", starX + 2, starY + 1, 3, 1)
                love.graphics.rectangle("fill", starX + 0, starY + 2, 7, 1)
                love.graphics.rectangle("fill", starX + 1, starY + 3, 5, 1)
                love.graphics.rectangle("fill", starX + 1, starY + 4, 1, 1)
                love.graphics.rectangle("fill", starX + 5, starY + 4, 1, 1)
            end
        end
    end,

    parseUpdate = function(dataStr)
        css.players = {}
        for _, pStr in ipairs(util.split(dataStr, "-")) do
            local parts = util.split(pStr, ",")
            if #parts >= 5 then
                local pID = tonumber(parts[1])
                local pSkin = tonumber(parts[5])
                
                -- Ensure connectionID is a number and not the default -1
                local myID = tonumber(connectionID) or -1

                -- STICKY HANDSHAKE:
                -- If we see skin 1000 from someone else, lock moddedConnection to 1000.
                -- We do NOT include an 'else' here, so the state persists.
                if math.floor(pSkin / (SEED_MAX + 1)) == MOD_VERSION and pID ~= myID and myID ~= -1 and network.moddedConnection ~= true then
                    -- flip modded connection on
                    network.moddedConnection = true

                    -- set local RNG seed
                    localRandom.opponent_seed = pSkin
                    localRandom.setSeed(localRandom.player_seed + localRandom.opponent_seed)

                    -- send modded skin
                    css.player_char = css.modded_char
                    css.char_idx = css.modded_idx
                    css.player_skin = css.modded_skin
                    network.sendCSSChar(css.player_char)
                    network.sendCSSSkin(css.player_skin)
                end

                table.insert(css.players, {
                    id = parts[1],
                    char = parts[2],
                    ready = parts[3],
                    wins = parts[4],
                    skin = parts[5],
                    username = parts[6] or "opp"
                })
            end
        end
    end,

    indexOf = function(array, value)
        for i, v in ipairs(array) do
            if v == value then
                return i
            end
        end
        return nil
    end,

    modded_skin_routine = function(self)
        network.moddedConnection = false
        css.modded_char = css.player_char or "maddy"
        css.modded_idx = css.char_idx or 1
        css.modded_skin = css.player_skin or 1
        if not css:char_is_vanilla(css.player_char) then
            css.player_char = "maddy"
            css.char_idx = 1
            css.player_skin = 1
        end
    end,

    char_is_vanilla = function(css, char)
        for _, c in ipairs(VANILLA_CHARS) do
            if c == char then
                return true
            end
        end
        return false
    end
}