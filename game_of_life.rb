#!/usr/bin/env ruby
#encoding=utf-8
#
#
#        ######   ######
#        ######   ######
#        ######   ######
#        ######   ######
#
#                 ######   ######
#                 ######   ######
#                 ######   ######
#                 ######   ######
#
#        ######
#        ######
#        ######
#        ######
#
#
# Any live cell with fewer than two live neighbours dies, as if caused by under-population.
# Any live cell with two or three live neighbours lives on to the next generation.
# Any live cell with more than three live neighbours dies, as if by overcrowding.
# Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.

require 'terminfo'
require 'ffi-ncurses'
require 'forwardable'
require 'drawille'
require 'pretty_backtrace'

#PrettyBacktrace.enable

#PrettyBacktrace.multi_line = true

class Game
  module Display
    class Generic
      def self.initialize
      end

      def self.update_screen(universe, interval)
        raise StandardError, "method not defined for display"
      end

      def self.x
        raise StandardError, "method not defined for display"
      end

      def self.y
        raise StandardError, "method not defined for display"
      end

      def self.destroy
      end
    end

    class Braille < Generic
      def self.initialize
        @@canvas   = Drawille::Canvas.new
      end

      def self.update_screen(universe, interval)
        @@canvas.clear
        universe.each { |x| x.each { |cell| self.draw(cell) } }
        puts @@canvas.frame
      end

      def self.x
        TermInfo.screen_columns * 2 - 3
      end

      def self.y
        TermInfo.screen_lines * 4 - 4
      end

      private

      def self.draw(cell)
        @@canvas.set(cell.x, cell.y) if cell.state?
      end
    end

    class Raw < Generic
      def self.update_screen(universe, interval)
        system('clear')
        puts universe
        sleep interval
      end

      def self.x
        TermInfo.screen_columns
      end

      def self.y
        TermInfo.screen_lines - 1
      end
    end

    class Curses < Generic
      def self.initialize
        FFI::NCurses.initscr
        FFI::NCurses.clear
        FFI::NCurses.curs_set 0
        FFI::NCurses.raw
        FFI::NCurses.noecho
        FFI::NCurses.move(0,0)
      end

      def self.update_screen(universe, interval)
        universe.each { |x| x.each { |cell| self.draw(cell) } }

        FFI::NCurses.refresh
        exit if self.quit?(interval)
      end

      def self.x
        FFI::NCurses.send("COLS")
      end

      def self.y
        FFI::NCurses.send("LINES")
      end

      def self.destroy
        FFI::NCurses.endwin
      end

      private

      def self.quit?(interval)
        FFI::NCurses.timeout(interval * 1000)
        key = FFI::NCurses.getch
        key.chr == "q" unless key == -1
      end

      def self.draw(cell)
        FFI::NCurses.move(cell.y, cell.x)
        FFI::NCurses.flushinp
        FFI::NCurses.addstr(cell.to_s)
      end
    end
  end

  class Cell
    DEAD  = false
    ALIVE = true

    attr_reader   :x, :y
    attr_accessor :state

    def initialize(x, y, state = DEAD)
      @x       = x
      @y       = y
      @state   = state
    end

    def state?
      @state
    end

    def dead!
      @state = DEAD
    end

    def alive!
      @state = ALIVE
    end

    def to_s
      @state ? "o" : " "
    end
  end

  class Universe
    extend Forwardable

    def_delegators :@universe, :map, :each

    attr_accessor :density, :width, :height

    def initialize
      @density  = 0.1
      @width    = nil
      @height   = nil
      @universe = nil
    end

    def create
      @universe ||= (1..@height).map do |y|
        (1..@width).map do |x|
          Game::Cell.new(x, y, rand < @density)
        end
      end
    end

    def tick
      raise StandardError, "no universe exists" unless @universe

      new_universe = @universe.map.with_index do |x, y_index|
        x.map.with_index do |cell, x_index|
          establish_next_state(cell, cell_relatives(cell, x_index, y_index))
        end
      end

      @universe = new_universe
    end

    def establish_next_state(cell, relatives)
      next_generation_cell = cell.dup

      if cell.state?
        next_generation_cell.dead! if relatives < 2
        next_generation_cell.dead! if relatives > 3
      else
        next_generation_cell.alive! if relatives == 3
      end

      next_generation_cell
    end

    def cell_relatives(cell, x_index, y_index)
      relatives = 0

      [-1, 0, 1].each do |y_offset|
        [-1, 0, 1].each do |x_offset|
          next if y_offset == 0 and x_offset == 0
          relatives += 1 if neighbour(x_index + x_offset, y_index + y_offset).state?
        end
      end

      relatives
    end

    def neighbour(x, y)
      x = -1 if x >= @width
      y = -1 if y >= @height
      @universe[y][x]
    end


    def [](x)
      @universe[x]
    end

    def to_s
      @universe.map { |x| x.map { |cell| cell.to_s }.join }.join("\n")
    end
  end

  DISPLAY = {
    :curses  => Display::Curses,
    :raw     => Display::Raw,
    :braille => Display::Braille,
  }

  attr_accessor :universe, :interval

  def initialize
    @display  = DISPLAY[:braille]
    @universe = Game::Universe.new
    @interval = 0.05
  end

  def start
    begin
      @display.initialize

      @universe.height = @display.y unless @universe.height
      @universe.width  = @display.x unless @universe.width

      @universe.create

      loop do
        @universe.tick
        @display.update_screen(@universe, @interval)
      end
    ensure
      @display.destroy
    end
  end

  def display=(display)
    @display = DISPLAY[display]
  end
end

#game = Game.new
#game.display           = :braille      # use different display type
#game.display           = :raw          # use different display type
#game.interval          =              # change interval between ticks
#game.universe.width    =              # override auto-detect
#game.universe.height   =              # override auto-detect
#game.universe.density  =              # density of randomly populated universe
#game.universe.layout   =              # by default universe begins in random state
#game.start

Game.new.start
