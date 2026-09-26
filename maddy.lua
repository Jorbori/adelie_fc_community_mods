-- objects/maddy.lua

maddy = {
    name="maddy",
    init = function(this, skin)
        this.connectionID = nil

        local player_skins = {
            {sprites["characters/maddy_1"], {255 / 255, 0 / 255, 77 / 255, 1}}, -- madeline
            {sprites["characters/maddy_2"], {126 / 255, 37 / 255, 83 / 255, 1}}, -- badeline
            {sprites["characters/maddy_3"], {29 / 255, 43 / 255, 83 / 255, 1}}, -- caroline
            {sprites["characters/maddy_4"], {171 / 255, 82 / 255, 54 / 255, 1}}, -- funkeline
            {sprites["characters/maddy_5"], {255 / 255, 119 / 255, 168 / 255, 1}}, -- sakura
        }

        this.spritesheet, this.hair_color = unpack(player_skins[tonumber(skin)])
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
        this.djump = 1
        this.dash_time = 0
        this.dash_target_x = 0
        this.dash_target_y = 0
        this.dash_accel_x = 0
        this.dash_accel_y = 0

        this.p_jump = false
        this.p_dash = false
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

        this.hair_x = {}
        this.hair_y = {}
        for i = 1, 5 do
            this.hair_x[i] = this.x
            this.hair_y[i] = this.y
        end

        this.updateHair = function(this)
            local last_x = this.x + (this.facing == 1 and 1 or 6)
            local last_y = this.y + 2.9 + (this.current_anim == "crouch" and 1 or 0)
            for i = 1, 5 do
                this.hair_x[i] = this.hair_x[i] + (last_x - this.hair_x[i]) / 1.5
                this.hair_y[i] = this.hair_y[i] + (last_y + 0.5 - this.hair_y[i]) / 1.5
                last_x = this.hair_x[i]
                last_y = this.hair_y[i]
            end
        end

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

                        if this.dash_time > 0 then
                            -- dash redirect
                            if this.dash_target_x == 0 then
                                o.vx = o.vx * 0.75
                                o.stop = true
                            else
                                o.vx = 3 * util.sign(this.dash_target_x)
                            end

                            if this.dash_target_y > 0 then
                                local k = this.dash_target_x == 0 and 1 or 0.7071
                                snap()
                                this.vy = -k * 4.7
                                o.vy = -k * 2
                                this.djump = 1
                            else
                                this.vy = this.dash_target_x == 0 and 0 or -2
                                o.vy = this.dash_target_x == 0 and -3 or -2
                            end

                            this.vx = this.vx * -0.5
                            this.dash_cooldown = 4
                            this.dash_time = 0

                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("hit", "static")

                        elseif this.vy > 0 and this:bottom() <= o:top() + 4 then
                            -- bounce on top
                            snap()
                            this.djump = 1
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

    update = function(this)
        local id = this.connectionID

        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            if this.freeze == 0 then
                this:move(this.vx, this.vy) -- hack so we don't miss a move when we freeze
                this:check_snowballs()
                this:updateHair()
            end
            return
        end

        -- iframes
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
        end

        -- dash cd
        if this.dash_cooldown > 0 then
            this.dash_cooldown = this.dash_cooldown - 1
        end

        -- respawn
        if this.respawn_timer > 0 then
            this.respawn_timer = this.respawn_timer - 1

            if this.respawn_timer == 0 then
                love.audio.play("spawn", "static")
                this.x = 120 - this.hurtbox.x - (this.hurtbox.w / 2)
                this.y = 20

                this.vx = 0
                this.vy = 0
                this.djump = 1
                this.hitstun = 0
                this.invincible_timer = 60

                local spawn_offset_x = this.facing == 1 and 1 or 6
                for i = 1, 5 do
                    this.hair_x[i] = this.x + spawn_offset_x
                    this.hair_y[i] = this.y + 3
                end
            end
            return
        end

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.167)
            this.vx = util.appr(this.vx, 0, 0.16)
        else

            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")

            local jump = jump_btn and not this.p_jump
            local dash = dash_btn and not this.p_dash and this.dash_cooldown == 0
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
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                    this.jbuffer = 0
                end
            end

            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end

            if on_ground then
                this.grace = 6
                this.djump = 1
                if this.vy < 0 then
                    this.dash_cooldown = 0;
                    love.audio.play("maddy_clip", "static")
                end
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end

            if this.dash_time > 0 then
                this.dash_time = this.dash_time - 1

                game.init_smoke(this.x, this.y)

                this.vx = util.appr(this.vx, this.dash_target_x, this.dash_accel_x)
                this.vy = util.appr(this.vy, this.dash_target_y, this.dash_accel_y)

                local dair_landed = this.dash_target_x == 0 and this.dash_target_y > 0 and on_ground
                local hb_w, hb_h = 16, 16
                if this.down_attack then
                    hb_w, hb_h = 24, 24
                end
                --local targetX = this.x + this.vx
                --local targetY = this.y + this.vy
                local cx = this:hmid(this.vx, 0)--targetX + this.hurtbox.x + (this.hurtbox.w / 2)
                local cy = this:vmid(0, this.vy)--targetY + this.hurtbox.y + (this.hurtbox.h / 2)
                local hb_x = cx - (hb_w / 2)
                local hb_y = cy - (hb_h / 2)

                -- dash attack
                hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 1, util.sign(this.vx)*4, (this.down_attack or dair_landed) and -2 or util.sign(this.vy) * 2.5 - 1, 2)
            else
                local maxrun = 2
                local accel = on_ground and 0.93 or 0.80
                local deccel = 0.16

                this.vx = math.abs(this.vx) <= maxrun and util.appr(this.vx, h_input * maxrun, accel) or util.appr(this.vx, util.sign(this.vx) * maxrun, deccel)
                if this.vx ~= 0 then this.facing = util.sign(this.vx) end

                local maxfall = 3
                if h_input ~= 0 and this:is_solid(h_input, 0) then
                    maxfall = 0.8
                    if frameCounter % 5 == 0 then
                        game.init_smoke(this.x + h_input * 4, this.y)
                    end
                end

                if not on_ground then
                    this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
                end

                if this.jbuffer > 0 then
                    if this.grace > 0 then
                        this.jbuffer = 0
                        this.grace = 0
                        this.vy = -3.36

                        love.audio.play("maddy_jump", "static")
                        game.init_smoke(this.x, this.y + 4)
                    else
                        local wall_dir = this:is_solid(-3, 0) and -1 or (this:is_solid(3, 0) and 1 or 0)
                        if wall_dir ~= 0 then
                            this.jbuffer = 0
                            this.vx = -wall_dir * (maxrun + 1.06)
                            this.vy = -3.36
                            love.audio.play("maddy_walljump", "static")
                            game.init_smoke(this.x + wall_dir * 6, this.y)
                        end
                    end
                end

                local d_full = 6.58
                local d_half = 4.65

                if this.djump > 0 and dash then
                    this.djump = this.djump - 1
                    this.dash_time = 4

                    this.down_attack = (v_input == 1 and h_input == 0 and on_ground)

                    this.dash_cooldown = this.down_attack and 15 or 20

                    local dx = h_input ~= 0 and h_input * (v_input ~= 0 and d_half or d_full) or (v_input ~= 0 and 0 or this.facing * d_full)
                    local dy = v_input ~= 0 and v_input * (h_input ~= 0 and d_half or d_full) or 0

                    this.vx = dx
                    this.vy = dy

                    this.dash_target_x = 3.07 * util.sign(this.vx)
                    this.dash_target_y = (this.vy >= 0 and 3.07 or 2.55) * util.sign(this.vy)
                    this.dash_accel_x = this.vy == 0 and 2.37 or 1.67
                    this.dash_accel_y = this.vx == 0 and 2.37 or 1.67

                    love.audio.play(this.down_attack and "maddy_downdash" or "maddy_dash", "static")
                    game.init_smoke(this.x, this.y)
                    --camera.shake(1, 1, 2)

                    if not this.down_attack then
                        local hb_w, hb_h = 16, 16
                        local targetX = this.x + this.vx
                        local targetY = this.y + this.vy
                        local cx = targetX + this.hurtbox.x + (this.hurtbox.w / 2)
                        local cy = targetY + this.hurtbox.y + (this.hurtbox.h / 2)
                        local hb_x = cx - (hb_w / 2)
                        local hb_y = cy - (hb_h / 2)
                        hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 2, util.sign(this.vx)*4, util.sign(this.vy) * 2.5 - 1, 2 + 2)
                        this.freeze = 2
                        return
                    end
                elseif dash then
                    this.invincible_timer = 10
                    this.dash_cooldown = 20
                    this.vx, this.vy = 0, 0
                    love.audio.play("maddy_nodash", "static")
                end
            end
            this.was_on_ground = on_ground
        end

        this:move(this.vx, this.vy)
        this:check_snowballs()

        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)

        local next_anim = "idle"
        if not anim_on_ground then
            if (this.facing == 1 and this:is_solid(1, 0)) or (this.facing == -1 and this:is_solid(-1, 0)) then
                next_anim = "wallslide"
            else
                next_anim = "jump"
            end
        elseif this.dash_time > 0 and this.vx == 0 then
            next_anim = "crouch"
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

        -- hair update
        this:updateHair()

        -- blast zones and stocks (maybe move elsewhere?)
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

    on_hit_confirm = function(this, target, hb)
        -- stuff to do on hit confirm (e.g., pogoing?)
        camera.shake(1.5, 1.5, 2)
    end,

    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)
        local tint = this.skin == 3 and 1 or 0

        -- hair color
        local hr, hg, hb = unpack(this.hair_color)
        if this.djump == 0 then
            hr, hg, hb = 41 / 255, 173 / 255, 255 / 255
        elseif this.dash_cooldown > 0 then
            hr = hr * 0.75 + 0.25 * tint
            hg = hg * 0.75 + 0.25 * tint
            hb = hb * 0.75 + 0.25 * tint
        end
        -- hair hitstun tint
        if this.hitstun > 0 then
            hr = hr * (255 / 255)
            hg = hg * (119 / 255)
            hb = hb * (168 / 255)
        end
        -- hair blink
        if isBlinking then
            hr, hg, hb = 1, 1, 1
        end
        -- draw hair
        love.graphics.setColor(hr, hg, hb, 1)
        for i = 5, 1, -1 do
            local hx = math.floor(this.hair_x[i] + 0.5)
            local hy = math.floor(this.hair_y[i] + 0.5)
            if i <= 2 then
                love.graphics.rectangle("fill", hx - 2, hy - 1, 5, 3)
                love.graphics.rectangle("fill", hx - 1, hy - 2, 3, 5)
            else
                love.graphics.rectangle("fill", hx - 1, hy, 3, 1)
                love.graphics.rectangle("fill", hx, hy - 1, 1, 3)
            end
        end

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

        -- apply pal swaps
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        elseif this.djump == 0 then
            love.graphics.setShader(paletteSwapShader)
            paletteSwapShader:send("color_find", this.hair_color)
            paletteSwapShader:send("color_replace", {41 / 255, 173 / 255, 255 / 255, 1.0})
        elseif this.dash_cooldown > 0 then
            love.graphics.setShader(paletteSwapShader)
            paletteSwapShader:send("color_find", this.hair_color)
            local r, g, b = unpack(this.hair_color)
            paletteSwapShader:send("color_replace", {r * 0.75 + 0.25 * tint, g * 0.75 + 0.25 * tint, b * 0.75 + 0.25 * tint, 1.0})
        end

        sprites.draw(this.spr, this.x + cx, this.y, 0, this.facing, 1, cx, 0)

        if this.connectionID == connectionID then
            local px = math.floor(this.x)
            local py = math.floor(this.y)
            love.graphics.rectangle("fill", px + 3, py - 6, 3, 1)
            love.graphics.rectangle("fill", px + 4, py - 5, 1, 1)
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)
    end
}
