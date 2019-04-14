require 'byebug'
require 'json'

def parse_filter
    file_path = File.join(File.dirname(__FILE__), 'res.txt')
    file = File.open(file_path, 'r')
    raw = file.read
    #file.close

    obs = raw.split("# Observations")[1].split("--->")[0].split(">$").size - 1
    goals = raw.split("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$").last.split("$>").size - 1
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

    correctness = raw.split("<?>").last.split("?").last.include?("true")
    file.close
    time = raw.split("<?>").last.split(correctness.to_s).last.split("\n\n").last.split("real").last.split("\n").first.split("\t").last
    minutes = time.split("m").first.to_i
    seconds = time.split("m").last.split("s").first.split(",").first.to_i
    miliseconds = time.split("m").last.split("s").first.split(",").last.to_i
    seconds = seconds + (miliseconds * 0.001)
    seconds = ((seconds * 1000).floor)/1000.0

    result = {}
    result[:correct] = correctness ? 1 : 0
    result[:minutes] = minutes
    result[:seconds] = seconds

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
        thresholds.each do |t|
            seconds[p][t] = 0
            accuracy[p][t] = 0
        end
    end
    
    Dir.foreach(dataset_path) do |item|
        if item == "." || item == ".." || item == "README.md" || item == ".zenodo.json" || item == ".git" || item.include?("noisy")
            next
        end
        symbol_item = item.gsub("-", "_").to_sym
        result[symbol_item] = {}
        problem_counter = 0
        Dir.foreach("#{dataset_path}/#{item}") do |tar|
            if tar == "." || tar == ".." || tar == "README.md" || tar == ".gitignore" || tar.include?("FILTERED")
                next
            end

            tar_path = "#{dataset_path}/#{item}/#{tar}"

            problem_counter = problem_counter + 1

            tmp = tar.split("_")
            if tmp.last.include?("full")
                percentual_observed = 100
            else
                tmp.pop
                percentual_observed = tmp.last.to_i
            end            
            
            thresholds.each do |tr|
                #FILTER
                run_type = "-filter"
                cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                system(cmd)
                single_result_f = parse_filter
                goals += single_result_f[:goals]
                landmarks += single_result_f[:landmarks]
                observations[percentual_observed.to_s] += single_result_f[:observations]
    
                #GOAL COMPLETION
                run_type = "-goalcompletion"
                cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                system(cmd)
                single_result_gc = get_heuristic_correctness_and_time
                seconds[percentual_observed.to_s][tr] += single_result_gc[:seconds]
                accuracy[percentual_observed.to_s][tr] += single_result_gc[:correct]
    
                #LANDMARK UNIQUENESS
                run_type = "-uniqueness"
                cmd = "bash #{run_path} #{java_path} #{jar_path} #{run_type} #{tar_path} #{tr} #{res_path}"
                system(cmd)
                single_result_u = get_heuristic_correctness_and_time
                seconds[percentual_observed.to_s][tr] += single_result_u[:seconds]
                accuracy[percentual_observed.to_s][tr] += single_result_u[:correct]
            end 
        end
        
        result[symbol_item][:problems] = problem_counter
        result[symbol_item][:goals_avg] = goals.to_f/problem_counter
        result[symbol_item][:landmarks_avg] = landmarks.to_f/problem_counter
        percentages.each do |p|
            result[symbol_item][:observations][p] = observations[p].to_f/problem_counter
            thresholds.each do |t|
                result[symbol_item][:observations][p][:uniqueness][:time][t] = (((seconds[p][t].to_f/problem_counter)*1000).floor)/1000.0
                result[symbol_item][:observations][p][:uniqueness][:accuracy][t] = (accuracy[p][t].to_f/problem_counter) * 100.0
            end
        end
    end
end

def analyse
    results = all_results
    output_path = "/home/kingusmao/grupo/results.json"
    File.write(results, output_path)
end

analyse

