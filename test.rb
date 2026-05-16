#!/bin/ruby

require 'gosu'

$Width, $Height = 960, 720
$delta = 0.017
$freeze_frames = 0
$time = 0
$playeronewins = 0
$playertwowins = 0

class Input
    attr_accessor :x
    attr_accessor :y
    def initialize(n:, e:, s:, w:, light:, heavy:)
        @x = 0
        @y = 0
        @attack_buttons = [light, heavy]
        @movement_buttons = [n, e, s, w]
        @directions = [[[0, 0], 0]]
    end
    def update()
        @x = @y = 0
        @x += 1 if Gosu.button_down? @movement_buttons[1]
        @x -= 1 if Gosu.button_down? @movement_buttons[3]
        @y += 1 if Gosu.button_down? @movement_buttons[2]
        @y -= 1 if Gosu.button_down? @movement_buttons[0]
        @directions.prepend([[@x, @y], $time]) if [@x, @y] != @directions[0][0]
        @directions = @directions.delete_if {|direction_time| $time - direction_time[1] > 1000 and direction_time != @directions[0]}
    end
    def direction_history(facing_right = true)
        directions_times = @directions
        if not facing_right
            directions_times.each do |direction_time|
                direction_time[0][0] *= -1
            end
        end
        directions = []
        directions_times.each do |direction_time|
            directions.append(direction_time[0])
        end
        return directions
    end
    def get_button_action(button)
        case button
        when @attack_buttons[0]
            return "light"
        when @attack_buttons[1]
            return "heavy"
        else
            return nil
        end
    end
end

class GameObject
    @@ids = []
    @@objects = []
    attr_accessor :ids
    attr_accessor :name
    attr_accessor :Id
    attr_accessor :children
    attr_accessor :parent
    attr_accessor :groups
    def self.get_objects
        return @@objects
    end
    def initialize(**keywords)
        @@objects.append(self)
        @Id = @@ids.length
        @@ids.append(@Id)
        @children = []
        @parent = nil
        @name = @Id.to_s
        @goups = []
        keywords.each() do |key|
            case key[0]
            when :name
                @name = key[1]
            when :parent
                @parent = key[1]
                @@objects.each() do |object|
                    object.children.append(self) if object == key[1]
                end
            when :groups
                key[1].each() do |group|
                    @groups.append(group)
                end
            end
        end
    end
    def self.kill_all
        @@ids = [0..2]
        @@objects = []
        @@objects.append $PlayerOneImage
        @@objects.append $PlayerTwoImage
    end
end

class Spacial_Object < GameObject
    attr_accessor :pos_x
    attr_accessor :pos_y
    attr_accessor :relative_pos_x
    attr_accessor :relative_pos_y
    def initialize(x, y, **)
        super(**)
        @pos_x = 0
        @pos_y = 0
        @relative_pos_x = x
        @relative_pos_y = y
        if not (@parent.respond_to?("pos_x") and @parent.respond_to?("pos_y"))
            @pos_x = @relative_pos_x
            @pos_y = @relative_pos_y
        else
            @pos_x = @relative_pos_x
            @pos_x = @relative_pos_y
        end
    end
end

class Image < Spacial_Object
    def initialize(x, y, z, *, tileable: false, **)
        super(x, y, **)
        @z_index = z
        @image = Gosu::Image.new(*, :tileable => tileable)
    end
    def draw
        @image.draw(@pos_x, @pos_y, @z_index)

    end
end

class ImageSet < Spacial_Object
    attr_accessor :flipped
    attr_accessor :animation_start
    def initialize(x, y, width, height, z, *, tileable: false, **)
        super(x, y, **)
        @z_index = z
        @animation_start = $time
        @flipped = false
        @frame = 0
        @width = width
        @height = height
        @images = Gosu::Image.load_tiles(*, width, height, :tileable => tileable)
        @empty_frames = []
        @images.each_with_index() do |image, i|
            @empty_frames.append(i) if self.check_empty_init(i)
        end
        @horizontal_count = (Gosu::Image.new(*).width / width).floor
        @frame_coordinate = [0, 0]
    end
    def check_empty_init(frame)
        @images[frame].to_blob.each_byte do |byte|
            return false if byte > 0
        end
        return true
    end
    def check_empty
        return @empty_frames.include? @frame
    end
    def update_frame
        @frame = @frame_coordinate[0] + @frame_coordinate[1] * @horizontal_count
    end
    def update_frame_coordinate
        @frame_coordinate[1] = (@frame / @horizontal_count).floor
        @frame_coordinate[0] = @frame % @horizontal_count
    end
    def frame
        return @frame
    end
    def frame=(value)
        @frame = value
        self.update_frame_coordinate
    end
    def frame_coordinate
        return @frame_coordinate
    end
    def frame_coordinate=((x, y))
        @frame_coordinate[0] = x
        @frame_coordinate[1] = y
        self.update_frame
    end
    def next_frame
        @frame += 1
        if @frame < self.length
            self.update_frame_coordinate
            return false
        end
        @frame -= self.length
        self.update_frame_coordinate
        return true
    end
    def previous_frame
        @frame -= 1
        if @frame >= 0
            self.update_frame_coordinate
            return false
        end
        @frame += self.length
        self.update_frame_coordinate
        return true
    end
    def animation
        return @frame_coordinate[1]
    end
    def animation=(value)
        @frame_coordinate[1] = value
        self.update_frame
    end
    def animation_frame
        return @frame_coordinate[0]
    end
    def animation_frame=(value)
        @frame_coordinate[0] = value
        self.update_frame
    end
    def cycle_animation
        @frame_coordinate[0] += 1
        if @frame_coordinate[0] < @horizontal_count
            self.update_frame
            return self.cycle_animation if check_empty
            return false
        end
        @frame_coordinate[0] -= @horizontal_count
        self.update_frame
        return self.cycle_animation if check_empty
        return true
    end
    def uncycle_animation
        @frame_coordinate[0] -= 1
        if @frame_coordinate[0] >= 0
            self.update_frame
            return false
        end
        @frame_coordinate += @horizontal_count
        self.update_frame
        return true
    end

    def length
        return @images.length
    end
    def draw()
        if @flipped
            @images[@frame].draw(@pos_x + @width * 0.5, @pos_y, @z_index, -1)
        else
            @images[@frame].draw(@pos_x - @width * 0.5, @pos_y, @z_index,)
        end
    end
end

class Box < Spacial_Object
    attr_accessor :width
    attr_accessor :height
    def initialize(x, y, width, height, **)
        super(x, y, **)
        @width = width
        @height = height
    end
end

class HurtBox < Box
    def initialize(x, y, width, height, **)
        super(x, y, width, height, :name => "hurtbox", **)
    end
    def draw_debug
        Gosu.draw_rect(@pos_x - @width * 0.5, @pos_y - @height * 0.5, @width, @height, Gosu::Color.argb(0xa0_2580ff), 2)
    end
end

class HitBox < Box
    attr_accessor :damage
    attr_accessor :knockback
    attr_accessor :recoil
    attr_accessor :stun
    attr_accessor :blockstun
    attr_accessor :attack_height
    attr_accessor :freeze_frames
    def initialize(x, y, width, height, **)
        super(x, y, width, height, :name => "hitbox", **)
        @damage = 0
        @knockback = 0
        @recoil = 0
        @stun = 0
        @blockstun = 0
        @attack_height = 0
        @freeze_frames = 0
    end
    def check_for_hit()
        return false if @width == 0 or @height == 0
        GameObject.get_objects.each() do |object|
            next if object.name != "hurtbox"
            next if object.parent == @parent
            next if (@pos_x - object.pos_x).abs > @width * 0.5 + object.width * 0.5
            next if (@pos_y - object.pos_y).abs > @height  * 0.5+ object.height * 0.5
            return object
        end
        return false
    end
    def reset
        @width = @height = @damage = @knockback = @recoil = @stun = @blockstun = @freeze_frames = 0
        @attack_height = "mid"
    end
    def draw_debug
        Gosu.draw_rect(@pos_x - @width * 0.5, @pos_y - @height * 0.5, @width, @height, Gosu::Color.argb(0xa0_ff253a), 2)
    end
end

class Player < GameObject
    attr_accessor :pos_x
    attr_accessor :pos_y
    attr_accessor :width
    attr_accessor :height
    attr_accessor :state
    attr_accessor :opponent
    attr_accessor :health
    attr_accessor :max_health
    attr_accessor :input
    attr_accessor :image
    def initialize(**)
        super(**)
        @width = 32.0
        @height = 192.0
        @WalkSpeed = 180
        @ForwardWalkFactor = 1.6
        @JumpForce = -1000
        @JumpDistance = 250
        @Gravity = 2800
        @FloorHeight = $Height - @height - 128
        @opponent

        @pos_x = 0
        @pos_y = @FloorHeight
        @vel_x = @vel_y = 0.0
        @state = "walking"
        @attack = ""
        @frame_count = 0
        @facing_right = true
        @health = @max_health = 200.0

        @input = nil
        @image = nil
        @hurtbox = HurtBox.new(@width * 0.5, @height * 0.5 + 8, 48, 176, :parent => self)
        @hitbox = HitBox.new(@width + 48, @height * 0.25, 96, 48, :parent => self)
    end
    def physics()
        case @state
        when "walking"
            @facing_right = @pos_x <= @opponent.pos_x
            if @input.y == 1
                @state = "crouching"
                @hurtbox.width = 48
                @hurtbox.height = 128
                @hurtbox.relative_pos_x = @width * 0.5
                @hurtbox.relative_pos_y = @height * 0.5 + 32
                @image.frame_coordinate=[0, 3]
                return self.physics()
            end
            @vel_x = @input.x * @WalkSpeed
            if @vel_x == 0 and @image.animation != 0
                @image.frame_coordinate=[0, 0]
                @image.animation_start = $time
            end
            if @vel_x != 0 and @image.animation != 1
                @image.frame_coordinate=[0, 1]
                @image.animation_start = $time
            end
            if ($time - @image.animation_start > 150 and @image.animation == 1) or ($time - @image.animation_start > 350 and @image.animation == 0)
                @image.animation_start = $time
                @image.cycle_animation
            end
            if (@vel_x > 0 and @facing_right) or (@vel_x < 0 and not @facing_right)
                @vel_x *= @ForwardWalkFactor
            end
            if @input.y == -1.0
                @state = "jumping"
                @image.animation_start = $time
                @vel_y = @JumpForce
                @vel_x = @input.x * @JumpDistance
                @hurtbox.width = 48
                @hurtbox.height = 102
                @hurtbox.relative_pos_x = @width * 0.5
                @hurtbox.relative_pos_y = @height * 0.5 -24
            end
        when "crouching"
            @image.animation = 7
            @facing_right = @pos_x <= @opponent.pos_x
            if @input.y == 0
                @state = "walking"
                @hurtbox.width = 48
                @hurtbox.height = 176
                @hurtbox.relative_pos_x = @width * 0.5
                @hurtbox.relative_pos_y = @height * 0.5 + 8
                return self.physics()
            end
            @vel_x = 0.0
            if @input.y == -1.0
                @state = "jumping"
                @vel_y = @JumpForce
                @vel_x = @input.x * @JumpDistance
                @hurtbox.width = 48
                @hurtbox.height = 102
                @hurtbox.relative_pos_x = @width * 0.5
                @hurtbox.relative_pos_y = @height * 0.5 -24
            end
        when "jumping"
            @vel_y += @Gravity * $delta
            if @vel_y <= 0
                @image.animation = 12
                if $time - @image.animation_start <= 100
                    @image.animation_frame = 0
                else
                    @image.animation_frame = 1
                end

            else
                @image.animation = 13
                if $time - @image.animation_start <= 500
                    @image.animation_frame = 0
                else
                    @image.animation_frame = 1
                end
            end
            if @pos_y + @vel_y * $delta > @FloorHeight
                @pos_y = @FloorHeight
                @state = "walking"
                @vel_y = 0.0
                @hurtbox.width = 48
                @hurtbox.height = 176
                @hurtbox.relative_pos_x = @width * 0.5
                @hurtbox.relative_pos_y = @height * 0.5 + 8
            end
        when "hitstun"
            if @pos_y != @FloorHeight
                @vel_x *= 0.96
                @vel_y += @Gravity * $delta
                if @pos_y + @vel_y * $delta > @FloorHeight
                    @pos_y = @FloorHeight
                    @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                end
            else
                @vel_x *= 0.84
            end
            if @frame_count >= 0
                @state = "walking" if @pos_y == @FloorHeight
                @state = "jumping" if @pos_y != @FloorHeight
                return self.physics()
            end
            @image.frame_coordinate = [0, 2]
            @frame_count += 1
        when "blockstun"
            if @frame_count >= 0
            @state = "walking"
            return self.physics()
            end
            @vel_x *= 0.84
            @frame_count += 1
        when "attacking"
            case @attack
            when "light normal attack"
                if @frame_count >= 12
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 10
                    @image.animation_frame = 0
                elsif @frame_count == 7
                    @hitbox.reset
                elsif @frame_count == 6
                    @image.animation_frame = 1
                    @hitbox.width = 64
                    @hitbox.height = 32
                    @hitbox.relative_pos_x = 64
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 56
                    @hitbox.damage = 5
                    @hitbox.knockback = 100
                    @hitbox.recoil = 100
                    @hitbox.stun = 8
                    @hitbox.blockstun = 6
                    @hitbox.attack_height = "mid"
                    @hitbox.freeze_frames = 1
                elsif @frame_count == 0
                    @vel_x = @vel_y = 0.0
                    @image.animation = 4
                    @image.animation_frame = 0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                end
                @vel_x *= 0.84
            when "heavy normal attack"
                if @frame_count >= 46
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 32
                    @image.animation_frame = 0
                    @hitbox.reset
                elsif @frame_count == 14
                    @vel_x += 400.0
                    @vel_x *= -1.0 if not @facing_right
                    @image.animation_frame = 1
                    @hitbox.width = 102
                    @hitbox.height = 48
                    @hitbox.relative_pos_x = 92
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 108
                    @hitbox.damage = 20
                    @hitbox.knockback = 500
                    @hitbox.recoil = 200
                    @hitbox.stun = 40
                    @hitbox.blockstun = 18
                    @hitbox.attack_height = "mid"
                    @hitbox.freeze_frames = 3
                elsif @frame_count == 0
                    @image.animation = 5
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                end
                @vel_x *= 0.84
            when "light crouching attack"
                if @frame_count >= 14
                    @state = "crouching"
                return self.physics()
                elsif @frame_count == 12
                    @image.animation_frame = 0
                elsif @frame_count == 9
                    @hitbox.reset
                elsif @frame_count == 8
                    @image.animation_frame = 1
                    @hitbox.width = 52
                    @hitbox.height = 32
                    @hitbox.relative_pos_x = 64
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 102
                    @hitbox.damage = 5
                    @hitbox.knockback = 100
                    @hitbox.recoil = 75
                    @hitbox.stun = 8
                    @hitbox.blockstun = 6
                    @hitbox.attack_height = "low"
                    @hitbox.freeze_frames = 1
                elsif @frame_count == 0
                    @vel_x = @vel_y = 0.0
                    @image.animation = 9
                    @image.animation_frame = 0
                    @hurtbox.width = 48
                    @hurtbox.height = 128
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 32
                end
                @vel_x *= 0.84
            when "heavy crouching attack"
                if @frame_count >= 52
                    @state = "crouching"
                    return self.physics()
                elsif @frame_count == 36
                    @image.frame_coordinate = [0, 7]
                    @hitbox.reset
                elsif @frame_count == 32
                    @image.animation_frame = 4
                elsif @frame_count == 24
                    @image.animation_frame = 3
                    @hitbox.width = 64
                    @hitbox.height = 86
                    @hitbox.relative_pos_x = 64
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 146
                    @hitbox.damage = 10
                    @hitbox.knockback = 800
                    @hitbox.recoil = 200
                    @hitbox.stun = 40
                    @hitbox.blockstun = 18
                    @hitbox.attack_height = "low"
                    @hitbox.freeze_frames = 2
                elsif @frame_count == 18
                    @hitbox.reset
                    @image.animation_frame = 2
                elsif @frame_count == 12
                    @vel_x += 800.0
                    @vel_x *= -1.0 if not @facing_right
                    @image.animation_frame = 1
                    @hitbox.width = 48
                    @hitbox.height = 96
                    @hitbox.relative_pos_x = 64
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 128
                    @hitbox.damage = 5
                    @hitbox.knockback = 100
                    @hitbox.recoil = 50
                    @hitbox.stun = 50
                    @hitbox.blockstun = 18
                    @hitbox.attack_height = "low"
                    @hitbox.freeze_frames = 1
                elsif @frame_count == 0
                    @image.animation = 10
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 128
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 32
               end
                @vel_x *= 0.92
            when "light jumping attack"
                if @frame_count == 12
                    @state = "jumping"
                elsif @frame_count == 10
                    @image.animation_frame = 0
                elsif @frame_count == 7
                    @hitbox.reset
                elsif @frame_count == 5
                    @image.animation_frame = 1
                    @hitbox.width = 64
                    @hitbox.height = 32
                    @hitbox.relative_pos_x = 64
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 56
                    @hitbox.damage = 10
                    @hitbox.knockback = 100
                    @hitbox.recoil = 75
                    @hitbox.stun = 8
                    @hitbox.blockstun = 6
                    @hitbox.attack_height = "high"
                    @hitbox.freeze_frames = 1
                elsif @frame_count == 0
                    @image.animation = 14
                    @image.animation_frame = 0
                    @hurtbox.width = 48
                    @hurtbox.height = 102
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 -24
                end
                @vel_y += @Gravity * $delta
                if @pos_y + @vel_y * $delta > @FloorHeight
                    @pos_y = @FloorHeight
                    @state = "walking"
                    @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                    @hitbox.reset
                end
            when "heavy jumping attack"
                if @frame_count >= 46
                    @state = "jumping"
                    return self.physics()
                elsif @frame_count == 32
                    @image.animation_frame = 0
                    @hitbox.reset
                elsif @frame_count == 14
                    @image.animation_frame = 3
                elsif @frame_count == 12
                    @image.animation_frame = 2
                    @hitbox.width = 82
                    @hitbox.height = 128
                    @hitbox.relative_pos_x = 68
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 108
                    @hitbox.damage = 10
                    @hitbox.knockback = 50
                    @hitbox.recoil = 200
                    @hitbox.stun = 40
                    @hitbox.blockstun = 18
                    @hitbox.attack_height = "high"
                    @hitbox.freeze_frames = 3
                elsif @frame_count == 10
                    @vel_x += 100.0 if @facing_right
                    @vel_x -= 100.0 if not @facing_right
                    @vel_y += 200.0
                    @image.animation_frame = 1
                    @hitbox.width = 96
                    @hitbox.height = 90
                    @hitbox.relative_pos_x = 76
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 72
                    @hitbox.damage = 10
                    @hitbox.knockback = 50
                    @hitbox.recoil = 200
                    @hitbox.stun = 40
                    @hitbox.blockstun = 18
                    @hitbox.attack_height = "high"
                    @hitbox.freeze_frames = 1
                elsif @frame_count == 0
                    @image.animation = 15
                    @image.animation_frame = 0
                    @hurtbox.width = 48
                    @hurtbox.height = 102
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 -2
                end
                @vel_y += @Gravity * $delta
                if @pos_y + @vel_y * $delta > @FloorHeight
                    @pos_y = @FloorHeight
                    @state = "walking"
                    @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                    @hitbox.reset
                end
            when "light fireball"
                if @frame_count >= 48
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 26
                    @image.animation_frame = 2
                    Fireball.new(@pos_x+64, @pos_y+32, 260) if @facing_right
                    Fireball.new(@pos_x-64, @pos_y+32, -260) if not @facing_right
                elsif @frame_count == 20
                    @image.animation_frame = 1
                elsif @frame_count == 0
                    @image.animation = 6
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                end
                @vel_x *= 0.84
            when "heavy fireball"
                if @frame_count >= 52
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 20
                    @image.animation_frame = 2
                    Fireball.new(@pos_x+64, @pos_y+32, 500) if @facing_right
                    Fireball.new(@pos_x-64, @pos_y+32, -500) if not @facing_right
                elsif @frame_count == 14
                    @image.animation_frame = 1
                elsif @frame_count == 0
                    @image.animation = 6
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                end
                @vel_x *= 0.84
            when "light DP"
                if @frame_count >= 46
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 26
                    @hitbox.reset
                elsif @frame_count == 20
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                elsif @frame_count == 6
                    @vel_x += 400.0
                    @vel_x *= -1.0 if not @facing_right
                    @image.animation_frame = 1
                    @hitbox.width = 48
                    @hitbox.height = 96
                    @hitbox.relative_pos_x = 48
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 0
                    @hitbox.damage = 10
                    @hitbox.knockback = 600
                    @hitbox.recoil = 200
                    @hitbox.stun = 41
                    @hitbox.blockstun = 28
                    @hitbox.attack_height = "mid"
                    @hitbox.freeze_frames = 6
                elsif @frame_count == 0
                    @image.animation = 11
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 0
                    @hurtbox.height = 0
                    @hurtbox.relative_pos_x = -9999
                    @hurtbox.relative_pos_y = 0
                end
                @vel_x *= 0.84
            when "heavy DP"
                if @frame_count >= 66
                    @state = "walking"
                    return self.physics()
                elsif @frame_count == 28
                    @hitbox.reset
                elsif @frame_count == 26
                    @hurtbox.width = 48
                    @hurtbox.height = 176
                    @hurtbox.relative_pos_x = @width * 0.5
                    @hurtbox.relative_pos_y = @height * 0.5 + 8
                elsif @frame_count == 8
                    @vel_x += 400.0
                    @vel_x *= -1.0 if not @facing_right
                    @image.animation_frame = 1
                    @hitbox.width = 48
                    @hitbox.height = 96
                    @hitbox.relative_pos_x = 48
                    @hitbox.relative_pos_x *= -1 if not @facing_right
                    @hitbox.relative_pos_x += @width if not @facing_right
                    @hitbox.relative_pos_y = 0
                    @hitbox.damage = 20
                    @hitbox.knockback = 800
                    @hitbox.recoil = 100
                    @hitbox.stun = 67
                    @hitbox.blockstun = 12
                    @hitbox.attack_height = "mid"
                    @hitbox.freeze_frames = 6
                elsif @frame_count == 0
                    @image.animation = 11
                    @image.animation_frame = 0
                    @vel_x = @vel_y = 0.0
                    @hurtbox.width = 0
                    @hurtbox.height = 0
                    @hurtbox.relative_pos_x = -9999
                    @hurtbox.relative_pos_y = 0
                end
                @vel_x *= 0.84
            else
                puts @attack
                @state = "walking"
                return self.physics
            end
            hit = @hitbox.check_for_hit
            if hit
                hit.parent.take_hit(@hitbox.damage, @hitbox.knockback, @hitbox.recoil, @hitbox.stun, @hitbox.blockstun, @hitbox.attack_height)
                @vel_x -= @hitbox.recoil if @facing_right
                @vel_x += @hitbox.recoil if not @facing_right
                $freeze_frames = @hitbox.freeze_frames
                @hitbox.reset
            end
            @frame_count += 1
        end
    end
    def move
        @pos_x += @vel_x * $delta
        @pos_x = @pos_x.clamp(0, $Width-@width)
        @pos_y += @vel_y * $delta
        @pos_y = 500 if @pos_y > 500
        @image.flipped = not @facing_right
        @children.each() do |child|
            next if not (child.respond_to?("relative_pos_x") and child.respond_to?("relative_pos_y"))
            child.pos_x = @pos_x + child.relative_pos_x
            child.pos_y = @pos_y + child.relative_pos_y
        end
    end
    def action(button)
        result = ""
        case @input.get_button_action(button)
        when "light"
            result << "light"
        when "heavy"
            result << "heavy"
        else
            return
        end
        case @state
        when "walking"
            directions = @input.direction_history(@facing_right)
            if directions[0..2] == [[1, 0], [1, 1], [0, 1]]
                result << " fireball"
            else
                result << " normal attack"
            end
        when "jumping"
            result << " jumping attack"
        when "crouching"
            directions = @input.direction_history(@facing_right)
            if directions[0..2] == [[1, 1], [0, 1], [1, 0]] or directions[0..3] == [[1,1], [0, 1], [0, 0], [1, 0]]
                result << " DP"
            else
                result << " crouching attack"
            end
        else
            return
        end
        @attack = result
        @state = "attacking"
        @image.animation_start = $time
        @frame_count = 0
        @hitbox.reset
    end
    def take_hit(damage, knockback, recoil, stun, blockstun, attack_height)
        direction = @input.direction_history(@facing_right)[0]
        return hurt(damage, knockback, stun) if direction[0] != -1
        return hurt(damage, knockback, stun) if ["jumping", "attacking", "hitstun"].include? @state
        case attack_height
        when "low"
            return hurt(damage, knockback, stun) if direction[1] != 1
            return block_hit(recoil, blockstun)
        when "mid"
            return block_hit(recoil, blockstun)
        when "high"
            return hurt(damage, knockback, stun) if direction[1] != 0
            return block_hit(recoil, blockstun)
        end
        puts "somthing that isn't suposed to happen happeden in the take hit function"

    end
    def hurt(damage, knockback, stun)
        @health -= damage
        @state = "hitstun"
        @vel_x = knockback
        @vel_x *= -1 if @facing_right
        @frame_count = -stun
    end
    def block_hit(recoil, blockstun)
        @state = "blockstun"
        @vel_x = recoil
        @vel_x *= -1 if @facing_right
        @frame_count = -blockstun
        @image.frame_coordinate = [0, 3 + @input.y * 5]
    end
end

class Fireball < Spacial_Object
    def initialize(x, y, speed = 280, **)
        super(x, y, **)
        @hitbox = HitBox.new(16, 16, 32, 32, :parent => self)
        @hurtbox = HurtBox.new(16, 16, 32, 32, :parent => self)
        @image = ImageSet.new(16, 0, 32, 32, 1, "fireball.png", :parent => self)
        @speed = speed
        @hitbox.damage = 10
        @hitbox.knockback = 100
        @hitbox.recoil = 50
        @hitbox.stun = 24
        @hitbox.blockstun = 14
        @hitbox.attack_height = "mid"
        @hitbox.freeze_frames = 1
    end
    def physics
        if @hitbox.check_for_hit
            @hitbox.check_for_hit.parent.take_hit(@hitbox.damage, @hitbox.knockback, @hitbox.recoil, @hitbox.stun, @hitbox.blockstun, @hitbox.attack_height)
            $freeze_frames = @hitbox.freeze_frames
            self.dissapear
        end
    end
    def move
        @pos_x += @speed * $delta
        @children.each() do |child|
            next if not (child.respond_to?("relative_pos_x") and child.respond_to?("relative_pos_y"))
            child.pos_x = @pos_x + child.relative_pos_x
            child.pos_y = @pos_y + child.relative_pos_y
        end
    end
    def dissapear
        @hitbox.reset
        @image.relative_pos_x = 999999
        @pos_x = -999999
        @pos_y = 99999
        @speed = 0
    end
    def take_hit(*)
        self.dissapear
    end
end

class Game < (Gosu::Window)
    def initialize
        super $Width, $Height
        $time = 0
        @reset = false
        @background = Gosu::Image.new("background.png", :tileable => true)
        @player1 = Player.new(:name => "player1")
        @player1.children.append($PlayerOneImage)
        @player1.image = $PlayerOneImage
        $PlayerOneImage.parent = @player1
        @player1.pos_x = $Width*0.5-160-@player1.width*0.5
        @player1.input = Input.new(:n => Gosu::GP_0_UP, :e => Gosu::GP_0_RIGHT, :s  => Gosu::GP_0_DOWN, :w  => Gosu::GP_0_LEFT, :light => Gosu::GP_0_BUTTON_2, :heavy => Gosu::GP_0_BUTTON_3)
        @player2 = Player.new(:name => "player2")
        @player2.children.append($PlayerTwoImage)
        @player2.image = $PlayerTwoImage
        $PlayerTwoImage.parent = @player2
        @player2.pos_x = $Width*0.5+160-@player2.width*0.5
        @player2.input = Input.new(:n => Gosu::GP_1_UP, :e => Gosu::GP_1_RIGHT, :s  => Gosu::GP_1_DOWN, :w  => Gosu::GP_1_LEFT, :light => Gosu::GP_1_BUTTON_2, :heavy => Gosu::GP_1_BUTTON_3)

        @player1.opponent = @player2
        @player2.opponent = @player1
        @player1.physics
        @player1.move
        @player2.physics
        @player2.move
        @wait = 4
        @wait_image = nil
    end
    def button_down(id)
        @player1.action(id)
        @player2.action(id)
    end
    def update
        if $freeze_frames > 0
            $freeze_frames -= 1
            return
        end
        if @wait >= 0
            if @wait == 0
                @wait_image = nil
                @wait = -1
                return
            else
                @wait_image = Gosu::Image.new(@wait.to_s << "wait.png")
            end
            @wait -= 1
            $freeze_frames = 50
            return
        end
        if @reset
            GameObject.kill_all
            self.initialize
        end

        $time = Gosu::milliseconds

        @player1.input.update()
        @player2.input.update()
        GameObject.get_objects.each() do |object|
            object.physics if object.respond_to?("physics")
        end

        GameObject.get_objects.each() do |object|
            object.move if object.respond_to?("move")
        end
        if @player1.health <= 0
            @reset = true
            $freeze_frames = 180
            Image.new(0, 0, 200, "p2winscreen.png")
        elsif @player2.health <= 0
            @reset = true
            $freeze_frames = 180
            Image.new(0, 0, 200, "p1winscreen.png")
        end
    end
    def draw
        @background.draw(0, 0, 0)
        @wait_image.draw(0, 0, 200) if @wait_image
        GameObject.get_objects.each() do |object|
            object.draw if object.respond_to?("draw")
        end
        Gosu.draw_rect(8, 8, $Width * 0.5 - 16, 32, Gosu::Color.argb(0xff_212121), 10)
        Gosu.draw_rect($Width * 0.5 -8 - ($Width * 0.5 -16) * (@player1.health / @player1.max_health), 8, ($Width * 0.5 - 16) * (@player1.health / @player1.max_health), 32, Gosu::Color.argb(0xff_ff0000), 20)
        Gosu.draw_rect($Width * 0.5 + 8, 8, $Width * 0.5 - 16, 32, Gosu::Color.argb(0xff_212121), 10)
        Gosu.draw_rect($Width * 0.5 + 8, 8, ($Width * 0.5 - 16) * (@player2.health / @player2.max_health), 32, Gosu::Color.argb(0xff_ff0000), 20)
    end
end

$PlayerOneImage = ImageSet.new(16, -192, 384, 384, 1, "player1.png")
$PlayerTwoImage = ImageSet.new(16, -192, 384, 384, 1, "player2.png")
Game.new.show
