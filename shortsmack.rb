require 'rubygems'
require 'gosu'
require 'gl'

class Window < Gosu::Window
  def initialize
    super(640, 400, false)
    self.caption = 'Operation Shortsmack'

    @background_image = Gosu::Image.new("media/space.png", :tileable => true)

    @player = Player.new
    @player.warp(320, 240)
  end

 # update() is called 60 times per second (by default) and should contain the main game logic: move objects, handle collisions, etc.
  def update
    if Gosu::button_down? Gosu::KbLeft or Gosu::button_down? Gosu::GpLeft then
      @player.turn_left
    end
    if Gosu::button_down? Gosu::KbRight or Gosu::button_down? Gosu::GpRight then
      @player.turn_right
    end
    if Gosu::button_down? Gosu::KbUp or Gosu::button_down? Gosu::GpButton0 then
      @player.accelerate
    end
    if Gosu::button_down? Gosu::KbDown or Gosu::button_down? Gosu::GpButton0 then
      @player.decelerate
    end
    @player.move
  end

  # draw() is called afterwards and whenever the window needs redrawing for other reasons, and may also be skipped every other time if the FPS go too low. It should contain the code to redraw the whole screen, but no updates to the game's state.
  def draw
    @player.draw
    @background_image.draw(0, 0, 0)
  end

  def button_down(id)
    if id == Gosu::KbEscape
      close
    end
  end
end # end class Window

class Player
  def initialize
    @image = Gosu::Image.new("media/numbermuncher.jpeg")
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @score = 0
  end

  def warp(x, y)
    @x, @y = x, y
  end

  def turn_left
    # @angle -= 3.5
    @vel_x -= Gosu::offset_x(@angle, 3.5)
    @vel_y -= Gosu::offset_y(@angle, 0)
  end

  def turn_right
    # @angle += 3.5
    @vel_x += Gosu::offset_x(@angle, 3.5)
    @vel_y += Gosu::offset_y(@angle, 0)
  end

  def accelerate
    @vel_x += Gosu::offset_x(@angle, 0.5)
    @vel_y += Gosu::offset_y(@angle, 0.5)
  end

  def decelerate
    @vel_x -= Gosu::offset_x(@angle, 0.5)
    @vel_y -= Gosu::offset_y(@angle, 0.5)
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x %= 640
    @y %= 480

    @vel_x *= 0.95
    @vel_y *= 0.95
  end

  def draw
    @image.draw_rot(@x, @y, 1, @angle)
  end
end #end class Player

Window.new.show
