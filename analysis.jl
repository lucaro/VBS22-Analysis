using JSON, CSV, DataFrames, DataFramesMeta
using Fontconfig, Cairo, Gadfly
using ColorSchemes, ColorBrewer

run = JSON.parsefile("run.json")
scores = CSV.read("scores.csv", DataFrame)

team_id_to_name = Dict(map(x -> x["uid"]["string"] => x["name"], run["description"]["teams"]))
tasks = filter(x -> length(x["submissions"]) > 0, run["tasks"])

submissions = DataFrame[]

for t in tasks

    task_name = t["description"]["name"]
    task_group = t["description"]["taskGroup"]["name"]
    task_start = t["started"]

    for s in t["submissions"]
        push!(submissions, DataFrame(
            task = task_name,
            group = task_group,
            time = s["timestamp"] - task_start,
            team = team_id_to_name[s["teamId"]["string"]],
            member = s["memberId"]["string"],
            item = s["item"]["name"],
            start = s["start"],
            ending = s["end"],
            status = s["status"]
        ))
    end

end

submissions = vcat(submissions...)

submissions[!, :group] = replace.(submissions[:, :group], "VB2022-" => "")
submissions[!, :group] = replace.(submissions[:, :group], "VBS2022-" => "")

## total scores
score_sum = combine(groupby(scores, [:team, :group]), :score => sum)

score_sum[!, :group] = replace.(score_sum[:, :group], "VB2022-" => "")
score_sum[!, :group] = replace.(score_sum[:, :group], "VBS2022-" => "")

g = groupby(score_sum, :group)
foreach(x -> x[:, :score_sum] = 100 * x[:, :score_sum] ./ maximum(x[:, :score_sum]), g)
score_sum_normalized = combine(g, :)

oder = sort(combine(groupby(score_sum_normalized, :team), :score_sum => sum => :sum), :sum, rev = true)[:, :team]

score_sum_normalized = @rorderby score_sum_normalized findfirst(==(:team), oder)

p = plot(score_sum_normalized, y = :score_sum, x = :team, color = :group, Geom.bar(),
Scale.color_discrete_manual(palette("Set1", 3)...),
Guide.colorkey(title = "Task Type"),
Guide.XLabel("Team"),
Guide.YLabel("Normalized Score"),
Theme(bar_spacing = 1mm));

draw(PDF("score_sum.pdf", 12cm, 8cm), p)


## correct/wrong submissions per team

submissions_per_team = combine(groupby(submissions, [:team, :group, :status]), :status => length => :count)
sort!(submissions_per_team, [:group, :status])
submissions_per_team = @rorderby submissions_per_team findfirst(==(:team), oder)

kis = submissions_per_team[submissions_per_team[:, :group] .!== "AVS", :]
kis[!, :key] = map(x -> "$(x[:group]) - $(x[:status])", eachrow(kis))

#hack to populate missing combinations with 0
h = collect(Iterators.product(unique(kis[:, :team]), unique(kis[:, :key])))[:]
kis = vcat(kis, DataFrame(team = map(x -> x[1], h), group = "", status = "", count = 0, key = map(x -> x[2], h)))

p = plot(kis, y = :count, x = :team, color = :key, Geom.bar(position = :dodge),
Scale.color_discrete_manual(palette("Paired", 4)...),
Guide.colorkey(title = "Task Type - Status"),
Guide.XLabel("Team"),
Guide.YLabel("Number of Submissions              ", orientation=:vertical),
Theme(bar_spacing = 0mm, key_position = :bottom));

draw(PDF("kis_status_count.pdf", 12cm, 8cm), p)


avs = submissions_per_team[submissions_per_team[:, :group] .== "AVS", :]

#hack to populate missing combinations with 0
h = collect(Iterators.product(unique(avs[:, :team]), unique(avs[:, :status])))[:]
avs = vcat(avs, DataFrame(team = map(x -> x[1], h), group = "AVS", status = map(x -> x[2], h), count = 0))

p = plot(avs, y = :count, x = :team, color = :status, Geom.bar(position = :dodge),
Scale.color_discrete_manual(palette("Set2", 4)...),
Guide.colorkey(title = "Status"),
Guide.XLabel("Team"),
Guide.YLabel("Number of Submissions              ", orientation=:vertical),
Theme(bar_spacing = 0mm, key_position = :bottom));
draw(PDF("avs_status_count.pdf", 12cm, 8cm), p)


## time until first (correct) submission per team and type

time_to_first_submission = combine(groupby(submissions, [:team, :group, :task]), :time => minimum => :first)

time_to_first_submission[!, :first] ./= 60_000

time_to_first_submission = @rorderby time_to_first_submission findfirst(==(:team), oder)

p = plot(time_to_first_submission, y = :first, x = :team, color = :group, Geom.boxplot(),
Scale.color_discrete_manual(palette("Set1", 3)...),
Guide.colorkey(title = "Task Type"),
Guide.XLabel("Team"),
Guide.YLabel("Minutes"),
Theme(key_position = :bottom));

draw(PDF("time_to_first_submission.pdf", 12cm, 8cm), p)


time_to_first_correct_submission = combine(groupby(submissions[submissions[:, :status] .== "CORRECT", :], [:team, :group, :task]), :time => minimum => :first)

time_to_first_correct_submission[!, :first] ./= 60_000

time_to_first_correct_submission = @rorderby time_to_first_correct_submission findfirst(==(:team), oder)

p = plot(time_to_first_correct_submission, y = :first, x = :team, color = :group, Geom.boxplot(),
Scale.color_discrete_manual(palette("Set1", 3)...),
Guide.colorkey(title = "Task Type"),
Guide.XLabel("Team"),
Guide.YLabel("Minutes"),
Theme(key_position = :bottom));

draw(PDF("time_to_first_correct_submission.pdf", 12cm, 8cm), p)