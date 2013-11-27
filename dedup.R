###Alright, lets get the unique terms and go manually clean
#x <- unique(dat[,c("Keyword","Type")])
#x <- orderBy(~Type+Keyword,x)
##Yikes, make sure we don't overwrite
#write.csv(x,"clean_2.csv",row.names=F,quote=F)

##If there are two copies of the same word in the SAME field with different types,
##merge them with the type from clean.csv
##If they are two copies of the same word but in DIFFERENT fields, leave them.
dat <- merge(dat,cleaned_terms)
##But lets check to make sure it makes sense
z <- ddply(dat, .(Field,Type,Keyword), summarise, n_rep=length(unique(Report)))
z <- orderBy(~-n_rep,z)
##Do the top words actually make sense?
z[1:50,]
##Do all words have only one type?
r <- ddply(z,.(Keyword), summarise, nf = length(unique(Field)),nt = length(unique(Type)),ent=paste0(Type,collapse=" "))
r <- orderBy(~-nt,r)
nrow(r[r$nt > 1,])

##Make sure theres no duplicate rows for any keywords
dat <- ddply(dat,.(Keyword,Report,Field),function(f){
  if(nrow(f)>1){
    f[1,"Count"] <- sum(f$Count)
  }
  f[1,]
})

##Having cleaned this, we now may have actions in titles...get rid of these
dat <- dat[!(dat$Type=="action" & dat$Field=="title"),]
