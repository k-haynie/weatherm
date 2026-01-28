#!/bin/sh 

# depends on python, json, os, and feedgnuplot
#
#
output=`python scraper.py`

# echo -E "$output"

temps=`echo -E "$output" | grep -E "^\"" | awk '{print $2}' | sort -n`
min_temp=`echo -E "$temps" | head -n 1 | xargs -I{} bash -c "echo '{} - 5'| bc"`
max_temp=`echo -E "$temps" | tail -n 1 | xargs -I{} bash -c "echo '{} + 5'| bc"`

prec=`echo -E "$output" | grep -E "^\"" | awk '{print $3}' | sort -n`
min_prec=`echo -E "$prec" | head -n 1 | xargs -I{} bash -c "echo '{} - 0.05'| bc"`
max_prec=`echo -E "$prec" | tail -n 1 | xargs -I{} bash -c "echo '{} + 0.05'| bc"`

echo "$output" > output.txt
# echo -E "$min_temp" "$max_temp" "$min_prec" "$max_prec"

graph=`echo -e "$output"| feedgnuplot \
    --domain --y2 1 \
    --terminal "dumb 100,30" \
    --lines --points \
    --unset grid \
    --timefmt '"%Y-%m-%d-%H:%M:%S"' --set 'format x "%a\n%I %p"' \
    --title "24-hour Forecast" \
    --xlabel "Time" \
    --ylabel "Temp *F" \
    --y2label "Precip %" \
    --ymin 0 --ymax "$max_temp" \
    --y2min 0 --y2max "$max_prec" \
    --with 'lines lc rgb "red"' \
    --exit`

echo -E "$graph"
