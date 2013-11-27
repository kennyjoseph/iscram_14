get_stats_q1 <- function(tmp,to_ignore){
  all <- unique(tmp$tweetid)
  count <- length(all)
  union <- length(union(all,ignored_tweets))
  only_ignore <- length(setdiff(ignored_tweets,all))
  only_unint <- length(setdiff(all,ignored_tweets))
  intersect <- length(intersect(all,ignored_tweets))
  return(c(count, union,only_ignore,only_unint,intersect))
}

get_tweets_from_mongo <- function(tweet_ids){
  mongo <- mongoDbConnect("iscram")
  return(dbGetQuery(mongo,"tweets",paste('{"_id": {$in: [',paste(tweet_ids,collapse=","),']}}')))
}