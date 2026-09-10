-- https://www.love2d.org/wiki/General_math
-- TODO: probably should throw these into util?
local function clamp(low, n, high) return math.min(math.max(low, n), high) end
local function lerp(a, b, t) return (1 - t) * a + t * b end
-- https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Cubic_B%C3%A9zier_curves
-- pt a -> pt b; c1 and c2 are control pts that determine the smoothness of the curve
local function cubic_bezier(a, b, c1, c2, t)
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t

    local x = uuu * a.x + 3 * uu * t * c1.x + 3 * u * tt * c2.x + ttt * b.x
    local y = uuu * a.y + 3 * uu * t * c1.y + 3 * u * tt * c2.y + ttt * b.y

    return { x = x, y = y }
end

--
local path_type = { LINEAR = "linear", CURVED = "curved" }

--[[
TODO: ((?) => "maybe", (*) => "high priority")
    - (?) don't draw black outline around moving platforms
    - (?) support for more complex platform sprites
        - optional separate bg and fg
    - (?) cleaner init
    - (?) support for arbitrary starting location (e.g. roa2 tempest peak, stormswept pillar)
        - would also be useful for making adjustments to balance spawn positions (at the start of the match)
    - (?) support for arbitrary # of waypoints
        - prooobably just for linear paths? e.g. melee yoshi's island
        - or add a new path type for it (that sounds better I think)
    - ...
--]]

moving_platform = {
    name = "moving_platform",
    
    init = function(this, w)
        this.is_solid = function() return false end
        this.hurtbox = {x=0, y=0, w=w, h=0}
        this.w = w
        this.semisolid = true
        --
        this.sprite = nil
        this.sprite_ox = 0  -- optional sprite offset
        this.sprite_oy = 0  --
        
        -- platform moves from a -> b -> a ... on repeat
        this.ptA = {x = this.x,      y = this.y}
        this.ptB = {x = this.x + 24, y = this.y}
        
        this.movement_duration = 90     -- time (in ticks) for platform to move between pts
        this.movement_timer = 0         --  ^ tracks # ticks for duration
        this.movement_delay = 30        -- time (in ticks) for platform to pause at the destination before resuming movement
        this.movement_delay_timer = 0   --  ^ tracks # ticks for delay
        this.movement_smoothing = false -- if true, apply smoothstep calculation to ease in and out of movement
        
        this.movement_path_type = path_type.LINEAR
        -- this.ptC1 = {x =  this.x + 8, y = this.y + 16}  -- additional control pts are used when defining a CURVED movement path
        -- this.ptC2 = {x = this.x + 16, y = this.y - 16}
        
    end,
    update = function(this)
        
        local px, py = this.x, this.y
        local riders = {}
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() == this.y - 1 and o:left() <= this:right() and o:right() >= this:left() then
                table.insert(riders, o)
                
                if o.set_up_riders then  -- support for goldstool
                    o.set_up_riders(o, riders)
                end
            end
        end
        
        local target_x, target_y
        
        if this.movement_timer < this.movement_duration then
            local t = clamp(0.0, this.movement_timer / this.movement_duration, 1.0)
            if this.movement_smoothing then
                t = t * t * (3 - 2 * t)
            end
            
            if this.movement_path_type == path_type.LINEAR then
                target_x = lerp(this.ptA.x, this.ptB.x, t)
                target_y = lerp(this.ptA.y, this.ptB.y, t)
            elseif this.movement_path_type == path_type.CURVED then
                local result = cubic_bezier(this.ptA, this.ptB, this.ptC1, this.ptC2, t)
                target_x, target_y = result.x, result.y
            end
            this.movement_timer = this.movement_timer + 1
            
        elseif this.movement_delay_timer < this.movement_delay then
            this.movement_delay_timer = this.movement_delay_timer + 1
            target_x, target_y = this.ptB.x, this.ptB.y
        else
            this.movement_timer = 1
            this.movement_delay_timer = 0
            
            this.rem.x, this.rem.y = 0, 0
            this.x, this.y = this.ptB.x, this.ptB.y
            target_x, target_y = this.x, this.y
            
            -- swap directions
            local temp = this.ptA
            this.ptA = this.ptB
            this.ptB = temp
            --
            temp = this.ptC1
            this.ptC1 = this.ptC2
            this.ptC2 = temp
        end
        
        -- rounding is needed to avoid more jittery movement at pt B compared to at pt A
        local dx = math.floor(target_x + 0.5) - px
        local dy = math.floor(target_y + 0.5) - py
        
        -- need to update rem here to avoid loss of precision
        this.rem.x = target_x - px - dx
        this.rem.y = target_y - py - dy
        
        -- update the platform
        this:move(dx, dy)
        
        -- update riders
        dx = this.x - px
        dy = this.y - py
        for _, r in ipairs(riders) do
            r:move(dx, dy)
        end
    end,
    draw = function(this)
        
        if this.sprite then
            sprites.draw(this.sprite, math.floor(this.x) + this.sprite_ox, math.floor(this.y) + this.sprite_oy)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.rectangle("fill", math.floor(this.x), math.floor(this.y), this.w, 3)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
}
