import json, os

url = "https://api.weather.gov/gridpoints/RNK/102,79/forecast/hourly"

response = json.loads(os.popen(f"curl -s {url}").read())

# print(response)

twelve_hour = response["properties"]["periods"][:12]

times = []
temps = []
desc = []

output = ""

for i in response["properties"]["periods"][:24]:
    times.append(i["startTime"].replace("T", "-")[:19])
    temps.append(i["temperature"])
    desc.append(i["shortForecast"])

    output += ('"' + times[-1] + '"' + " ")
    output += (str(temps[-1]) + " ")
    output += str(i["probabilityOfPrecipitation"]["value"]/100) + "\n"

print(output)

