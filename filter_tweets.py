from util import get_tweet, get_regexes,get_from_regexes, EARTHQUAKE_TWEET_TIME,get_regex_from_array,get_from_single_regex,write_out_tweet
import codecs
from collections import defaultdict, Counter
from datetime import timedelta, datetime
import json
from pymongo import MongoClient

tweet_file = codecs.open("~/data_for_iscram/private/twitter_start_eq.tab",'r','utf-8')

out_fil = codecs.open("~/data_for_iscram/public/term_to_tweet.csv","w","utf-8") 

client = MongoClient()
collection = client["iscram"].tweets

locations = []
entities = []
actions = []
for line in codecs.open("keywords.txt",encoding='utf-8'):
	spl = line.strip().split("|")
	type_of_term = spl[1]

	if type_of_term == 'entity':
		entities.append(spl[0])
	elif type_of_term == 'location':
		locations.append(spl[0])
	elif type_of_term == 'action':
		actions.append(spl[0])
	else:
		print 'TYPE WRONG!!'

loc_regex = get_regexes(locations)
entities_regex = get_regexes(entities)
actions_regex = get_regexes(actions)

to_ignore = []
for line in open("ignore.txt"):
	to_ignore.append(line.strip())
ignore_regex = get_regex_from_array(to_ignore)

vieweg_censor = []
for line in open("vieweg_censor.txt"):
	vieweg_censor.append(line.strip())
censor_regex = get_regex_from_array(vieweg_censor)

ush_counter = Counter()
found_tweets = 0
i = 0
last_dt = ""
time_to_break = EARTHQUAKE_TWEET_TIME+timedelta(7)
for line in tweet_file:
	i+=1
	if i % 100000 == 0:
		print last_dt
		print found_tweets

	lowercase_content, time_in_minutes, date_time, tweet_json = get_tweet(line)

	#Bad tweet
	if lowercase_content is None:
		continue

	#To make the regexes easier to write
	lowercase_content+="\n"

	#Only considering from the week after the disaster
	last_dt = date_time
	if date_time > time_to_break:
		break

	##Find all the terms using regexes
	ignore_int =  get_from_single_regex(ignore_regex,lowercase_content)
	ins_loc = get_from_regexes(loc_regex,lowercase_content)
	ins_ent = get_from_regexes(entities_regex,lowercase_content)
	ins_act = get_from_regexes(actions_regex,lowercase_content)

	##This is kind of ugly, I'm going to check each one twice, but its okay
	if len(ins_loc) or len(ins_ent) or len(ins_act) or len(ignore_int):
		#If we found it, insert the tweet into mongo
		found_tweets +=1
		tweet_json['_id'] = i
		collection.insert(tweet_json)

		##We'll use this for results...write out which terms were found to a simple csv
		for to_ig in ignore_int:
			write_out_tweet(out_fil,i,to_ig,"ignore")
		for z in ins_loc:
			write_out_tweet(out_fil,i,z,"location")
		for z in ins_ent:
			write_out_tweet(out_fil,i,z,"entity")
		for z in ins_act:
			write_out_tweet(out_fil,i,z,"action")
		##We'll check whether or not this tweet would have been censored by vieweg,
		#but only if we find it
		censor_int =  get_from_single_regex(censor_regex,lowercase_content)
		for z in censor_int:
			write_out_tweet(out_fil,i,z,"censor")

out_fil.close()
print found_tweets
print i