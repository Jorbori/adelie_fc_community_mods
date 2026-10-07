-- objects/block.lua

block = {
    name = "block",
    init = function(this)
        this.connectionID = "block_" .. math.floor(this.x) .. "_" .. math.floor(this.y)
        
        this.hurtbox = {x = 0, y = 0, w = 8, h = 8}

        this.w = 6
        this.semisolid = true

        this.thrown_timer = 0
        this.held = false
        this.destroyed = false
        
        this.layer = -1
        this.freeze = 0
        
        this.draw_offset_y = 0 
        
        this.damage = 0
        this.hitstun = 0
        this.active = true

        this.hitbox_timer = 0
        
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

    update_freeze = function(this)
        if this.freeze and this.freeze > 0 then
            this.freeze = this.freeze - 1
            return
        end
    end,

    update_destruction = function(this)
        if this:right() < stage.blastZone.l or this:left() > stage.blastZone.r or this:top() > stage.blastZone.b or this.x < -500 or this.y < -500 then
            this.destroyed = true
            if this.hb then
                this.hb.active = false
                this.hb = nil
            end
            for i, o in ipairs(objects) do
                if o == this then
                    table.remove(objects, i)
                    break
                end
            end
            return true
        end
    end,

    -- this function is for handling a bug where if lani hits the stool with her grapple, it is still considered held by her until she takes damage
    lani_bug_handling = function(this, lani)
        if lani.state == 0 and not lani.holding then
            lani:release_holding(this, this.vx, this.vy, false)
            lani.grapple_hit = false
            return false
        end

        return true
    end,

    manage_hold_state = function(this)
        local is_actually_held = false

        for _, obj in ipairs(objects) do
            if obj.holding == this or obj.grapple_hit == this then
                this.throwerID = obj.connectionID
                is_actually_held = true

                if obj.type.name == "lani" then is_actually_held = goldstool.lani_bug_handling(this, obj) end --delete this if the lani bug gets fixed
                break
            end
        end
        if not is_actually_held then
            this.held = false
        end
        if this.hb then
            this.hb.active = false
            this.hb = nil
        end
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
        if not on_ground then
            this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
        end

        this.was_on_ground = on_ground

    end,

    move_riders = function(this, riders, dx, dy)
        for _, r in ipairs(riders) do
            r:move(dx, dy)
            if r.type.name == "goldstool" and r:oob() then goldstool.oobbehavior(r) end
        end
    end,

    handle_move = function(this)
        local px = this.x
        local py = this.y
        local riders = {}

        -- Set Up Riders
        this:set_up_riders(riders)

        -- Move Function
        if not this.held then this:move(this.vx, this.vy) end

        -- Move Riders
        local dx = this.x - px
        local dy = this.y - py
        block.move_riders(this, riders, dx, dy)
    end,

    create_hitboxes = function(this)
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and not this.held and frameCounter % 4 == 0 then
            local hb_w, hb_h = this.hurtbox.w + (this.hurtbox.w / 2), this.hurtbox.h + (this.hurtbox.h / 2)
            local targetX = this.x + this.vx
            local targetY = this.y + this.vy
            local cx = targetX + this.hurtbox.x
            local cy = targetY + this.hurtbox.y
            local hb_x = cx - (hb_w / 4)
            local hb_y = cy - (hb_h / 4)
            local kb_mod = this.vy > 0 and 2 or 1
            this.body_hb = hitbox.create(this.thrown_timer > 0 and this.throwerID or this.connectionID, hb_x, hb_y, hb_w, hb_h, 2, util.sign(this.vx)*3, math.abs(util.sign(this.vy) * (1.25 * kb_mod) - (0.5 * kb_mod)) * -1, 2)
        end
    end,

    update = function(this)
        block.update_freeze(this)

        if block.update_destruction(this) then return end

        if this.held then block.manage_hold_state(this) end

        if not this.held then block.manage_thrown_state(this) end

        block.update_physics(this)

        block.handle_move(this)

        block.create_hitboxes(this)
    end,

    draw = function(this)
        if this.destroyed then return end
        
        love.graphics.setColor(1, 1, 1, 1)
        sprites.draw(sprites["objects/block"], math.floor(this.x), math.floor(this.y + this.draw_offset_y))

        love.graphics.setColor(1, 1, 1, 1)
    end
}