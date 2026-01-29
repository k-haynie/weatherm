import json, os, sys

# variables
latlng = ",".join(i[:7] for i in sys.argv[1].split(",") if i != ",")
summary=(sys.argv[3] == "yes")
hour_cutoff = min(int(sys.argv[2]), 13 if summary else 155)

# use the lat_lng to find the govt api url to query
info = json.loads(os.popen(f"curl -s https://api.weather.gov/points/{sys.argv[1][:-1]}").read())

# in the style of:
# https://api.weather.gov/points/37.4137,-79.1424

# target url style:
# url = "https://api.weather.gov/gridpoints/RNK/102,79/forecast/hourly"

location = info["properties"]["relativeLocation"]["properties"]
loc_str = f'{location["city"]}, {location["state"]}'
output = f"{loc_str}\n"

if not summary:
    target_url = info["properties"]["forecastHourly"]
    response = json.loads(os.popen(f"curl -s {target_url}").read())

    for i in response["properties"]["periods"][:hour_cutoff]:
        output += ",".join([
            '"' + i["startTime"][:19]+ '"',
            str(i["temperature"]),
            str(i["probabilityOfPrecipitation"]["value"]/100),
            i["shortForecast"],
            i["windSpeed"],
            i["windDirection"],
            ""
        ]) + "\n"
else:
    target_url = info["properties"]["forecast"]
    response = json.loads(os.popen(f"curl -s {target_url}").read())

    for i in response["properties"]["periods"][:hour_cutoff]:
        output += ",".join([
            '"' + i["startTime"][:19]+ '"',
            str(i["temperature"]),
            str(i["probabilityOfPrecipitation"]["value"]/100),
            i["shortForecast"],
            i["windSpeed"],
            i["windDirection"],
            i["detailedForecast"].replace(",", " ")
        ]) + "\n"

print(output)
