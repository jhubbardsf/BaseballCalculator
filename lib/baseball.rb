module Baseball
  require 'CSV'

  module_function

  def batting_stats(path = nil)
    if path
      file = File.open(path)
      content = file.read
      content.strip!
    end
    @stats ||= CSV.parse(content, { headers: true, converters: :integer})
  end

  def master_stats(path = nil)
    if path
      file = File.open(path)
      content = file.read
      content.strip!
    end
    @master_stats ||= CSV.parse(content, { headers: true })
  end

  # Get a comprehensive list of all batters batting over 200
  def eligible_batters(first_year, second_year)
    # Only select those who had at bats.
    eligible = batting_stats.select { |player| player["AB"] }

    # Get players with over 200 at bats.
    eligible = eligible.select { |player| player["AB"] > 200 && (player["yearID"] == first_year || player["yearID"] == second_year) }

    # Limits it to players who had over 200 in both the first year and second year.
    combined_hash = {}
    eligible.each { |x| combined_hash[x["playerID"]] ||= 0; combined_hash[x["playerID"]] += 1 }
    eligible.reject! { |x| combined_hash[x["playerID"]] == 1 }

    # Figure out if a player was traded and combine stats
    stats_to_combine = eligible.select { |x| eligible.count { |y|  y["playerID"] == x["playerID"] } > 2 }
    stc_1 = stats_to_combine.select { |x| x["yearID"] == first_year }
    stc_2 = stats_to_combine.select { |x| x["yearID"] == second_year }
    combined_stats = combine_stats(stc_1).concat(combine_stats(stc_2))

    # Finally, go through the over_200 list, delete all the player stats for those years and insert the combined stats.
    combined_stats.each do |stat|
      eligible.delete_if { |x| x["playerID"] == stat["playerID"] && x["yearID"] == stat["yearID"] }
    end
    eligible = eligible.concat(combined_stats).sort_by! { |x| [ x["playerID"], x["yearID"] ] } # Adding in the combined stats.
  end

  # Find batting averages for players between two years.
  def batting_average_differences(year1, year2)
    batters = eligible_batters(year1, year2)
    averages = []
    batters.each_slice(2) do |slice|
      batter09 = slice[0]
      batter10 = slice[1]
      ba1 = (batter09["H"].to_f/batter09["AB"].to_f).round(3)
      ba2 = (batter10["H"].to_f/batter10["AB"].to_f).round(3)
      averages << {
          playerID: batter09["playerID"],
          average1: ba1,
          average2: ba2,
          difference: (ba2 - ba1).round(3),
      }
    end

    # Return the batting averages sorted by the difference in descending order.
    averages.sort_by! { |x| x[:difference] }.reverse!
  end

  # Return the most improved batter between two years.
  def most_improved_batter(year1, year2)
    batters = batting_average_differences(year1, year2)
    most_improved_batter = batters[0]

    mstat = master_stats.select { |x| x["playerID"] == most_improved_batter[:playerID] }[0]
    fname = mstat["nameFirst"]
    lname = mstat["nameLast"]
    full_name = "#{fname} #{lname}"
    most_improved_batter[:full_name] = full_name
    most_improved_batter
  end

  # Get the slugging percentage of a team.
  def team_slugging_percentage(team, year)
    players = batting_stats.select { |player| player["teamID"] == team && player["yearID"] == year }

    # Find out if anyone needs their stats combined.
    all_stats = []
    players.each do |player|
      temp = batting_stats.select { |x| x["teamID"] != team && x["yearID"] == year && x["playerID"] == player["playerID"] }
      all_stats.concat(temp)
    end
    players = players.concat(all_stats)


    # Figure out who was traded and combine their stats
    combined_hash = {}
    players.each { |x| combined_hash[x["playerID"]] ||= 0; combined_hash[x["playerID"]] += 1 }
    stats_to_combine = players.select { |x| combined_hash[x["playerID"]] > 1 } # Find players with more than one entry.
    players.delete_if { |x| combined_hash[x["playerID"]] > 1 } # Deletes them from the player list.
    players = players.concat(combine_stats(stats_to_combine)) # Combines them and then concats the arrays.

    # Now get the slugging percentage for each player and return it.
    completed_list = []
    players.each do |player|
      completed_list << slugging_percentage(player)
    end
    completed_list
  end

  # Get the slugging percentage for a particular player.
  def slugging_percentage(player)
    if player["AB"].to_i > 0
      slug_percentage = ((player["H"].to_f - player["2B"].to_f - player["3B"].to_f - player["HR"].to_f) +
          (2 * player["2B"].to_f) + (3 * player["3B"].to_f) + (4 * player["HR"].to_f)) / player["AB"].to_f
    else
      slug_percentage = 0
    end

    mstat = master_stats.select { |x| x["playerID"] == player["playerID"] }[0]
    full_name = "#{mstat['nameFirst']} #{mstat['nameLast']}"

    return_hash = {
        playerID: player["playerID"],
        slugging_percentage: slug_percentage.round(3),
        full_name: full_name
    }
  end

  # Get a list of players with multiple stats for one year and combine them.
  def combine_stats(stats_to_combine)
    combined = [] # Will be the list of combined stats.
    combined_names = {} # List of names who have been combined.

    stats_to_combine.each do |player|
      if combined_names[player["playerID"]] == nil
        stats_for_player = stats_to_combine.select { |x| x["playerID"] == player["playerID"] }
        total_stats = stats_for_player.delete_at(0) # Get the first stat and remove it.

        stats_for_player.each do |stat|
          stat.each do |k, v| # Combine all numeric/non-year stats to the first.
            if is_numeric?(v) && k != "yearID"
              total_stats[k] = total_stats[k].to_i + stat[k].to_i
            end
          end
        end

        total_stats["league"] = "MLB" # Change league title to reflect the combination.
        total_stats["teamID"] = "TOT" # Change the team title to reflect the combination.
        combined << total_stats
        combined_names[player["playerID"]] = 1
      end
    end

    combined
  end

  def triple_crown_winner(year)
    # Only select those who had at bats.
    eligible = batting_stats.select { |player| player["AB"] }

    # Get players with over 500 at bats.
    eligible = eligible.select { |player| player["AB"] >= 500 && player["yearID"] == year }
    important_stats = []
    eligible.each do |player|
      important_stats << {
          playerID: player["playerID"],
          league: player["league"],
          home_runs: player["HR"],
          rbi: player["RBI"],
          batting_average: (player["H"].to_f / player["AB"].to_f).round(3)
      }
    end
    al_stats = important_stats.select { |x| x[:league] == "NL" }
    nl_stats = important_stats.select { |x| x[:league] == "AL" }

    al_winner = check_for_tcw(al_stats)
    nl_winner = check_for_tcw(nl_stats)
    result = al_winner + nl_winner
  end

  def check_for_tcw(league_stats)
    best_batter = league_stats.sort_by { |x| x[:batting_average] }.reverse![0]
    most_hrs = league_stats.sort_by { |x| x[:home_runs] }.reverse![0]
    best_rbi = league_stats.sort_by { |x| x[:rbi] }.reverse![0]

    if ((best_batter == most_hrs) && (most_hrs== best_rbi)) && (best_batter && most_hrs && best_rbi)
      mstat = master_stats.select { |x| x["playerID"] == best_batter[:playerID] }[0]
      full_name = "#{mstat["nameFirst"]} #{mstat["nameLast"]}"
      result =  "#{league_stats[0][:league]} has a winner, #{full_name}. "
    elsif (best_batter && most_hrs && best_rbi)
      result = "#{league_stats[0][:league]} does not have a winner. "
    else
      result = "No data for this year."
    end

    result
  end

  def is_numeric?(s)
    !!Integer(s) rescue false
  end
end