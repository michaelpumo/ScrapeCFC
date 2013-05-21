<cfparam name="url.url" type="string" default="" />

<cfset scrape = new lib.scrape() />
<cfdump var="#scrape.getData(url.url, "json")#" />