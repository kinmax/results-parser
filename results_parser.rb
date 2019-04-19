require 'byebug'
require 'json'

def parse_filter
    file_path = File.join(File.dirname(__FILE__), 'res.txt')
    file = File.open(file_path, 'r')
    raw = file.read
    file.close

    

    obs = raw.split("# Observations")[1].split("--->")[0].split(">$").size - 1
    goals = raw.scan(/--->/).count
    landmarks = raw.split("--->").drop(1)    
    landmarks_last = landmarks.last.split("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$").first
    landmarks.pop
    landmarks.push(landmarks_last)
    land_count = 0
    landmarks.each do |goal|
        land_count += goal.split("Amount of Fact Landmarks: ")[1].split(".").first.to_i
    end
    land_count = land_count.to_f/(raw.scan(/--->/).count)

    results = {}
    results[:observations] = obs
    results[:goals] = goals
    results[:landmarks] = land_count

    results
end

def get_heuristic_correctness_and_time
    file_path = File.join(File.dirname(__FILE__), 'res.txt')
    file = File.open(file_path, 'r')
    raw = file.read
    file.close

    correctness = raw.split("<?>").last.split("?").last.include?("true")
    time = raw.split("<?>").last.split(correctness.to_s).last.split("\n\n").last.split("real").last.split("\n").first.split("\t").last
    minutes = time.split("m").first.to_i
    seconds = time.split("m").last.split("s").first.split(",").first.to_i
    miliseconds = time.split("m").last.split("s").first.split(",").last.to_i
    seconds = seconds + (miliseconds * 0.001)
    seconds = ((seconds * 1000).floor)/1000.0
    rec_goals = raw.split("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$").last.scan("$>").count - 1

    result = {}
    result[:correct] = correctness ? 1 : 0
    result[:minutes] = minutes
    result[:seconds] = seconds
    result[:recognized_goals] = rec_goals

    result
end

def all_results
    dataset_path = "/home/kingusmao/grupo/goal-plan-recognition-dataset"
    res_path = "/home/kingusmao/grupo/results-parser/res.txt"
    jar_path = "/home/kingusmao/grupo/Landmark-Based-GoalRecognition/goalrecognizer1.1.jar"
    java_path = "/usr/bin/java"
    run_path = "./run.sh"
    thresholds = %w(0 10 20 30).freeze
    percentages = %w(10 30 50 70 100).freeze
    result = {}
    goals = 0
    landmarks = 0
    observations = {}
    seconds = {}   
    accuracy = {}
    percentages.each do |p|
        observations[p] = 0
        seconds[p] = {}
        accuracy[p] = {}
        seconds[p][:goalcompletion] = {}
        accuracy[p][:goalcompletion] = {}
        seconds[p][:uniqueness] = {}
        accuracy[p][:uniqueness] = {}
        thresholds.each do |t|
            seconds[p][:goalcompletion][t] = 0
            accuracy[p][:goalcompletion][t] = 0
            seconds[p][:uniqueness][t] = 0
            accuracy[p][:uniqueness][t] = 0
        end
    end
    
    Dir.foreach(dataset_path) do |item|
        if item == "." || item == ".." || item == "README.md" || item == ".zenodo.json" || item == ".git" || item.include?("noisy")
            next
        end
        puts item
        symbol_item = item.gsub("-", "_").to_sym
        result[symbol_item] = {}
        problem_counter = 0
        Dir.foreach("#{dataset_path}/#{item}") do |tar|
            if tar == "." || tar == ".." || tar == "README.md" || tar == ".gitignore" || tar.include?("FILTERED")
                next
            end
            puts tar

            begin
                tar_path = "#{dataset_path}/#{item}/#{tar}"

                problem_counter = problem_counter + 1

                tmp = tar.split("_")
                if tar.include?("full")
                    percentual_observed = 100
                else
                    tmp.pop
                    percentual_observed = tmp.last.to_i
                end 
                
                
                
                thresholds.each do |tr|
                    #FILTER
                    if tr == "0" # so it only runs once per file
                        run_type = "-filter"
                        cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                        system(cmd)
                        single_result_f = parse_filter
                        goals += single_result_f[:goals]
                        landmarks += single_result_f[:landmarks]
                        observations[percentual_observed.to_s] += single_result_f[:observations]
                    end
        
                    #GOAL COMPLETION
                    run_type = "-goalcompletion"
                    cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                    system(cmd)
                    single_result_gc = get_heuristic_correctness_and_time
                    seconds[percentual_observed.to_s][:goalcompletion][tr] += single_result_gc[:seconds]
                    accuracy[percentual_observed.to_s][:goalcompletion][tr] += single_result_gc[:correct]
        
                    #LANDMARK UNIQUENESS
                    run_type = "-uniqueness"
                    cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                    system(cmd)
                    single_result_u = get_heuristic_correctness_and_time
                    seconds[percentual_observed.to_s][:uniqueness][tr] += single_result_u[:seconds]
                    accuracy[percentual_observed.to_s][:uniqueness][tr] += single_result_u[:correct]
                end
            rescue StandardError => e
                puts e.backtrace
            end
        end

        begin
            

            result[symbol_item][:problems] = problem_counter
            result[symbol_item][:goals_avg] = goals.to_f/problem_counter
            result[symbol_item][:landmarks_avg] = landmarks.to_f/problem_counter
            result[symbol_item][:observations] = {}

            percentages.each do |p|
                result[symbol_item][:observations][p] = {}
                result[symbol_item][:observations][p][:uniqueness] = {}
                result[symbol_item][:observations][p][:goalcompletion] = {}
                thresholds.each do |t|
                    result[symbol_item][:observations][p][:uniqueness][:time] = {}
                    result[symbol_item][:observations][p][:uniqueness][:accuracy] = {}
                    result[symbol_item][:observations][p][:goalcompletion][:time] = {}
                    result[symbol_item][:observations][p][:goalcompletion][:accuracy] = {}
                end
            end

            percentages.each do |p|
                result[symbol_item][:observations][p][:observations_avg] = observations[p].to_f/problem_counter
                thresholds.each do |t|
                    result[symbol_item][:observations][p][:uniqueness][:time][t] = ((((seconds[p][:uniqueness][t].to_f/problem_counter)*1000).floor)/1000.0) * 5
                    result[symbol_item][:observations][p][:uniqueness][:accuracy][t] = ((accuracy[p][:uniqueness][t].to_f/problem_counter) * 100.0) * 5
                    result[symbol_item][:observations][p][:goalcompletion][:time][t] = ((((seconds[p][:goalcompletion][t].to_f/problem_counter)*1000).floor)/1000.0) * 5
                    result[symbol_item][:observations][p][:goalcompletion][:accuracy][t] = ((accuracy[p][:goalcompletion][t].to_f/problem_counter) * 100.0) * 5
                end
            end
        rescue StandardError => e
            puts e.backtrace
        end       
    end

    result
end

def analyse
    results = all_results
    output_path = "/home/kingusmao/grupo/results-parser/results.json"
    File.write(output_path, JSON.pretty_generate(results))
end

analyse

