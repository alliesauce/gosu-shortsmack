# Encoding: UTF-8

require 'rubygems'
require 'gosu'
require 'gl'

WIDTH, HEIGHT = 1500,900
# :fullscreen => true


module ZOrder
  Background, Juices, Questions, Player, UI = *0..4
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
    # @life_image = Gosu::Image.new(self, "media/bryan.bmp", false)
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

  attr_accessor :x, :y, :angle, :lives, :score

  def initialize(x, y)
    @image = Gosu::Image.new("media/bryan.bmp")
    @beep = Gosu::Sample.new("media/beep.wav")
    @x, @y = x, y
    @score = 0
    @lives = 3
    @alive = true
  end

  def move_left
    @x = [@x - Speed, WIDTH].min
    @x %= 1500
    @y %= 900
  end

  def move_right
    @x = [@x + Speed, WIDTH].min
    @x %= 1500
    @y %= 900
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

  #When a player dies, we subtract a life, then warp them back to the middle of the screen.
  def kill
    @lives -= 1
    @alive = false
    return if @lives <= 0
    warp
  end

  def dead?
    !@alive
    return @lives == 0
  end

  def warp(x=750,y=450)
    # @velocity_x = @velocity_y = @angle = 0.0
    @x, @y = x, y
    @alive = true
  end

  def collect_juices(juices)
    juices.reject! do |juice|
      if Gosu::distance(@x, @y, juice.x, juice.y) < 35 then
        @score += 10
        @beep.play
        true
      else
        false
      end
    end
  end

  def avoid_questions(questions)
    @player = self
    questions.reject! do |question|
      if Gosu::distance(@x, @y, question.x, question.y) < 100 then
        @score -= 50
        @player.kill
        @lives -= 1
        @beep.play
        true
      else
        false
      end
    end
  end

end # end class Player


# Also taken from the tutorial, but drawn with draw_rot and an increasing angle for extra rotation coolness!
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
    img = @animation[Gosu::milliseconds / 150 % @animation.size];
    img.draw_rot(@x, @y, ZOrder::Juices, @y, 0.5, 0.5, 1, 1, @color, :add)
  end

  def update
    # Move towards bottom of screen
    @y += 5
    # Return false when out of screen (gets deleted then)
    @y < 950
  end
end

class Question
  attr_reader :x, :y, :angle

  def initialize(image)
    @image = Gosu::Image.new("media/wat.png")
    @x = rand * 1500
    @y = 0
    @angle = rand(360)
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::Questions, @angle)
  end

  def update
    @y += 5
    @y < 950
  end
end


class OpenGLIntegration < (Example rescue Gosu::Window)
  def initialize
    super WIDTH, HEIGHT
    self.caption = "Operation Shortsmack"
    @gl_background = GLBackground.new
    @life_image = Gosu::Image.new(self, "media/bryan.bmp", false)
    @game_in_progress = false
    @font = Gosu::Font.new(20)
    setup_game
  end

  def setup_game
    @player = Player.new(400, 500)
    @juice_anim = Gosu::Image::load_tiles("media/juice.png", 50, 50)
    @juices = Array.new
    @question = Gosu::Image::load_tiles("media/wat.png", 250, 250)
    @questions = Array.new
    @game_in_progress = true
  end

  def update
    if button_down? Gosu::KbQ
      close
    end

    if button_down? Gosu::KbS
      setup_game unless @game_in_progress
    end

    # if button_down? Gosu::KbR
    #   @game_in_progress = false
    # end

    control_player unless @player.dead?
    @player.collect_juices(@juices)

    @juices.reject! { |juice| !juice.update }

    @player.avoid_questions(@questions)

    @questions.reject! { |question| !question.update }

    @gl_background.scroll

    # rand(number) controls how many juices and questions fall at a time
    @juices.push(Juice.new(@juice_anim)) if rand(150) == 0
    @questions.push(Question.new(@question)) if rand(50) == 0
  end

  def control_player
    @player.move_left if Gosu::button_down? Gosu::KbLeft or Gosu::button_down? Gosu::GpLeft
    @player.move_right if Gosu::button_down? Gosu::KbRight or Gosu::button_down? Gosu::GpRight
    @player.accelerate if Gosu::button_down? Gosu::KbUp or Gosu::button_down? Gosu::GpUp
    @player.brake if Gosu::button_down? Gosu::KbDown or Gosu::button_down? Gosu::GpDown
  end

  def end_game
    close if Gosu::button_down? Gosu::KbQ or Gosu::button_down? Gosu:: GpQ
  end

  def draw

    if @player.lives <= 0
      @font.draw("GAME OVER", 700, 150, 50, 2.0, 2.0, 0xffffffff)
      # @font.draw("press 'r' to restart", 700, 320, 50, 1, 1, 0xffffffff)
      @font.draw("press 'q' to quit", 700, 345, 50, 1, 1, 0xffffffff)
      #sleep
    end

    @player.draw unless @player.dead?
    @juices.each { |juice| juice.draw }
    @questions.each { |question| question.draw }
    draw_lives
    @font.draw("Score: #{@player.score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @gl_background.draw(ZOrder::Background)
    # @life_image.draw(self, "media/bryan.bmp", false)
  end

  def draw_lives
    return unless @player.lives > 0
    x = 10
    @player.lives.times do
      @life_image.draw(x, 40, 0)
      x += 20
    end
  end
end #class OpenGL



OpenGLIntegration.new.show if __FILE__ == $0
