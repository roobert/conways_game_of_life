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

require 'ffi-ncurses'
require 'forwardable'
require 'pretty_backtrace'

PrettyBacktrace.enable
PrettyBacktrace.multi_line = true

class Game
  module Screen
    def self.start
      FFI::NCurses.initscr
      FFI::NCurses.clear
      FFI::NCurses.curs_set 0
      FFI::NCurses.raw
      FFI::NCurses.noecho
      FFI::NCurses.move(0,0)
    end

    def self.stop
      FFI::NCurses.endwin
    end

    def self.x
      FFI::NCurses.send("COLS")
    end

    def self.y
      FFI::NCurses.send("LINES")
    end

    def self.puts(string)
      FFI::NCurses.flushinp
      FFI::NCurses.addstr(string)
      FFI::NCurses.refresh
    end

    def self.update_cell(cell)
      FFI::NCurses.move(cell.y, cell.x)
      FFI::NCurses.flushinp
      FFI::NCurses.addstr(cell.to_s)
    end

    def self.quit?(interval)
      FFI::NCurses.timeout(interval * 1000)
      key = FFI::NCurses.getch
      key.chr == "q" unless key == -1
    end

    def self.refresh
      FFI::NCurses.refresh
    end
  end

  class Cell
    DEAD  = false
    ALIVE = true

    attr_reader   :x, :y
    attr_accessor :state

    def initialize(x, y, state = DEAD)
      @x     = x
      @y     = y
      @state = state
    end

    def state?
      alive?
    end

    def dead?
      true unless @state
    end

    def alive?
      true if @state
    end

    def dead!
      @state = DEAD
    end

    def alive!
      @state = ALIVE
    end

    def toggle!
      @state = @state ? alive! : dead!
    end

    def to_s
      state? ? "#" : " "
    end
  end

  class Universe
    extend Forwardable

    attr_reader :height, :width, :cell

    def_delegators :@universe, :map, :map

    def initialize(density, interval)
      @width    = dimension(:x).to_i
      @height   = dimension(:y).to_i
      @interval = interval
      @density  = density
      @universe = nil
    end

    def dimension(requested_dimension)
      return Game::Screen.send(requested_dimension) unless Game::Screen.send(requested_dimension) == 0
      raise StandardError, "could not detect screen size"
    end

    def [](x)
      @universe[x]
    end

    def neighbour(x, y)
      x = -1 if x >= @width
      y = -1 if y >= @height
      @universe[y][x]
    end

    def create
      (1..@height).map do |y|
        (1..@width).map do |x|
          Game::Cell.new(x, y, rand < @density)
        end
      end
    end

    def tick
      @universe ||= create

      new_universe = @universe.map.with_index do |x, y_index|
        x.map.with_index do |cell, x_index|
          establish_next_state(cell, cell_relatives(cell, x_index, y_index))
        end
      end

      @universe = new_universe
    end

    def establish_next_state(cell, relatives)
      next_generation_cell = cell.dup

      if cell.alive?
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
          relatives += 1 if neighbour(x_index + x_offset, y_index + y_offset).state?
        end
      end

      relatives
    end

    def update_screen
      @universe.each_with_index do |x, y_index|
        x.each_with_index do |cell, x_index|
          Screen.update_cell(cell)
        end
      end

      Screen.refresh
    end
  end

  attr_accessor :interval, :density

  def initialize(interval = 0.1, density = 0.05)
    @interval = interval
    @density  = density
  end

  def start
    Screen.start

    @universe = Game::Universe.new(@density, @interval)

    loop do
      @universe.tick
      @universe.update_screen
      exit if Screen.quit?(@interval)
    end
  end

  def stop
    Screen.stop
  end
end

begin
  game = Game.new
  game.start
ensure
  game.stop
end
