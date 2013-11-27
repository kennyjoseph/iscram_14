ISCRAM 2014
=================
This gives the code for the following article:

Joseph, K., Landwehr, P.M., Carley, K.M. and Pfeffer, J. Exploring the dangers of pre-defined keyword sampling on Twitter.  To (hopefully) appear in ISCRAM '14

As always, apologies for any unclear parts of the code, please email with questions.  This is hopefully the last article that I'll write where I'm going back
to work that was done when I was still fairly unfamiliar with R and python, so hopefully furture repos will be nicer :)


Input data
----------------

Unfortunately, I can't share either the raw tweets or the Ushahidi data (or the scored tweets... basically anything referred to as being in ~/data_for_iscram/private/).  The Twitter restrictions are well-known, but if you want the tweet IDs I may be able to get those (depending on restrictions imposed by the source of the data ... email me).  However, the Ushahidi one may be a little surprising.  
The Ushahidi data was public at some point last year (that's how I got it), but I can't find it anywhere on the web anymore.  Given the
claims in (Munro, 2013) that Ushahidi data revealed too much personalized information, I'm going to wait on giving out that data until a) someone 
asks for it and b) I find someone who worked with the data to give me a reason why I can't find it online anymore.

However, I do share the keywords that were pulled *out* of the Ushahidi reports, because I don't think there is enough context in these to really extract person information.The raw keywords drawn are in *ush_keywords.csv*.  The manually cleaned terms are in *clean.csv*.

Also note that in gen_results.R, there are several references to ~/data_for_iscram/public/. Anything in this folder is publically available, but its all pretty big so I couldn't put it on Github and didn't want to fill up that much space on my public Dropbox ... I'm a poor grad student, don't blame me.  Anywho, email if you want that data.

Code
---------------
The process is a little convoluted because I jump back and forth between python and R and throw a little mongo in there for good measure. However, everything runs from gen_results.R, within which there are comments that talk about the other files that are in this folder

Supplementary files
------------------

-email_to_annotators.txt is the text of the email I sent to the other two annotators describing how to do the annotation

-tweet_ids_sampled.rdat are the set of ids from our own mongo DB that were sampled for the present work

-util.py has a bunch of utility functions that were used in train_on_old_tweets.py and filter_tweets.py.  These are basically methods to parse and search tweets for terms and a Unicode CSV reader drawn from code on StackOverflow

-func.R has a few utility R functions

-dedup.R was a file used to set up clean.csv, which we then vetted by hand.

Misc.
-------------
The only computationally interesting piece that isn't really discussed in the paper is the level of speedup I saw in running a few big regexes to search for terms vs. using a single regex for each term.  Even when all of them were pre-compiled, the speed-up had to be 20-50x, which surprised me a little.
