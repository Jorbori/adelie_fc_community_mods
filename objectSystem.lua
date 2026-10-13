-- objectSystem.lua
require("objects/maddy")
require("objects/lani")
require("objects/heavy_maddy")
require("objects/gem_maddy")
require("objects/stepstools")
require("objects/goldstool")
require("objects/snowball")
require("objects/block")
require("objects/roundelie")

objectSystem = {
    createObject = function(type, x, y, ...)
        local obj = {
            type = type,
            collideable = true,
            solids = false,
            freeze = 0,
            x = x,
            y = y,
            vx = 0,
            vy = 0,
            rem = {x = 0, y = 0},
            hurtbox = {x = 0, y = 0, w = 16, h = 16}
        }

        obj.left = function(this, ox, oy)
            ox, oy = ox or 0, oy or 0
            return this.x + this.hurtbox.x + ox
        end

        obj.right = function(this, ox, oy)
            return this:left(ox, oy) + this.hurtbox.w - 1
        end

        obj.top = function(this, ox, oy)
            ox, oy = ox or 0, oy or 0
            return this.y + this.hurtbox.y + oy
        end

        obj.bottom = function(this, ox, oy)
            return this:top(ox, oy) + this.hurtbox.h - 1
        end

        obj.hmid = function(this, ox, oy)
            return math.floor((this:left(ox, oy) + this:right(ox, oy)) / 2)
        end

        obj.vmid = function(this, ox, oy)
            return math.floor((this:top(ox, oy) + this:bottom(ox, oy)) / 2)
        end

        obj.oob = function(this, ox, oy)
            return this:left(ox, oy) > stage.blastZone.r or this:bottom(ox, oy) < stage.blastZone.t or this:right(ox, oy) < stage.blastZone.l or this:top(ox, oy) > stage.blastZone.b
        end

        local function check_solid(this, px, py, p)
            return px < p.x + p.w and px + this.hurtbox.w > p.x and
                   py < p.y + p.h and py + this.hurtbox.h > p.y
        end

        local function check_semisolid(this, px, py, p)
            local curr_bottom = this.y + this.hurtbox.y + this.hurtbox.h
            local next_bottom = py + this.hurtbox.h

            return curr_bottom <= p.y and next_bottom > p.y and px < p.x + p.w and px + this.hurtbox.w > p.x
        end

        obj.is_solid = function(this, dx, dy, ignore_semisolid)
            local px = this.x + this.hurtbox.x + dx
            local py = this.y + this.hurtbox.y + dy
            for _, p in ipairs(stage.platforms) do
                if p.type == "solid" and check_solid(this, px, py, p) then
                    return p
                elseif p.type == "semisolid" and not ignore_semisolid and check_semisolid(this,px, py, p) then
                    return p
                end
            end
            for _, p in ipairs(objects) do
                if p.solid and check_semisolid(this, px, py, p) then
                    return p
                elseif p.semisolid and not ignore_semisolid and check_semisolid(this, px, py, p) then
                    return p
                end
            end
            return false
        end

        obj.move = function(this, ox, oy, on_collide_x, on_collide_y)
            this.rem.x = this.rem.x + ox
            this.rem.y = this.rem.y + oy

            local amtX = math.floor(this.rem.x + 0.5)
            local amtY = math.floor(this.rem.y + 0.5)

            this.rem.x = this.rem.x - amtX
            this.rem.y = this.rem.y - amtY

            local stepX = util.sign(amtX)
            for i = 1, math.abs(amtX) do
                if not this:is_solid(stepX, 0) then
                    this.x = this.x + stepX
                else
                    if on_collide_x and on_collide_x(this, stepX) then
                        break
                    end

                    if this.hitstun and this.hitstun > 0 then
                        local wall_bounce = 0.4
                        this.vx = -this.vx * wall_bounce
                        if math.abs(this.vx) < 0.5 then this.vx = 0 end
                    else
                        this.vx = 0
                    end
                    this.rem.x = 0
                    break
                end
            end

            local stepY = util.sign(amtY)
            for i = 1, math.abs(amtY) do
                if not this:is_solid(0, stepY) then
                    this.y = this.y + stepY
                else
                    if on_collide_y and on_collide_y(this, stepY) then
                        break
                    end

                    if this.hitstun and this.hitstun > 0 then
                        if stepY > 0 then
                            local floor_bounce = 0.75
                            this.vy = -this.vy * floor_bounce
                        else
                            local ceiling_bounce = 0.2
                            this.vy = -this.vy * ceiling_bounce
                        end
                        if math.abs(this.vy) < 0.5 then this.vy = 0 end
                    else
                        this.vy = 0
                    end
                    this.rem.y = 0
                    break
                end
            end
        end

        obj.moveWithoutCollide = function(this, ox, oy, on_collide_x, on_collide_y)
            this.rem.x = this.rem.x + ox
            this.rem.y = this.rem.y + oy

            local amtX = math.floor(this.rem.x + 0.5)
            local amtY = math.floor(this.rem.y + 0.5)

            this.rem.x = this.rem.x - amtX
            this.rem.y = this.rem.y - amtY

            local stepX = util.sign(amtX)
            for i = 1, math.abs(amtX) do
                this.x = this.x + stepX
            end

            local stepY = util.sign(amtY)
            for i = 1, math.abs(amtY) do
                this.y = this.y + stepY
            end
        end

        obj.type.init(obj, ...)

        table.insert(objects, obj)
        return obj
    end,
}
