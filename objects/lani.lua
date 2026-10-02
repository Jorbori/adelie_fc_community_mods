-- objects/lani.lua

lani = {
    name="lani",
    init = function(this, skin)
        this.connectionID = nil

        this.block = objectSystem.createObject(goldstool, this.x, this.y - 10, skin, "_")


        local player_skins = {
            {sprites["characters/lani_1"], {255 / 255, 236 / 255, 39 / 255, 1}}, -- lani
            {sprites["characters/lani_2"], {255 / 255, 163 / 255, 0 / 255, 1}}, -- elaina
            {sprites["characters/lani_3"], {255 / 255, 241 / 255, 232 / 255, 1}}, -- saena
            {sprites["characters/lani_4"], {126 / 255, 37 / 255, 83 / 255, 1}}, -- lila
        }

        local selected_skin = player_skins[tonumber(skin)] or player_skins[1]
        this.spritesheet, this.scarf_color = unpack(selected_skin)

        this.spr = this.spritesheet[7]
        this.damage = 0
        this.stocks = 3
        this.facing = 1
        this.hitstun = 0
        this.active = true

        this.hurtbox = {x = 1, y = 3, w = 6, h = 5}

        this.t_jump_grace = 0
        this.t_var_jump = 0
        this.var_jump_speed = 0

        this.grapple_x = this.x + 4
        this.grapple_y = this.y + 5
        this.grapple_dir = 0
        this.grapple_wave = 0
        this.t_grapple_cooldown = 0
        this.t_heli_cooldown = 0
        this.t_grapple_jump_grace = 0
        this.state = 0
        this.grapple_retract = false
        this.grapple_boost = false
        this.grapple_jump_grace_y = 0
        this.jump_grace_y = 0

        this.input_jump = false
        this.input_grapple = false
        this.input_jump_pressed = 0
        this.input_grapple_pressed = 0

        this.respawn_timer = 0
        this.invincible_timer = 0
        this.freeze = 0
        this.rem = {x = 0, y = 0}

        this.air_grapples = 5
        this.cling_timer = 0
        this.sweats = {}

        this.used_helicopter = false
        this.helicopter_timer = 0
        this.pickup_timer = 0

        this.holding = nil
        this.grapple_hit = nil
        this.grapple_hb = nil
        this.slam_hb = nil

        this.scarf_x = {}
        this.scarf_y = {}

        this.movementFlightLock = false
        for i = 1, 5 do
            this.scarf_x[i] = this.x + 4
            this.scarf_y[i] = this.y + 5
        end

        this.bounce = function(this, x, y)
            if this.grapple_hit and not this.grapple_hit.destroyed and (this.state == 1 or this.state == 12) then
                this.grapple_hit.held = false
            end
            if this.state >= 10 and this.state <= 12 or this.state == 1 then
                this.grapple_retract = true
            end

            this.state, this.vy, this.var_jump_speed, this.t_var_jump, this.t_jump_grace, this.auto_var_jump = 0, -4, -4, 4, 0, true
            this.vx = this.vx + util.sign(this.x - x) * 0.5
            this:move(0, y - this.y)
        end

        this.release_holding = function(this, obj, vx, vy, thrown)
            obj.held = false
            obj.vx = vx
            obj.vy = vy
            this.holding = nil
            this.movementFlightLock = false
            if obj.on_release then
                obj:on_release(thrown)
            end
            if thrown then
                hitbox.create(this.connectionID, 1 + this:hmid(obj.vx, 0) - 6, this:vmid(0, obj.vy - 4) - 6, 12, 12, 1, obj.vx, obj.vy, 2)
            end
        end

        this.corner_correct = function(this, dir_x, dir_y, side_dist, only_sign)
            only_sign = only_sign or 0
            if dir_x ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this:is_solid(dir_x, i * s) then
                                this.x = this.x + dir_x
                                this.y = this.y + i * s
                                if this.state == 11 and i > 1 then
                                    this.invincible_timer = 8
                                end
                                return true
                            end
                        end
                    end
                end
            elseif dir_y ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this:is_solid(i * s, dir_y) then
                                this.x = this.x + i * s
                                this.y = this.y + dir_y
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end

        this.on_collide_x = function(this, stepX)
            local id = this.connectionID
            local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)

            if this.state == 0 and stepX == h_input and this:corner_correct(h_input, 0, 2, -1) then
                return true
            end
            if this.state == 11 and this:corner_correct(this.grapple_dir, 0, 4, 0) then
                return true
            end
            return false
        end

        this.on_collide_y = function(this, stepY)
            local id = this.connectionID
            local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)

            if stepY < 0 and this:corner_correct(0, -1, 2, h_input) then
                return true
            end

            this.t_var_jump = 0
            return false
        end

        this.animations = {
            idle = {frames = {1}, speed = 1},
            run = {frames = {1, 2, 3, 4}, speed = 4},
            jump = {frames = {3}, speed = 1},
            throw = {frames = {4}, speed = 1},
            cling = {frames = {5}, speed = 1},
            crouch = {frames = {6}, speed = 1},
            up = {frames= {7} , speed = 1},
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0
    end,

    update = function(this)
        local id = this.connectionID

        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            if this.freeze == 0 then
                this:move(this.vx, this.vy, this.on_collide_x, this.on_collide_y)
            end
            return
        end

        if this.invincible_timer > 0 then this.invincible_timer = this.invincible_timer - 1 end

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
                this.state = 0
                this.t_grapple_cooldown = 0
                this.t_heli_cooldown = 0
                this.air_grapples = 5
                this.used_helicopter = false
                this.pickup_timer = 0
                this.sweats = {}

                this.holding = nil
                this.grapple_hit = nil
                if this.grapple_hb then this.grapple_hb.active = false; this.grapple_hb = nil end
                if this.slam_hb then this.slam_hb.active = false; this.slam_hb = nil end

                this.grapple_x = this.x + 4
                this.grapple_y = this.y + 5
                this.grapple_retract = false

                for i = 1, 5 do
                    this.scarf_x[i] = this.x + 4
                    this.scarf_y[i] = this.y + 5
                end
            end
            return
        end

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)

        if this.t_grapple_cooldown > 0 and this.state < 1 then
            this.t_grapple_cooldown = this.t_grapple_cooldown - 1
        end
        if this.t_heli_cooldown > 0 and this.state < 1 then
            this.t_heli_cooldown = this.t_heli_cooldown - 1
        end

        if this.hitstun > 0 then
            if this.grapple_hit then
                if not this.grapple_hit.destroyed then
                    this.grapple_hit.held = false
                end
                this.grapple_hit = nil
            end

            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.167)
            this.vx = util.appr(this.vx, 0, 0.16)

            if this.state >= 10 and this.state <= 12 then
                this.grapple_retract = true
            end
            
            this.t_heli_cooldown = 0
            this.t_grapple_cooldown = 0
            this.used_helicopter = false
            this.air_grapples = 5
            if this.grapple_hb then this.grapple_hb.active = false; this.grapple_hb = nil end
            if this.slam_hb then this.slam_hb.active = false; this.slam_hb = nil end

            this.state = 0
        else
            local jump_btn = inputSource.getKeyDown(id, "b1")
            local grapple_btn = inputSource.getKeyDown(id, "b2")

            this.input_jump_pressed = (jump_btn and not this.input_jump) and 4 or (jump_btn and math.max(this.input_jump_pressed - 1, 0) or 0)
            this.input_grapple_pressed = (grapple_btn and not this.input_grapple) and 4 or (grapple_btn and math.max(this.input_grapple_pressed - 1, 0) or 0)

            this.input_jump = jump_btn
            this.input_grapple = grapple_btn

            local consume_jump_press = function()
                local val = this.input_jump_pressed > 0
                this.input_jump_pressed = 0
                return val
            end
            local consume_grapple_press = function()
                local val = this.input_grapple_pressed > 0
                this.input_grapple_pressed = 0
                return val
            end

            local ground_hit = this:is_solid(0, 1)
            local on_ground = ground_hit ~= false
            local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

            if on_ground then
                this.t_jump_grace = 4
                this.jump_grace_y = this.y
                this.air_grapples = 5
                this.used_helicopter = false
            else
                this.t_jump_grace = math.max(this.t_jump_grace - 1, 0)
            end
            this.t_grapple_jump_grace = math.max(this.t_grapple_jump_grace - 1, 0)

            if this.state == 0 then
                if h_input ~= 0 then this.facing = h_input end

                local accel = (math.abs(this.vx) > 2 and h_input == util.sign(this.vx)) and 0.1 or (on_ground and 0.8 or (h_input ~= 0 and 0.4 or 0.2))
                this.vx = util.appr(this.vx, 2 * h_input, accel)

                if not on_ground then
                    local max_fall = v_input == 1 and 5.2 or 4.4
                    local grav = (math.abs(this.vy) < 0.2 and jump_btn) and 0.4 or 0.8
                    this.vy = math.min(this.vy + grav, max_fall)
                end

                if on_semisolid and v_input == 1 and jump_btn then
                    if not this:is_solid(0, 1, true) then
                        this.y = this.y + 1
                        on_ground = false
                        this.t_jump_grace = 0
                        consume_jump_press()
                    end
                end

                if this.t_var_jump > 0 then
                    if this.input_jump or this.auto_var_jump then
                        this.vy = this.var_jump_speed
                        this.t_var_jump = this.t_var_jump - 1
                    else
                        this.t_var_jump = 0
                    end
                end

                if this.input_jump_pressed > 0 then
                    if this.t_jump_grace > 0 then
                        consume_jump_press()
                        this.state, this.vy, this.var_jump_speed, this.t_var_jump, this.t_jump_grace, this.auto_var_jump = 0, -4, -4, 4, 0, false
                        this.vx = this.vx + h_input * 0.2
                        --this:move(0, this.jump_grace_y - this.y)
                        love.audio.play("maddy_jump", "static")
                    elseif this:is_solid(2, 0) then
                        consume_jump_press()
                        this.state, this.vy, this.var_jump_speed, this.vx, this.t_var_jump, this.auto_var_jump, this.facing = 0, -3, -3, -3, 4, false, -1
                        this:move(-3, 0)
                        love.audio.play("maddy_walljump", "static")
                    elseif this:is_solid(-2, 0) then
                        consume_jump_press()
                        this.state, this.vy, this.var_jump_speed, this.vx, this.t_var_jump, this.auto_var_jump, this.facing = 0, -3, -3, 3, 4, false, 1
                        this:move(3, 0)
                        love.audio.play("maddy_walljump", "static")
                    elseif this.t_grapple_jump_grace > 0 then
                        love.audio.play("maddy_jump", "static")
                        consume_jump_press()
                        this.state, this.t_grapple_jump_grace, this.vy, this.var_jump_speed, this.t_var_jump, this.auto_var_jump, this.grapple_retract = 0, 0, -3, -3, 4, false, true
                        this.vx = math.max(-4, math.min(this.vx, 4))
                        --this:move(0, this.grapple_jump_grace_y - this.y)
                    end
                end

                if this.holding then
                    if not this.input_grapple and not this.holding:is_solid(0, -2) then
                        this.holding.x = this.x
                        this.holding.y = this.y - 5

                        local b = (v_input == 1)
                        if v_input == 1 then -- drop
                            this:release_holding(this.holding, 2 * this.facing, 0, false)
                        else
                            this:release_holding(this.holding, 4 * this.facing, -1, true)
                        end
                        love.audio.play("lani_throw", "static")
                    end
                end

                if not this.holding and consume_grapple_press() then
                    if v_input == 1 and this.t_grapple_cooldown <= 0 then
                        local sb_exists = false
                        for _, o in ipairs(objects) do
                            if o.type and o.type.name == "snowball" then
                                sb_exists = true
                                break
                            end
                        end
                        if not sb_exists then
                            local sb = objectSystem.createObject(snowball, this.x, this.y + 4)
                            this.holding = sb
                            sb.held = true
                            this.state = 0
                            game.init_smoke(this.x, this.y + 4)
                            this.pickup_timer = 2
                            love.audio.play("lani_snowball", "static")
                        else
                            game.init_smoke(this.x + 4, this.y + 4)
                            love.audio.play("lani_empty", "static")
                        end
                    elseif v_input == -1 and not this.used_helicopter and this.t_heli_cooldown <= 0 then
                        this.state = 20
                        this.used_helicopter = true
                        this.helicopter_timer = 15
                        this.cling_timer = 0
                        this.vx = this.vx * 0.5
                        this.vy = math.min(this.vy * 0.25, 0)
                        love.audio.play("lani_copter", "static")

                    elseif this.t_grapple_cooldown <= 0 and (on_ground or this.air_grapples > 0) then
                        if not on_ground then
                            this.air_grapples = this.air_grapples - 1
                        end
                        this.t_grapple_cooldown = 15
                        this.cling_timer = 0
                        this.state, this.grapple_x, this.grapple_y, this.grapple_wave, this.grapple_retract, this.t_var_jump = 10, this.x + 4, this.y + 5, 0, false, 0
                        this.grapple_dir = h_input ~= 0 and h_input or this.facing
                        this.facing = this.grapple_dir
                        this.vx = 0
                        this.vy = 0
                        love.audio.play("lani_grappleout", "static")
                        
                        this.grapple_hb = hitbox.create(this.connectionID, this.grapple_x - 3, this.grapple_y - 2, 6, 5, 2, -this.grapple_dir * 1.25, -1.25, 60)
                    else
                        game.init_smoke(this.x + 4, this.y + 4)
                        love.audio.play("lani_empty", "static")
                    end
                end

            elseif this.state == 1 then
                local hold = this.grapple_hit
                if not hold.destroyed then
                    hold.x = util.appr(hold.x, this.x, 8)
                    hold.y = util.appr(hold.y, this.y - 5, 8)

                    if hold.x == this.x and hold.y == this.y - 5 then
                        this.state = 0
                        this.holding = hold
                        this.grapple_hit = nil
                    end
                else
                    this.state = 0
                    this.grapple_hit = nil
                end

            elseif this.state == 20 then
                this.helicopter_timer = this.helicopter_timer - 1
                local progress = 1 - (this.helicopter_timer / 15)

                local target_vy = (-0.5 - (progress * 1.75)) * 0.6
                local accel = 0.1 + (progress * 0.5)

                this.vy = util.appr(this.vy, target_vy, accel)
                this.vx = util.appr(this.vx, h_input * 2.5, 0.15)

                if this.helicopter_timer > 0 and this.helicopter_timer % 3 == 0 then
                    hitbox.create(this.connectionID, this.x - 8, this.y - 12, 12, 10, 1, this.vx + 1.5, math.min(-1, this.vy * 0.9), 3)
                    hitbox.create(this.connectionID, this.x + 4, this.y - 12, 12, 10, 1, this.vx - 1.5, math.min(-1, this.vy * 0.9), 3)
                end

                if this.helicopter_timer <= 0 then
                    this.state = 0
                    this.t_heli_cooldown = 15
                    this.t_grapple_cooldown = 3
                    this.vy = this.vy - 0.75

                    hitbox.create(this.connectionID, this.x - 8, this.y - 12, 24, 12, 8, this.vx * 1.5, -4, 3)
                end

            elseif this.state == 10 then
                this.vx = 0
                this.vy = 0

                local function check_point_solid(cx, cy)
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" then
                            if cx >= p.x and cx <= p.x + p.w and cy >= p.y and cy <= p.y + p.h then
                                return true
                            end
                        end
                    end
                    return false
                end

                local hit_type = 0
                for i = 1, math.min(64 - math.abs(this.grapple_x - (this.x + 4)), 6) do
                    local check_x = this.grapple_x + this.grapple_dir
                    local check_y = this.grapple_y

                    if check_point_solid(check_x, check_y) then
                        hit_type = 1
                    end

                    if hit_type == 0 then
                        for dy = -1, 1, 2 do
                            if check_point_solid(check_x, check_y + dy) then
                                hit_type = 1
                                break
                            end
                        end
                    end

                    if hit_type == 0 then
                        for _, o in ipairs(objects) do
                            if o.on_release and not o.held and not o.destroyed then -- SlimeGuy's Mods adds goldstool check
                                if check_x >= o:left() and check_x <= o:right() and check_y >= o:top() and check_y <= o:bottom() then
                                    this.grapple_hit = o
                                    hit_type = 3
                                    break
                                end
                            end
                        end
                    end

                    if hit_type == 0 then
                        this.grapple_x = this.grapple_x + this.grapple_dir * 2
                    elseif hit_type == 1 then
                        this.state, this.grapple_wave, this.grapple_boost = 11, 2, false
                        this.t_grapple_cooldown = 6 -- hit wall
                        this.slam_hb = hitbox.create(this.connectionID, this.grapple_dir == 1 and this.x + 6 or this.x - 2, this.y - 2, 4, 12, 4, this.grapple_dir * 4, -2, 60)
                        this.slam_hb.bodyslam = true
                        this.slam_hb.hit_sfx = "zap"
                        love.audio.play("lani_grapplehit", "static")
                        break
                    elseif hit_type == 3 then
                        this.grapple_hit.held = true
                        this.state, this.grapple_wave, this.grapple_boost = 12, 2, false
                        this.t_grapple_cooldown = 6 -- hit snowball
                        love.audio.play("lani_grapplehit", "static")
                        break
                    end

                    if hit_type == 0 and math.abs(this.grapple_x - (this.x + 4)) >= 64 then
                        this.grapple_retract = true
                        this.state = 0
                        break
                    end
                end

                if this.grapple_hb then
                    if this.grapple_hb.active then
                        this.grapple_hb.x = this.grapple_dir == 1 and (this.grapple_x - 16) or this.grapple_x
                        this.grapple_hb.y = on_ground and this.grapple_y - 4 or this.grapple_y - 2
                        this.grapple_hb.w = 16
                        local d = math.abs(this.grapple_x - this:hmid() - 1)
                        local k = math.min(1, d / 64)
                        this.grapple_hb.damage = math.floor(4 + k * 2)
                        this.grapple_hb.kx = k < 1 and -this.grapple_dir * 10 * k * (0.9375 - k) or this.grapple_dir * 4
                        this.grapple_hb.ky = -3 + 2 * k
                        if k == 1 then
                            this.grapple_hb.grapple_sweetspot = true
                            this.grapple_hb.hit_sfx = "zap"
                        end
                    else
                        this.t_grapple_cooldown = 6 -- hit player
                        love.audio.play("lani_grapplehit", "static")
                        this.grapple_hb = nil
                    end
                end

                this.grapple_wave = util.appr(this.grapple_wave, 1, 0.2)

                if this.state == 10 then
                    if not this.input_grapple or math.abs((this.y + 5) - this.grapple_y) > 8 then
                        this.state, this.grapple_retract = 0, true
                        love.audio.play("lani_grappleback", "static")
                    end
                end

            elseif this.state == 11 then
                if not this.grapple_boost then
                    this.grapple_boost = true
                    this.vx = this.grapple_dir * 8
                end

                this.vx = util.appr(this.vx, this.grapple_dir * 5, 0.25)
                this.vy = util.appr(this.vy, 0, 0.4)

                if this.vy == 0 and (this.y + 5) ~= this.grapple_y then
                    this:move(0, util.sign(this.grapple_y - (this.y + 5)) * 0.5)
                end

                if consume_jump_press() then
                    if this:is_solid(this.grapple_dir * 2, 0) then
                        this.state, this.vy, this.var_jump_speed, this.vx, this.t_var_jump, this.auto_var_jump, this.facing = 0, -3, -3, -this.grapple_dir * 3, 4, false, -this.grapple_dir
                        this:move(-this.grapple_dir * 3, 0)
                        love.audio.play("maddy_walljump", "static")
                    else
                        this.grapple_jump_grace_y = this.y
                        love.audio.play("lani_grapplejump", "static")
                        this.state, this.t_grapple_jump_grace, this.vy, this.var_jump_speed, this.t_var_jump, this.auto_var_jump, this.grapple_retract = 0, 0, -3, -3, 4, false, true
                        this.vx = math.max(-4, math.min(this.vx, 4))
                        this:move(0, this.grapple_jump_grace_y - this.y)
                    end
                end

                this.grapple_wave = util.appr(this.grapple_wave, 0, 0.6)

                if not this.input_grapple then
                    this.state, this.t_grapple_jump_grace, this.grapple_jump_grace_y, this.grapple_retract = 0, 4, this.y, true
                    this.facing = this.facing * -1
                    this.vx = math.abs(this.vx) <= 0.5 and 0 or math.max(-5, math.min(this.vx, 5))
                end

                if util.sign((this.x + 4) - this.grapple_x) == this.grapple_dir then
                    this.state, this.grapple_retract = 0, true
                    this.t_grapple_jump_grace = 4
                    this.grapple_jump_grace_y = this.y
                    this.vx = util.sign(this.vx) * math.min(5, math.abs(this.vx))
                end

                if this.state == 11 and this:is_solid(this.grapple_dir, 0) then
                    this.cling_timer = this.cling_timer + 1

                    if this.cling_timer > 30 and math.random() < 0.2 then
                        table.insert(this.sweats, {
                            x = this.x + 4 + math.random(-2, 2),
                            y = this.y + math.random(0, 4),
                            vy = -0.5
                        })
                    end

                    if this.cling_timer >= 60 then
                        this.state, this.grapple_retract = 0, true
                        this.t_grapple_jump_grace = 4
                        this.grapple_jump_grace_y = this.y
                        this.vx = 0
                        this.cling_timer = 0
                    end
                else
                    this.cling_timer = 0
                end

            elseif this.state == 12 then
                local obj = this.grapple_hit
                if obj.destroyed then
                    this.state, this.grapple_retract = 0, true
                else
                    local overlap_x = obj:right() >= this:left() and obj:left() <= this:right()
                    local overlap_y = obj:bottom() >= this:top() and obj:top() <= this:bottom()

                    if overlap_x and overlap_y then
                        this.state = 1
                        this.grapple_retract = true
                        love.audio.play("maddy_jump", "static")
                    else
                        local amt = -this.grapple_dir * 6
                        local step = util.sign(amt)
                        local pull_collided = false

                        for i = 1, math.abs(amt) do
                            if not obj:is_solid(step, 0) then
                                obj.x = obj.x + step
                            else
                                if not obj.corner_correct(obj, step, 0, 4, 0) then
                                    pull_collided = true
                                    break
                                end
                            end
                        end

                        if pull_collided then
                            this.state, this.grapple_retract, obj.held = 0, true, false
                        else
                            this.grapple_x = util.appr(this.grapple_x, this.x + 4, 6)
                        end

                        local target_y = this.y - 5
                        if obj.y ~= target_y then
                            obj.y = obj.y + util.sign(target_y - obj.y) * 0.5
                        end

                        this.grapple_wave = util.appr(this.grapple_wave, 0, 0.6)

                        if not this.input_grapple or math.abs(obj.y - target_y) > 8 or util.sign((obj.x + 4) - (this.x + 4)) == -this.grapple_dir then
                            this.state, this.grapple_retract = 0, true
                            this:release_holding(obj, -this.grapple_dir * 5, 0, true)
                        end
                    end
                end
            end
        end

        if this.state ~= 10 and this.grapple_hb then
            this.grapple_hb.active = false
            this.grapple_hb = nil
        end

        if this.grapple_retract then
            this.grapple_x = util.appr(this.grapple_x, this.x + 4, 12)
            this.grapple_y = util.appr(this.grapple_y, this.y + 5, 6)
            if this.grapple_x == this.x + 4 and this.grapple_y == this.y + 5 then
                this.grapple_retract = false
            end
        end

        -- Mod checks for if lani should follow goldstool in flight
        if this.movementFlightLock and this.holding then 
            this:move(this.holding.vx, this.holding.vy) --
        else 
            this:move(this.vx, this.vy, this.on_collide_x, this.on_collide_y) --
        end

        -- slam hitbox
        if this.state == 11 and not this:is_solid(this.grapple_dir, 0) then
            if this.slam_hb then
                if this.slam_hb.active then
                    this.slam_hb.x = this.grapple_dir == 1 and this.x + 6 or this.x - 2
                    this.slam_hb.y = this.y - 2
                else
                    this.slam_hb = nil
                    love.audio.play("hit", "static")
                end
            end
        else
            if this.slam_hb then
                this.slam_hb.active = false
                this.slam_hb = nil
            end
        end

        lani.check_goldstool_is_flying(this) -- Mod checks for if lani needs to goldstool fly

        if this.holding then
            this.holding.x = this.x
            if this.pickup_timer > 0 then
                this.holding.y = this.pickup_timer == 2 and (this.y + 4) or this.y
                this.pickup_timer = this.pickup_timer - 1
            else
                this.holding.y = this.y - 5
            end

            local v_in = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
            local is_crouching = (this.state == 0 and this:is_solid(0, 1) and v_in == 1)

            this.holding.draw_offset_y = is_crouching and 1 or 0
        end

        for i = #this.sweats, 1, -1 do
            local sw = this.sweats[i]
            sw.y = sw.y + sw.vy
            sw.vy = sw.vy + 0.1
            if sw.y > this.y + 12 then
                table.remove(this.sweats, i)
            end
        end

        for _, o in ipairs(objects) do
            if o.type and o.type.name == "snowball" and not o.held and not o.destroyed then
                local o_left = o:left()
                local o_right = o:right()

                if math.abs(o.vx) > 0 then
                    o_left = o.x - 2
                    o_right = o.x + 9
                end

                local overlap_x = this:right() >= o_left and this:left() <= o_right
                local overlap_y = this:bottom() >= o:top() and this:top() <= o:bottom()

                if overlap_x and overlap_y then
                    if this.vy >= 0 and (this.y + 7 - this.vy) < (o.y + o.vy + 4) then
                        this:bounce(o.x + 4, o.y - 7)
                        love.audio.play("maddy_jump", "static")
                        o.freeze = 1
                        o.vy = -1
                    end
                end
            end
        end

        local next_anim = "idle"
        if this.state == 20 then
            next_anim = "up"
        elseif this.state == 10 then
            next_anim = "throw"
        elseif this.state == 11 then
            if this:is_solid(this.grapple_dir, 0) then
                next_anim = "cling"
            else
                next_anim = "throw"
            end
        elseif not this:is_solid(0, 1) then
            next_anim = "jump"
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
        this.spr = this.spritesheet[anim.frames[this.anim_frame]]

        local last_x = this.x + 4 - this.facing
        local last_y = this.y + 5
        local time = love.timer.getTime()

        for i = 1, #this.scarf_x do
            local p8_sin = -math.sin((time + i * 0.25) * math.pi * 2)

            this.scarf_x[i] = this.scarf_x[i] + (last_x - this.scarf_x[i] - this.facing) / 1.5
            this.scarf_y[i] = this.scarf_y[i] + (last_y - this.scarf_y[i] + p8_sin * i * 0.25) / 2

            local dx = this.scarf_x[i] - last_x
            local dy = this.scarf_y[i] - last_y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 1.5 then
                this.scarf_x[i] = last_x + (dx / dist) * 1.5
                this.scarf_y[i] = last_y + (dy / dist) * 1.5
            end

            last_x = this.scarf_x[i]
            last_y = this.scarf_y[i]
        end

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
            this.sweats = {}
            this.used_helicopter = false

            if this.holding then
                this:release_holding(this.holding, 0, 0, false)
            end

            if this.grapple_hit and not this.grapple_hit.destroyed and (this.state == 1 or this.state == 12) then
                this.grapple_hit.held = false
            end

            if this.grapple_hb then this.grapple_hb.active = false; this.grapple_hb = nil end
            if this.slam_hb then this.slam_hb.active = false; this.slam_hb = nil end

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

    check_goldstool_is_flying = function(this)
        if this.holding and this.holding.flying and this.holding.flystarttimer <= 0 then
            this.movementFlightLock = true
            
            -- force a drop if lani hits a celing or wall
            local hit_ceiling = this:is_solid(0, -1) or this.holding:is_solid(0, -1)
            local hit_wall = this:is_solid(util.sign(this.vx), 0)

            if (hit_ceiling or hit_wall) and (this.holding.flylock <= 0) then
                this.holding.held = false
                this.holding.collides = true
                this.holding = nil
                this.movementFlightLock = false
            end

            -- OOB check
            if this.holding and this.holding:oob() then
                this.holding.held = false
                this.holding.collides = true
                this.holding = nil
                this.movementFlightLock = false
                this.y = stage.blastZone.t - 50
            end
        end
    end,

    on_hit_confirm = function(this, target, hb)
        camera.shake(1.5, 1.5, 2)
        if hb.bodyslam then
            -- body slam
            this.freeze = 4
            target.freeze = 4
            table.insert(particles_fg, {
                x = target:hmid(), y = target:vmid(),
                timer = 0,
                duration = 8,
                update = function(p)
                    p.timer = p.timer + 1
                    return p.timer >= p.duration
                end,
                draw = function(p)
                    local fade = 1 - (p.timer / p.duration)
                    local len = p.timer * 4
                    love.graphics.setColor(1, 1, 1, fade)
                    love.graphics.rectangle("fill", math.floor(p.x - len / 2), math.floor(p.y - 1), len, 2)
                    love.graphics.rectangle("fill", math.floor(p.x - 1), math.floor(p.y - len), 2, len * 2)
                    love.graphics.setColor(1, 1, 1, 1)
                end
            })
        elseif hb.grapple_sweetspot then
            -- tipper sparks
            this.freeze = 6
            target.freeze = 6
            camera.shake(3, 3, 5)
            for i = 1, 8 do
                table.insert(particles_fg, {
                    x = target:hmid(),
                    y = target:vmid(),
                    vx = (math.random() * 8 - 4) + this.grapple_dir * 1.5,
                    vy = (math.random() * 8 - 4) - 1,
                    timer = 0,
                    duration = 10 + math.random(0, 10),
                    update = function(p)
                        p.x = p.x + p.vx
                        p.y = p.y + p.vy
                        p.vx = p.vx * 0.85
                        p.vy = p.vy * 0.85
                        p.timer = p.timer + 1
                        return p.timer >= p.duration
                    end,
                    draw = function(p)
                        local fade = 1 - (p.timer / p.duration)
                        if p.timer < 4 then
                            love.graphics.setColor(1, 1, 1, fade)
                        else
                            love.graphics.setColor(255/255, 236/255, 39/255, fade)
                        end
                        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                        if (p.vx * p.vx + p.vy * p.vy) > 1.5 then
                            love.graphics.setColor(255/255, 163/255, 0/255, fade * 0.6)
                            love.graphics.rectangle("fill", math.floor(p.x - p.vx * 0.6), math.floor(p.y - p.vy * 0.6), 1, 1)
                        end
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                })
            end
        end
    end,

    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)

        local last_x = this.x + 4 - this.facing
        local last_y = this.y + 5

        local sr, sg, sb, sa = unpack(this.scarf_color)
        if this.t_grapple_cooldown > 0 or this.air_grapples == 0 then
            sr, sg, sb = sr * 0.75, sg * 0.75, sb * 0.75
        end
        if this.hitstun > 0 then
            sr, sg, sb = sr * 255 / 255, sg * 119 / 255, sb * 168 / 255
        end
        if isBlinking then
            hr, hg, hb = 1, 1, 1
        end
        love.graphics.setColor(sr, sg, sb, 1)
        for i = 1, #this.scarf_x do
            love.graphics.rectangle("fill", math.floor(this.scarf_x[i]), math.floor(this.scarf_y[i]), 1, 1)
            love.graphics.rectangle("fill", math.floor((this.scarf_x[i] + last_x) / 2), math.floor((this.scarf_y[i] + last_y) / 2), 1, 1)
            last_x = this.scarf_x[i]
            last_y = this.scarf_y[i]
        end

        if this.state >= 10 and this.state <= 12 then
            local amplitude = 2 * this.grapple_wave
            if amplitude > 0.1 then
                local x0, x1 = this.x + 4, this.grapple_x
                local y0 = this.y + 5
                local x_sign = util.sign(x1 - x0)
                local x_max = math.abs(x1 - x0) - 1

                for i = 1, x_max do
                    local fade_x_dist = 6
                    local fade = (i <= fade_x_dist) and (i / (fade_x_dist + 1)) or (i > x_max - fade_x_dist + 1 and (x_max + 1 - i) / (fade_x_dist + 1) or 1)
                    local ax = x0 + i * x_sign
                    local ay = y0 + math.sin(love.timer.getTime() * 24 + i * 0.08) * amplitude * fade

                    love.graphics.setColor(29/255, 43/255, 83/255, 1)
                    love.graphics.rectangle("fill", ax, ay + 1, 1, 1)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.rectangle("fill", ax, ay, 1, 1)
                end
            else
                -- avoid love.graphics.line
                local x0, x1 = math.floor(this.x + 4), math.floor(this.grapple_x)
                local y0, y1 = math.floor(this.y + 5), math.floor(this.grapple_y)
                local dx, dy = x1 - x0, y1 - y0
                local steps = math.max(math.abs(dx), math.abs(dy))

                for i = 0, steps do
                    local t = steps == 0 and 0 or i / steps
                    local lx = math.floor(x0 + dx * t)
                    local ly = math.floor(y0 + dy * t)

                    love.graphics.setColor(29/255, 43/255, 83/255, 1)
                    love.graphics.rectangle("fill", lx, ly + 1, 1, 1)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.rectangle("fill", lx, ly, 1, 1)
                end
            end
        end

        if this.state == 20 and not isBlinking then
            local time = love.timer.getTime() * 45
            local cx = this.x + 4
            local cy = this.y - 2
            local rx = 10
            local ry = 3

            love.graphics.setColor(1, 1, 1, 1)
            for i = 0, 8 do
                local px = cx + math.cos(time - i * 0.3) * rx
                local py = cy + math.sin(time - i * 0.3) * ry
                love.graphics.rectangle("fill", math.floor(px), math.floor(py), 1, 1)
            end

            local hx = cx + math.cos(time) * rx
            local hy = cy + math.sin(time) * ry
            local x0, y0 = math.floor(this.x + 4), math.floor(this.y + 3)
            local dx, dy = math.floor(hx) - x0, math.floor(hy) - y0
            local steps = math.max(math.abs(dx), math.abs(dy))
            for i = 0, steps do
                local t = steps == 0 and 0 or i / steps
                local lx, ly = math.floor(x0 + dx * t), math.floor(y0 + dy * t)
                love.graphics.setColor(29/255, 43/255, 83/255, 1)
                love.graphics.rectangle("fill", lx, ly + 1, 1, 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", lx, ly, 1, 1)
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", math.floor(hx)-1, math.floor(hy)-1, 2, 2)
        end

        if this.grapple_retract then
            local x0, x1 = math.floor(this.x + 4), math.floor(this.grapple_x)
            local y0, y1 = math.floor(this.y + 5), math.floor(this.grapple_y)
            local dx, dy = x1 - x0, y1 - y0
            local steps = math.max(math.abs(dx), math.abs(dy))

            for i = 0, steps do
                local t = steps == 0 and 0 or i / steps
                local lx, ly = math.floor(x0 + dx * t), math.floor(y0 + dy * t)
                love.graphics.setColor(29/255, 43/255, 83/255, 1)
                love.graphics.rectangle("fill", lx, ly + 1, 1, 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", lx, ly, 1, 1)
            end
        end

        if isBlinking then
            love.graphics.setShader(whiteShader)
        elseif this.t_grapple_cooldown > 0 or this.air_grapples == 0 then
            love.graphics.setShader(paletteSwapShader)
            paletteSwapShader:send("color_find", this.scarf_color)
            local r, g, b, a = unpack(this.scarf_color)
            paletteSwapShader:send("color_replace", {r * 0.75, g * 0.75, b * 0.75, a or 1.0})
        end

        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end

        sprites.draw(this.spr, this.x + 4, this.y + 8, 0, this.facing, 1, 4, 8)

        love.graphics.setShader()

        if not isBlinking then
            love.graphics.setColor(41/255, 173/255, 255/255, 1)
            for _, sw in ipairs(this.sweats) do
                love.graphics.rectangle("fill", math.floor(sw.x), math.floor(sw.y), 1, 1)
            end
        end

        if this.connectionID == connectionID then
            local px = math.floor(this.x)
            local py = math.floor(this.y)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", px + 3, py - 6, 3, 1)
            love.graphics.rectangle("fill", px + 4, py - 5, 1, 1)
        end

        love.graphics.setColor(1, 1, 1)
    end
}
