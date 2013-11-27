import re,csv, codecs, cStringIO, sys
from datetime import datetime

MINIMUM_TWEET_LENGTH = 5;
EARTHQUAKE_TWEET_TIME = datetime(2010,1,12,17,53)
TIME_OF_EARTHQUAKE = datetime

def get_tweet(line):
	split_line = line.strip().split("\t");
	if len(split_line) < 5:
		return [None]*4
	
	time = split_line[len(split_line)-3];
	if time.find("\\") != -1:
		return [None]*4

	date_time = datetime.strptime(time, "%Y-%m-%d %H:%M:%S")
	time_in_minutes = (date_time-EARTHQUAKE_TWEET_TIME).seconds/60.0
	
	content = "\t".join(split_line[1:(len(split_line)-3)])
	lowercase_content = content.lower()
	
	terms = re.split("\s+",lowercase_content)

	if len(terms) < MINIMUM_TWEET_LENGTH:
		return [None]*4

	tweet_json = {'date' : date_time,
				  'content' : content
				 }

	return [lowercase_content,time_in_minutes, date_time, tweet_json]

def get_regex_from_array(terms):
	return re.compile(r'\b[#]*('
				+'|'.join([x.replace(".","[.]") for x in terms])
				+r')[\W]*[\s\n]',re.UNICODE)

def get_regexes(terms):
	regexes = []
	ut = sorted([x for x in terms], key=lambda term: -len(term))
	len_last = len(ut[0])
	same_len_terms = [ut[0]]
	for z in ut:
		if len(z) != len_last:
			regexes.append(get_regex_from_array(same_len_terms))
			print str(len_last) + ": " + str(len(same_len_terms))
			same_len_terms=[]
		same_len_terms.append(z)
		len_last = len(z)

	regexes.append(get_regex_from_array(same_len_terms))
	print str(len_last) + ": " + str(len(same_len_terms))
	return regexes

def get_from_single_regex(r,content):
	return [re.sub(r'#*([#\w\s.\'-]+)\W*',r'\1',x) for x in r.findall(content)]

def get_from_regexes(regexes,content):
	ins = []
	for r in regexes:
		ins+=get_from_single_regex(r,content)
	return ins

class UTF8Recoder:
    """
    Iterator that reads an encoded stream and reencodes the input to UTF-8
    """
    def __init__(self, f, encoding):
        self.reader = codecs.getreader(encoding)(f)
 
    def __iter__(self):
        return self
 
    def next(self):
        return self.reader.next().encode("utf-8")
 
class UnicodeDictReader:
    """
    A CSV reader which will iterate over lines in the CSV file "f",
    which is encoded in the given encoding.
    """
 
    def __init__(self, f, encoding="utf-8", **kwds):
        f = UTF8Recoder(f, encoding)
        self.reader = csv.reader(f, **kwds)
        self.header = self.reader.next()
 
    def next(self):
        row = self.reader.next()
        vals = [unicode(s, "utf-8") for s in row]
        return dict((self.header[x], vals[x]) for x in range(len(self.header)))
 
    def __iter__(self):
        return self
 
def write_out_tweet(out_fil,i,term,type_of):
	out_fil.write(",".join([str(i),term,type_of]) + "\n")


#def generate_search_regex(term):
#	return re.compile(r'\b[#]*'+term+'[\W]*[\s\n]',re.UNICODE)

#def get_terms_w_regex_in_tweet(terms,lowercase_content):
#	return [term for term in terms if term[1].search(lowercase_content) is not None]
 