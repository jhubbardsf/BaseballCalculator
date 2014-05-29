class StaticPagesController < ApplicationController
  require 'baseball'

  def home
  end

  def upload
    Baseball.batting_stats(params[:batting_file].tempfile.path)
    Baseball.master_stats(params[:master_file].tempfile.path)

    most_improved = Baseball.most_improved_batter(2009, 2010)
    oakland_stats = Baseball.team_slugging_percentage('OAK', 2007)
    triple_winner = Baseball.triple_crown_winner(2012)

    result = { most_improved: most_improved, oakland_stats: oakland_stats, triple_winner: triple_winner }

    logger = Logger.new(STDOUT)
    logger.info result

    respond_to do |format|
      format.json { render json: result }
    end
  end
end