# frozen_string_literal: true

class SystemsController < ApplicationController
  def show
    @info = authorize(SystemInfo.new).load_all
  end

  def dbsize
    @info = authorize(SystemInfo.new).dbsize.load
  end

  # named config_options since config is already a controller method
  def config_options
    @options = authorize(SystemInfo.new).config_options
  end
end
