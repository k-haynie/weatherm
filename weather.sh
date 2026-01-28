#!/bin/sh 

# depends on python, json, os, and feedgnuplot


output=`python scraper.py`

limited_output=`echo -E "$output" | awk -F ',' '{ print $1 " " $2 " " $3 }'`

# output contains several columns:
# 1. DateTime of Forecast
# 2. Temperature
# 3. % probability of precipitation
# 4. short forecast 
# 5. detailed forecast 
# 6. wind speed (and mph)
# 7. wind direction

# echo -E "$output"

# -- find the temps --  
temps=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $2}' | sort -n`
min_temp=`echo -E "$temps" | head -n 1 | xargs -I{} bash -c "echo '{} - 5'| bc"`
max_temp=`echo -E "$temps" | tail -n 1 | xargs -I{} bash -c "echo '{} + 5'| bc"`

# -- find the precipitation likelihood --
prec=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $3}' | sort -n`
min_prec=`echo -E "$prec" | head -n 1 | xargs -I{} bash -c "echo '{} - 0.05'| bc"`
max_prec=`echo -E "$prec" | tail -n 1 | xargs -I{} bash -c "echo '{} + 0.05'| bc"`

shortForecast=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $4}' | sort -n`
wind=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $5 " " $6}' | sort -n`

table=`echo -E "$output" \
    | grep -E "^\"" \
    | awk -F ',' '
        BEGIN {
            sunny = "\033[93m ◯ "
            yellow = "\033[33m"
            cloudy = "\033[93m ≋ "
            rain = "\033[34m ∴ "
            snow = "\033[37m ✶ "
            clear = "\033[27m ⍜ "
            reset = "\033[0m"
            green = "\033[32m"
        }
        { print green }
        { system("date -d" $1 " +%a_%I_%p") }
        { print reset "," yellow $2 reset "°F," "\033[36m" $3 reset " %," }
        { 
            if (index($4, "Sunny") > 0) { c = sunny }
            else if (index($4, "Cloudy") > 0) { c = cloudy }
            else if (index($4, "Clear") > 0) { c = clear }
            else if (index($4, "Rain") > 0) { c = rain }
            else if (index($4, "Snow") > 0 || index($4, "Ice") > 0) { c = snow }
            else { c = reset }
            printf "%s%s%s", c, $4, reset
        }
        { print "," $5 " " $6 }' \
    | tr -s '\n' '-' \
    | sed -E 's/-([A-Z])/\n\1/g;s/0.0 /0 /g;s/-,/,/g;s/_/ /g;s/([A-Z])-/\1/g;s/-//g' \
    | column -s ',' -o ' | ' -t \
    --table-columns " Time of Day,Temp,Rain,Desc,Wind" \
    --table-right 1,2,3`

# echo "$output" > output.txt
# echo -E "$min_temp" "$max_temp" "$min_prec" "$max_prec"
descs=`echo -E "$output" | grep -E "^\"" | awk '{print $4}'`

# -- find the current terminal size --
rows=`tput lines | xargs -I{} bash -c "echo {} / 1.5 | bc"`
cols=`tput cols | xargs -I{} bash -c "echo {} - 2 | bc"`

# -- output the graph
graph=`echo -e "$limited_output"| feedgnuplot \
    --domain \
    --y2 1 \
    --terminal "dumb $cols,$rows ansi enhanced" \
    --lines --points \
    --unset grid \
    --timefmt '"%Y-%m-%dT%H:%M:%S"'\
    --set 'format x "%a\n%I %p"' \
    --title "24-hour Forecast" \
    --xlabel "\nTime of Day" \
    --ylabel "Temp" \
    --y2label " Rain\n Chance" \
    --legend "Degrees (°F)" 1\
    --legend "Precip (%)" 2\
    --ymin 0 --ymax "$max_temp" \
    --y2min 0 --y2max "$max_prec" \
    --cmds 'set style line 3 lc rgb "yellow" lw 2'\
    --exit`

echo -e "\n$table\n$graph"
