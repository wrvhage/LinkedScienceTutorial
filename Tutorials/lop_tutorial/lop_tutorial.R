library(SPARQL)
library(ggmap)
library(zoo)
library(plyr)

# define SPARQL end-point and namespaces

# VU University Amsterdam LOP server
# endpoint <- "http://semanticweb.cs.vu.nl/lop/sparql/"
# options <- NULL

# Local Jena Fuseki setup
endpoint <- "http://localhost:3030/lop/sparql"
options <- "output=xml"

prefix <- c("lop","http://semanticweb.cs.vu.nl/poseidon/ns/instances/",
            "eez","http://semanticweb.cs.vu.nl/poseidon/ns/eez/",
            "geo","http://www.geonames.org/ontology#",
            "skos","http://www.w3.org/2004/02/skos/core#",
            "wn30","http://purl.org/vocabularies/princeton/wn30/",
            "wn20schema","http://www.w3.org/2006/03/wn/wn20/schema/")

sparql_prefix <- "PREFIX sem: <http://semanticweb.cs.vu.nl/2009/11/sem/>
                  PREFIX poseidon: <http://semanticweb.cs.vu.nl/poseidon/ns/instances/>
                  PREFIX eez: <http://semanticweb.cs.vu.nl/poseidon/ns/eez/>
                  PREFIX wgs84: <http://www.w3.org/2003/01/geo/wgs84_pos#>
                  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                  PREFIX geo: <http://www.geonames.org/ontology#>
                  PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
                  PREFIX wn30: <http://purl.org/vocabularies/princeton/wn30/>
                  PREFIX wn20schema: <http://www.w3.org/2006/03/wn/wn20/schema/>
"


# get events per region

q <- paste(sparql_prefix, 
  "SELECT *
   WHERE {
     ?event sem:hasPlace ?place .
     ?place eez:inPiracyRegion ?region .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# count the events per region

count_per_region <- table(res$region)
sorted_counts <- sort(count_per_region)

# plot as a pie chart

pie(sorted_counts, col=rainbow(12))


# get event types and region of events

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event sem:eventType ?event_type .
     ?event sem:hasPlace ?place .
     ?place eez:inPiracyRegion ?region .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# calculate counts with a two-way table

event_region_table <- table(res$event_type,res$region)

# draw a stacked barplot

par(mar=c(4,10,1,1))
barplot(event_region_table, col=rainbow(10), horiz=TRUE, las=1, cex.names=0.8)
legend("topright", rownames(event_region_table),
       cex=0.8, bty="n", fill=rainbow(10))


# get event type, latitude and longitude per event

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event sem:eventType ?event_type .
     ?event sem:hasPlace ?place .
     ?place wgs84:lat ?lat .
     ?place wgs84:long ?long .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# plot on a map

qmap('Gulf of Aden', zoom=2) +
  geom_point(aes(x=long, y=lat, colour=event_type), data=res) +
  scale_color_manual(values = rainbow(10))


# get events that mention "RPG" in the description
# fetch event type, latitude, longitude

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event rdfs:comment ?description .
     FILTER regex(?description,'RPG','i')
     ?event sem:eventType ?event_type .
     ?event sem:hasPlace ?place .
     ?place wgs84:lat ?lat .
     ?place wgs84:long ?long .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# plot on a map

qmap('Gulf of Aden', zoom=2) +
  geom_point(aes(x=long, y=lat, colour=event_type), data=res) +
  scale_color_manual(values = rainbow(10))


# get event type, victim ship type, and region of events

q <- paste(sparql_prefix,
"SELECT ?event_type ?actor_type ?region
   WHERE {
     ?event sem:eventType ?event_type .
     ?event sem:hasPlace ?place .
     ?place eez:inPiracyRegion ?region .
     ?event sem:hasActor ?actor .
     ?actor sem:actorType ?actor_type .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

et_region <- table(res$event_type,res$region)
at_region <- table(res$actor_type,res$region)

# compute correlation between regions with respect to event types

et_cor <- cor(et_region, method='pearson')
sort(et_cor['eez:Region_Gulf_of_Aden',], decreasing=TRUE)

# compute correlation between regions with respect to victim ship types

at_cor <- cor(at_region, method='pearson')
sort(at_cor['eez:Region_Gulf_of_Aden',], decreasing=TRUE)


# get event type of events that involve a merchant vessel of some sort

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event sem:eventType ?event_type .
     ?event sem:hasActor ?actor .
     ?actor sem:actorType ?actor_type .
     ?actor_type rdfs:subClassOf poseidon:atype_merchant_vessel .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=paste(options,"&entailment=rdfs"))$results

mv_et_table <- table(res$event_type)


# count events per event types for all types of ships

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event sem:eventType ?event_type .
     ?event sem:hasActor ?actor .
     ?actor sem:actorType ?actor_type .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

all_et_table <- table(res$event_type)


# count events per event types for non-merchant vessels
# by subtracting the counts of merchant vessel events from all events 

rest_et_table <- all_et_table - mv_et_table


# perform a chi-square test between attacks that happen to
# merchant vessels and other vessels

chisq.test(mv_et_table,rest_et_table)


# show number of attacks per quarter

q <- paste(sparql_prefix,
  "SELECT *
   WHERE {
     ?event sem:hasPlace ?place .
     ?place eez:inPiracyRegion ?region .
     ?event sem:hasTimeStamp ?time .
   }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# construct a table containing ones for each time at which an event takes place

event_times_aden <- res[res[['region']]=='eez:Region_Gulf_of_Aden',][['time']]
date_table_aden <- zoo(rep(1,length(event_times_aden)),as.Date(event_times_aden))
event_times_india <- res[res[['region']]=='eez:Region_India_Bengal',][['time']]
date_table_india <- zoo(rep(1,length(event_times_india)),as.Date(event_times_india))

# add the ones up per quarter year

india_per_quarter <- aggregate(date_table_india,as.yearqtr)
aden_per_quarter <- aggregate(date_table_aden,as.yearqtr)

plot(india_per_quarter,type="b",xlab="quarter",ylab="number of piracy events",
     pch=16,col='purple')
lines(aden_per_quarter,type="b",pch=16,col="red")
legend("topleft",c("Gulf of Aden","India and Gulf of Bengal"),fill=c("red","purple"))


# WordNet transgressions aggregated per GeoNames continent per year
q <- paste(sparql_prefix,
  "SELECT DISTINCT ?event ?continent ?time
   WHERE {
     ?transgression rdfs:label \"transgression\"@en-us .
     ?event_type (skos:closeMatch|skos:exactMatch)/wn20schema:hyponymOf* ?transgression .
     ?event rdf:type ?event_type .
     ?cont geo:featureCode geo:L.CONT .
     ?cont geo:name ?continent .
     ?event sem:hasPlace/eez:inEEZ/geo:inCountry/geo:parentFeature* ?cont .
     ?event sem:hasTimeStamp ?time .
  }")

res <- SPARQL(endpoint,q,ns=prefix,extra=options)$results

# convert dates to only years
as.year <- function(x) as.numeric(floor(as.yearmon(x)))

# aggregate events per continent, per continent aggregate per year
continent_year <- dlply(res, .(continent), 
                        function(x) aggregate(zoo(rep(1,nrow(x)),x$time),as.year))

# enumerate the continent names in decreasing order of 
# the maximum number of events per year
max_per_cont <- unlist(lapply(continent_year,max))
cont <- names(sort(max_per_cont,decreasing=TRUE))

plot(continent_year[[cont[1]]],xlim=c(2005,2011),ylim=c(0,max(max_per_cont)),
     type="b",xlab="year",ylab="number of transgression events",pch=16,col='purple')
lapply(seq(1,length(cont)),
       function(i) lines(continent_year[[cont[i]]],type="b",pch=16,col=rainbow(7)[i]))
legend("topright",cont,fill=rainbow(7),cex=0.5)

