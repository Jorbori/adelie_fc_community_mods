-- objects/roundelie.lua
-- v0.8.1

-- Movement Documentation:
-- Z to jump, left and right arrow keys to move
-- X + Up causes a small midair "bounce" slightly smaller than a jump. 
--   Can be done up to 3 times before touching the ground
--   Was changed to have no cooldown between uses (but the parameter to adjust cooldown time was not removed)
-- X + Down causes roundelie to accelerate downward quickly while held
--   Has a top speed higher than the regular terminal velocity
--   Has a hitbox that pushes opponents downward, which may "trap" them as they fall
--     - There's a 1f delay before the hitbox comes out, and an initial burst of speed is applied after the delay
--     - The hitbox remains active as long as the input is held, or until roundelie collides a wall or with the ground
--   If X + Down is held when roundelie hits a wall, roundelie bounces back and upward off the wall
--   (ie in the direction opposite roundelie's facing direction, not necessarily away from the wall)
--   If X + Down is held when roundelie hits ground, roundelie bounces back and upward off the ground and sends out a shockwave
--     Roundelie's bounce and the shockwave are larger if roundelie hits the ground at the max speed of the down + x attack
--     The shockwave does upward knockback to all opponents at ground height and somewhat close to roundelie laterally
--     The shockwave is slightly offset laterally in the direction roundelie was facing when they hit the ground
--     This hitbox is also marked by particles for clarity
-- X + Left/Right/Nothing causes roundelie to teleport in the held direction
--   Zeros roundelie's x speed, but does not change its y speed
--   Has a 2 second cooldown before roundelie can teleport again
--   This is indicated by the color of roundelie's beak, which changes when the teleport is unavailable
--   Has a hitbox that sends opponents in the direction held 1f after the teleport (not necessarily the teleport direction)
--      TODO: ^ I don't think this is actually true? I never switch input during or immediately after teleport but I regularly send opponent flying in the opposite direction
--   Roundelie is invulnerable for the first two frames of the teleport, and the hitbox is also active for those first two frames
--   There's a 3f delay before roundelie can act out of a teleport, e.g. buffering a grace-jump
-- Jump + Down lets roundelie fall through any semisolids it interacts with
--   Falling through semisolids which roundelie is standing on requires pressing jump, like other characters
-- Snowball interactions:
--   Roundelie can dive into a snowball to bounce off of it, and the resulting bounce is higher than a bounce off of the ground
--   Roundelie can teleport into a snowball to launch it in the direction that it's facing
--   Roundelie can knock a snowball into the air with the ground-slam/shockwave attack
--   Roundelie can stop a snowball from rolling either by diving into it or by knocking it into the air with the ground-slam

--[[
TODO: ((?) => "maybe", (*) => "high priority")

(core/moveset)
    - add min delay between bjump uses
        (spamming input should still work to buffer bjumps, but it'll feel better if every bjump gains some height)
    - experiment with preventing roundelie from cancelling out of dive for first few frames
        (mainly I think this will make the dive feel a bit better and sell it more as an "action")
    - (?) experiment with teleport knockback (imo current knockback doesn't really fit with the concept of a teleport, it should be a bit more chaotic or at least have variance relative to roundelie's position?)
    - (?) let roundelie influence horizontal speed slightly (but still not dive, teleport, or bjump) during conk state
    - (?) small speed boost when starting a roll or when changing roll direction
    - (?) slight bounce off of the ground after landing a midair roll at max fall-speed
    - ...
 
(visual)
    - * rosetta skin rework
    - flip doesn't handle direction changes well
        i.e. roundelie shouldn't change rotation in midair, and flip should at most take 3 rotations
            (could add new upside-down midair poses to help mitigate this?)
            (could also experiment with speeding up the flip anim the longer it's out, to avoid excessively long flips)
    - gold skin needs SOMETHING for inflate equivalent effect
        (and probably something for transitioning <-> crouch, also?)
    - hitstun changes
        - flip is default pose; animations play out to get into flip if needed
        - orientation is based on knockback
            - e.g. knockback to the right, roundelie will be oriented to the right
            - (?) can have roundelie flip into the new direction (new animation 'flip_hitstun')
        - bouncing off of the floor or wall changes orientation and causes roundelie to flip into new orientation
        - (?) experiment with tears/sroundelie face during hitstun
    - (?) fall duration check maybe should be a distance check instead? e.g. should diving through top plat on lava fields be considered a "big" fall
    - (?) experiment with adding an anim to transition to the look up pose from different orientations
    - (?) more changes to teleport vfx
            experiment drawing sparks with energy shooting between them for on-hit effect
                + a more explicit poof of smoke for the standard/non-hit effect
            (can also experiment with drawing an after-image in the origin point smoke, again, but this time using stencil?)
    - (?) experiment with sweat drops for empty bjump (out of uses)
        (could also use the "tears" effect for this, in addition to the sweat drops)

(other)
    - * sfx pass (shockwave/ground-slam, teleport, unique sounds for roundelie in general)
    - ...
]]--

roundelie = {
    name="roundelie",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/roundelie_1"], { 29/255,  43/255,  83/255, 1}}, -- roundelie (default)
            {sprites["characters/roundelie_2"], {126/255,  37/255,  83/255, 1}}, -- delaughter (purple/red)
            {sprites["characters/roundelie_3"], {255/255,  29/255,   0/255, 1}}, -- statue (golden)
            -- TODO: rosetta skin is temporarily disabled until it's reworked
            -- {sprites["characters/roundelie_4"], {1,1,1,1}}, -- ancient monument (from rosetta)
        }
        
        this.spritesheet, this.base_color = unpack(player_skins[tonumber(skin)])
        this.skin = tonumber(skin)
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
        this.bjump = 2
        this.dash_time = 0
        
        this.p_jump = false
        this.p_dash = false
        this.is_start_of_jump = false     -- true if roundelie is starting a jump or bjump (up+x)
        this.is_first_frame_jump = false  -- true if roundelie is jumping off the ground on the first possible tick after landing
        this.was_on_ground = false
        this.was_big_conk = false
        this.was_big_fall = false
        this.should_draw_dive_vfx = false
        
        this.teleport_hb  = nil  -- hitbox created by left/right+x and neutral+x attacks
        this.teleport_info = {
            init = false,       -- true if teleport has started (=> flag used to trigger vfx)
            horizontal = false, -- true if teleport has an input direction (i.e. not a neutral input)
            on_hit = false      -- true if teleport has hit the opponent
        }
        -- hitboxes created by diving (down+x) into the ground
        this.dive_ground_slam_hb  = nil
        this.shockwave_left_hb = nil
        this.shockwave_right_hb = nil
        this.shockwave_info = {
            -- TODO: probably would be better to calculate init velocity based on the range of the ground-slam hitbox?
            --       and then have adjustable param for "how far does shockwave extend past the ground-slam", or something similar?
            vx = 0,         -- shockwave velocity (differs between big and small slam) 
            x_init = 0,     -- x pos for the initial dive impact
            y_init = 0,     -- y pos for the initial dive impact
            cx = 0,         -- offset applied to initial x pos (shockwave hitbox is created after a delay)
            left = false,   -- true if there's a shockwave moving to the left
            right = false,  -- true if there's a shockwave moving to the right
            create = false, -- true if shockwave(s) will be created when the delay timer == 0
        }
        
        this.animations = {
            idle1 =  {frames = {1}, speed = 1},  -- upright
            idle2 =  {frames = {2}, speed = 1},  -- oriented right (CW 90)
            idle3 =  {frames = {3}, speed = 1},  -- upside-down
            idle4 =  {frames = {4}, speed = 1},  -- oriented left (CCW 90)
            crouch = {frames = {5}, speed = 1},  --
            up =     {frames = {6}, speed = 1},  -- looking up
            -- sprite is rotated by frame_idx * 90 degrees, and base sprite is oriented left, so animation => oriented up -> right -> down -> left
            roll  =  {frames = {7, 7, 7, 7}, speed = 3},
            flip =   {frames = {7, 7, 7, 7}, speed = 3},  -- used to correct orientation in midair
            jump1 =  {frames = {8}, speed = 1},  -- rising
            jump2 =  {frames = {9}, speed = 1},  --
            jump3 =  {frames = {10}, speed = 1}, -- falling
            dive1 =  {frames = {11}, speed = 1}, --
            dive2 =  {frames = {12}, speed = 1}, -- "fast" dive; used when landing will cause a big ground-slam
            conk =   {frames = {13}, speed = 1}, -- disoriented; used during big bounce
            crouch_up = {frames = {14}, speed = 3, has_ending = true},  --
            squash_small_fall = {frames = {5, 14}, speed = 3, has_ending = true},  --
            squash_big_fall   = {frames = {5, 14}, speed = 4, has_ending = true},  --
            inflate_start = {frames = {8}, speed = 2, has_ending = true, next_anim = "inflate"},       --
            inflate       = {frames = {8}, speed = 7, has_ending = true, next_anim = "inflate_exit"},  --
            inflate_exit  = {frames = {9}, speed = 3, has_ending = true},                              --
            inflate_quick = {frames = {8}, speed = 1, has_ending = true, next_anim = "inflate_start"}, -- inflate for 1f and then start another inflate, to handle edge case of multiple jumps in quick succession
            teleport_start   = {frames = {8}, speed = 1},                                                 --
            teleport_inflate = {frames = {9}, speed = 6, has_ending = true, next_anim = "inflate_exit"},  --
            -- flip_start = {...}  -- TODO: implement
                -- mainly to handle edge cases, e.g. cancel out of first-frame flip jump into standard inflate jump
        }
        this.directions = { UP = 1, RIGHT = 2, DOWN = 3, LEFT = 4 }
        this.orientation = this.directions.UP
        this.idle_poses = { "idle1", "idle2", "idle3", "idle4" }
        this.current_anim = this.idle_poses[1]
        this.anim_frame = 1
        this.anim_timer = 0
        this.is_squishy = not ((this.skin == 3) or (this.skin == 4))
        
        this.respawn_timer = 0
        this.invincible_timer = 0
        this.dash_cooldown = 0
        this.bump_cooldown = 0
        this.freeze = 0
        this.conk = 0
        this.conkdir = 0
        this.dive_start = 0
        this.dive_smoketrail = 0
        this.dribble_window = 0
        this.falling_timer = 0
        this.invis_timer = 0
        this.shockwave_delay_timer = 0
        
        this.prev_x = 0
        this.prev_y = 0
        this.prev_vx = 0
        this.prev_vy = 0
        this.prev_facing = 1
        
        -- assumes args a and b are both tables with values for x, y, w, and h
        this.check_for_collision = function(a, b, x_offset, y_offset)
            return a.x < b.x + b.w + (x_offset or 0) and a.x + a.w > b.x + (x_offset or 0) and
                   a.y < b.y + b.h + (y_offset or 0) and a.y + a.h > b.y + (y_offset or 0)
        end
        
        this.check_snowballs = function(this)
            if this.hitstun > 0 then return end
            for _, o in ipairs(objects) do
                if o.type and o.type.name == "snowball" and not o.destroyed and not o.held then
                    -- check for collision with the snowball in the path of the dive to determine whether to draw the dive's smoke-trail effect
                    if (this.should_draw_dive_vfx and this.dive_start == 3 and this.dribble_window > 0) then -- TODO: "dive_start == 3" is a messy check
                        local h_input = (inputSource.getKeyDown(this.connectionID, "right") and 1 or 0) - (inputSource.getKeyDown(this.connectionID, "left") and 1 or 0)
                        local temp_x = this.x
                        local temp_y = this.y
                        -- roundelie's position is temporarily updated in order to make use of the existing `bottom`, `right`, etc. functions
                        this.x = this.x + 2 * this.vx + (3 * h_input)  -- bit hacky, but works well enough to determine whether roundelie is going to bounce on top of a snowball
                        this.y = this.y + 2 * this.vy + 8              -- ^
                        snowball_collision_check = this:bottom() <= o:top() + 4 and this:bottom() >= o:top() and this:top() <= o:bottom() and this:left() <= o:right() and this:right() >= o:left()
                        this.should_draw_dive_vfx = this.should_draw_dive_vfx and (not (snowball_collision_check))
                        -- reset position
                        this.x = temp_x
                        this.y = temp_y
                    end
                    
                    if (this.dive_ground_slam_hb and this.dive_ground_slam_hb.active and
                        this.dive_ground_slam_hb.x < o:right() and o:left() < this.dive_ground_slam_hb.x + this.dive_ground_slam_hb.w and
                        this.dive_ground_slam_hb.y < o:bottom() and o:top() < this.dive_ground_slam_hb.y + this.dive_ground_slam_hb.h) then
                        -- dive-bomb quake launches snowball
                        o.vy = this.dive_ground_slam_hb.big_dive_slam and -2.75 or -2.0
                        o.throwerID = this.connectionID
                        o.thrown_timer = 10
                        o.stop = true
                        
                    elseif o.throwerID ~= this.connectionID and this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                        local function snap()
                            this:move(0, o.y-8-this.y)
                            if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                                this:move(0, this.y+8-o.y)
                            end
                        end
                        
                        if this.dash_time > 0 then
                            -- teleport into snowball
                            o.vx = 5.15 * this.facing  -- teleport is stronger than maddy dash => should launch snowball with higher speed
                            o.vy = -1.75
                            o.stop = false
                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("zap", "static")
                            this.teleport_info.on_hit = true
                            
                        elseif ((this.down_attack and this.conk == 0) or this.vy > 0) and this:bottom() <= o:top() + 4 then
                            snap()
                            this.bjump = 2
                            
                            -- dive into snowball
                            if this.down_attack then
                                -- TODO: probably a bit messy to have code repeated here when it's basically just copy-pasted from the update function...
                                if (this.prev_vy == 4.5 and this.dive_start == 0) then
                                    -- big bounce
                                    this.vy = -3.75 - 0.75  -- snowball is bouncy => dive bounce should rebound higher than it would off the ground
                                    this.was_big_conk = true
                                    this.conk = 10
                                    o.vy = -2.25
                                    o.vx = o.vx * 0.5
                                else
                                    -- small bounce
                                    this.vy = -2.0 - 0.75
                                    this.conk = 8
                                    o.vy = -1.75
                                    o.vx = o.vx * 0.75
                                end
                                
                                this.dive_smoketrail = 0
                                this.down_attack = false
                                this.vx = 0.15 * this.conk * this.conkdir
                                love.audio.play("maddy_jump", "static")
                                
                                o.stop = true
                                o.throwerID = this.connectionID
                                o.thrown_timer = 10
                                
                            -- bounce on top of snowball
                            else
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
        end
        
        this.update_dynamic_hitboxes = function(this)
            -- update the dive ground-slam hitbox ..
            --     the dive ground-slam hitbox is active near the ground for the first 2 frames,
            --     and then chunks of the ground shoot out for the next 5 frames, while the hitbox moves with the chunks
            local hb = this.dive_ground_slam_hb
            if hb and hb.active and hb.big_dive_slam and hb.duration <= 6 then
                -- hb.duration is decremented *after* this, so e.g. tick 3 is at `hb.duration == 6` (with initial duration of 8)
                -- also hitbox is *actually* active for (duration - 1), currently (8 - 1) => 7 ticks
                if hb.duration == 6 then
                    hb.y = hb.y - 3  -- hitbox suddenly expands to the height of a full tile on the third tick
                    hb.h = hb.h + 3
                elseif hb.duration == 5 then
                    hb.y = hb.y - 3
                    hb.h = hb.h - 4
                    hb.kx = hb.kx * 0.66  -- knockback for the ground chunks is much weaker after the third tick
                    hb.ky = hb.ky * 0.66
                elseif hb.duration == 4 then
                    hb.y = hb.y - 2
                elseif hb.duration <= 3 then
                    hb.y = hb.y - 1
                end
            end
            
            -- shockwave position and velocity are updated before the hitbox is created and continue to be updated so long as a shockwave exists
            if this.shockwave_info.create or ((not this.shockwave_info.create) and (this.shockwave_info.left or this.shockwave_info.right)) then
                this.shockwave_info.cx = this.shockwave_info.cx + this.shockwave_info.vx
                this.shockwave_info.vx = util.appr(this.shockwave_info.vx, 0.5, 0.6)
            end
            
            -- shockwave hitboxes travel out from the center of the ground-slam hitbox (=> the impact of the dive)
            if (this.shockwave_left_hb and this.shockwave_left_hb.active) or (this.shockwave_right_hb and this.shockwave_right_hb.active) then
                
                if this.shockwave_info.left and (not this.shockwave_info.create) and (not (this.shockwave_left_hb and this.shockwave_left_hb.active)) then
                    -- left shockwave was created but is now no longer active
                    this.shockwave_info.left = false
                end
                if this.shockwave_info.right and (not this.shockwave_info.create) and (not (this.shockwave_right_hb and this.shockwave_right_hb.active)) then
                    -- right shockwave was created but is now no longer active
                    this.shockwave_info.right = false
                end
                
                if this.shockwave_left_hb and this.shockwave_left_hb.active then
                    -- update left shockwave
                    local hb = this.shockwave_left_hb
                    hb.x = hb.x - this.shockwave_info.vx
                    hb.y = 6 - hb.h > 1.2 and hb.y - 1.2 or hb.y - (6 - hb.h)
                    hb.h = util.appr(hb.h, 6, 1.2)
                    -- check for collision with walls
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb, p, -3, 0) then
                            hb.duration = 1
                            this.shockwave_info.left = false
                            break
                        end
                    end
                end
                if this.shockwave_right_hb and this.shockwave_right_hb.active then
                    -- update right shockwave
                    local hb = this.shockwave_right_hb
                    hb.x = hb.x + this.shockwave_info.vx
                    hb.y = 6 - hb.h > 1.2 and hb.y - 1.2 or hb.y - (6 - hb.h)
                    hb.h = util.appr(hb.h, 6, 1.2)
                    -- check for collision with walls
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb, p, 3, 0) then
                            hb.duration = 1
                            this.shockwave_info.right = false
                            break
                        end
                    end
                end
            end
            
             -- create shockwave hitboxes after an initial delay
            if this.shockwave_info.create and this.shockwave_delay_timer == 0 then
                this.shockwave_info.create = false
                
                local x_init, y_init, cx, w, h, duration = this.shockwave_info.x_init, this.shockwave_info.y_init, this.shockwave_info.cx, 3, 4, 6
                if this.shockwave_info.left then
                    local hb = {x = x_init - (w/2) - cx, y = y_init + (8 - h), w = w, h = h}
                    local is_wall = false
                    -- check for collision with walls
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb, p, -3, 0) then
                            is_wall = true
                            break
                        end
                    end
                    if (not is_wall) then
                        this.shockwave_left_hb = hitbox.create(this.connectionID, hb.x, hb.y, hb.w, hb.h, 1, -2.0, -1.75, duration)
                    end
                end
                if this.shockwave_info.right then
                    local hb = {x = x_init - (w/2) + cx, y = y_init + (8 - h), w = w, h = h}
                    local is_wall = false
                    -- check for collision with walls
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb, p, 3, 0) then
                            is_wall = true
                            break
                        end
                    end
                    if (not is_wall) then
                        this.shockwave_right_hb = hitbox.create(this.connectionID, hb.x, hb.y, hb.w, hb.h, 1, 2.0, -1.75, duration)
                    end
                end
            end
        end
        
        -- (( honestly this was a whole lot of work for a not-very-interesting effect LOL and I won't be sad if it's replaced ))
        -- TODO: experiment with a new effect using sprites for the particles (similar to how smoke is drawn)
        this.draw_teleport_vfx = function(this)
            
            local prev_x, prev_y = this.prev_x, this.prev_y
            this.teleport_info.init = false
            
            -- (1) poof out / start-point
            if this.teleport_info.horizontal then
                -- TODO: either rework the afterimage sprites to behave more like the existing smoke, OR
                --     experiment with "stencil" to have the afterimage smoke effect and existing smoke combine a bit more neatly
                game.init_smoke(prev_x, prev_y)
            end
            
            -- (2) pop in / end-point
            local cx = this.hurtbox.x + (this.hurtbox.w / 2)
            local cy = this.hurtbox.y + (this.hurtbox.h / 2) - 1
            
            local n = 3  -- split circle into `n` partitions
            local r = 2 * math.pi / n -- radians
            
            -- groups of randomly distributed "spark" particles
            for i = 1, n do
                -- each group has a base angle within equal partitions of a circle centered on the teleport hitbox
                for i = 1, 7 do
                    local angle = (i * r) + (2 * math.pi * math.random() * 0.5)  -- angle is further randomized for each particle
                    -- (( ty @meep @lazydevs on youtube for the refs, lol ))
                    table.insert(
                        particles_fg, {
                            x = this.x + cx,
                            y = this.y + cy,
                            vx = math.sin(angle),
                            vy = math.cos(angle),
                            speed = 3.5 + math.random(8,14) * 0.095,  -- magnitude for movement vector
                            drag = 0.5,  -- i.e. deceleration applied on each tick
                            
                            timer = 0,
                            duration = 7 + math.random(0, 3),
                            
                            tp_info = this.teleport_info,
                            on_hit_flag = false,
                            
                            update = function(p)
                                if p.timer > 0 and (not p.on_hit_flag) and p.tp_info.on_hit then
                                    p.on_hit_flag = true
                                    p.speed = p.speed * 1.35  --
                                    p.drag  = p.drag * 1.35   --
                                end
                                p.x = p.x + p.vx * p.speed
                                p.y = p.y + p.vy * p.speed
                                p.vx = p.vx * p.drag
                                p.vy = p.vy * p.drag
                                
                                p.timer = p.timer + 1
                                return p.timer >= p.duration
                            end,
                            
                            draw = function(p)
                                local fade = 1 - (p.timer / (p.duration + (p.duration/2)))
                                local scalar = 1.95
                                love.graphics.setColor(1, 1, 1, 1)
                                
                                if p.timer <= 2 then  -- meant to match up with initial "burst" (white circle drawn over the hitbox for 1f)
                                    love.graphics.setColor(1, 1, 1, 1)
                                else
                                    -- TODO: messy, and I don't think the "scalar" is doing what I think it's' doing...
                                    if p.on_hit_flag then
                                        love.graphics.setColor((255*fade*scalar)/255, (156*fade*scalar)/255, (39*fade*scalar)/255, 1)
                                    else
                                        love.graphics.setColor((229*fade*scalar)/255, (229*fade*scalar)/255, (229*fade*scalar)/255, fade)
                                    end
                                end
                                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                                if p.on_hit_flag then
                                    love.graphics.setColor((255*fade*scalar)/255, (116*fade*scalar)/255, (39*fade*scalar)/255, 1)
                                else
                                    love.graphics.setColor((215*fade*scalar)/255, (215*fade*scalar)/255, (215*fade*scalar)/255, fade)
                                end
                                if p.timer >= 1 and (p.x - p.vx * p.speed >= 1.5) then
                                    love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed), math.floor(p.y - p.vy * p.speed), 1, 1)
                                    if (p.x - p.vx * p.speed >= 3.5) then
                                        love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed - ((p.vx / p.drag) * p.speed)), math.floor(p.y - p.vy * p.speed - ((p.vy/p.drag) * p.speed)), 1, 1)
                                    end
                                end
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                        })
                end
            end
            
            -- smoke and initial burst frame(s)
            table.insert(
                particles_fg, {
                    x = this.x,
                    y = this.y,
                    cx = this.hurtbox.x + (this.hurtbox.w / 2),
                    cy = this.hurtbox.y + (this.hurtbox.h / 2),
                    timer = 0,
                    duration = 3,
                    draw_smoke = true,
                    
                    update = function(p)
                        p.timer = p.timer + 1
                        return p.timer >= p.duration
                    end,
                    
                    draw = function(p)
                        -- smoke
                        if p.draw_smoke and p.timer >= 2 then
                            p.draw_smoke = false
                            game.init_smoke(p.x, p.y)
                        end
                        
                        -- initial burst
                        if p.timer <= 1 then
                            love.graphics.setColor(1, 1, 1)
                            -- hitbox is size 10x10 and centered on roundelie => 12-diameter circle fits well enough
                            love.graphics.circle("fill", p.x + p.cx, p.y + p.cy, 6)
                        end
                    end
                })
        end
        
        --
        this.init_dust_cloud = function(x, y, direction)
            table.insert(particles_fg, {
                x = x,
                y = y + (direction ~= 0 and (love.math.random() * 2 - 1) or 0),
                vx = (direction ~= 0) and (0.18 * direction) or (love.math.random() * 0.3 - 0.15),
                vy = -0.1 - love.math.random() * 0.2,
                timer = 0,  -- start @ -1 => animated on 4s, start @ 0 => 1st frame of animation is only held for 3f
                duration = 12,
                flipX = (direction ~= 0) and direction or (love.math.random() > 0.5 and -1 or 1),
                update = function(p)
                    p.x = p.x + p.vx
                    p.y = p.y + p.vy
                    p.timer = p.timer + 1
                    if p.timer >= p.duration then
                        return true
                    end
                end,
                draw = function(p)
                    local frame = math.floor(p.timer / p.duration * 3) + 1
                    if frame > 3 then frame = 3 end
                    local cx = 4
                    local dx, dy = math.floor(p.x), math.floor(p.y)
                    local spr = (direction ~= 0) and sprites["characters/roundelie_dust_cloud_A"] or sprites["characters/roundelie_dust_cloud_B"]
                    sprites.draw(spr[frame], dx + cx, dy, 0, p.flipX, 1, cx, 0)
                end,
            })
        end
        
        --
        this.init_ground_chunk = function(start_x, start_y, dest_x, dest_y, color)
            table.insert(particles_fg, {
                x = start_x + love.math.random() * 2 - 1,
                y = start_y + love.math.random() * 2 - 1,
                -- initially particle vx/y was determined using start and dest(ination) xy pos but rn it's mostly magic numbers, lol
                --  .. start_x + vx + (drag * vx) = dest_x  =>  vx = (dest_x - start_x) / (1 + drag)
                vx = (dest_x - start_x),
                vy = (dest_y - start_y) * 0.35,
                drag = 0.375, -- lower to *increase*
                min_vx = 0,
                
                init_delay = 1,  -- bit of a hack, but, ehh
                timer = 0,
                duration = 16,
                
                anim_frame = math.random(3),
                flipX = love.math.random() > 0.5 and -1 or 1,
                flipY = love.math.random() > 0.5 and -1 or 1,
                color = color,

                update = function(p)
                    if (p.init_delay > 0) then
                        p.init_delay = p.init_delay - 1
                        return
                    end
                    
                    p.x = p.x + p.vx
                    p.y = p.y + p.vy
                    p.vx = util.appr(math.abs(p.vx * p.drag), p.min_vx, 0.157) * util.sign(p.vx)
                    p.vy = util.appr(p.vy, 3.0, math.abs(p.vy) > 0.2 and 0.45 or 0.30) -- meant to hang a bit at the top of the arc
                    
                    p.timer = p.timer + 1
                    return p.timer > p.duration
                end,
                
                draw = function(p)
                    if p.init_delay ~= 0 then return; end
                    
                    local fade = (p.duration - p.timer > 3) and 1.0 or (1.0 - (3 - (p.duration - p.timer)) * 0.25)
                    local tint = (p.color.r < 150 and p.color.g < 150 and p.color.b < 150) and 20 or 0
                    local sprite_ndx = p.anim_frame > 2 and 2 or p.anim_frame
                    local cx, cy = 4, 4
                    local dx, dy = math.floor(p.x) + cx, math.floor(p.y) + cy
                    
                    love.graphics.setShader(paletteSwapShader)
                    paletteSwapShader:send("color_find", {255/255, 255/255, 255/255, 1.0})
                    paletteSwapShader:send("color_replace", {(p.color.r + tint)/255, (p.color.g + tint)/255, (p.color.b + tint)/255, 1.0})
                    love.graphics.setColor(1, 1, 1, fade)
                    
                    sprites.draw(sprites["characters/roundelie_ground_chunk"][sprite_ndx], dx, dy, 0, p.flipX, p.flipY, cx, cy)
                    
                    love.graphics.setShader()
                    love.graphics.setColor(1, 1, 1)
                end,
            })
        end
        
        --
        this.init_shockwave = function(info, direction)
            table.insert(particles_fg, {
                shockwave_info = info,
                direction = direction,
                is_active = true,
                
                x = info.x_init + (direction == -1 and 3 or -2),
                y = info.y_init,
                vx = info.vx,
                prev_vx = info.vx,
                
                shockwave_delay_timer = 2,
                timer = -1,
                duration = 10, --9, --10,
                
                update = function(p)
                    if p.is_active and p.direction == -1 and p.shockwave_info.left == false then
                        p.timer = p.duration - 3
                        p.is_active = false
                    elseif p.is_active and p.direction == 1 and p.shockwave_info.right == false then
                        p.timer = p.duration - 3
                        p.is_active = false
                    else
                        p.timer = p.timer + 1
                    end
                    p.shockwave_delay_timer = p.shockwave_delay_timer - 1
                    p.vx = p.shockwave_delay_timer > 0 and p.vx or util.appr(p.vx, 0.5, 0.6)
                    
                    p.x = p.x + (p.direction * (p.is_active and p.vx or p.prev_vx))
                    p.prev_vx = p.is_active and p.vx or p.prev_vx
                    return p.timer >= p.duration
                end,
                
                draw = function(p)
                    local frame = math.floor((p.timer + 1) / p.duration * 4) + 1
                    if frame > 4 then frame = 4 end
                    local dx, dy = math.floor(p.x), math.floor(p.y)
                    sprites.draw(sprites["characters/roundelie_shockwave"][frame], dx, dy, 0, p.direction, 1, 4, 0)
                end,
            })
        end
    end,
    
    update = function(this)
        local id = this.connectionID
        
        -- # of ticks that roundelie disappears (=> sprite is not drawn) after a teleport
        if this.invis_timer > 0 then
            -- roundelie is invulnerable while invisible
            -- timer continues to decrement during freeze
            this.invis_timer = this.invis_timer - 1
        end
        
        -- initial delay before a shockwave is created
        if this.shockwave_delay_timer > 0 then
            this.shockwave_delay_timer = this.shockwave_delay_timer - 1
        end
        
        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            this:update_dynamic_hitboxes()
            if this.freeze == 0 then
                this:move(this.vx, this.vy)
                this:check_snowballs()
            end
            return
        end
        
        -- # of ticks since roundelie has started falling
        if this.falling_timer > 0 then
            this.falling_timer = this.falling_timer + 1
        end
        
        --
        if this.dribble_window > 0 then
            this.dribble_window = this.dribble_window - 1
        end
        if this.conk > 1 then this.dribble_window = 0; elseif this.conk == 1 then this.dribble_window = 8; end  -- TODO: messy
        
        -- # of ticks until roundelie is able to act after bouncing
        if this.conk > 0 then
            this.conk = this.conk - 1
        end
        
        -- # of ticks after starting a dive before roundelie is able to perform a big bounce
        if this.dive_start > 0 then
            this.dive_start = this.dive_start - 1
        end
        
        -- dive vfx
        if this.dive_smoketrail > 0 then
            this.dive_smoketrail = this.dive_smoketrail - 1
        end
        
        -- iframes
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
        end
        
        -- dash cd
        if this.dash_cooldown > 0 then
            this.dash_cooldown = this.dash_cooldown - 1
        end
        
        -- bump cd
        if this.bump_cooldown > 0 then
            this.bump_cooldown = this.bump_cooldown - 1
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
                this.bjump = 2
                this.hitstun = 0
                this.invincible_timer = 60
                this.dash_cooldown = 0
                this.bump_cooldown = 0
                -- idk how much of this is needed ...
                this.current_anim = this.idle_poses[1]
                this.orientation = this.directions.UP
                this.anim_frame = 1
                this.anim_timer = 0
                
                if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
                if this.dive_ground_slam_hb then this.dive_ground_slam_hb.active = false; this.dive_ground_slam_hb = nil end
                if this.shockwave_left_hb then this.shockwave_left_hb.active = false; this.shockwave_left_hb = nil end
                if this.shockwave_right_hb then this.shockwave_right_hb.active = false; this.shockwave_right_hb = nil end
            end
            return
        end
        
        -- update dynamic hitboxes
        this:update_dynamic_hitboxes()
        
        -- update roundelie
        this.prev_facing = this.facing
        this.is_start_of_jump = false
        this.is_first_frame_jump = false
        
        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        
        local MAX_RUN_SPEED  = 2.0  -- different from ra2, but the speed building doesn't fit well with the character and is overcomplicated
        local MAX_FALL_SPEED = 3.0
        local MAX_DIVE_SPEED = 4.5
        
        -- hitstun (set by hitbox.lua)
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, MAX_FALL_SPEED, 0.15)
            this.vx = util.appr(this.vx, 0, 0.143)
            
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            if this.dive_ground_slam_hb then this.dive_ground_slam_hb.active = false; this.dive_ground_slam_hb = nil end
            if this.shockwave_left_hb then this.shockwave_left_hb.active = false; this.shockwave_left_hb = nil end
            if this.shockwave_right_hb then this.shockwave_right_hb.active = false; this.shockwave_right_hb = nil end
        else
            
            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")
            
            local jump = jump_btn and not this.p_jump
            local dash = dash_btn and not this.p_dash and this.dash_cooldown == 0
            local bump = dash_btn and (not this.p_dash) and this.bump_cooldown == 0
            this.p_jump = jump_btn
            this.p_dash = dash_btn
            
            local ground_hit = this:is_solid(0, 1)
            local on_ground = ground_hit ~= false
            local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)
            
            -- weird semisolid fall through
            if on_semisolid and v_input == 1 and not (this.was_on_ground) and jump_btn then --very hacky fix and I don't like it but I don't want to edit the move function since it breaks interoperability (would be very easy though). Maybe better fix? Or at least a hacky fix that's identical to the ideal case
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                    this.jbuffer = 0
                    this.vy = this.prev_vy
                end
            end
            
            if on_ground and this.vy > 0 then
                this.vy = 0
                this.rem.y = 0
            end
            
            -- regular semisolid fall through
            if on_semisolid and v_input == 1 and jump then -- can definitely be combined with above part, but want to keep hacky and normal stuff separate for now
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                end
            end
            
            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end
            
            if on_ground then
                
                if this.vy < 0 then
                    this.bump_cooldown = 0;
                    love.audio.play("maddy_clip", "static")
                end
                this.grace = 6
                this.bjump = 2
                
                -- dive -> bounce off of the ground
                if this.down_attack then
                    this.dive_smoketrail = 0
                    this.down_attack = false
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    
                    -- diving into the ground also results in a "ground-slam" attack and can also result in a follow-up "shockwave" attack
                    local check_is_big_slam = this.prev_vy == MAX_DIVE_SPEED and this.dive_start == 0
                    local cx = this.hurtbox.x + (this.hurtbox.w / 2)
                    local hb_x, hb_w, hb_offset
                    if check_is_big_slam then
                        hb_offset = (-1.0 * this.conkdir) + (3.0 * h_input)
                        hb_x, hb_w = (this.x + cx - 14) + hb_offset, 28  -- 3.5 tiles
                        this.conk = 10
                        this.was_big_conk = true
                        this.vy = -3.75
                        camera.shake(2, 2, 4)
                    else
                        hb_offset = (-0.75 * this.conkdir) + (1.75 * h_input)
                        hb_x, hb_w = (this.x  + cx - 10) + hb_offset, 20  -- 2.5 tiles
                        this.conk = 9
                        this.vy = -2.0
                    end
                    
                    local impact_x, impact_y = (this.x + cx) + hb_offset, this.y
                    
                    -- ground can be composed of multiple platforms
                    --   => we need to find the left-most and right-most platforms within the attack range
                    local platform_left, platform_right = ground_hit, ground_hit
                    
                    -- find the left-most platform
                    while hb_x < platform_left.x do
                        local new_platform = this:is_solid((platform_left.x - this.x - this.hurtbox.w - this.hurtbox.x), 1)
                        if new_platform and new_platform.y == platform_left.y then platform_left = new_platform; else break; end
                    end
                    -- find the right-most platform
                    while (hb_x + hb_w) > (platform_right.x + platform_right.w) do
                        local new_platform = this:is_solid((platform_right.x + platform_right.w - this.x - this.hurtbox.x), 1)
                        if new_platform and new_platform.y == platform_right.y then platform_right = new_platform; else break; end
                    end
                    
                    -- the ground-slam hitbox is constrained to the size of the ground roundelie is diving into, + 1/2 the width of a tile
                    local prev_hb_x = hb_x
                    hb_x = math.max(hb_x, platform_left.x - 4)
                    hb_w = math.min((prev_hb_x + hb_w - hb_x), (platform_right.x + platform_right.w + 4) - hb_x)
                    
                    -- the hitbox is further constrained by walls
                    local hb_right = { x = impact_x, y = this.y + 4, w = (hb_x + hb_w) - impact_x, h = 4 }
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb_right, p, 0, 0) then
                            hb_w = p.x - hb_x + 4
                            break
                        end
                    end
                    local hb_left =  { x = hb_x, y = this.y + 4, w = impact_x - hb_x, h = 4 }
                    for _, p in ipairs(stage.platforms) do
                        if p.type == "solid" and this.check_for_collision(hb_left, p, 0, 0) then
                            hb_x = p.x + p.w - 4
                            break
                        end
                    end
                    
                    -- create follow-up shockwave(s) if conditions are met
                    if check_is_big_slam then
                        this.dive_ground_slam_hb = hitbox.create(this.connectionID, hb_x, this.y + 4, hb_w, 4, 3, -2 * this.conkdir, -4, 8)
                        this.dive_ground_slam_hb.big_dive_slam = true
                        --
                        this.shockwave_info.vx = 4.75
                        this.shockwave_info.left = true
                        this.shockwave_info.right = true
                    else
                        this.dive_ground_slam_hb = hitbox.create(this.connectionID, hb_x, this.y + 4, hb_w, 4, 2, -2 * this.conkdir, -3, 3)
                        this.dive_ground_slam_hb.small_dive_slam = true
                        --
                        this.shockwave_info.vx = 4.0 --3.75
                        this.shockwave_info.left = (h_input == -1)
                        this.shockwave_info.right = (h_input == 1)
                    end
                    
                    if (this.shockwave_info.left or this.shockwave_info.right) and (not this.shockwave_info.create) then
                        this.shockwave_info.x_init = impact_x
                        this.shockwave_info.y_init = impact_y
                        this.shockwave_info.cx = 0
                        this.shockwave_info.create = this.shockwave_info.left or this.shockwave_info.right
                        this.shockwave_delay_timer = 2
                        
                        -- draw visual effects for the shockwave(s)
                        if this.shockwave_info.create then
                            if this.shockwave_info.left  then this.init_shockwave(this.shockwave_info, -1); end
                            if this.shockwave_info.right then this.init_shockwave(this.shockwave_info,  1); end
                        end
                    end
                    
                    -- draw visual effects for the ground-slam (dust clouds & ground chunks)
                    
                    -- (1) draw chunks of the ground that fly out on impact
                    if check_is_big_slam then
                        
                        -- find the most common color in a selection of pixels near the impact position
                        local temp_canvas, img_data, img_x_a, img_x_b, img_y, img_w, img_h
                        
                        love.graphics.push("all")  -- store coord system to preserve any transforms applied to main canvas, e.g. if window was resized
                        love.graphics.origin()     -- reset coord system to default state
                        
                        if ground_hit.type == "solid" or ground_hit.type == "semisolid" then
                            -- "ground" is a platform
                            img_w, img_h = stage.fgImage:getPixelDimensions()
                            temp_canvas = love.graphics.newCanvas(img_w, img_h)
                            
                            -- TODO: imageData should be created once and then referenced, since repeated calls to create imageData from a canvas can be slow
                            --  (see warning here: https://love2d.org/wiki/Canvas:newImageData)
                            love.graphics.setCanvas(temp_canvas)
                            love.graphics.clear()

                            love.graphics.draw(stage.fgImage, 0, 0)
                            love.graphics.setCanvas()  -- reset
                            img_data = temp_canvas:newImageData()
                            
                            img_x_a = math.max( 0, math.min(this.dive_ground_slam_hb.x + 4, impact_x - 5) )
                            img_x_b = math.min( img_w, math.max(this.dive_ground_slam_hb.x + this.dive_ground_slam_hb.w - 4, impact_x + 5) )
                            img_y = impact_y + 9  -- => second row of pixels from the top
                        else
                            -- "ground" is an object
                            local temp_sprite = nil
                            if ground_hit.type.name == "moving_platform" then
                                temp_sprite = ground_hit.sprite
                            else
                                temp_sprite = sprites["objects/" .. ground_hit.type.name]
                            end
                            img_w, img_h = temp_sprite:getPixelDimensions()
                            temp_canvas = love.graphics.newCanvas(img_w, img_h)
                            
                            love.graphics.setCanvas(temp_canvas)
                            love.graphics.clear()
                            love.graphics.draw(temp_sprite, 0, 0)
                            love.graphics.setCanvas()  -- reset
                            img_data = temp_canvas:newImageData()

                            img_x_a = 0
                            img_x_b = img_w - 1
                            img_y = (img_h / 2) - 1
                        end
                        
                        love.graphics.pop()  -- reapply stored coord system transforms
                        
                        local counts = {}
                        local most_common_color = {r = 1, g = 0, b = 1, a = 1}
                        local max_count = 0
                        
                        for i = 1, (img_x_b - img_x_a) do
                            local r, g, b, a = img_data:getPixel(img_x_a + i, img_y)
                            if (a ~= 0 and r ~= nil and g ~= nil and b ~= nil and a ~= nil) then
                                local color = {r = (r*255), g = (g*255), b = (b*255), a = a}
                                local color_key = color.r .. "_" .. color.g .. "_" .. color.b .. "_" .. color.a
                                counts[color_key] = (counts[color_key] or 0) + 1
                                if counts[color_key] > max_count then
                                    max_count = counts[color_key]
                                    most_common_color = color
                                end
                            end
                        end
                        
                        -- distribute ground chunks within the area of the hitbox
                        local init_x, a_x, b_x, temp = impact_x - 4, nil, nil, nil  -- ground chunks travel from pt a -> b
                        
                        this.init_ground_chunk(init_x, impact_y + 4, init_x, impact_y - 5, most_common_color)
                        b_x = hb_x - 0
                        a_x = init_x - ((init_x - b_x) / 2)
                        this.init_ground_chunk(a_x, impact_y + 4, b_x, impact_y - 5, most_common_color)  -- marks left edge of the hitbox
                        b_x = hb_x + hb_w - 8
                        a_x = init_x + ((b_x - init_x) / 2)
                        this.init_ground_chunk(a_x, impact_y + 4, b_x, impact_y - 5, most_common_color)  -- marks right edge of the hitbox
                        
                        local rem_hb_width = (hb_x + hb_w - 6) - (hb_x + 6)
                        local slot_count = math.floor(rem_hb_width / 6)           -- # of "slots" where a ground chunk can be placed
                        local base_width = math.floor(rem_hb_width / slot_count)  -- portion of the total width allocated for each slot
                        local extra_width = rem_hb_width % slot_count             -- leftover space is evenly distributed between the slots
                        
                        b_x = hb_x - 2
                        for i = 1, slot_count do
                            b_x = b_x + base_width + (i <= extra_width and 1 or 0)
                            a_x = init_x + ((b_x - init_x) / 2)
                            this.init_ground_chunk(a_x, impact_y + 4, b_x, impact_y - 6, most_common_color)
                        end
                    end
                
                    -- (2) draw dust clouds over the ground-slam hitbox
                    this.init_dust_cloud(hb_x + 1, this.dive_ground_slam_hb.y - 1, -1)
                    this.init_dust_cloud(hb_x + hb_w - 8, this.dive_ground_slam_hb.y - 1, 1)
                    
                    local slot_count = math.floor(hb_w / 8)  -- the dust cloud sprite is ~6px wide, +2px for padding
                    local base_width = math.floor(hb_w / slot_count)
                    local extra_width  = hb_w % slot_count
                    
                    local curr_x = hb_x - 4 + 1
                    for i = 1, slot_count - 1 do
                        curr_x = curr_x + base_width + (i <= extra_width and 1 or 0)
                        this.init_dust_cloud(curr_x, this.dive_ground_slam_hb.y - 2, 0)
                    end
                end
                
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end
            
            if this.dash_time > 0 then
                if this.dash_time == 2 then  -- TODO: messy
                    this.freeze = 3  -- half of the value applied on-hit
                    this.teleport_hb = hitbox.create(this.connectionID, (this.x  - 1), (this.y  - 1), 10, 10, 3, 5 * this.facing, 0, 2)
                    this.teleport_hb.telefrag = true
                    this.teleport_hb.hit_sfx = "zap"  -- generic "crit" sfx used for big hits, e.g. Lani's tipper and body slam
                    this.vx = 0
                end
                this.dash_time = this.dash_time - 1
                this.vx = 0
            else
                if this.teleport_hb then
                    this.teleport_hb.active = false
                    this.teleport_hb = nil
                end
            end
            local accel = on_ground and 0.93 or 0.80
            local deccel = 0.16
            
            this.vx = math.abs(this.vx) <= MAX_RUN_SPEED and util.appr(this.vx, h_input * MAX_RUN_SPEED, accel) or util.appr(this.vx, util.sign(this.vx) * MAX_RUN_SPEED, deccel)
            if this.vx ~= 0 then this.facing = util.sign(this.vx) end
            
            if not on_ground then
                this.vy = util.appr(this.vy, MAX_FALL_SPEED, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
            end
            
            if this.jbuffer > 0 then
                if this.grace > 0 then
                    this.is_start_of_jump = true
                    
                    if (not this.was_on_ground) and this:is_solid(0, 1) then this.is_first_frame_jump = true; end
                    
                    this.jbuffer = 0
                    -- this.grace = 0
                    this.vy = -3.36
                    
                    love.audio.play("maddy_jump", "static")
                    game.init_smoke(this.x, this.y + 4)
                end
            end
            
            -- might be overcomplicated; left over from maddy code
            local hb_w, hb_h = 10, 10
            local targetX = this.x + this.vx
            local targetY = this.y + this.vy
            local cx = targetX + this.hurtbox.x + (this.hurtbox.w / 2)
            local cy = targetY + this.hurtbox.y + (this.hurtbox.h / 2)
            local hb_x = cx - (hb_w / 2)
            local hb_y = cy - (hb_h / 2)
            
            local is_wall_bounce = false
            
            if v_input == 1 and dash_btn and not on_ground and this.conk < 1 then
                if not this.down_attack then 
                    -- dive has a 1f delay before the hitbox comes out and an initial burst of speed after the delay
                    this.freeze = 1
                    this.vy = util.appr(this.vy, MAX_DIVE_SPEED, 1.95)
                    
                    -- a bit hacky, but this helps prevent the smoke-trail effect from being drawn when roundelie starts diving right before bouncing (e.g., while dribbling or wall-climbing)
                    this.should_draw_dive_vfx = this.dribble_window == 0 or
                                                (not ((this:is_solid(this.vx + (h_input * 3), this.vy)) or
                                                      (this.p_jump and (not this:is_solid(this.vx, this.vy + 4, true))) or
                                                      (this:is_solid(this.vx, this.vy + 4))))
                    this.dive_start = 3  -- currently set to line up with the dive smoke-trail effect
                else
                    -- the dive hitbox remains active as long as the input (down+x) is held
                    hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 1, util.sign(this.vx), 4.5, 2)
                    this.vy = util.appr(this.vy, MAX_DIVE_SPEED, 0.60)
                    if this.dive_smoketrail > 0 then game.init_smoke(this.x, this.y) end
                end

                this.down_attack = true
                this.was_big_conk = false
                this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1  -- needs to be kept updated for snowball logic
                
                -- dive -> bounce off of a wall
                local wall_dir = this:is_solid(-3, 0) and 1 or (this:is_solid(3, 0) and -1 or 0)
                if wall_dir ~= 0 then
                    is_wall_bounce = true
                    this.conk = 8
                    this.dive_smoketrail = 0
                    this.vy = -2.7
                    game.init_smoke(this.x - wall_dir * 6, this.y)  -- same as maddy wall-jump
                end
            else
                this.down_attack = false
            end
            if this.conk > 0 then
                this.vx = 0.15 * this.conk * this.conkdir * (is_wall_bounce and 2 or 1)
            elseif v_input == -1 and bump and this.bjump > 0 then
                this.is_start_of_jump = true
                this.bump_cooldown = 0  --TODO: different from main branch, update documentation and code neatness if you want to keep
                this.vy = -3.0
                love.audio.play("maddy_nodash", "static")
                if this.bjump >= 1 then
                    game.init_smoke(this.x, this.y)
                    this.bjump = this.bjump - 1
                end
            elseif dash then
                if v_input == 0 then
                    this.dash_time = 2
                    this.dash_cooldown = 31
                    this.invincible_timer = 2
                    this.vx = 32 * h_input
                    this.teleport_info.init = true
                    this.teleport_info.horizontal = h_input ~= 0
                    this.teleport_info.on_hit = false
                    love.audio.play("maddy_dash", "static")  -- TODO: placeholder
                end
            end
            this.was_on_ground = on_ground
            this.prev_x = this.x  -- need to keep track of original position for some visual effects drawn after movement/collision is calculated
            this.prev_y = this.y  --
            this.prev_vx = this.vx
            this.prev_vy = this.vy -- part of the hacky semisolid fix
        end
        
        
        -- apply updates
        this:move(this.vx, this.vy)
        this:check_snowballs()
        
        
        -- check if roundelie has landed on a platform
        -- (this is done after movement is calculated so that animations are more accurate)
        local anim_on_ground, anim_is_landing = false, false
        if this.hitstun == 0 and this.vy >= 0 and this:is_solid(0, 1) then
            anim_on_ground = true
            if (not this.was_on_ground) and (not this.down_attack) then
                game.init_smoke(this.x, this.y + 4)
                anim_is_landing = true
                
                if this.prev_vy > 3 or (this.prev_vy == 3 and this.falling_timer >= 15) then
                    this.was_big_fall = true
                else
                    this.was_big_fall = false
                end
                this.falling_timer = 0
            end
        else
            if this.vy < 0 and this.falling_timer > 0 then
                this.falling_timer = 0
            elseif this.falling_timer == 0 then
                this.falling_timer = 1
            end
        end
        
        -- teleport vfx
        if this.teleport_info.init then
            this:draw_teleport_vfx()
            this.current_anim = "teleport_start"  -- bit hacky
            this.invis_timer = 3
        end
        
        -- dive vfx
        if this.should_draw_dive_vfx then
            this.dive_smoketrail = 2
            game.init_smoke(this.prev_x, this.prev_y - 4)
            love.audio.play("maddy_downdash", "static")  -- TODO: placeholder
            this.should_draw_dive_vfx = false
        end
        
        -- update sprite / animation orientation
        if this.current_anim == "roll" or this.current_anim == "flip" then
            this.orientation = this.anim_frame
        end
        
        if this.prev_facing ~= this.facing then
            if this.current_anim == "roll" and anim_on_ground and math.abs(this.vx) > 0 and math.abs(this.prev_vx) > 0 and v_input ~= 1 then
                -- draw dust cloud after changing direction mid-roll
                this.init_dust_cloud(this.x + (this.facing == 1 and 1 or 0), this.y + 2, -1 * this.facing)
            end
            
            if this.orientation == this.directions.RIGHT then
                this.orientation = this.directions.LEFT
                this.anim_frame = this.anim_frame + 2
            elseif this.orientation == this.directions.LEFT then
                this.orientation = this.directions.RIGHT
                this.anim_frame = this.anim_frame - 2
            end
        end
        
        -- update roll speed
        local prev_anim_speed, new_anim_speed = this.animations.roll.speed, 4
        if ((math.abs(this.vx) + math.abs(this.vy)) / 2) >= ((MAX_RUN_SPEED + MAX_FALL_SPEED) / 2) then
            new_anim_speed = 2
        elseif (math.abs(this.vx) >= MAX_RUN_SPEED) or (this.vy <= -1.0) then
            new_anim_speed = 3
        end
        this.animations.roll.speed = new_anim_speed
        
        -- determine next sprite / animation
        local anim = this.animations[this.current_anim]
        local anim_is_finished = anim.has_ending and ((anim.speed * #anim.frames) <= (this.anim_timer + 1))
        local anim_is_loop = (not anim.has_ending)
        local next_anim
        
        if this.hitstun > 0 then
            this.animations.flip.speed = math.min(this.animations.roll.speed, 3)
            if (not anim_on_ground) then
                next_anim = "flip"
            else
                -- animations are paused during hitstun
                next_anim = this.current_anim
            end
        elseif this.current_anim == "teleport_start" then
            -- roundelie is inflated when reappearing after a teleport
            this.orientation = this.directions.UP
            next_anim = "teleport_inflate"
        elseif not anim_on_ground then
            if this.is_start_of_jump then
                --
                this.orientation = this.directions.UP
                if (not (this.current_anim == "inflate_start" or this.current_anim == "inflate")) and this.is_first_frame_jump and math.abs(this.vx) >= 1.5 then
                    next_anim = "roll"
                elseif this.current_anim == "inflate_start" and anim_is_finished then
                    next_anim = "inflate_quick"
                else
                    next_anim = "inflate_start"
                end
            elseif (not (this.current_anim == "inflate_start" or this.current_anim == "inflate")) and this.conk > 0 and this.was_big_conk then
                -- during big bounce
                next_anim = "conk"
            elseif this.down_attack and this.dribble_window == 0 then
                -- dive / down attack
                this.orientation = this.directions.UP
                next_anim = (this.vy == MAX_DIVE_SPEED) and "dive2" or "dive1"
            -- handle sequences of animations
            elseif (not anim_is_loop) and (not anim_is_finished) then
                --
                next_anim = this.current_anim
            elseif (not anim_is_loop) and anim_is_finished and anim.next_anim then
                --
                next_anim = anim.next_anim
            elseif this.current_anim == "roll" then
                -- roll (midair)
                if math.abs(this.vx) < MAX_RUN_SPEED then  -- more strict than the check for the grounded roll
                    this.animations.flip.speed = math.min(this.animations.roll.speed, 3)
                    next_anim = (this.orientation == this.directions.UP) and "jump2" or "flip"
                else
                    next_anim = "roll"
                end
            elseif this.current_anim == "flip" then
                -- roundelie continues rotating until it's upright
                -- TODO: flip rotation shouldn't change if roundelie changes the direction its facing
                --      i.e. if the flip rotation is CW, rotation after turning around should still be CW
                --      (maybe also experiment with speeding up anim if facing direction changes?)
                next_anim = (this.orientation == this.directions.UP) and "jump2" or "flip"
            else
                if this.orientation ~= this.directions.UP then
                    this.animations.flip.speed = math.min(this.animations.roll.speed, 3)
                    next_anim = "flip"
                else
                    -- default midair pose (jump/fall)
                    next_anim = this.vy < 0.3 and "jump2" or "jump3"
                end
            end
        --
        else
            -- handle crouch animations
            if this.is_squishy and this.current_anim == "crouch" and v_input ~= 1 then
                next_anim = "crouch_up"
            elseif v_input == 1 then
                this.orientation = this.directions.UP
                next_anim = "crouch"
            -- handle sequences of animations
            elseif (not anim_is_loop) and (not anim_is_finished) then
                --
                next_anim = this.current_anim
            elseif (not anim_is_loop) and anim_is_finished and anim.next_anim then
                next_anim = anim.next_anim
            elseif this.is_squishy and this.current_anim == "inflate_exit" then
                -- handle inflate animation ending when on the ground, e.g. after teleport
                next_anim = "crouch_up"
            elseif anim_is_landing and this.is_squishy and this.current_anim ~= "roll" and (not (math.abs(this.vx) >= 1.0 and this.current_anim == "flip")) then
                -- roundelie squashes from the impact of landing
                this.orientation = this.directions.UP
                next_anim = (this.was_big_fall or this.current_anim == "squash_big_fall") and "squash_big_fall" or "squash_small_fall"
            elseif (this.current_anim == "roll" and (math.abs(this.vx) >= 1.0 or (h_input ~= 0 and math.abs(this.vx) > 0))) or (this.current_anim ~= "roll" and math.abs(this.vx) > 0.5) then
                --
                next_anim = "roll"
            elseif v_input == -1 and this.orientation == this.directions.UP then
                --
                next_anim = "up"
            else
                next_anim = this.idle_poses[this.orientation]
            end
        end
        
        -- update current animation
        if next_anim ~= this.current_anim then
            if (next_anim == "roll" or next_anim == "flip") then
                this.anim_frame = this.orientation
                if this.current_anim == "roll" or this.current_anim == "flip" then
                    this.anim_timer = this.anim_timer % anim.speed
                else
                    -- roll/flip animation is sped up at the start to appear more natural
                    this.anim_timer = 0
                end
            else
                this.anim_frame = 1
                -- e.g. if anim.speed is 3, then anim_frame will increment when anim_timer == 3
                --   => if anim_timer is initialized to 0, the first frame of the animation will only be drawn for 2 frames
                this.anim_timer = -1
            end
            this.current_anim = next_anim
        end
        
        if this.hitstun == 0 then this.anim_timer = this.anim_timer + 1; end  -- animations are paused during hitstun
        
        local anim = this.animations[this.current_anim]
        if (not anim_is_loop) and (this.anim_timer > 0) and (this.anim_timer % anim.speed == 0) then
            this.anim_frame = this.anim_frame + 1
        elseif anim_is_loop and this.anim_timer >= anim.speed then
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
            
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            if this.dive_ground_slam_hb then this.dive_ground_slam_hb.active = false; this.dive_ground_slam_hb = nil end
            if this.shockwave_left_hb then this.shockwave_left_hb.active = false; this.shockwave_left_hb = nil end
            if this.shockwave_right_hb then this.shockwave_right_hb.active = false; this.shockwave_right_hb = nil end
            
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
        -- the large shockwave already applies camera shake
        if (not hb.big_dive_slam) then camera.shake(1.5, 1.5, 2) end
        
        if hb.big_dive_slam then
            --target.freeze = 2
        elseif hb.small_dive_slam then
            --target.freeze = 1
        elseif hb.telefrag then
            this.teleport_info.on_hit = true
            
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
            
            this.freeze = 6
            target.freeze = 6
            
            if this.invis_timer > 0 then this.invis_timer = this.invis_timer + 2; end
            
            camera.shake(3, 3, 5)
        end
    end,
    
    draw = function(this)
        if not this.active and this.stocks <= 0 then return; end
        if this.respawn_timer > 0 or this.invis_timer > 0 then return; end
        
        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)
        local isInflate  = this.current_anim == "inflate" or this.current_anim == "teleport_inflate" or this.current_anim == "inflate_quick"
        local isRotating = this.current_anim == "roll" or this.current_anim == "flip"
        
        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        local rotation = isRotating and math.rad(this.facing * this.anim_frame * 90) or 0
        local cx, cy = this.hurtbox.x + (this.hurtbox.w / 2), 4
        
        this.spr = this.spritesheet[frame_idx]
        
        -- apply tints and shaders
        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end
        
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        elseif this.dash_cooldown > 0 then
            love.graphics.setShader(paletteSwapShader)
            if this.skin == 3 then
                -- eyes swap from default (gold) -> "activated" (white)
                paletteSwapShader:send("color_find",    {203/255, 136/255,   4/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 255/255, 255/255, 1.0})
            elseif this.skin == 4 then
                -- TODO: replace placeholder effect
                paletteSwapShader:send("color_find",    {171/255,  82/255,  54/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 119/255, 168/255, 1.0})
            else
                local r, g, b = unpack(this.base_color)
                local tint = this.skin == 1 and 1.25 or 0.95
                r, g, b = r * tint, g * tint, b * tint
                -- ref: https://stackoverflow.com/questions/13328029/how-to-desaturate-a-color
                --      https://en.wikipedia.org/wiki/Grayscale#Luma_coding_in_video_systems
                local L = 0.299 * r + 0.587 * g + 0.114 * b  -- calculate luma using standard human-eye luminance weights (BT.601)
                local f = 0.20  -- => 20% desaturation
                paletteSwapShader:send("color_find", this.base_color)
                paletteSwapShader:send("color_replace", {(r + f * (L - r)), (g + f * (L - g)), (b + f * (L - b)), 1.0})
            end
        end
        
        -- draw sprite(s)
        if this.skin == 3 then
            -- roundelie's face and belly for the statue/gold skin are drawn on top of "base" sprites that aren't flipped
            local base_spr = sprites[ this.current_anim == "crouch" and "characters/roundelie_3_base_crouch" or "characters/roundelie_3_base_default" ]
            sprites.draw(base_spr, this.x + cx, this.y, 0, 1, 1, cx, 0)
        end
        
        if this.is_squishy and isInflate then
            -- the inflate pose uses a larger sprite that's separate from the rest of the spritesheet
            local spr_inflate = (this.skin == 1 and "characters/roundelie_1_inflate" or "characters/roundelie_2_inflate")
            sprites.draw(sprites[spr_inflate], this.x + cx, this.y + cy, rotation, this.facing, 1, cx + 1, cy + 1)
        else
            sprites.draw(this.spr, this.x + cx, this.y + cy, rotation, this.facing, 1, cx, cy)
        end
        
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
