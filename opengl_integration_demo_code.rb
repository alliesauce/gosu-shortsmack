# Encoding: UTF-8

# The tutorial game over a landscape rendered with OpenGL.
# Basically shows how arbitrary OpenGL calls can be put into
# the block given to Window#gl, and that Gosu Images can be
# used as textures using the gl_tex_info call.

require 'rubygems'
require 'gosu'
require 'gl'

WIDTH, HEIGHT = 1500,900
# :fullscreen => truemkdir


module ZOrder
  Background, Juices, Player, UI = *0..3
end

# The only really new class here.
# Draws a scrolling, repeating texture with a randomized height map.
class GLBackground
  # Height map size
  POINTS_X = 7
  POINTS_Y = 7
  # Scrolling speed
  SCROLLS_PER_STEP = 50

  def initialize
    @image = Gosu::Image.new("media/hacker_code.jpg", :tileable => true)
    @scrolls = 0
    @height_map = Array.new(POINTS_Y) { Array.new(POINTS_X) { rand } }
  end

  def scroll
    @scrolls += 1
    if @scrolls == SCROLLS_PER_STEP then
      @scrolls = 0
      @height_map.shift
      @height_map.push Array.new(POINTS_X) { rand }
    end
  end

  def draw(z)
    # gl will execute the given block in a clean OpenGL environment, then reset
    # everything so Gosu's rendering can take place again.
    Gosu::gl(z) { exec_gl }
  end

  private

  include Gl

  def exec_gl
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glClearDepth(0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    # Get the name of the OpenGL texture the Image resides on, and the
    # u/v coordinates of the rect it occupies.
    # gl_tex_info can return nil if the image was too large to fit onto
    # a single OpenGL texture and was internally split up.
    info = @image.gl_tex_info
    return unless info

    # Pretty straightforward OpenGL code.

    glDepthFunc(GL_GEQUAL)
    glEnable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity
    glFrustum(-0.10, 0.10, -0.075, 0.075, 1, 100)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity
    glTranslate(0, 0, -4)

    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, info.tex_name)

    offs_y = 1.0 * @scrolls / SCROLLS_PER_STEP

    0.upto(POINTS_Y - 2) do |y|
      0.upto(POINTS_X - 2) do |x|
        glBegin(GL_TRIANGLE_STRIP)
          z = @height_map[y][x]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.left, info.top)
          glVertex3d(-0.5 + (x - 0.0) / (POINTS_X-1), -0.5 + (y - offs_y - 0.0) / (POINTS_Y-2), z)

          z = @height_map[y+1][x]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.left, info.bottom)
          glVertex3d(-0.5 + (x - 0.0) / (POINTS_X-1), -0.5 + (y - offs_y + 1.0) / (POINTS_Y-2), z)

          z = @height_map[y][x + 1]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.right, info.top)
          glVertex3d(-0.5 + (x + 1.0) / (POINTS_X-1), -0.5 + (y - offs_y - 0.0) / (POINTS_Y-2), z)

          z = @height_map[y+1][x + 1]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.right, info.bottom)
          glVertex3d(-0.5 + (x + 1.0) / (POINTS_X-1), -0.5 + (y - offs_y + 1.0) / (POINTS_Y-2), z)
        glEnd
      end
    end
  end
end

# Roughly adapted from the tutorial game. Always faces north.
class Player
  Speed = 7

  attr_reader :score

  def initialize(x, y)
    @image = Gosu::Image.new("media/bryan.bmp")
    @beep = Gosu::Sample.new("media/beep.wav")
    @x, @y = x, y
    @score = 0
  end

  def move_left
    @x = [@x - Speed, 0].max
  end

  def move_right
    @x = [@x + Speed, WIDTH].min
  end

  def accelerate
    @y = [@y - Speed, 50].max
  end

  def brake
    @y = [@y + Speed, HEIGHT].min
  end

  def draw
    @image.draw(@x - @image.width / 2, @y - @image.height / 2, ZOrder::Player)
  end

  def collect_juices(juices)
    juices.reject! do |juice|
      if Gosu::distance(@x, @y, juice.x, juice.y) < 50 then
        @score += 10
        @beep.play
        true
      else
        false
      end
    end
  end
end

# Also taken from the tutorial, but drawn with draw_rot and an increasing angle
# for extra rotation coolness!
class Juice
  attr_reader :x, :y

  def initialize(animation)
    @animation = animation
    @color = Gosu::Color.new(0xff_000000)
    @color.red = rand(255 - 40) + 40
    @color.green = rand(255 - 40) + 40
    @color.blue = rand(255 - 40) + 40
    @x = rand * 1500
    @y = 0
  end

  def draw
    img = @animation[Gosu::milliseconds / 250 % @animation.size];
    img.draw_rot(@x, @y, ZOrder::Juices, @y, 0.5, 0.5, 1, 1, @color, :add)
  end

  def update
    # Move towards bottom of screen
    @y += 5
    # Return false when out of screen (gets deleted then)
    @y < 950
  end
end

class OpenGLIntegration < (Example rescue Gosu::Window)
  def initialize
    super WIDTH, HEIGHT

    self.caption = "OpenGL Integration"

    @gl_background = GLBackground.new

    @player = Player.new(400, 500)
# changed
    @juice_anim = Gosu::Image::load_tiles("media/juice.png", 50, 50)
    @juices = Array.new

    @font = Gosu::Font.new(20)
  end

  def update
    @player.move_left if Gosu::button_down? Gosu::KbLeft or Gosu::button_down? Gosu::GpLeft
    @player.move_right if Gosu::button_down? Gosu::KbRight or Gosu::button_down? Gosu::GpRight
    @player.accelerate if Gosu::button_down? Gosu::KbUp or Gosu::button_down? Gosu::GpUp
    @player.brake if Gosu::button_down? Gosu::KbDown or Gosu::button_down? Gosu::GpDown

    @player.collect_juices(@juices)

    @juices.reject! { |juice| !juice.update }

    @gl_background.scroll

# rand(number) controls how many juices fall at a time
# changed
    @juices.push(Juice.new(@juice_anim)) if rand(300) == 0
  end

  def draw
    @player.draw
    @juices.each { |juice| juice.draw }
    @font.draw("Score: #{@player.score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @gl_background.draw(ZOrder::Background)
  end
end

OpenGLIntegration.new.show if __FILE__ == $0
