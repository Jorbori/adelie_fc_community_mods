cloud = {
    name = "cloud",
    init = function(this, dir)
        this.vx = dir * 0.65
        this.is_solid = function() return false end
        this.hurtbox = {x=0, y=0, w=16, h=0}
        this.w = 16
        this.semisolid = true
    end,
    update = function(this)
        local px = this.x
        local riders = {}
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() == this.y - 1 and o:left() <= this:right() and o:right() >= this:left() then
                if not util.tableContains(riders, o) then table.insert(riders, o) end
                if o.set_up_riders then
                    o.set_up_riders(riders)
                end
            end
        end
        this:move(this.vx, this.vy)
        local dx = this.x - px
        for _, r in ipairs(riders) do
            r:move(dx, 0)
        end

        if this.x > 300 then
            this.x = -60
        elseif this.x < -60 then
            this.x = 300
        end
    end,
    draw = function(this)
        sprites.draw(sprites["objects/cloud"], math.floor(this.x), math.floor(this.y))
    end
}

