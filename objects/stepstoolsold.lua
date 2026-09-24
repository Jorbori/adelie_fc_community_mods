-- objects/woodstool.lua

stepstools = {
    name="stepstools",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/woodstool_1"], {1, 1, 1, 1}}, -- oak
            {sprites["characters/woodstool_2"], {1, 1, 1, 1}}, -- birch
            {sprites["characters/woodstool_3"], {1, 1, 1, 1}}, -- acacia
            {sprites["characters/woodstool_4"], {1, 1, 1, 1}}, -- cherry
        }
        
        this.spritesheet, this.nothing = unpack(player_skins[tonumber(skin)])
        this.skin = skin
        this.spr = this.spritesheet[7]
        this.damage = 0
        this.stocks = 3
        this.facing = 1
        this.hitstun = 0
        this.active = true

        -- Override the base hurtbox
        this.hurtbox = {x = 1, y = 3, w = 6, h = 5}
        -- this.w = 6
        -- this.semisolid = true

        this.grace = 0
        this.jbuffer = 0

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
            kick = {frames = {8}, speed = 1},
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0

        this.respawn_timer = 0
        this.invincible_timer = 0
        this.dash_cooldown = 0
        this.freeze = 0

        this.holding = nil

        this.goldstool = objectSystem.createObject(goldstool, this.x, stage.blastZone.b + 10, skin, this)

        this.exhaustion = 0
        this.exhaustionLimit = 3
        this.sweats = {}
        this.sweatTimer = 0

        this.self_throw = 0
        this.self_throw_cooldown = 0
        this.self_throw_blink_timer = 0;

        this.movementFlightLock = false

        this.body_hb = nil
        this.body_timer = 0

        this.in_pickup_range = function(this, o)
            return this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= (o:top() - 4) and this:top() <= (o:bottom() + 4) and not o.held
        end

        this.check_for_pickup = function()
            for _, o in ipairs(objects) do
                if o.on_release and not o.destroyed then
                    if this:in_pickup_range(o) then
                        return o
                    end
                end
            end
            return nil
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

    update = function(this)
        local id = this.connectionID

        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            if this.freeze == 0 then
                this:move(this.vx, this.vy) -- hack so we don't miss a move when we freeze
                this:check_snowballs()
            end
            return
        end

        -- iframes
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
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
                this.self_throw = 1
                this.hitstun = 0
                this.invincible_timer = 60

                this.sweats = {}

                local spawn_offset_x = this.facing == 1 and 1 or 6
            end
            return
        end

        -- exhaustion effect
        if this.exhaustion >= this.exhaustionLimit then
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

        -- Set Up Riders
        -- local px = this.x
        -- local py = this.y
        -- local riders = {}
        -- for _, o in ipairs(objects) do
        --     if o ~= this and o:bottom() >= this.y - 5 and o:bottom() <= this.y and o:left() <= this:right() and o:right() >= this:left() then
        --         table.insert(riders, o)
        --     end
        -- end

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun
        if this.hitstun > 0 then
            if this.self_throw == 2 then this.self_throw = 1 end
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.167)
            this.vx = util.appr(this.vx, 0, 0.16)
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
            local on_self_goldstool = on_semisolid and this:check_for_pickup() and this:check_for_pickup().type.name == "goldstool"

            if on_ground and not this.was_on_ground then
                game.init_smoke(this.x, this.y + 4)
                this.self_throw = 0
            end

            if on_ground and this.vy > 0 then
                this.vy = 0
            end

            if on_ground and (not on_self_goldstool or (this.goldstool:is_solid(0, 1) and not this.goldstool.flying)) then
                this.exhaustion = 0
            end

            if not (this.holding and this.holding.flying) then
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
                    if this.vy < 0 then
                        love.audio.play("maddy_clip", "static")
                    end
                elseif this.grace > 0 then
                    this.grace = this.grace - 1
                end
                local maxrun = 2
                local accel = on_ground and 0.93 or 0.80
                local deccel = 0.16

                if this.self_throw == 2 then
                    this.vx = util.appr(this.vx, h_input * (maxrun * 0.35), 0.2 or 0.18)
                else
                    this.vx = math.abs(this.vx) <= maxrun and util.appr(this.vx, h_input * maxrun, accel) or util.appr(this.vx, util.sign(this.vx) * maxrun, deccel)
                end
                if this.vx ~= 0 then this.facing = util.sign(this.vx) end

                local maxfall = 2.6
                if h_input ~= 0 and this:is_solid(h_input, 0) then
                    if this.self_throw == 2 then this.self_throw = 1 end
                    maxfall = 0.693
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
                            if this.self_throw == 2 then this.self_throw = 1 end
                            this.jbuffer = 0
                            this.vx = -wall_dir * (maxrun + 1.06)
                            this.vy = -3.36
                            love.audio.play("maddy_walljump", "static")
                            game.init_smoke(this.x + wall_dir * 6, this.y)
                        end
                    end
                end
            end

            if this.holding and this.holding.flying and this.holding.flystarttimer <= 0 then
                this.movementFlightLock = true
                
                -- ONLY force a drop if we hit a CEILING or a WALL. 
                -- We ignore the floor (is_solid(0, 1)) because you start on the floor.
                local hit_ceiling = this:is_solid(0, -1) or this.holding:is_solid(0, -1)
                local hit_wall = this:is_solid(util.sign(this.vx), 0)

                -- Use <= 0 so it works with the goldstool's countdown
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
                    this.y = stage.blastZone.t - 10
                end
            end

            local pickupcheck = this:check_for_pickup()

            local touching_field = false
            for _, o in ipairs(objects) do
                if o.type and (o.type.name == "goldstool" or o.type.name == "snowball") and not o.destroyed and o ~= this.holding and o ~= this.goldstool and o ~= pickupcheck then
                    if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                        touching_field = true
                        break
                    end
                end
            end


            -- pickup objects with ⬇️❎ (also cancel dash if you do this)
            if this.holding then
                local pickup = this.holding

                if on_ground then pickup.exhaustion = 0 end
                
                if (not touching_field) then
                    pickup:move(this.x - pickup.x, this.y - 4 - pickup.y)
                end 
                
                if dash or touching_field then
                    pickup.held = false
                    pickup.collides = true
                    this.holding = nil
                    
                    -- don't drop in ceiling
                    while pickup:is_solid(0, 0) do
                        pickup.y = pickup.y + 1
                    end
                    
                    -- throw
                    if dash then
                        pickup.vx = inputSource.getKeyDown(id, "left") and -4 or inputSource.getKeyDown(id, "right") and 4 or (inputSource.getKeyDown(id, "up") or inputSource.getKeyDown(id, "down")) and 0 or this.facing < 0 and -4 or 4
                        pickup.vy = inputSource.getKeyDown(id, "down") and 0 or inputSource.getKeyDown(id, "up") and -3 or -1
                        if pickup.on_release then
                            pickup:on_release()
                        end
                        if pickup.type.name == "snowball" and ((this.facing == 1 and this:is_solid(1, 0)) or (this.facing == -1 and this:is_solid(-1, 0))) then
                            pickup.y = pickup.y - 29
                            pickup.vy = -3
                        end
                        love.audio.play("lani_throw", "static")
                        this.movementFlightLock = false
                    else
                        pickup.vx = this.vx * -0.5
                        pickup.vy = this.vy * -0.5
                    end
                    
                    dash = false
                end
            else
                local pickup = this:check_for_pickup()
                if dash and inputSource.getKeyDown(id, "down") and pickup and not touching_field and this.exhaustion < this.exhaustionLimit then
                    dash = false
                    
                    if this.self_throw == 2 then this.self_throw = 1 end
                    pickup.held = true
                    pickup.collides = false
                    pickup.flying = false
                    pickup.throwerID = this.connectionID
                    this.holding = pickup
                    this.exhaustion = this.exhaustion + 1
                    
                    -- boost
                    if not this:is_solid(0, 1) then
                        this.vy = -3.2
                        
                        if not this:is_solid(0, -3) then
                            this.grace = 6
                        end
                    end
                else
                    if dash then
                        if inputSource.getKeyDown(id, "down") and this.goldstool.exhaustion <= this.goldstool.exhaustionLimit then
                            this.goldstool.flying = true
                            this.goldstool.collides = false
                            this.goldstool.flylock = 11
                        elseif this.self_throw == 0 and this.self_throw_cooldown == 0 then
                            this.vx = inputSource.getKeyDown(id, "left") and -4 or inputSource.getKeyDown(id, "right") and 4 or (inputSource.getKeyDown(id, "up") or inputSource.getKeyDown(id, "down")) and 0 or this.facing < 0 and -4 or 4
                            this.vy = inputSource.getKeyDown(id, "down") and 0 or inputSource.getKeyDown(id, "up") and -3 or -1
                            this.self_throw = 2
                            this.self_throw_cooldown = 15
                            this.self_throw_blink_timer = 0
                            love.audio.play("lani_throw", "static")
                        end
                    end
                end
                end

                    local d_full = 6.58
                    local d_half = 4.65
                
                    
                this.was_on_ground = on_ground
            end

        if this.movementFlightLock and this.holding then this:move(this.holding.vx, this.holding.vy)
        else this:move(this.vx, this.vy) end
        
        

        -- Move riders
        -- local dx = this.x - px
        -- local dy = this.y - py
        -- for _, r in ipairs(riders) do
        --    r:move(dx, dy)
        -- end
        
        -- Update carried object position after movement
        if this.holding then
            this.holding.x = this.x
            this.holding.y = this.y - 4
        end
        
        this:check_snowballs()

        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)

        -- self_throw_blink_timer managment
        this.self_throw_blink_timer = this.self_throw_blink_timer + 1
        this.self_throw_blink_timer = this.self_throw_blink_timer % 15

        local next_anim = "idle"
        if not anim_on_ground then
            if this.self_throw == 2 then
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
            this.sweats = {}
            this.self_throw = 0
            this.self_throw_cooldown = 0
            this.exhaustion = 0
            if this.holding then
                this.holding.held = false
                this.holding = nil
            end

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

        -- Self Throw Damage
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and this.self_throw == 2 and this.body_timer <= 0 then
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

        if this.self_throw_cooldown > 0 then this.self_throw_cooldown = this.self_throw_cooldown - 1 end
    end,

    transition_idle = function(this)
    end,

    transition_holding = function(this)
    end,

    transition_kicking = function(this)
    end,

    grounded_set_vars = function(this)
    end,

    wallslide_set_vars = function(this)
    end,

    on_hit_confirm = function(this, target, hb)
        -- stuff to do on hit confirm (e.g., pogoing?)
        camera.shake(1.5, 1.5, 2)
        if hb.firstframe then
            local direction = hb.dir or 1
            -- tipper sparks
            this.freeze = 6
            target.freeze = 6
            camera.shake(3, 3, 5)
            for i = 1, 8 do
                table.insert(particles_fg, {
                    x = target:hmid(),
                    y = target:vmid(),
                    vx = (math.random() * 8 - 4) + direction * 1.5,
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
        if hb == this.body_hb then this.body_timer = 4 end
        if hb == this.goldstool.body_hb then this.goldstool.body_timer = 4 end
        if hb == this.goldstool.leftwing_hb or hb == this.goldstool.rightwing_hb then this.goldstool.wings_timer = 4 end
    end,
 
    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)
        local tint = this.skin == 3 and 1 or 0

        -- sprite hitstun tint
        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        elseif this.self_throw > 0 and this.self_throw_blink_timer < 6 then
            love.graphics.setColor(162 / 255, 136 / 255, 121 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end

        -- apply pal swaps
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        end

        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w / 2)

        sprites.draw(this.spr, this.x + cx, this.y, 0, this.facing, 1, cx, 0)

        if this.connectionID == connectionID then
            local px = math.floor(this.x)
            local py = math.floor(this.y)
            love.graphics.rectangle("fill", px + 3, py - 6, 3, 1)
            love.graphics.rectangle("fill", px + 4, py - 5, 1, 1)
        end

        -- exhaustion effect
        if not isBlinking then
            love.graphics.setColor(41/255, 173/255, 255/255, 1)
            for _, sw in ipairs(this.sweats) do
                love.graphics.rectangle("fill", math.floor(sw.x), math.floor(sw.y), 1, 1)
            end
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)

        
    end
}
