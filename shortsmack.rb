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
  POINTS_X = 12
  POINTS_Y = 12
  # Scrolling speed
  SCROLLS_PER_STEP = 50

  def initialize
    @image = Gosu::Image.new("media/hacker_code_blue.jpg", :tileable => true)
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

  def avoid_questions(questions)
    questions.reject! do |question|
      if Gosu::distance(@x, @y, question.x, question.y) < 150 then
        @score -= 50
        @beep.play
        true
      else
        false
      end
    end
  end
end # end class Player


# Also taken from the tutorial, but drawn with draw_rot and an increasing angle
# for extra rotation coolness!
class Juice
   attr_reader :x, :y, :angle

  def initialize(image)
    @image = Gosu::Image.new("media/juice_large.png")
    @x = rand * 1500
    @y = 0
    @angle = rand(360)
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::Juices, @angle)
  end

  def update
    @y += 10
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

class Timer

  # def initialize
  #   @time = 120
  # end

# def countdown
#   @number = 120
#     while @number > 0
#       @time = Time.at(@number).strftime "%M:%S"
#       sleep 1
#       @number - 1
#     end
#   end
# end
# def countdown
# t = Time.new(0)
# countdown_time_in_seconds = 300 # change this value

# countdown_time_in_seconds.downto(0) do |seconds|
#   puts (t + seconds).strftime('%H:%M:%S')
#   sleep 1
# end
# end
end


class OpenGLIntegration < (Example rescue Gosu::Window)
  def initialize
    super WIDTH, HEIGHT

    self.caption = "Operation Shortsmack"

    @gl_background = GLBackground.new

    @player = Player.new(400, 500)

    @juice= Gosu::Image::load_tiles("media/juice_large.png", 100, 100)
    @juices = Array.new

    @question = Gosu::Image::load_tiles("media/wat.png", 250, 250)
    @questions = Array.new

    @font = Gosu::Font.new(20)
    @timer = Timer.new
  end

  def update
    @player.move_left if Gosu::button_down? Gosu::KbLeft or Gosu::button_down? Gosu::GpLeft
    @player.move_right if Gosu::button_down? Gosu::KbRight or Gosu::button_down? Gosu::GpRight
    @player.accelerate if Gosu::button_down? Gosu::KbUp or Gosu::button_down? Gosu::GpUp
    @player.brake if Gosu::button_down? Gosu::KbDown or Gosu::button_down? Gosu::GpDown

    @player.collect_juices(@juices)

    @juices.reject! { |juice| !juice.update }

    @player.avoid_questions(@questions)

    @questions.reject! { |question| !question.update }

    @gl_background.scroll

# rand(number) controls how many juices and questions fall at a time
    @juices.push(Juice.new(@juice)) if rand(250) == 0
    @questions.push(Question.new(@question)) if rand(40) == 0
  end

  def draw
    @player.draw
    @juices.each { |juice| juice.draw }
    @questions.each { |question| question.draw }
    @font.draw("Score: #{@player.score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    # @font.draw("#{@timer.countdown} Seconds To Go", 1000, 20, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
if @player.score < 0
  sleep 5
end

    @gl_background.draw(ZOrder::Background)
  end

end

OpenGLIntegration.new.show if __FILE__ == $0

