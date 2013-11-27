require(reshape)
require(plyr)
require(data.table)
require(ggplot2)
require(doBy)
require(e1071)
require(bootstrap)
require(RMongo)

setwd("github")

###Set words to ignore
WORDS_TO_IGNORE <- c("earthquake", "port-au-prince", "ouest", "tsunami", "haiti","tremblement",
                     "quake", "shaking","haitiearthquake")
write.table(WORDS_TO_IGNORE,"ignore.txt",quote=F,row.names=F,col.names=F)

VIEWEG_CENSOR_TERMS <- c("rt","ass","bless","bullshit",
                         "charity","god","hell",
                         "hope for haiti","jerk","money",
                         "telethon","wtf")
write.table(VIEWEG_CENSOR_TERMS,"vieweg_censor.txt",quote=F,row.names=F,col.names=F)

##Run get_keywords.py to get the keywords from the Ushahidi data
ush_dat <- read.csv("ush_keywords.csv",stringsAsFactors=F,encoding="utf-8")

##How many did we get from the NER?
ddply(ush_dat, .(Type), summarise, len=length(Keyword),uni=length(unique(Keyword)))

###We outputted the data for cleaning...lets read in and see what we've got now
##and we've also made sure that there were no duplicate types  (dedup.R)
##t <- ddply(cleaned_terms,.(Keyword),summarise, r = length(Type));t[t$r >1,]
cleaned_terms <- read.csv("clean.csv",stringsAsFactors=F)
##These are the terms we got rid of with manual cleaning
removed <- setdiff(unique(ush_dat$Keyword),cleaned_terms$Keyword)
##We have a cleaned set...lets first remove those that we got rid of
ush_dat <- ush_dat[!ush_dat$Keyword %in% removed,]
##So fix all types to be the type we cleaned
ush_dat <- ddply(ush_dat,.(Keyword), function(f){
  if(length(unique(f$Type)) != 1){ 
    f$Type <- cleaned_terms[cleaned_terms$Keyword == f$Keyword[1],"Type"]
  }
  f
})

##Combine to find num reports
agg_ush <- ddply(ush_dat, .(Keyword,Type),summarise, n_rep=length(Report),count=sum(Count))

##Run python script train_on_old_tweets.py to generate data for the second part of the metric
write.table(agg_ush[,"Keyword"],"keywords_for_old.txt",quote=F,row.names=F,col.names=F)
##Read in the resulting files
old_tweet_fils <-Sys.glob("~/data_for_iscram/public/old_train_out/old_tweet_likelihood_*.csv")
len_boot <- length(old_tweet_fils)
old_tweet_res <- rbindlist(lapply(
                        old_tweet_fils,
                        fread,
                        header=F,
                        stringsAsFactors=F))
otr <- old_tweet_res[,list(mean_count=sum(V2)/len_boot,v=V3[1]),by=V1]
names(otr) <- c("Keyword","NumInOld","NumOld")
scored_keywords <- merge(agg_ush,otr,by=c("Keyword"),all.x=T)

oldv <- log(scored_keywords$NumInOld)
oldv[is.na(oldv)] <- min(oldv,na.rm=T) - 1
oldv <- scale(oldv)
ushv <- scale(log(scored_keywords$n_rep))

scored_keywords$OldRank <- 1/(oldv + abs(min(oldv))+1)
scored_keywords$UshRank <- ushv + abs(min(ushv)) + 1
scored_keywords$score <- scored_keywords$OldRank * scored_keywords$UshRank
scored_keywords$NumOld <- NULL
scored_keywords <- orderBy(~-score,scored_keywords)


####Figure 1
plot_dat <- ddply(scored_keywords,.(Type),function(f){orderBy(~-score,f)[c(1:5,(nrow(f)-4):nrow(f)),]})
pd2 <- scored_keywords[scored_keywords$Keyword %in% WORDS_TO_IGNORE,]
pd2$Type <- "Intuitive"
plot_dat <- rbind(plot_dat,pd2)
plot_dat$Keyword <- factor(plot_dat$Keyword, levels=plot_dat[order(plot_dat$score),]$Keyword)
plot_dat$Type <- factor(plot_dat$Type, levels=c("action","entity","location","Intuitive"))
##Figure 1
p1 <- ggplot(plot_dat, aes(Keyword,score)) + geom_bar(stat="identity") + facet_wrap(~Type,scales="free_x",nrow = 1) + theme(axis.text.x=element_text(angle=45,hjust=1)) 
p1 <- p1 + ylab("Benefit Score")
ggsave("fig1.pdf", p1, height=3, width=12)

write.table(scored_keywords[,c("Keyword","Type")],"keywords.txt",quote=F,row.names=F,col.names=F,sep="|")

#########################################
#################Analysis#################
#############################################
word_types <-  c("location","action","entity")
type_combos <- apply(bincombinations(3),1,function(f){word_types[f==1]})[2:8]
##Read in the results from filter_tweets.py
results_of_search <- fread("~/data_for_iscram/public/term_to_tweet.csv",header=F)
setnames(results_of_search,"V1","tweetid")
setnames(results_of_search,"V2","keyword")
setnames(results_of_search,"V3","type")
##Make sure we're still good and haven't re-cleaned since running
results_of_search <- results_of_search[results_of_search$keyword %in% scored_keywords$Keyword,]
##Give each term a score
results_of_search[,score:=scored_keywords[scored_keywords$Keyword == keyword,"score"][1],by=keyword]

ignored_tweets <- unique(results_of_search[results_of_search$type=="ignore",]$tweetid)
df <- data.frame(Type=rep(sapply(type_combos,paste,collapse=","),each=3), 
                 Words= c("All","GE1","G1"),
                 count=0,
                 union=0,
                 only_ignore=0,
                 only_unint=0,
                 intersect=0,
                 size_ignored=length(ignored_tweets))

for(i in 1:length(type_combos)){
  ##get the types of keywords to use
  combos <- type_combos[[i]]
  tmp <- results_of_search[results_of_search$type %in% combos,]
  ##Remove intuitive keywords from unintuitive list
  tmp <- tmp[!(tmp$keyword %in% WORDS_TO_IGNORE & tmp$type !="ignore"),]
  ##calculate
  df[1+(i-1)*3,3:7] <- get_stats_q1(tmp,to_ignore)
  df[2+(i-1)*3,3:7] <- get_stats_q1(tmp[tmp$score >=1,],to_ignore)
  df[3+(i-1)*3,3:7] <- get_stats_q1(tmp[tmp$score > 1],to_ignore)  
}

##Compare sizes
theme_set(theme_bw(18))
df$Words <- factor(df$Words, levels=c("All","GE1","G1"))
p2<- ggplot(df,aes(Words,count,color=Type,group=Type)) + geom_point() + geom_line() + geom_hline(y=length(ignored_tweets)) + ylab("Number of Tweets") + xlab("Keywords Included")
ggsave("fig2.pdf", p2, height=4, width=6)
##Compute the jaccard coefficient and then plot it
df$jaccard <- df$intersect/df$union
p3 <- ggplot(df,aes(Words,jaccard,color=Type,group=Type)) + geom_point() + geom_line()  + ylab("Jaccard coefficient") + xlab("Keywords Included")
ggsave("fig3.pdf", p3, height=4, width=6)

##What terms were more in the intersect than others?
theme_set(theme_bw(30))
all_unint <- unique(results_of_search[results_of_search$type %in% word_types,"tweetid",with=F]$tweetid)
tweet_intersect <- intersect(all_unint,ignored_tweets)
results_of_search[,intersection_tweet:=0,]
results_of_search[results_of_search$tweetid %in% tweet_intersect,]$intersection_tweet <- 1
r <- results_of_search[results_of_search$type %in% word_types & !(results_of_search$keyword %in% WORDS_TO_IGNORE),
         list(num_intersect=sum(intersection_tweet),
              num_t=length(tweetid),
              type=type[1],
              score=score[1]),by=keyword]
r$percentage <- r$num_intersect/r$num_t
r$weighted_p <- r$percentage*log(r$num_intersect+1)
p4 <- ggplot(r, aes(weighted_p,score,color=type)) + geom_point(alpha=.4) + scale_y_continuous(trans='log10',limit=c(.1,10),breaks=c(.1,1,10),labels=c(".1","1","10")) + scale_x_continuous(trans='log10',limit=c(.0001,10),breaks=c(.0001,1,10),labels=c(".0001","1","10")) + stat_smooth(method="loess",alpha=.4,size=1.3) + ylab("Benefit Score") + xlab("Weighted Overlap Score")
ggsave("fig4.pdf",p4, height=8,width=12) 

############################################
##########compare to Vieweg’s #s#################
##############################################
censored_ids <- read.csv("censored_tweets.txt",header=F)
##Lets only consider tweets w/ unintuitive terms and **Step 1: ignore terms with score < 1
st <-  results_of_search[(!(results_of_search$keyword %in% WORDS_TO_IGNORE) & 
                            results_of_search$intersection_tweet==0 & 
                            results_of_search$score >=1 ),]
#Remove duplicate finds for scoring then score (e.g. remove "food","food")
setkey(st,"tweetid","keyword")
st <- st[!duplicated(st[,c("tweetid","keyword"),with=F]),]

scored_tweets <-st[,list(score=sum(score), has_loc_ent=("location" %in% type | "entity" %in% type)),by=tweetid]
##size of dataset
nrow(scored_tweets)
##Pull out tweets she censored
scored_tweets <- scored_tweets[!scored_tweets$tweetid %in% censored_ids$V1,]
##yuck, tweets without a location or entity are highly unlikely to be relevant
ggplot(scored_tweets, aes(score, color=has_loc_ent)) + geom_density() + scale_x_log10()

###**Step 2: Ignore tweets that are comprised only of actions
scored_tweets <- scored_tweets[scored_tweets$has_loc_ent == "TRUE",]
#size now
nrow(scored_tweets)

##Take 100 random tweets and check 'em out (she did 1,000 but we were doing it ourselves)
set.seed(1)
##**Step 3: take only the top 5%
scored_sample <- scored_tweets[scored_tweets$score> quantile(scored_tweets$score,.95),]
sampled <- scored_sample[sample.int(nrow(scored_sample),250),]$tweetid
tweets <- get_tweets_from_mongo(sampled)
write.csv(tweets$content,"tweets_to_score.csv",row.names=F)

###################################
##########check what the coders said#########
######################################
my_scores <- read.csv("~/data_for_iscram/private/kenny_scored.csv")
my_scores$tweetid <- tweets$X_id
my_scores <- merge(scored_tweets[,c("tweetid","score"),with=F],my_scores)
my_scores$has_loc <- results_of_search[results_of_search$tweetid %in% sampled, "location" %in% type,by=tweetid]$V1

geoffs_scores <- read.csv("~/data_for_iscram/private/geoff_scored.csv")
peters_scores <- read.csv("~/data_for_iscram/private/pml_scored.csv")
my_scores$geoff <- geoffs_scores$Coding
my_scores$geoff <- tolower(my_scores$geoff)
my_scores <- merge(my_scores,peters_scores,by="tweet")
my_scores[my_scores$geoff != my_scores$class,]
my_scores$peter <- tolower(my_scores$peter)
###easier to work with a data frame
my_scores <- data.frame(my_scores)
kappam.fleiss(my_scores[,c("class","geoff","peter")])

my_scores$r <- apply(my_scores[,c("class","peter","geoff")],1, function(f){sum(f == "r")})
my_scores$n <- apply(my_scores[,c("class","peter","geoff")],1, function(f){sum(f == "n")})
my_scores$o <- apply(my_scores[,c("class","peter","geoff")],1, function(f){sum(f == "o")})
my_scores$final_class <- c("r","n","o")[apply(my_scores[,c("r","n","o")],1,which.max)]
##There is only one case where there is no majority, so I made the final decision
##This tweet was sent by the Community Coalition for Haiti - I thought it was definitely providing SA
##In any case, for the rough percentages given in the article, it didn't matter too much
my_scores[my_scores$r == 1 & my_scores$n == 1,][1,]$final_class <- "r"
##What were the percentages?
table(my_scores$final_class)/250
##Were scores higher for SA tweets?
summary(aov(score~final_class,my_scores))
####Were there more locations in SA tweets?  Binarize first so its SA or not, like in the text
my_scores$bin_sa <- my_scores$final_class == "r"
chisq.test(table(my_scores[,c("bin_sa","has_loc")]))

#######Most relevant tweets in only unintuitive/intuitive##################
########We're repeating code here, but I'd rather do that and have analyses separate
setkey(results_of_search,"tweetid","keyword")
score_top <- results_of_search[!duplicated(results_of_search[,c("tweetid","keyword"),with=F]),]
score_top$score[score_top$keyword %in% WORDS_TO_IGNORE] <- 0
score_top <- orderBy(~-score,score_top[,list(score=sum(score),has_int=intersection_tweet[1]==0), by=tweetid])
##Conclusion - hand select from top 300
get_tweets_from_mongo(score_top[score_top$has_int=="FALSE",][1:300,]$tweetid)


