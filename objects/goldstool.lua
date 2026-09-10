goldstool = {
    name = "goldstool",
    init = function(this, skin, owner)
        this.connectionID = "goldstool_" .. math.floor(this.x) .. "_" .. math.floor(this.y)
        this.throwerID = nil

        local player_skins = {
                {sprites["objects/goldstool_1"], {255 / 255, 236 / 255, 39 / 255, 0.5}}, -- gold
                {sprites["objects/goldstool_2"], {41 / 255, 173 / 255, 255 / 255, 0.5}}, -- diamond
                {sprites["objects/goldstool_3"], {0 / 255, 228 / 255, 54 / 255, 0.5}}, -- emerald
                {sprites["objects/goldstool_4"], {175 / 255, 76 / 255, 255 / 255, 0.5}}, -- amethyst
            }

        this.spritesheet, this.beamColor = unpack(player_skins[tonumber(skin)])
        this.skin = skin
        this.spr = this.spritesheet[4]

        this.owner = owner

        this.hurtbox = {x = 1, y = 0, w = 6, h = 8}
        this.wings_were_active = false
        this.body_was_active = false
        this.w = 6
        this.semisolid = true
        this.collides = true
        this.flying = false
        this.was_flying = false
        this.flystarttimer = 0
        this.flylock = 0
        this.step = 0
        this.held = false

        this.wings_timer = 0
        this.body_timer = 0

        this.animations = {
            idle = {frames = {1}, speed = 1},
            flying = {frames = {2}, speed = 1},
            flystart = {frames = {3, 4}, speed = 3}
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0
        this.layer = -1

        this.was_on_ground = false
        this.was_colliding = false

        this.body_hb = nil
        this.leftwing_hb = nil
        this.rightwing_hb = nil

        this.exhaustion = 0
        this.exhaustionLimit = 2
        this.sweats = {}
        this.sweatTimer = 0

        this.was_held = false
        this.body_hitbox_lock = 0

        this.on_release = function()
        end

        this.corner_correct = function(this_obj, dir_x, dir_y, side_dist, only_sign)
            only_sign = only_sign or 0
            if dir_x ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this_obj:is_solid(dir_x, i * s) then
                                this_obj.x = this_obj.x + dir_x
                                this_obj.y = this_obj.y + i * s
                                return true
                            end
                        end
                    end
                end
            elseif dir_y ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this_obj:is_solid(i * s, dir_y) then
                                this_obj.x = this_obj.x + i * s
                                this_obj.y = this_obj.y + dir_y
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end
    end,

    update = function(this)  
        local ground_hit = this:is_solid(0, 1)
        local on_ground = ground_hit ~= false
        local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

        if this.owner.respawn_timer > 0 then this.exhaustion = 0 end

        -- check for oob
        if this:oob() then goldstool.oobbehavior(this) end

        -- check for flystarttimer
        if this.flying then
            if this.was_flying == false then
                this.flystarttimer = 6
                this.was_flying = true
                love.audio.play("stoolfly", "static")
            end
        else
            this.was_flying = false
        end

        -- check for finish flying
        if this.flying then
            if this.flystarttimer <= 0 then
                if this:is_solid(0, 0) or ground_hit or this:is_solid(0, 2) or this:is_solid(0, 3) and this.was_colliding == false then
                    this.was_colliding = true
                elseif ground_hit == false and this.was_colliding == true then
                    if this.flylock <= 0 then
                        this.flying = false
                        this.collides = true
                        this.exhaustion = 0
                        this.sweats = {}
                    end
                    this.was_colliding = false
                end
            else
                this.flystarttimer = this.flystarttimer - 1
            end
        end

        -- Decrement flylock
        if this.flylock > 0 then
            this.flylock = this.flylock - 1
        end

        -- friction
        this.vx = util.appr(this.vx, 0, 0.2 or 0.18)

        if this.flying and this.flystarttimer <= 0 then
            this.vy = util.appr(this.vy, -3.5, 0.25)
        else
            if on_ground and not this.was_on_ground then
            game.init_smoke(this.x, this.y + 4)
            end

            if on_ground then
                this.exhaustion = 0
            end

            if on_ground and this.vy > 0 then
                this.vy = 0
            end

            local maxfall = 2.6
            if not on_ground then
                this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
            end
        end

        this.was_on_ground = on_ground

        if this.held then
            this.flystarttimer = 0
            local is_actually_held = false
            for _, obj in ipairs(objects) do
                if obj.holding == this or obj.grapple_hit == this then
                    this.throwerID = obj.connectionID
                    is_actually_held = true
                    break
                end
            end
            this.was_held = true
        else
            if this.was_held and this.throwerID and this.throwerID ~= this.owner.connectionID then
                this.was_held = false
                this.body_hitbox_lock = 17
            end
        end

        if this.body_hitbox_lock > 0 then this.body_hitbox_lock = this.body_hitbox_lock - 1 end

        -- Set Up Riders
        local px = this.x
        local py = this.y
        local riders = {}

        goldstool.set_up_riders(this, riders)

        -- damage stuff
        -- Movement damage
        local hb_w, hb_h = this.hurtbox.w + (this.hurtbox.w / 2), this.hurtbox.h + (this.hurtbox.h / 2)
        local targetX = this.x + this.vx
        local targetY = this.y + this.vy
        local cx = targetX + this.hurtbox.x
        local cy = targetY + this.hurtbox.y
        local hb_x = cx - (hb_w / 4)
        local hb_y = cy - (hb_h / 4)
        local kb_mod = this.vy > 0 and 2 or 1
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and not this.held and this.owner then
            if this.body_was_active then
                this.body_was_active = true
            end
            if this.body_timer <= 0 and this.body_hitbox_lock <= 0 and this.flystarttimer >= 0 then
                if this.flying then
                else this.body_hb = hitbox.create(this.owner.connectionID, hb_x, hb_y, hb_w, hb_h, 2, util.sign(this.vx)*3, math.abs(util.sign(this.vy) * (1.25 * kb_mod) - (0.5 * kb_mod)) * -1, 2) end
            end
        else
            this.body_was_active = false
        end
        this.body_timer = this.body_timer - 1
        -- Wing Damage
        hb_w, hb_h = 8, 9
        hb_x = cx - 1
        if(this.flying and this.flystarttimer <= 0) then
            if not this.wings_were_active then
                this.leftwing_hb = hitbox.create(this.owner.connectionID, hb_x - 7, hb_y, hb_w, hb_h, 8, -4, -3, 2)
                this.rightwing_hb = hitbox.create(this.owner.connectionID, hb_x + 7, hb_y, hb_w, hb_h, 8, 4, -3, 2)

                this.leftwing_hb.firstframe = true
                this.leftwing_hb.dir = -1

                this.rightwing_hb.firstframe = true
                this.rightwing_hb.dir = 1

                this.wings_were_active = true

                this.leftwing_hb.hit_sfx = "zap"
                this.rightwing_hb.hit_sfx = "zap"
            elseif this.wings_timer <= 0 then
                this.leftwing_hb = hitbox.create(this.owner.connectionID, hb_x - 7, hb_y, hb_w, hb_h, 2, -2, util.sign(this.vy) * -2 - 1, 2)
                this.rightwing_hb = hitbox.create(this.owner.connectionID, hb_x + 7, hb_y, hb_w, hb_h, 2, 2, util.sign(this.vy) * -2 - 1, 2)

                this.leftwing_hb.dir = -1
                this.rightwing_hb.dir = 1
            end
        else
            this.wings_were_active = false
        end
        this.wings_timer = this.wings_timer - 1

        -- Move stool
        if this.flying and this.flystarttimer <= 0 then
            this:moveWithoutCollide(this.vx, this.vy)
        elseif not this.held then
            this:move(this.vx, this.vy)
        end

        -- Move riders
        local dx = this.x - px 
        local dy = this.y - py
        for _, r in ipairs(riders) do
            r:move(dx, dy)
            if r.type.name == "goldstool" and r:oob() then goldstool.oobbehavior(r) end
        end

        -- exhaustion effect
        if this.exhaustion > this.exhaustionLimit then
            this.sweatTimer = this.sweatTimer + 1
            if this.sweatTimer >= 3 then
                table.insert(this.sweats, {
                                x = this.x + 4 + math.random(-2, 2),
                                y = this.y + math.random(0, 4),
                                vy = -0.5,
                                t = 8
                            })
                this.sweatTimer = 0
            end
        end
        
        for i = #this.sweats, 1, -1 do
            local sw = this.sweats[i]
            sw.y = sw.y + sw.vy
            sw.vy = sw.vy + 0.1
            sw.t = sw.t - 1
            if sw.t <= 0 then
                table.remove(this.sweats, i)
            end
        end  

        -- sprite stuff

        local next_anim = "idle"
        if this.flystarttimer > 0 then
            next_anim = "flystart"
        elseif this.flying then
            next_anim = "flying"
        end

        if next_anim ~= this.current_anim then
            this.current_anim = next_anim
            this.anim_frame = 1
            this.anim_timer = 0
        end

        local anim = this.animations[this.current_anim]
        this.anim_timer = this.anim_timer + 1

        if this.anim_timer >= anim.speed then
            this.anim_timer = 0
            this.anim_frame = this.anim_frame + 1
            if this.anim_frame > #anim.frames then
                this.anim_frame = 1
            end
        end
    end,

    set_up_riders = function(this, riders)
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() >= this.y - 4 and o:bottom() <= this.y and o:left() <= this:right() and o:right() >= this:left() and o.type.name ~= "cloud" and o.type.name ~= "moving_platform" then
                table.insert(riders, o)
                if o.semisolid then
                    for _, p in ipairs(objects) do
                        if p ~= o and p:bottom() >= o.y - 4 and p:bottom() <= o.y and p:left() <= o:right() and p:right() >= o:left() and p.type.name ~= "cloud" and o.type.name ~= "moving_platform" then
                            table.insert(riders, p)
                        end
                    end
                end
            end
        end
    end,

    oobbehavior = function(this)
        if this.exhaustion < this.exhaustionLimit then
                this.flying = true
                this.was_flying = true
                this.flystarttimer = 0
                this.collides = false
                this.y = stage.blastZone.b - 5
                this.vy = -3.5
                this.was_colliding = false
            else
                this.flying = false
                this.was_flying = false
                this.collides = true
                this.y = stage.blastZone.t
                this.vy = 2.6
                this.was_colliding = true
            end
        this.x = this.owner.x
        this.vx = 0
        this.exhaustion = this.exhaustion + 1

        table.insert(particles_mg, {
            x = this.x,
            y = stage.blastZone.t,
            w = 8,
            timer = 0,
            update = function(b)
                -- Beam effect
                if b.timer <= 0 then
                    b.w = b.w - 2
                    b.x = b.x + 1
                    b.timer = 8
                end
                b.timer = b.timer - 1
                return b.w <= 0
            end,
            draw = function(b)
                if b.w > 2 then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.rectangle("fill", math.floor(b.x), stage.blastZone.t, b.w, 500)
                    love.graphics.setColor(this.beamColor)
                    love.graphics.rectangle("fill", math.floor(b.x + 1), stage.blastZone.t, b.w - 2, 500)
                else
                    love.graphics.setColor(this.beamColor)
                    love.graphics.rectangle("fill", math.floor(b.x), stage.blastZone.t, b.w, 500)
                end
                love.graphics.setColor(1, 1, 1)
            end,
        })
    end,

    draw = function(this)
        local isBlinking = this.body_hitbox_lock > 0 and (math.floor(this.body_hitbox_lock / 4) % 2 == 0 or debugEnabled)

        -- Sweat
        love.graphics.setColor(41/255, 173/255, 255/255, 1)
        for _, sw in ipairs(this.sweats) do
            love.graphics.rectangle("fill", math.floor(sw.x), math.floor(sw.y), 1, 1)
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)

        -- apply pal swaps
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        end

        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w)

        sprites.draw(this.spr, this.x + 1, this.y - 1, 0, 1, 1, cx, 0)

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
    end
}