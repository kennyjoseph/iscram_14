from util import get_regex_from_array,get_from_single_regex
from pymongo import MongoClient

out_fil = open("censored_tweets.txt","w")
client = MongoClient()
collection = client["iscram"].tweets

vieweg_censor = []
for line in open("vieweg_censor.txt"):
	vieweg_censor.append(line.strip())
censor_regex = get_regex_from_array(vieweg_censor)

found_tweets = 0
i = 0
for tweet in collection.find():
	i+=1
	if i % 100000 == 0:
		print i
	lowercase_content = tweet["content"].lower()
	censor_int =  get_from_single_regex(censor_regex,lowercase_content)
	if len(censor_int) > 0 or 'pray' in lowercase_content or 'donat' in lowercase_content:
		found_tweets +=1
		out_fil.write(str(tweet["_id"]) + "\n")

out_fil.close()
print found_tweets