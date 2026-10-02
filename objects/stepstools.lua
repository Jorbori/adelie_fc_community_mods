stepstools = {
    name="stepstools",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/woodstool_1"]}, -- oak
            {sprites["characters/woodstool_2"]}, -- birch
            {sprites["characters/woodstool_3"]}, -- acacia
            {sprites["characters/woodstool_4"]}, -- cherry
        }

        this.spritesheet = unpack(player_skins[tonumber(skin)])
        this.skin = skin
        this.spr = this.spritesheet[7]
        this.damage = 0
        this.stocks = 3
        this.facing = 1
        this.hitstun = 0
        this.active = true

        -- Override the base hurtbox
        this.hurtbox = {x = 1, y = 3, w = 6, h = 5}

        this.grace = 0
        this.jbuffer = 0

        this.holding = nil

        this.goldstool = objectSystem.createObject(goldstool, this.x, this.y - 20 --[[stage.blastZone.b + 10]], skin, this)

        this.p_jump = false
        this.p_dash = false
        this.was_on_ground = false

        this.state = "defualt"

        this.kicks = 1
        this.kick_cooldown = 0

        this.hold_chain = 0

        this.animations = {
            idle = {frames = {1}, speed = 1},
            run = {frames = {1, 2, 3, 4}, speed = 4},
            jump = {frames = {3}, speed = 1},
            wallslide = {frames = {5}, speed = 1},
            crouch = {frames = {6}, speed = 1},
            up = {frames= {7} , speed = 1},
            kick = {frames = {8}, speed = 1},
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0

        this.sweats = {}

        this.body_hb = nil
        this.body_timer = 0

        this.respawn_timer = 0
        this.invincible_timer = 0
        this.freeze = 0

        this.check_snowballs = function(this)
            if this.hitstun > 0 then return end
            for _, o in ipairs(objects) do
                if o.type and o.type.name == "snowball" and not o.destroyed and o.throwerID ~= this.connectionID and not o.held then
                    if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                        local function snap()
                            this:move(0, o.y-8-this.y)
                            if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                                this:move(0, this.y+8-o.y)
                            end
                        end

                        if this.state == "kicking" and math.abs(this.vx) > 0.7 then
                            local kick_target_x = 3.07 * util.sign(this.vx)
                            local kick_target_y = (this.vy >= 0 and 3.07 or 2.55) * util.sign(this.vy)

                            -- kick redirect
                            if kick_target_x == 0 then
                                o.vx = o.vx * 0.75
                                o.stop = true
                            else
                                o.vx = 3 * util.sign(kick_target_x)
                            end

                            if kick_target_y > 0 then
                                local k = kick_target_x == 0 and 1 or 0.7071
                                snap()
                                this.vy = -k * 4.7
                                o.vy = -k * 2
                                this.kicks = 1
                                this.hold_chain = 0
                            else
                                this.vy = kick_target_x == 0 and 0 or -2
                                o.vy = kick_target_x == 0 and -3 or -2
                            end

                            this.vx = this.vx * -0.5
                            this.kick_cooldown = 3

                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("hit", "static")

                        elseif this.vy > 0 and this:bottom() <= o:top() + 4 then
                            -- bounce on top
                            if this.state == "kicking" then stepstools.set_state_default(this) end

                            snap()
                            this.jbuffer = 0
                            this.kick_cooldown = 0
                            this.kicks = 1
                            this.hold_chain = 0
                            
                            if this.p_jump or inputSource.getKeyDown(this.connectionID, "b1") then
                                this.vy = -3.36
                                love.audio.play("maddy_jump", "static")
                            else
                                this.vy = -1.5
                            end
                            
                            o.vy = o:is_solid(0, 1) and -1 or -0.5
                        end
                    end
                end
            end
        end
    end,

    update_freeze = function(this)
        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            if this.freeze == 0 then
                this:move(this.vx, this.vy) -- hack so we don't miss a move when we freeze
                this:check_snowballs()
            end
            return
        end
    end,

    update_iframes = function(this)
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
        end
    end,

    update_respawn = function(this)
        if this.respawn_timer > 0 then
            this.respawn_timer = this.respawn_timer - 1

            if this.respawn_timer == 0 then
                love.audio.play("spawn", "static")
                this.x = 120 - this.hurtbox.x - (this.hurtbox.w / 2)
                this.y = 20

                this.vx = 0
                this.vy = 0
                this.hitstun = 0
                this.invincible_timer = 60
            end
            return true
        end
        return false
    end,

    update_sweats = function(this)
        -- exhaustion effect
        if this.hold_chain == 3 then
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

    update_physics = function(this, id, h_input, v_input)
        -- hitstun
        if this.hitstun > 0 then
            stepstools.physics_hitstun(this)
        else

            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")
            local jump = jump_btn and not this.p_jump
            local dash = dash_btn and not this.p_dash

            this.p_jump = jump_btn
            this.p_dash = dash_btn

            local ground_hit = this:is_solid(0, 1)
            local on_ground = ground_hit ~= false
            local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

            if on_ground and not this.was_on_ground then
                game.init_smoke(this.x, this.y + 4)
            end

            if on_ground and this.vy > 0 then
                this.vy = 0
            end

            -- semisolid fall through
            if on_semisolid and v_input == 1 and jump then
                on_ground, jump = stepstools.physics_semisolid_fall_through(this)
            end

            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end

            if on_ground then
                if not this.holding then stepstools.set_state_default(this) end
                this.kicks = 1
                this.hold_chain = 0
                this.grace = 6
                if this.vy < 0 then
                    love.audio.play("maddy_clip", "static")
                end
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end

            if this.kick_cooldown > 0 then
                this.kick_cooldown = this.kick_cooldown - 1
            end

            if dash then stepstools.dash_btn_logic(this, id) end

            stepstools.physics_neutral(this, on_ground, h_input)

            this.was_on_ground = on_ground
        end
    end,

    dash_btn_logic = function(this, id)
        if this.holding then
            stepstools.throw(this, id)
        elseif inputSource.getKeyDown(id, "down") then
            local pickup = stepstools.available_pickup(this)
            if pickup ~= nil and this.hold_chain < 3 then
                stepstools.pickup(this, pickup)
            else
                stepstools.call_goldstool(this)
            end
        else
            stepstools.kick(this, id)
        end
    end,

    snowball_throw_handling = function(o, dir)
        if dir < 0 then o.vx = math.abs(o.vx) * -1
        elseif dir > 0 then o.vx = math.abs(o.vx) end
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

        if o.type.name == "snowball" then stepstools.snowball_throw_handling(o, x) end
    end,

    throw = function(this, id)
        local pickup = this.holding

        pickup.vx = inputSource.getKeyDown(id, "left") and -4 or inputSource.getKeyDown(id, "right") and 4 or (inputSource.getKeyDown(id, "up") or inputSource.getKeyDown(id, "down")) and 0 or this.facing < 0 and -4 or 4
        pickup.vy = inputSource.getKeyDown(id, "down") and 0 or inputSource.getKeyDown(id, "up") and -3 or -1

        if pickup:is_solid(0, 0, true) then stepstools.shift_out(pickup) end
        
        pickup:on_release(pickup.vx ~= 0)

        love.audio.play("lani_throw", "static")

        stepstools.set_state_default(this)
    end,

    available_pickup = function(this)
        for _, o in ipairs(objects) do
            if o.on_release and not o.held and this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= (o:top() - 4) and this:top() <= (o:bottom() + 4) then return o end
        end
    end,

    pickup = function(this, o)
        this.state = "holding"
        this.holding = o

        this.hold_chain = this.hold_chain + 1

        o.held = true

        -- boost
        if not this:is_solid(0, 1) then
            this.vy = -3.2
            
            if not this:is_solid(0, -3) then
                this.grace = 6
            end
        end
    end,

    call_goldstool = function(this)
        stepstools.pickup(this, this.goldstool)
    end,

    kick = function(this, id)
        if this.kicks > 0 and this.kick_cooldown == 0 then
            this.state = "kicking"
            this.kicks = this.kicks - 1
            this.kick_cooldown = 15
            this.vx = inputSource.getKeyDown(id, "left") and -4 or inputSource.getKeyDown(id, "right") and 4 or (inputSource.getKeyDown(id, "up") or inputSource.getKeyDown(id, "down")) and 0 or this.facing < 0 and -4 or 4
            this.vy = inputSource.getKeyDown(id, "down") and 0 or inputSource.getKeyDown(id, "up") and -3 or -1
        end
    end,

    set_state_default = function(this)
        this.state = "default"
        if this.holding then this.holding = nil end
    end,

    physics_hitstun = function(this)
        this.dash_time = 0
        this.hitstun = this.hitstun - 1
        this.vy = util.appr(this.vy, 2.6, 0.167)
        this.vx = util.appr(this.vx, 0, 0.16)
        if this.state == "kicking" then stepstools.set_state_default(this) end
    end,

    physics_semisolid_fall_through = function(this)
        if not this:is_solid(0, 1, true) then
            this.y = this.y + 1
            this.jbuffer = 0
            return false, false
        end
    end,

    physics_neutral = function(this, on_ground, h_input)
        local maxrun = (this.state == "kicking") and 0.7 or 2
        local accel = on_ground and 0.93 or 0.80
        local deccel = 0.16

        local wall_dir = this:is_solid(-3, 0) and -1 or (this:is_solid(3, 0) and 1 or 0)
        local on_wall = wall_dir ~= 0

        this.vx = math.abs(this.vx) <= maxrun and util.appr(this.vx, h_input * maxrun, accel) or util.appr(this.vx, util.sign(this.vx) * maxrun, deccel)
        if this.vx ~= 0 then this.facing = util.sign(this.vx) end

        local maxfall = 2.6
        if h_input ~= 0 and this:is_solid(h_input, 0) then
            maxfall = 0.693
            if frameCounter % 5 == 0 then
                game.init_smoke(this.x + h_input * 4, this.y)
            end
        end

        if not on_ground then
            this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
        end

        if on_wall and this.state == "kicking" then stepstools.set_state_default(this) end

        if this.jbuffer > 0 then
            if this.grace > 0 then
                this.jbuffer = 0
                this.grace = 0
                this.vy = -3.36

                love.audio.play("maddy_jump", "static")
                game.init_smoke(this.x, this.y + 4)
            else
                if on_wall then
                    this.jbuffer = 0
                    this.vx = -wall_dir * (maxrun + 1.06)
                    this.vy = -3.36
                    love.audio.play("maddy_walljump", "static")
                    game.init_smoke(this.x + wall_dir * 6, this.y)
                end
            end
        end
    end,

    animate_sprite = function(this, v_input)
        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)

        local next_anim = "idle"
        if not anim_on_ground then
            if this.state == "kicking" then
                next_anim = "kick"
            elseif (this.facing == 1 and this:is_solid(1, 0)) or (this.facing == -1 and this:is_solid(-1, 0)) then
                next_anim = "wallslide"
            else
                next_anim = "jump"
            end
        elseif v_input == -1 then
            next_anim = "up"
        elseif v_input == 1 then
            next_anim = "crouch"
        elseif math.abs(this.vx) > 0.1 then
            next_anim = "run"
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

    update_death = function(this)
        -- blast zones and stocks
        if this:oob(0, 0) then
            love.audio.play("kill", "static")
            camera.shake(3, 3, 15)

            game.spawnExplosion(math.max(0, math.min(240, this:hmid())),
                math.max(0, math.min(135, this:vmid())),
                this:right() < stage.blastZone.l and "left" or
                this:left() > stage.blastZone.r and "right" or
                this:bottom() < stage.blastZone.t and "top" or
                "bottom",
                {41/255, 173/255, 255/255})

            this.stocks = this.stocks - 1
            this.damage = 0
            this.vx = 0
            this.vy = 0
            this.hitstun = 0
            this.rem.x = 0
            this.rem.y = 0
            this.kicks = 1
            this.kick_cooldown = 0
            this.hold_chain = 0
            this.sweats = {}
            stepstools.set_state_default(this)

            if this.stocks > 0 then
                this.x = -1000
                this.y = -1000
                this.respawn_timer = 30
            else
                this.x = -1000
                this.y = -1000
                this.active = false
            end
        end
    end,

    handle_move = function(this)
        this:move(this.vx, this.vy)
        this:check_snowballs()
    end,

    handle_holding = function(this)
        if this.state == "holding" then
            this.holding.x = this.x
            this.holding.y = this.y - 4
        end
    end,

    update = function(this)
        local id = this.connectionID

        stepstools.update_freeze(this)

        -- iframes
        stepstools.update_iframes(this)

        -- respawn
        if stepstools.update_respawn(this) then return end

        stepstools.update_sweats(this)

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)

        stepstools.update_physics(this, id, h_input, v_input)
        
        stepstools.handle_move(this)
        stepstools.handle_holding(this)

        stepstools.animate_sprite(this, v_input)

        stepstools.update_death(this)

        stepstools.create_hitboxes(this)
    end,

    create_hitboxes = function(this)
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and this.state == "kicking" and this.body_timer <= 0 then
            local hb_w, hb_h = this.hurtbox.w * 2, this.hurtbox.h * 2
            local targetX = this.x + this.vx
            local targetY = this.y + this.vy
            local cx = targetX + this.hurtbox.x
            local cy = targetY + this.hurtbox.y
            local hb_x = cx - (hb_w / 4)
            local hb_y = cy - (hb_h / 4)
            local kb_mod = this.vy > 2 and 0.6 or 1
            this.body_hb = hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 2, (util.sign(this.vx)*4) * kb_mod, (util.sign(this.vy) * 1.25 - 0.5) * kb_mod, 2)
        end
        this.body_timer = this.body_timer - 1
    end,

    on_hit_confirm = function(this, target, hb)
        -- stuff to do on hit confirm (e.g., pogoing?)
        camera.shake(1.5, 1.5, 2)
        if hb == this.body_hb then this.body_timer = 4 end
    end,

    draw_sweats = function(this)
        love.graphics.setColor(41/255, 173/255, 255/255, 1)
        for _, sw in ipairs(this.sweats) do
            love.graphics.rectangle("fill", math.floor(sw.x), math.floor(sw.y), 1, 1)
        end
        love.graphics.setColor(1, 1, 1)
    end,

    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)

        -- sprite hitstun tint
        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        elseif this.kicks == 0 and frameCounter % 15 < 6 then
            love.graphics.setColor(162 / 255, 136 / 255, 121 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end

        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w / 2)

        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        end

        sprites.draw(this.spr, this.x + cx, this.y, 0, this.facing, 1, cx, 0)

        stepstools.draw_sweats(this)

        if this.connectionID == connectionID then
            local px = math.floor(this.x)
            local py = math.floor(this.y)
            love.graphics.rectangle("fill", px + 3, py - 6, 3, 1)
            love.graphics.rectangle("fill", px + 4, py - 5, 1, 1)
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)
    end,
}