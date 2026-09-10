-- All game sprites go in spriteList
-- Single entry: "spritename"
-- Multi sprite: {"spritename", numcols, numrows}
-- Draw a sprite with: sprites.draw(sprites["spritename"][sprindex])

local spriteList = {
    "ui/logo",
    "ui/cssframe",
    "ui/icon_kb",
    "ui/icon_pad",
    "ui/portrait_maddy_1",
    "ui/portrait_maddy_2",
    "ui/portrait_maddy_3",
    "ui/portrait_maddy_4",
    "ui/portrait_lani_1",
    "ui/portrait_lani_2",
    "ui/portrait_lani_3",
    "ui/portrait_lani_4",
    "ui/portrait_heavy_maddy_1",
    "ui/portrait_heavy_maddy_2",
    "ui/portrait_heavy_maddy_3",
    "ui/portrait_heavy_maddy_4",
    "ui/portrait_gem_maddy_1",
    "ui/portrait_gem_maddy_2",
    "ui/portrait_gem_maddy_3",
    "ui/portrait_gem_maddy_4",
    "ui/portrait_stepstools_1",
    "ui/portrait_stepstools_2",
    "ui/portrait_stepstools_3",
    "ui/portrait_stepstools_4",
    "ui/portrait_roundelie_1",
    "ui/portrait_roundelie_2",
    "ui/portrait_roundelie_3",
    "ui/portrait_roundelie_4",
    "ready",
    "set",
    "go",
    "ko",
    "heart",
    "adelie",
    {"smoke", 3, 1},
    {"characters/maddy_1", 7, 1},
    {"characters/maddy_2", 7, 1},
    {"characters/maddy_3", 7, 1},
    {"characters/maddy_4", 7, 1},
    {"characters/heavy_maddy_1", 7, 1},
    {"characters/heavy_maddy_2", 7, 1},
    {"characters/heavy_maddy_3", 7, 1},
    {"characters/heavy_maddy_4", 7, 1},
    {"characters/lani_1", 7, 1},
    {"characters/lani_2", 7, 1},
    {"characters/lani_3", 7, 1},
    {"characters/lani_4", 7, 1},
    {"characters/woodstool_1", 8, 1},
    {"characters/woodstool_2", 8, 1},
    {"characters/woodstool_3", 8, 1},
    {"characters/woodstool_4", 8, 1},
    {"characters/roundelie_1", 16, 1},
    "characters/roundelie_1_inflate",
    {"characters/roundelie_2", 16, 1},
    "characters/roundelie_2_inflate",
    {"characters/roundelie_3", 16, 1},
    "characters/roundelie_3_base_default",
    "characters/roundelie_3_base_crouch",
    {"characters/roundelie_4", 16, 1},
    {"characters/roundelie_dust_cloud_A", 3, 1},  -- right/left
    {"characters/roundelie_dust_cloud_B", 3, 1},  -- up
    {"characters/roundelie_ground_chunk", 2, 1},
    {"characters/roundelie_shockwave", 4, 1},
    {"objects/goldstool_1", 4, 1},
    {"objects/goldstool_2", 4, 1},
    {"objects/goldstool_3", 4, 1},
    {"objects/goldstool_4", 4, 1},
    "objects/snowball",
    "objects/block",
    "objects/cloud",
    {"stages/tinker_cog", 4, 1},
    {"stages/summit_flag", 6, 1},
    {"stages/burning_trail_fire", 5, 1},
    {"stages/burning_trail_small_grass", 3, 1},
    {"stages/burning_trail_tall_grass", 3, 1},
}

sprites = {
    init = function()
        for _,s in ipairs(spriteList) do
            if type(s) == "table" then
                local img = love.graphics.newImage("resources/graphics/"..s[1]..".png")
                local quads = {}
                local quadW, quadH = img:getPixelWidth() / s[2], img:getPixelHeight() / s[3]
                for x=0,s[2]-1 do
                    for y=0,s[3]-1 do
                        local quad = love.graphics.newQuad(quadW * x, quadH * y, quadW, quadH, img)
                        table.insert(quads, {img=img, quad=quad})
                    end
                end
                sprites[s[1]] = quads
            else
                sprites[s] = love.graphics.newImage("resources/graphics/"..s..".png")
            end
        end
    end,
    draw = function(spr, x, y, r, sx, sy, ox, oy)
        sx = sx or 1
        sy = sy or sx
        if type(spr) == "table" then
            love.graphics.draw(spr.img, spr.quad, x, y, r, sx, sy, ox, oy)
        else
            love.graphics.draw(spr, x, y, r, sx, sy, ox, oy)
        end
    end
}
