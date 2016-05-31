# Encoding: UTF-8

require 'rubygems'
require 'gosu'
require 'gl'
require 'timers'

WIDTH, HEIGHT = 1500,900
# :fullscreen => true


module ZOrder
  Background, Questions, Juices, Player, UI = *0..5
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
    @rooster = Gosu::Sample.new("media/rooster.wav")
    @pain = Gosu::Sample.new("media/pain.wav")
    @x, @y = x, y
    @score = 0
    @lives = 5
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

  #When a player dies, we subtract a life, then warp them back to the middle of the screen, towards the bottom.
  def kill
    @lives -= 1
    @alive = false
    return if @lives <= 0
    warp
  end

  def dead?
    !@alive
    return @lives <= 0
  end

  def warp(x=750,y=800)
    # @velocity_x = @velocity_y = @angle = 0.0
    @x, @y = x, y
    @alive = true
  end

  def collect_juices(juices)
    juices.reject! do |juice|
      #stops player from being able to collect when dead
      if @alive
        if Gosu::distance(@x, @y, juice.x, juice.y) < 50 then
          @lives += 1
          @rooster.play
           true
        else
          false
        end
      end
    end
  end

  def avoid_questions(questions)
    @player = self
    questions.reject! do |question|
      #stops player from being able to collect when dead
      if @alive
        if Gosu::distance(@x, @y, question.x, question.y) < 150 then
          # @score -= 50
          @player.kill
          # @lives -= 1
          @pain.play
          true
        else
          false
        end
      end
    end
  end

end # end class Player


# Also taken from the tutorial, but drawn with draw_rot and an increasing angle for extra rotation coolness!
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
  attr_reader :minutes
  attr_reader :seconds
  def initialize(window)
    @minutes = 0
    @seconds = 0
    @last_time = Gosu::milliseconds()
  end

  def update
    if (Gosu::milliseconds - @last_time) / 1000 == 1
      @seconds += 1
      @last_time = Gosu::milliseconds()
    end
    if @seconds > 59
      @seconds = 0
      @minutes += 1
    end
    if @minutes > 59
      @minutes = 0
    end
  end
end #end class Timer

class OpenGLIntegration < (Example rescue Gosu::Window)
  attr_reader :timer

  def initialize
    super WIDTH, HEIGHT
    self.caption = "Operation Shortsmack"
    @gl_background = GLBackground.new
    @life_image = Gosu::Image.new("media/bryan.bmp")
    @game_in_progress = false
    @font = Gosu::Font.new(20)
    setup_game
    @timer = Timer.new(self)
  end

  def setup_game
    @player = Player.new(400, 500)
    @score = 0
    @juice= Gosu::Image::load_tiles("media/juice_large.png", 100, 100)
    @juices = Array.new
    @question = Gosu::Image::load_tiles("media/wat.png", 250, 250)
    @questions = Array.new
    # @font = Gosu::Font.new(20)
    @game_in_progress = true
  end

  def update
    if button_down? Gosu::KbQ
      close
    end

    if button_down? Gosu::KbS
      setup_game unless @game_in_progress
    end

    control_player unless @player.dead?
    @player.collect_juices(@juices)

    @juices.reject! { |juice| !juice.update }

    @player.avoid_questions(@questions)

    @questions.reject! { |question| !question.update }

    @gl_background.scroll

    @timer.update

    # rand(number) controls how many juices and questions fall at a time
    @juices.push(Juice.new(@juice)) if rand(150) == 0
    @questions.push(Question.new(@question)) if rand(40) == 0
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
      @font.draw("BRYAN I THOUGHT YOU WERE A WIZARD", 400, 150, 50, 2.0, 2.0, 0xffffffff)
      # @font.draw("press 'r' to restart", 700, 320, 50, 1, 1, 0xffffffff)
      @font.draw("press 'q' to quit", 675, 345, 50, 1, 1, 0xffffffff)
      #sleep
    end

    @score += 1 unless @player.dead?
    @player.draw unless @player.dead?
    @juices.each { |juice| juice.draw } unless @player.dead?
    @questions.each { |question| question.draw } unless @player.dead?
    # draw_lives
    @font.draw("Lives: #{@player.lives}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @seconds = @score / 60
    if @player.dead?
      @font.draw("You died in #{@seconds} seconds", 600, 250, 50, 1.5, 1.5, Gosu::Color.argb(0xff_ff0000))
    end

    @gl_background.draw(ZOrder::Background)
    # @life_image.draw(self, "media/bryan.bmp", false)

    if @player.lives > 0
      x = 10
      @player.lives.times do
        @life_image.draw(x, 40, 0)
        x += 40
      end
    end
  end
end #class OpenGL

class Window_PlayTime < OpenGLIntegration

  def initialize(window, x, y, z)
    super(window, x, y, 160, 70, 10)
    @window = window
    @font = Font.new(window ,@window.initial.font_name, @window.initial.font_size)
    # colors
  end

  def adapt_time
    if @window.timer.minutes < 10
      @minutes_display = "0" + @window.timer.minutes.to_s
    else
      @minutes_display = @window.timer.minutes.to_s
    end
    if @window.timer.seconds < 10
      @seconds_display = "0" + @window.timer.seconds.to_s
    else
      @seconds_display = @window.timer.seconds.to_s
    end
  end

  def update
    adapt_time
    self.draw
  end

  def draw
    self.drawBox(@x, @y, @width, @height, @z)
    @font.draw("Play Time:", self.x+20, self.y+10, @z, 1, 1, @blue_text)
    @font.draw_rel(@hours_display+":"+@minutes_display+":"+@seconds_display, self.x + @width - 15, self.y + 50, @z, 1.0, 0.5)
  end
end



OpenGLIntegration.new.show if __FILE__ == $0

