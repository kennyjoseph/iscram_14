from util import get_tweet, EARTHQUAKE_TWEET_TIME,get_regexes,get_from_regexes
from collections import Counter
import codecs, re,sys

tweet_file = codecs.open("/Users/kjoseph/eclipse_workspace/InfoSocial/ordered_w_user.tab",'r','utf-8')
tweet_out_fil = "/Users/kjoseph/eclipse_workspace/"\
				"InfoSocial/old_train_out/old_tweet_likelihood_"

in_fil = codecs.open("keywords_for_old.txt",encoding='utf-8')
ush_terms = set([line.strip() for line in in_fil])
in_fil.close

regexes = get_regexes(ush_terms)

ush_counter = Counter()
found_tweets = 1
last_dt = ""
output_file = codecs.open(tweet_out_fil+"1.csv","w",encoding='utf-8')
n_outfil = 2
i = 0
for line in tweet_file:
	i+=1
	if found_tweets % 1000000 == 0 and len(ush_counter) >0:
		print last_dt
		for u,v in ush_counter.most_common():
			output_file.write(u + "," + str(v) + ","+ str(found_tweets) + "\n")
		output_file.close()
		ush_counter=Counter()
		output_file = codecs.open(tweet_out_fil+str(n_outfil)+".csv",
								  "w",encoding='utf-8')
		n_outfil+=1

	lowercase_content, time_in_minutes, date_time, tweet_json= get_tweet(line)
	if lowercase_content is None:
		continue

	last_dt = date_time
	if date_time > EARTHQUAKE_TWEET_TIME:
		break

	ins = get_from_regexes(regexes,lowercase_content)

	if len(ins) > 0:
		found_tweets +=1	
		for int_term in ins:
			ush_counter[int_term] +=1
found_tweets = str(found_tweets)


output_file.close()
print found_tweets
print i