-- objects/goldstool.lua

goldstool = {
    name = "goldstool",
    init = function(this, skin, owner)
        this.connectionID = "goldstool_" .. math.floor(this.x) .. "_" .. math.floor(this.y)
        
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

        this.state = "free_body"

        this.w = 6
        this.semisolid = true

        this.fly_start_timer = 0

        this.was_colliding = false

        this.screen_wraps = 0

        this.holder = nil
        this.thrown_timer = 0
        this.held = false
        this.was_held = false
        this.destroyed = false

        this.wings_timer = 0
        
        this.animations = {
            idle = {frames = {1}, speed = 1},
            flying = {frames = {2}, speed = 1},
            flystart = {frames = {3, 4}, speed = 3}
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0
        this.layer = -1
        this.freeze = 0

        this.body_hb = nil
        this.leftwing_hb = nil
        this.rightwing_hb = nil

        this.sweats = {}
        
        this.draw_offset_y = 0 
        
        this.damage = 0
        this.hitstun = 0
        this.active = true

        this.body_timer = 0
        this.wings_timer = 0
        
        this.hb = nil
        this.throwerID = nil

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

        this.on_release = function(this)
            this.thrown_timer = 30
        end

        this.set_up_riders = function(this, riders)
            for _, o in ipairs(objects) do
                if o.connectionID ~= this.connectionID and o:bottom() >= this.y - 4 and o:bottom() <= this.y and o:left() <= this:right() and o:right() >= this:left() and o.type.name ~= "cloud" and o.type.name ~= "moving_platform" then
                    if not util.tableContains(riders, o) then table.insert(riders, o) end
                    if o.set_up_riders then
                        o:set_up_riders(riders)
                    end
                end
            end
        end
    end,

    update_oob = function(this)
        if this:oob() and this.owner.respawn_timer == 0 then
            if this.held and this.holder then
                this.holder.y = stage.blastZone.t - 20
                this.held = false
            end

            -- handle varying cases for whether or not the goldstool has hit the screen wrap limit
            if this.screen_wraps < 2 then
                goldstool.set_state_fly(this)
                this.y = stage.blastZone.b
                this.vy = -3.5
            else
                goldstool.set_state_free_body(this)
                this.y = stage.blastZone.t
                this.vy = 2.6
            end

            -- other vars
            this.x = this.owner.x
            this.vx = 0

            this.screen_wraps = this.screen_wraps + 1

            goldstool.create_beam(this)
        end
    end,

    initiate_flight = function(this)
        if this.state == "free_body" and this.fly_start_timer == 0 and this.screen_wraps < 2 then this.fly_start_timer = 6 end
    end,

    update_fly_start = function(this)
        this.fly_start_timer = this.fly_start_timer - 1
        if this.fly_start_timer == 0 then
            goldstool.set_state_fly(this)
        end
    end,

    set_state_fly = function(this)
        this.state = "flying"
        this.was_colliding = false
    end,

    set_state_free_body = function(this)
        this.state = "free_body"
    end,

    check_for_finish_fly = function(this)
        local colliding = this:is_solid(0, 0) and this:is_solid(0, 1) and this:is_solid(0, 2) and this:is_solid(0, 3)

        -- first needs to collide with ground
        if colliding then
            this.was_colliding = true
        end

        -- then needs to stop colliding with the ground
        if not colliding and this.was_colliding then
            goldstool.set_state_free_body(this)
        end
    end,

    update_freeze = function(this)
        if this.freeze and this.freeze > 0 then
            this.freeze = this.freeze - 1
            return
        end
    end,

    get_holder = function(this)
        for _, obj in ipairs(objects) do
            if obj.holding == this or obj.grapple_hit == this then
                return obj
            end
        end
        return nil
    end,

    manage_holder = function(this)
        if not this.holder then this.holder = goldstool.get_holder(this)
        elseif this.holder.holding == nil and this.holder.grapple_hit == nil then this.holder = nil end
    end,

    manage_hold_state = function(this)
        if this.holder then
            this.throwerID = this.holder.connectionID
            this.held = true
        else
            this.held = false
        end
        
        if this.hb then
            this.hb.active = false
            this.hb = nil
        end

        -- interactions involving the fly state when a character is holding the stool
        if this.was_held == false and this.held == true then
            if this.state == "flying" then goldstool.set_state_free_body(this) end
            if this.fly_start_timer > 0 then this.fly_start_timer = 0 end
        end

        -- update this.was_held
        this.was_held = this.held

    end,

    manage_thrown_state = function(this)
        this.thrown_timer = math.max(0, this.thrown_timer - 1)
        if this.thrown_timer == 0 then this.throwerID = nil end
    end,

    update_physics = function(this)
        local ground_hit = this:is_solid(0, 1)
        local on_ground = ground_hit ~= false

        -- friction
        this.vx = util.appr(this.vx, 0, 0.2 or 0.18)

        if on_ground and not this.was_on_ground then
        game.init_smoke(this.x, this.y + 4)
        end

        if on_ground and this.vy > 0 then
            this.vy = 0
        end

        local maxfall = 2.6
        if this.state == "free_body" and not on_ground then
            this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
        end

        -- flight
        if this.state == "flying" then
            this.vy = util.appr(this.vy, -3.5, 0.25)
            if this.held and this.holder:is_solid(0, 1) and this.vy > 0 then this.vy = 0 end
            goldstool.check_for_finish_fly(this)
        end

        this.was_on_ground = on_ground
    end,

    move_riders = function(this, riders, dx, dy)
        for _, r in ipairs(riders) do
            r:move(dx, dy)
        end
    end,

    shift_out = function(o)
        local x, y = 1, 1

        if not o:is_solid(0, 8, true) then x, y = 0, 1 end
        if not o:is_solid(-8, 0, true) then x, y = -1, 0 end
        if not o:is_solid(8, 0, true) then x, y = 1, 0 end

        if x == 0 and y == 0 then
            if not o:is_solid(8, 8, true) then x, y = 1, 1 end
            if not o:is_solid(-8, 8, true) then x, y = -1, 1 end
        end

        while o:is_solid(0, 0, true) do
            o.x = o.x + x
            o.y = o.y + y
        end
    end,

    check_for_force_drop = function(this)
        if this:is_solid(0, 0) and this:is_solid(0, 1) and this:is_solid(0, 2) and this:is_solid(0, 3) then
            --if holder.type.name == "stepstools" then stepstools.set_state_default(holder) end
            this.holder.holding = nil
            goldstool.shift_out(this.holder)
            this.holder.vy = 0
            this.held = false
        end
    end,

    handle_move = function(this)
        local px = this.x
        local py = this.y
        local riders = {}

        -- Set Up Riders
        this:set_up_riders(riders)

        -- Move Function
        if not this.held then
            if this.state == "free_body" then this:move(this.vx, this.vy)
            elseif this.state == "flying" then this:moveWithoutCollide(this.vx, this.vy) end
        elseif this.state == "flying" then
            local dx, dy = this.holder.x - this.x, this.holder.y - this.y

            this:moveWithoutCollide(this.vx - this.holder.vx, this.vy - this.holder.vy)

            this.holder.x = this.x + dx
            this.holder.y = this.y + dy

            goldstool.check_for_force_drop(this)
        end

        -- Move Riders
        local dx = this.x - px
        local dy = this.y - py
        goldstool.move_riders(this, riders, dx, dy)
    end,

    update_screen_wraps = function(this)
        if not this.held then
            if this:is_solid(0, 1) then this.screen_wraps = 0 end
        else
            if this.holder then
                if this.holder:is_solid(0, 1) then this.screen_wraps = 0 end
            end
        end
    end,
    
    animate_sprite = function(this)
        local next_anim = "idle"
        if this.fly_start_timer > 0 then
            next_anim = "flystart"
        elseif this.state == "flying" then
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

    create_hitboxes = function(this)
        local hb_w, hb_h = this.hurtbox.w + (this.hurtbox.w / 2), this.hurtbox.h + (this.hurtbox.h / 2)
        local targetX = this.x + this.vx
        local targetY = this.y + this.vy
        local cx = targetX + this.hurtbox.x
        local cy = targetY + this.hurtbox.y
        local hb_x = cx - (hb_w / 4)
        local hb_y = cy - (hb_h / 4)

        -- Body Damage
        if this.state == "free_body" and this.fly_start_timer == 0 and (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and not this.held and this.body_timer == 0 then
            local kb_mod = this.vy > 0 and 2 or 1
            this.body_hb = hitbox.create(this.thrown_timer > 0 and this.throwerID or this.owner.connectionID, hb_x, hb_y, hb_w, hb_h, 2, util.sign(this.vx)*3, math.abs(util.sign(this.vy) * (1.25 * kb_mod) - (0.5 * kb_mod)) * -1, 2)
        end

        -- Wing Damage
        if this.state == "flying" and not this.held then
            hb_w, hb_h = 8, 9
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
            elseif this.wings_timer == 0 then
                this.leftwing_hb = hitbox.create(this.owner.connectionID, hb_x - 7, hb_y, hb_w, hb_h, 2, -2, util.sign(this.vy) * -2 - 1, 2)
                this.rightwing_hb = hitbox.create(this.owner.connectionID, hb_x + 7, hb_y, hb_w, hb_h, 2, 2, util.sign(this.vy) * -2 - 1, 2)

                this.leftwing_hb.dir = -1
                this.rightwing_hb.dir = 1
            end
        else
            this.wings_were_active = false
        end
        if this.body_timer > 0 then this.body_timer = this.body_timer - 1 end
        if this.wings_timer > 0 then this.wings_timer = this.wings_timer - 1 end
    end,

    update = function(this)
        goldstool.update_oob(this)

        goldstool.update_freeze(this)

        goldstool.update_sweats(this)

        goldstool.manage_holder(this)

        goldstool.manage_hold_state(this)

        if not this.held then goldstool.manage_thrown_state(this) end

        if this.fly_start_timer > 0 then goldstool.update_fly_start(this) end

        goldstool.update_physics(this)

        goldstool.handle_move(this)

        goldstool.update_screen_wraps(this)

        goldstool.animate_sprite(this)

        goldstool.create_hitboxes(this)
    end,

    update_sweats = function(this)
        -- exhaustion effect
        if this.screen_wraps >= 2 then
            if frameCounter % 3 == 0 then
                table.insert(this.sweats, {
                    x = this.x + 4 + math.random(-2, 2),
                    y = this.y + math.random(0, 4),
                    vy = -0.5,
                    t = 8
                })
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
    end,

    draw_sweats = function(this)
        love.graphics.setColor(41/255, 173/255, 255/255, 1)
        for _, sw in ipairs(this.sweats) do
            love.graphics.rectangle("fill", math.floor(sw.x), math.floor(sw.y), 1, 1)
        end
        love.graphics.setColor(1, 1, 1)
    end,

    create_beam = function(this)
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
        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w)

        sprites.draw(this.spr, this.x + 1, this.y - 1, 0, 1, 1, cx, 0)

        goldstool.draw_sweats(this)

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
    end
}