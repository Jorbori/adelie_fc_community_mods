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

        this.was_on_ground = false

        this.animations = {
            idle = {frames = {1}, speed = 1},
            run = {frames = {1, 2, 3, 4}, speed = 4},
            jump = {frames = {3}, speed = 1},
            wallslide = {frames = {5}, speed = 1},
            crouch = {frames = {6}, speed = 1},
            up = {frames= {7} , speed = 1},
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0

        this.respawn_timer = 0
        this.invincible_timer = 0
        this.dash_cooldown = 0
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
                        if this.vy > 0 and this:bottom() <= o:top() + 4 then
                            -- bounce on top
                            snap()
                            this.jbuffer = 0
                            this.dash_cooldown = 0
                            
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
            return
        end
    end,

    update_physics = function(this, id, h_input, v_input)
        -- hitstun
        if this.hitstun > 0 then
            stepstools.physics_hitstun(this)
        else

            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")

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
                stepstools.physics_semisolid_fall_through(this)
            end

            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end

            stepstools.physics_neutral(this, on_ground, h_input)

            if on_ground then
                this.grace = 6
                if this.vy < 0 then
                    love.audio.play("maddy_clip", "static")
                end
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end
            this.was_on_ground = on_ground
        end
    end,

    physics_hitstun = function(this)
        this.dash_time = 0
        this.hitstun = this.hitstun - 1
        this.vy = util.appr(this.vy, 3, 0.167)
        this.vx = util.appr(this.vx, 0, 0.16)
    end,

    physics_semisolid_fall_through = function(this)
        if not this:is_solid(0, 1, true) then
            this.y = this.y + 1
            on_ground = false
            jump = false
            this.jbuffer = 0
        end
    end,

    physics_neutral = function(this, on_ground, h_input)
        local maxrun = 2
        local accel = on_ground and 0.93 or 0.80
        local deccel = 0.16

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
    end,

    animate_sprite = function(this, v_input)
        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)

        local next_anim = "idle"
        if not anim_on_ground then
            --[[if this.self_throw == 2 then
                next_anim = "kick"
            else]]if (this.facing == 1 and this:is_solid(1, 0)) or (this.facing == -1 and this:is_solid(-1, 0)) then
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

    update = function(this)
        local id = this.connectionID

        stepstools.update_freeze(this)

        -- iframes
        stepstools.update_iframes(this)

        -- respawn
        stepstools.update_respawn(this)

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)

        stepstools.update_physics(this, id, h_input, v_input)

        this:move(this.vx, this.vy)
        this:check_snowballs()

        stepstools.animate_sprite(this, v_input)

        stepstools.update_death(this)
    end,

    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        -- sprite hitstun tint
        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end

        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w / 2)

        sprites.draw(this.spr, this.x + cx, this.y, 0, this.facing, 1, cx, 0)

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)
    end,
}