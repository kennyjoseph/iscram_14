import argparse, os, codecs, random, csv, re, nltk, re, pprint, collections, re, sys, unicodecsv
from datetime import datetime, timedelta
from collections import Counter
import cPickle as pickle
from util import UnicodeDictReader, EARTHQUAKE_TWEET_TIME

stopwords = nltk.corpus.stopwords.words('english')
regex = re.compile("[\W]*([A-Za-z&-\'0-9]+,*)[\W)]*")

###########################################################################
##########PARSE TITLE#############
###########################################################################
def get_proper_noun(d):
	word = d[0]
	i = 0
	if d[0][-1] == ',':
		word = word.replace(',','')
		return word, 1

	for i in range(1,len(d)):
		if d[i][0].isupper()  or d[i][0].isdigit():
			word += " " + d[i]
			if d[i][-1] == ',':
				word = word.replace(',','')
				break
		else:
			break
	return word, i+1


def parse_title(title):
	title = regex.findall(title)
	#print 'init title::: ' + str(title)
	locations = []
	##First, pull out locations
	title_terms = ['at','@','in','on','by']
	for t in title_terms:
		if t not in title:
			continue
		index = title.index(t)
		#print 'found: ' + t + ' at: ' + str(index)
		if index == (len(title)-1):
			continue
		location,n_words = get_proper_noun(title[index+1:])
		locations.append(location)
		#print 'got out location: ' + location + ' :::: returned n_words: ' + str(n_words)
		title[index] = "___"
		title = title[0:index+1] + title[index+n_words+1:]
		#print 'new title: ' + str(title)
	
	entities = []
	#now pull out named entities
	i = 0
	while i != len(title):
		if title[i][0].isupper():
			entity,n_words = get_proper_noun(title[i:])
			if n_words > 1:
				#print 'got out entity: ' + entity + ' :::: returned n_words: ' + str(n_words)
				#entities.append(entity)
				waeoi=0
			i += n_words
		else:
			i+=1
	return locations, entities
	

###########################################################################
##########PARSE DESCRIPTION#############
###########################################################################

def extract_entity_names(t):
    entities = []
    actions = []
    if hasattr(t, 'node') and t.node:
        if t.node == "NE":
        	entities.append(' '.join([child[0] for child in t]).lower())
        else:
            for child in t:
                e1, a1 = extract_entity_names(child)
                entities.extend(e1)
                actions.extend(a1)
    else:
    	if t[1] in ['VBP','VBN','VBG','VBD','VB'] \
    		and t[0].lower() not in stopwords \
    		and len(t[0]) >= 3 \
    		and ".com" not in t[0] \
    		and "www." not in t[0] \
    		and "http" not in t[0] \
    		and "xd" not in t[0] \
    		and unicode.isalnum(t[0][0]):
				actions.append(t[0])    
  
    return [entities, actions]

def parse_description(description):

	sentences = nltk.tokenize.sent_tokenize(description)
	#print '*****************sentences*********'
	new_sentences = []
	for sentence in sentences:
		new_sentences += sentence.split("\n")
	sentences = new_sentences
	tokenized_sentences = [nltk.word_tokenize(sentence) for sentence in sentences]
	tagged_sentences = [nltk.pos_tag(sentence) for sentence in tokenized_sentences]
	chunked_sentences = nltk.batch_ne_chunk(tagged_sentences, binary=True)
	
	actions = []
	entities = []
	for tree in chunked_sentences:
		e, a = extract_entity_names(tree)
		entities += e
		actions += a
	return entities, actions

###########################################################################
##########GET THE DATA#############
###########################################################################
def write_field(out_fil, rep_num,time,type_of_obj,data):
	rep_num = str(rep_num)
	time = str(time)
	counter_data = Counter(data)
	for k,v in counter_data.iteritems():
		out_fil.write(",".join([rep_num,time,k.replace(",","").lower(),str(v),type_of_obj])+"\n")	

#INCIDENT TITLE,LOCATION,LATITUDE,LONGITUDE,VERIFIED,minutes_since_inception,CATEGORY,DESCRIPTION,,,,,,
def get_ushahidi_data(filename, out_fil):
	#ushahidi_reports = []
	i=0
	fil = codecs.open(filename,'r')
	ush_reader = UnicodeDictReader(fil, delimiter=',', quotechar='\"')
	ONE_WEEK_AFTER = EARTHQUAKE_TWEET_TIME+timedelta(7)
	for row in ush_reader:
		time = datetime.strptime(row["INCIDENT DATE"], "%d/%m/%Y %H:%M")
		if time > ONE_WEEK_AFTER:
			continue
		i+=1
		print '*****************ROW ' + str(i) + '****************\n'
		desc_ent, desc_act = parse_description(row["DESCRIPTION"])
		title_loc, title_ent = parse_title(row["INCIDENT TITLE"])
		locations = [w.strip() for w in row["LOCATION"].split(",")]
		write_field(out_fil, i,time,"location",locations+title_loc)
		write_field(out_fil, i,time,"entity",title_ent+desc_ent)
		write_field(out_fil, i,time,"action",desc_act)


###########################################################################
##########MAIN#############
###########################################################################

parser = argparse.ArgumentParser(description='run iscram_2014 sampling')
#####Options
parser.add_argument('-ushahidi_file', type=str, default="~/data_for_iscram/private/Haiti_Ushahidi.csv",nargs="?", help = "If you want to sample from the ushahidi_file, provide it")

args = parser.parse_args()
out_fil = codecs.open("ush_keywords.csv","w","utf-8")
out_fil.write("Report,Time,Keyword,Count,Type\n")
get_ushahidi_data(args.ushahidi_file,out_fil)
#pickle.dump(search_terms_data,open('ushahidi.pkl',"wb"))
out_fil.close()

