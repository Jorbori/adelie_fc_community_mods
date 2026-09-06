-- stage.lua
require("objects/cloud")
require("objects/moving_platform")

-- TODO: probably should throw this into util?
local function mid(x, y, z) return math.max(math.min(x, y), math.min(math.max(x, y), z)) end
--

cc_clouds = function(r, g, b)
    for i = 1, 32 do
        table.insert(particles_bg, {
            x = math.random() * 240,
            y = math.random() * 135,
            spd = (1 + math.random() * 4) * 0.5,
            w = 32 + math.random() * 32,
            c = {r, g, b},
            update = function(p)
                p.x = p.x + p.spd
                if p.x > 240 then
                    p.x = -p.w
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                local h = math.max(1, math.floor(16 - p.w * 0.1875))
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), math.floor(p.w), h)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc2_clouds = function(flat, r, g, b)
    for i = 1, 32 do
        table.insert(flat and particles_fg or particles_bg, {
            x = math.random() * 240,
            y = flat and GAME_HEIGHT + 4 or math.random() * 135,
            spd = (1 + math.random() * 4) * 0.25,
            size = 16 + math.random() * 32,
            big = (i % 2 == 0),
            c = {r, g, b},
            flat = flat,
            update = function(p)
                p.x = p.x + p.spd
                if p.x > 260 then
                    p.x = -p.size
                    p.y = p.flat and GAME_HEIGHT + 4 or math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                love.graphics.arc("fill", math.floor(p.x), math.floor(p.y), p.size / 3, math.pi, math.pi * 2)

                if p.big then
                    love.graphics.arc("fill", math.floor(p.x) - p.size / 3, math.floor(p.y), p.size / 5, math.pi, math.pi * 2)
                    love.graphics.arc("fill", math.floor(p.x) + p.size / 3, math.floor(p.y), p.size / 6, math.pi, math.pi * 2)
                end

                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc_snowflakes = function()
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 1.25),
            spd = (0.25 + math.random() * 5) * 0.5,
            off = math.random(),
            c = math.random() < 0.5 and {194/255, 195/255, 199/255} or {255/255, 241/255, 232/255},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.s + 1, p.s + 1)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

--cc_snowflakes with customizable snowflakes for the Depths of Hell stage
cc_snowflakes_custom = function(spd, r, g, b)
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 1.25),
            spd = (0.25 + math.random() * spd) * 0.5,
            off = math.random(),
            c = {r, g, b},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.s + 1, p.s + 1)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

--cc_snowflakes with color changing particles specific to puzzlemod
cc_snowflakes_puzzlemod = function(r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4)
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 1.25),
            spd = (0.25 + math.random() * 5) * 0.5,
            off = math.random(),
            c1 = {r1, g1, b1},
            c2 = {r2, g2, b2},
            c3 = {r3, g3, b3},
            c4 = {r4, g4, b4},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                if p.x < 120 and p.y >= 79 then love.graphics.setColor(p.c1)
                elseif p.x > 120 and p.y >= 79 then love.graphics.setColor(p.c2)
                elseif p.x <= 120 and p.y < 79 then love.graphics.setColor(p.c3)
                elseif p.x >= 120 and p.y < 79 then love.graphics.setColor(p.c4) end
                --love.graphics.setColor(p.c)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.s + 1, p.s + 1)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc2_snowflakes = function()
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 2),
            spd = (0.25 + math.random() * 5) * 0.5,
            off = math.random(),
            c = {255/255, 241/255, 232/255},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                if p.s < 1 then
                    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                else
                    love.graphics.rectangle("fill", math.floor(p.x) - 1, math.floor(p.y), 3, 1)
                    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y) - 1, 1, 3)
                end
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

-- particle code ported over from the rosetta p8 cart (by meep)
rosetta_sandstorm = function()
    -- the particles are designed around smaller p8 window size (128x128) => adjustments made to compensate
    for i = 0, math.floor(24 * (1 + (128/240))) do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 1.25),
            spd = (0.25 * math.random() * 0.25),
            off = math.random(),
            c_rand = math.random(),
            
            update = function(p)
                
                p.x = (p.x + ((p.spd + 1) * (128/240))) % 240
                p.y = (p.y + ((0.25 + 0.25 * math.sin(p.off)) * (128/135))) % 135
                p.off = p.off + 0.0125
            end,
            
            draw = function(p)
                local r, g, b = (p.c_rand < 0.8) and util.color(15) or util.color(13)
                local size = (p.s < 1) and 1 or 2
                
                local c = {}
                if p.c_rand < 0.8 then
                    c[1], c[2], c[3] = util.color(15)
                else
                    c[1], c[2], c[3] = 255/255, 157/255, 129/255
                end
                love.graphics.setColor(c)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), size, size)
                love.graphics.setColor(1, 1, 1, 1)
            end,
        })
    end
end

rosetta_clouds = function()
-- init ...
    -- for i=0,16 do
        -- add(clouds,{ x=rnd"128",
                     -- y=rnd"64",
                     -- spd=0.25+rnd"0.75",
                     -- w=32+rnd"32",
                     -- c=rnd"1"<0.5 and 2 or 14
                    -- })
                    
-- TODO: need to replicate p8 fillp functionality
--      probably with a shader? or using stencil

-- function draw_clouds()
    -- fillp"0b1010010110100101.1"
    -- foreach(clouds,
            -- function(c)
                -- c.x+=c.spd-cam_dx
                -- for i=0,2 do
                    -- rectfill(c.x-i,c.y+i,c.x+c.w+i,c.y+16-c.w*0.1875-i,c.c)
                -- end
                -- if c.x>128 then
                    -- c.x=-c.w
                    -- c.y=rnd"64"
                -- end
            -- end)
    -- fillp()
-- end
end

make_cog = function(x, y, flip_x)
    table.insert(particles_fg, {
        x = x - 2,
        y = y - 2,
        flip_x = flip_x,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 2) + anim_offset) % 4 + 1
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/tinker_cog"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    })
end

make_flag = function(x, y, flip_x)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 4) + anim_offset) % 3 + (p.secret and 4 or 1)
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/summit_flag"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    }
    table.insert(particles_fg, f)
    return f
end

--modded make_flag variant for color selection
make_flag_custom = function(x, y, flip_x, r, g, b)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 4) + anim_offset) % 3 + (p.secret and 4 or 1)
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0

            love.graphics.setShader(paletteSwapShader)

            local rr, gr, br = util.color(8)
            paletteSwapShader:send("color_find", {rr, gr, br, 1})
            paletteSwapShader:send("color_replace", {r, g, b, 1})

            sprites.draw(sprites["stages/summit_flag"][frame], p.x, p.y, 0, sx, 1, ox, 0)

            love.graphics.setShader()
        end
    }
    table.insert(particles_fg, f)
    return f
end

make_burning_trail_fire = function(x, y, flip_x)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 3) + anim_offset) % 5 + (p.secret and 4 or 1)
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/burning_trail_fire"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    }
    table.insert(particles_mg, f)
    return f
end

make_burning_trail_small_grass = function(x, y, flip_x)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        anim_dir = 1;
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = math.floor(anim_offset + 1.5 + math.sin(frameCounter / 5 * 1.2)) + 1
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/burning_trail_small_grass"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    }
    table.insert(particles_mg, f)
    return f
end

make_burning_trail_tall_grass = function(x, y, flip_x)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = math.floor(anim_offset + 1.5 + math.sin(frameCounter / 5 * 1.2)) + 1
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/burning_trail_tall_grass"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    }
    table.insert(particles_mg, f)
    return f
end

stage = {
    platforms = {},

    layouts = {
        function()
            stage.name = "lava field"

            stage.addPlatform(72, 100, 96, 28, "solid")
            stage.addPlatform(104, 60, 32, 4, "semisolid")
            stage.addPlatform(66, 75, 28, 4, "semisolid")
            stage.addPlatform(146, 75, 28, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/bf_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/bf_fg.png")

            stage.bgColor = nil
            stage.bgShader = lavaShader

            stage.music = nil;
        end,
        function()
            stage.name = "final iceberg"

            stage.addPlatform(72, 100, 96, 28, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/fd_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/fd_fg.png")

            stage.bgColor = nil
            stage.bgShader = auroraShader

            stage.music = nil;
        end,
        function()
            stage.name = "temple of roundelie"

            stage.addPlatform(72, 96, 96, 14, "solid")
            stage.addPlatform(80, 110, 80, 18, "solid")
            stage.addPlatform(88, 66, 64, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/adetemple_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/adetemple_fg.png")

            stage.bgColor = nil
            stage.bgShader = sunsetShader

            stage.music = nil;
        end,
        -- tinker
        function()
            stage.name = "tinker tower"

            stage.addPlatform(72, 100, 96, 32, "solid")
            stage.addPlatform(72, 68, 24, 4, "semisolid")
            stage.addPlatform(144, 68, 24, 4, "semisolid")

            stage.addPlatform(56, 100, 16, 4, "semisolid")
            stage.addPlatform(168, 100, 16, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/tinker_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/tinker_fg.png")

            stage.bgColor = nil
            stage.bgShader = steampunkShader

            stage.music = nil;

            make_cog(125, 106)
            cc_snowflakes()
        end,
        -- summit from foreverred
        function()
            stage.name = "everred peak"

            stage.addPlatform(56, 127, 8, 24, "solid")
            stage.addPlatform(64, 119, 16, 32, "solid")

            stage.addPlatform(96, 111, 8, 40, "solid")
            stage.addPlatform(104, 87, 8, 64, "solid")
            stage.addPlatform(112, 79, 16, 72, "solid")
            stage.addPlatform(128, 95, 8, 56, "solid")
            stage.addPlatform(136, 119, 8, 32, "solid")

            stage.addPlatform(160, 119, 16, 32, "solid")
            stage.addPlatform(176, 127, 8, 24, "solid")

            stage.spawnDist = 48
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/summit_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/summit_fg.png")

            stage.bgColor = nil
            stage.bgShader = daytimeShader

            stage.music = nil;

            local enable_secret = false

            local date = os.date("*t")
            if (date.month == 11 and date.day == 20) or (date.month == 3 and date.day == 31) or localRandom.float() < 0.01 then
                -- secret always enabled on nov. 20th and march 31st. otherwise 1% chance to happen
                enable_secret = true
            end

            make_flag(116, 71).secret = enable_secret
            cc_snowflakes()
        end,
        -- ancient trench from foreverred
        function()
            stage.name = "ancient trench"

            stage.addPlatform(104, 95, 32, 56, "solid")
            stage.addPlatform(72, 103, 32, 8, "solid")
            stage.addPlatform(136, 103, 32, 8, "solid")
            stage.addPlatform(88, 111, 16, 16, "solid")
            stage.addPlatform(136, 111, 16, 16, "solid")
            stage.addPlatform(80, 111, 8, 8, "solid")
            stage.addPlatform(152, 111, 8, 8, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/trench_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/trench_fg.png")

            stage.bgColor = nil
            stage.bgShader = spaceShader

            stage.music = nil;
            -- TODO: this is also called in the stage select screen
            objectSystem.createObject(cloud, -60, 128, 1)
        end,
        -- the lonely island from amazon
        function()
            stage.name = "amazonia"

            stage.addPlatform(68, 87, 40, 24, "solid")
            stage.addPlatform(76, 111, 24, 8, "solid")
            stage.addPlatform(76, 63, 24, 4, "semisolid")
            stage.addPlatform(76, 39, 24, 4, "semisolid")

            stage.addPlatform(108, 87, 24, 4, "semisolid")

            stage.addPlatform(132, 87, 32, 24, "solid")
            stage.addPlatform(132, 111, 24, 16, "solid")
            stage.addPlatform(140, 127, 16, 24, "solid")
            stage.addPlatform(164, 103, 16, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/amazon_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/amazon_fg.png")

            stage.bgColor = nil
            stage.bgShader = amazonShader

            stage.music = nil;
        end,
        -- old site from solanum
        function()
            stage.name = "solanum mountain"

            stage.addPlatform(60, 119, 32, 32, "solid")
            stage.addPlatform(92, 111, 16, 40, "solid")
            stage.addPlatform(132, 111, 16, 40, "solid")
            stage.addPlatform(148, 119, 24, 32, "solid")

            stage.addPlatform(124, 111, 8, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/solanum_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/solanum_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil
            
            stage.music = nil;

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- archaic meadow grotto from fingals
        function()
            stage.name = "archaic meadow grotto"

            stage.addPlatform(100, 63, 40, 24, "solid")

            stage.addPlatform(52, 87, 16, 32, "solid")
            stage.addPlatform(68, 87, 16, 64, "solid")
            stage.addPlatform(84, 111, 16, 40, "solid")
            stage.addPlatform(100, 119, 40, 32, "solid")
            stage.addPlatform(140, 111, 16, 40, "solid")
            stage.addPlatform(156, 87, 16, 64, "solid")
            stage.addPlatform(172, 87, 16, 32, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/meadow_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/meadow_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(14)
            stage.bgShader = nil

            stage.music = nil;

            cc2_clouds(false, util.color(15))
            cc2_snowflakes()
        end,
        -- 600m from celeste
        function()
            stage.name = "600 m"

            stage.addPlatform(48, 103, 32, 48, "solid")
            stage.addPlatform(80, 111, 32, 40, "solid")

            stage.addPlatform(136, 119, 32, 32, "solid")
            stage.addPlatform(168, 111, 24, 40, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/600m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/600m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- chest level from celeste
        function()
            stage.name = "2200 m"

            stage.addPlatform(96, 95, 48, 16, "solid")
            stage.addPlatform(88, 103, 8, 8, "solid")
            stage.addPlatform(88, 111, 64, 8, "solid")
            stage.addPlatform(-16, 119, 256, 16, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/2200m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/2200m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- opening level from cc2
        function()
            stage.name = "trailhead"

            stage.addPlatform(-16, 95, 32, 16, "solid")
            stage.addPlatform(-16, 111, 24, 40, "solid")

            stage.addPlatform(44, 95, 8, 8, "solid")
            stage.addPlatform(64, 95, 24, 8, "solid")
            stage.addPlatform(104, 95, 32, 8, "solid")
            stage.addPlatform(152, 95, 24, 8, "solid")
            stage.addPlatform(188, 95, 8, 8, "solid")

            stage.addPlatform(224, 95, 32, 24, "solid")
            stage.addPlatform(232, 119, 24, 32, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/bridge_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/bridge_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;

            cc2_clouds(false, 81 / 255, 72 / 255, 100 / 255)
            cc2_snowflakes()
        end,
        -- opening level from cc2
        function()
            stage.name = "golden valley"

            stage.addPlatform(72, 63, 24, 8, "solid")
            stage.addPlatform(96, 63, 8, 24, "solid")

            stage.addPlatform(96, 111, 48, 40, "solid")

            stage.addPlatform(136, 79, 32, 4, "semisolid")

            stage.spawnDist = 40
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/valley_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/valley_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(13)
            stage.bgShader = nil

            stage.music = nil;

            cc2_clouds(false, util.color(15))
            cc2_clouds(true, util.color(15))
            cc2_snowflakes()
        end,
        -- last level from cc2
        function()
            stage.name = "destination"

            stage.addPlatform(48, 87, 24, 32, "solid")
            stage.addPlatform(96, 103, 48, 48, "solid")
            stage.addPlatform(168, 87, 24, 32, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/destination_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/destination_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(15)
            stage.bgShader = nil

            stage.music = nil;

            cc2_clouds(false, util.color(7))
            cc2_clouds(true, util.color(7))
            cc2_snowflakes()
        end,
    },

    modded_layouts = {
        -- squaredelie chamber from rosetta
        function()
            -- layout based on smash4 town & city / p+ luigi's mansion v2 / roa2 air armada
            stage.name = "[wip] pyramid stage"
            
            stage.addPlatform(72, 100, 96, 56, "solid")
            
            -- platforms start joined together at the center of the stage and then move out to hover above the edges
            -- // platforms are 20 units (2.5 tiles) above the main stage
            --
            -- left platform
            p1 = objectSystem.createObject(moving_platform, 96 - 48 + 12, 76, 24)
            p1.ptA = {x = 96, y = 76}
            p1.ptB = {x = 96 - 48 + 12, y = 76}
            p1.movement_duration = 30 * 2    -- 2 sec travel time
            p1.movement_delay = 30 * 12      -- 12 sec pause
            p1.movement_smoothing = true
            p1.sprite = love.graphics.newImage("resources/graphics/stages/pyramid_platform.png")
            p1.sprite_ox = -1
            
            -- right platform
            p2 = objectSystem.createObject(moving_platform, 120 + 48 - 12, 76, 24)
            p2.ptA = {x = 120, y = 76}
            p2.ptB = {x = 120 + 48 - 12, y = 76}
            p2.movement_duration = 30 * 2
            p2.movement_delay = 30 * 12
            p2.movement_smoothing = true
            p2.sprite = love.graphics.newImage("resources/graphics/stages/pyramid_platform.png")
            p2.sprite_ox = -1
            
            -- set timers to avoid characters landing on top of the platform at match start
            p1.movement_timer = p1.movement_duration          -- TODO: bit hacky?
            p1.movement_delay_timer = p1.movement_delay - 60
            p2.movement_timer = p2.movement_duration
            p2.movement_delay_timer = p2.movement_delay - 60
            
            stage.spawnDist = 24
            stage.blastZone = {l=0,r=240,t=-30,b=147}--b=151}  -- bottom blastzone raised up by 1/2 tile
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/pyramid_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/pyramid_fg.png")
            
            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(1)
            stage.bgShader = nil
            
            stage.music = nil
            
            rosetta_sandstorm()
            rosetta_clouds()
        end,

        -- Memorial from Fuji
        function()
            stage.name = "memorial"

            stage.addPlatform(56, 88, 128, 16, "solid")
            stage.addPlatform(64, 104, 112, 8, "solid")
            stage.addPlatform(72, 112, 96, 24, "solid")
            stage.addPlatform(76, 64, 24, 4, "semisolid")
            stage.addPlatform(140, 64, 24, 4, "semisolid")


            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/memorial_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/memorial_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;
            cc_clouds (util.color(2))
            cc_snowflakes()
        end,
        
        -- 500m from arielle
        function()
            stage.name = "arielle 500 m"
            --this stage is accurate to the gaps under the platforms, so if there is ever a character that can teleport into the gaps, be sure to redo the hitboxes

            --left region
            stage.addPlatform(0, 103, 80, 8, "solid")
            stage.addPlatform(0, 111, 16, 40, "solid")

            stage.addPlatform(16, 71, 32, 8, "solid")
            stage.addPlatform(24, 63, 16, 16, "solid")

            stage.addPlatform(48, 111, 32, 8, "solid")
            stage.addPlatform(56, 119, 48, 8, "solid")
            stage.addPlatform(56, 127, 16, 24, "solid")
            stage.addPlatform(88, 127, 16, 24, "solid")

            --center platform
            stage.addPlatform(104, 79, 32, 16, "solid")

            --right region
            stage.addPlatform(144, 103, 24, 16, "solid")
            stage.addPlatform(144, 119, 96, 8, "solid")
            stage.addPlatform(144, 127, 16, 24, "solid")
            stage.addPlatform(176, 127, 16, 24, "solid")
            stage.addPlatform(216, 127, 16, 24, "solid")

            stage.addPlatform(192, 87, 32, 8, "solid")
            stage.addPlatform(200, 79, 16, 16, "solid")

            stage.spawnDist = 68
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/arielle_500m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/arielle_500m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- 1500m from perisher
        function()
            stage.name = "perisher 1500 m"

            -- left platform
            stage.addPlatform(56, 87, 48, 16, "solid")
            stage.addPlatform(56, 103, 40, 8, "solid")
            stage.addPlatform(56, 111, 24, 8, "solid")
            stage.addPlatform(64, 119, 8, 8, "solid")

            -- center island
            stage.addPlatform(104, 127, 32, 24, "solid")
            stage.addPlatform(128, 119, 8, 8, "solid")

            -- right platform
            stage.addPlatform(136, 79, 48, 24, "solid")
            stage.addPlatform(168, 103, 16, 16, "solid")
            stage.addPlatform(176, 119, 8, 8, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/perisher_1500m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/perisher_1500m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- Depths of Hell (Normal Route Summit) from SNEK mod
        function()
            stage.name = "depths of hell"

            --mainland
            stage.addPlatform(80, 103, 16, 56, "solid")
            stage.addPlatform(96, 111, 64, 48, "solid")

            --roof
            stage.addPlatform(104, 55, 32, 16, "solid")
            stage.addPlatform(96, 63, 8, 8, "solid")

            --ledge
            stage.addPlatform(136, 87, 16, 4, "semisolid")

            stage.spawnDist = 28
            stage.blastZone = {l=0,r=240,t=-30,b=126}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/hell_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/hell_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(2)
            stage.bgShader = nil

            stage.music = nil;

            local enable_secret = false

            local date = os.date("*t")
            if (date.month == 11 and date.day == 20) or (date.month == 3 and date.day == 31) or localRandom.float() < 0.01 then
                -- secret always enabled on nov. 20th and march 31st. otherwise 1% chance to happen
                enable_secret = true
            end

            make_flag_custom(125, 103, false, util.color(11)).secret = enable_secret
            cc_snowflakes_custom(10, util.color(0))
        end,
        
        -- scrapped puzzlemod stage, too messy
        --[[
        function()
            stage.name = "puzzlemod"

            --control center chunk
            stage.addPlatform(96, 47, 48, 8, "solid")

            --falling brick chunk
            stage.addPlatform(160, 15, 8, 16, "solid")
            stage.addPlatform(184, 31, 8, 16, "solid")

            stage.addPlatform(144, 31, 16, 4, "semisolid")
            stage.addPlatform(168, 31, 16, 4, "semisolid")

            --classic chunk
            stage.addPlatform(48, 63, 16, 8, "solid")
            stage.addPlatform(48, 71, 8, 8, "solid")
            stage.addPlatform(88, 87, 8, 8, "solid")

            

            --lava chunk
            stage.addPlatform(96, 87, 24, 8, "solid")
            stage.addPlatform(120, 71, 24, 4, "semisolid")

            --grey chunk
            stage.addPlatform(144, 71, 8, 16, "solid")
            stage.addPlatform(184, 63, 8, 16, "solid")

            --rocky chunk
            stage.addPlatform(64, 119, 16, 32, "solid")

            stage.addPlatform(56, 95, 16, 4, "semisolid")

            local enable_secret = false

            local date = os.date("*t")
            if (date.month == 11 and date.day == 20) or (date.month == 3 and date.day == 31) or localRandom.float() < 0.01 then
                -- secret always enabled on nov. 20th and march 31st. otherwise 1% chance to happen
                enable_secret = true
            end

            make_flag_custom(65, 111, false, util.color(11)).secret = enable_secret

            --grass chunk
            stage.addPlatform(96, 119, 16, 32, "solid")
            stage.addPlatform(128, 111, 16, 40, "solid")

            stage.addPlatform(112, 119, 16, 4, "semisolid")

            --snow chunk
            stage.addPlatform(184, 103, 8, 24, "solid")
            stage.addPlatform(176, 111, 8, 8, "solid")

            stage.addPlatform(144, 111, 32, 4, "semisolid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/puzzlemod_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/puzzlemod_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = "music/menu_theme.ogg"

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        ]]
        -- puzzlemod
        function()
            stage.name = "puzzlemod"

            local topPoslist = {{72, 31}, {120, 31}}
            local bottomPoslist = {{72, 79}, {120, 79}}
            local chunkIDs = {1, 2, 3, 4}
            local numChunks = 4
            local snowflakeColors = {}
            
            -- used to create a stage fg and bg image by combining the images for the separate chunks
            -- (roundelie pick colors from the stage fg image for the ground chunks that are created after diving into the ground)
            local temp_canvas_fg, temp_canvas_bg = love.graphics.newCanvas(240, 135), love.graphics.newCanvas(240, 135)
            love.graphics.push("all")  -- store coord system to preserve any transforms applied to main canvas, e.g. if window was resized
            love.graphics.origin()     -- reset coord system to default state

            for i, v in pairs(topPoslist) do
                local cx, cy = v[1], v[2]
                
                local curIndex = localRandom.next() % (numChunks) + 1
                local curChunk = chunkIDs[curIndex]
                
                -- Control Center Chunk
                if(curChunk == 1) then
                    stage.addPlatform(cx + 32, cy + 32, 16, 16, "solid")
                    stage.addPlatform(cx + 0, cy + 32, 32, 4, "semisolid")

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/control_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/control_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(6)})
                -- Falling Brick Chunk
                elseif(curChunk == 2) then
                    stage.addPlatform(cx + 32, cy + 32, 16, 8, "solid")
                    stage.addPlatform(cx + 0, cy + 16, 32, 4, "semisolid")

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/brick_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/brick_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(6)})
                -- Classic Chunk
                elseif(curChunk == 3) then
                    stage.addPlatform(cx + 16, cy + 32, 32, 4, "semisolid")

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/classic_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/classic_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(7)})
                -- Lava Chunk
                elseif(curChunk == 4) then
                    stage.addPlatform(cx + 0, cy + 0, 16, 4, "semisolid")
                    stage.addPlatform(cx + 16, cy + 16, 32, 4, "semisolid")
                    stage.addPlatform(cx + 0, cy + 32, 48, 4, "semisolid")

                    --objectSystem.createObject(block, cx + 8, cy + 24, 1)

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/lava_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/lava_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(5)})
                end
                
                table.remove(chunkIDs, curIndex)
                numChunks = numChunks - 1
            end

            chunkIDs = {1, 2, 3, 4}
            numChunks = 4

            for i, v in pairs(bottomPoslist) do
                local cx, cy = v[1], v[2]
                
                local curIndex = localRandom.next() % (numChunks) + 1
                local curChunk = chunkIDs[curIndex]

                -- Grey Chunk
                if(curChunk == 1) then
                    stage.addPlatform(cx + 0, cy + 32, 48, 16, "solid")
                    stage.addPlatform(cx + 16, cy + 24, 16, 8, "solid")

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/grey_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/grey_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(6)})
                -- Sand Chunk
                elseif(curChunk == 2) then
                    stage.addPlatform(cx + 16, cy + 32, 16, 16, "solid")
                    stage.addPlatform(cx + 32, cy + 16, 16, 32, "solid")
                    stage.addPlatform(cx + 0, cy + 32, 16, 4, "semisolid")

                    local enable_secret = false

                    local date = os.date("*t")
                    if (date.month == 11 and date.day == 20) or (date.month == 3 and date.day == 31) or localRandom.float() < 0.01 then
                        -- secret always enabled on nov. 20th and march 31st. otherwise 1% chance to happen
                        enable_secret = true
                    end

                    make_flag_custom(cx + 21, cy + 24, false, util.color(11)).secret = enable_secret

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/sand_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/sand_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {162/255, 136/255, 121/255})
                -- Grass Chunk
                elseif(curChunk == 3) then
                    stage.addPlatform(cx + 0, cy + 32, 16, 16, "solid")
                    stage.addPlatform(cx + 32, cy + 32, 16, 16, "solid")
                    stage.addPlatform(cx + 16, cy + 32, 16, 4, "semisolid")

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/grass_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/grass_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(9)})
                -- Snow Chunk
                elseif(curChunk == 4) then
                    stage.addPlatform(cx + 0, cy + 32, 48, 16, "solid")
                    stage.addPlatform(cx + 16, cy + 16, 16, 4, "semisolid")

                    objectSystem.createObject(snowball, cx + 16, cy + 8, 1)

                    love.graphics.setCanvas(temp_canvas_bg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/snow_bg.png"), cx, cy)
                    love.graphics.setCanvas(temp_canvas_fg)
                    love.graphics.draw(love.graphics.newImage("resources/graphics/stages/puzzlemod/snow_fg.png"), cx, cy)

                    table.insert(snowflakeColors, {util.color(7)})
                end
                
                table.remove(chunkIDs, curIndex)
                numChunks = numChunks - 1
            end
            love.graphics.pop()        -- reapply stored coord system transforms
            love.graphics.setCanvas()  -- reset

            stage.spawnDist = 22
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            
            stage.bgImage = love.graphics.newImage(temp_canvas_bg:newImageData())
            stage.fgImage = love.graphics.newImage(temp_canvas_fg:newImageData())

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil
            stage.music = "music/puzzlemod.ogg"

            cc_clouds(util.color(1))
            cc_snowflakes_puzzlemod(snowflakeColors[1][1], snowflakeColors[1][2], snowflakeColors[1][3], snowflakeColors[2][1], snowflakeColors[2][2], snowflakeColors[2][3], snowflakeColors[3][1], snowflakeColors[3][2], snowflakeColors[3][3], snowflakeColors[4][1], snowflakeColors[4][2], snowflakeColors[4][3])
        end,
        -- burnin' trail
        function()
            stage.name = "burnin' trail"

            --mainland
            stage.addPlatform(56, 71, 24, 40, "solid")
            stage.addPlatform(80, 79, 8, 48, "solid")
            stage.addPlatform(88, 95, 40, 56, "solid")
            stage.addPlatform(128, 111, 8, 40, "solid")
            stage.addPlatform(136, 119, 24, 32, "solid")

            --island
            stage.addPlatform(128 + 8, 47 + 8, 16, 4, "semisolid")
            stage.addPlatform(144 + 8, 47 + 8, 32, 16, "solid")
            stage.addPlatform(160 + 8, 63 + 8, 16, 8, "solid")

            --torches
            make_burning_trail_fire(64, 57)
            make_burning_trail_fire(72, 57)
            make_burning_trail_fire(88, 81)
            make_burning_trail_fire(112, 81)
            make_burning_trail_fire(136, 105)

            --small grass
            make_burning_trail_small_grass(96, 91)
            make_burning_trail_small_grass(128, 207)
            make_burning_trail_small_grass(144, 115)
            make_burning_trail_small_grass(152, 115)

            --tall grass
            make_burning_trail_tall_grass(56, 65)
            make_burning_trail_tall_grass(176, 49)
            make_burning_trail_tall_grass(168, 49)

            stage.spawnDist = 24
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/burning_trail_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/burning_trail_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            stage.music = nil;
        end,

        --
        function()
            -- layout based on brawl smashville
            stage.name = "cc_ville"
            
            stage.addPlatform(80, 100, 80, 16, "solid")
            stage.addPlatform(88, 116, 64, 8, "solid")
            
            -- a single platform moves between the left and right side of the stage, stopping past the edge of the main stage
            -- // the platform is 24 units (3 tiles) above the main stage
            p = objectSystem.createObject(moving_platform, 32 + 129, 76, 32)  -- TODO: hacky; should calculate initial position instead
            p.ptA = {x = 32, y = 76}
            p.ptB = {x = 32 + 144, y = 76}
            p.movement_duration = 210  -- 7 sec travel time
            p.movement_delay = 30      -- 1 sec pause
            p.movement_timer = 170     -- // init mid-movement to avoid characters landing on top of the platform at match start
            p.movement_smoothing = true
            p.sprite = love.graphics.newImage("resources/graphics/stages/cc_ville_platform.png")
            
            stage.spawnDist = 32
            stage.blastZone = {l=0-8,r=240+8,t=-30,b=151}  -- blastzones are pushed out by 1 tile on each side
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/cc_ville_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/cc_ville_fg.png")
            
            stage.bgColor = nil
            stage.bgShader = nil --lavaShader
            
            stage.music = nil;
        end,
        
        --
        function()
            -- layout based on p+ green hill zone / roa2 aetherian forest
            stage.name = "cc_hillzone"
            
            stage.addPlatform(80, 100, 80, 48, "solid")
            
            -- a single platform swings in an arc (half circle) above the main stage
            -- https://help.altair.com/2023/panopticon/authoring/onlinehelp/DrawingaCirclewithCubicBzierCurves.htm
            -- // at highest pt, the platform is 36 units (4.5 tiles) above the main stage
            -- // at lowest pt, the platform is approx 16 units (2 tiles) above the main stage
            p = objectSystem.createObject(moving_platform, 84 + 18, 60 + 21, 16)  -- TODO: hacky; should calculate initial position instead
            p.ptA =  {x = 84, y = 100 - 40 + 8}
            p.ptC1 = {x = 84 + (56 * 0.05), y = 100 - (40 * 0.334)}
            p.ptC2 = {x = 84 + (56 * 0.95), y = 100 - (40 * 0.334)}
            p.ptB =  {x = 84 + 56, y = 100 - 40 + 8}
            p.movement_duration = 150  -- 5 sec travel time
            p.movement_delay = 0       -- // the platform naturally pauses at the top of the arc
            p.movement_timer = 60      -- // init mid-movement to avoid characters landing on top of the platform at match start
            p.movement_smoothing = true
            p.movement_path_type = "curved"
            p.sprite = love.graphics.newImage("resources/graphics/stages/cc_hillzone_platform.png")
            
            stage.spawnDist = 32
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/cc_hillzone_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/cc_hillzone_fg.png")
            
            stage.bgColor = nil
            stage.bgShader = nil --lavaShader
            
            stage.music = nil;
        end,
    },

    init = function(stageIdx)
        stage.platforms = {}
        stageIdx = stageIdx or 1
        if stage.layouts[stageIdx] then
            stage.layouts[stageIdx]()
        elseif stage.modded_layouts[stageIdx - #stage.layouts] then
            stage.modded_layouts[stageIdx - #stage.layouts]()
        else
            stage.layouts[1]()
        end
    end,

    addPlatform = function(x, y, w, h, pType)
        table.insert(stage.platforms, {x = x, y = y, w = w, h = h, type = pType})
    end,

    draw_bg = function()
        love.graphics.setColor(1, 1, 1, 1)

        if stage.bgImage then
            if stage.bgShader then
                love.graphics.setShader(stage.bgShader)
                stage.bgShader:send("t", love.timer.getTime())
            end
            love.graphics.draw(stage.bgImage, 0, 0)
            if stage.bgShader then
                love.graphics.setShader()
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end,

    draw_fg = function()
        if stage.fgImage then
            love.graphics.draw(stage.fgImage, 0, 0)
        else
            for _, p in ipairs(stage.platforms) do
                if p.type == "solid" then
                    love.graphics.setColor(0.4, 0.4, 0.4)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                end
                love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end,
}
