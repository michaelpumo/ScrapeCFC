ScrapeCFC
=========

A CFC that scrapes information from a given URL.

The use of ScrapeCFC requires Adobe ColdFusion 9+ or Railo 4. I have only test this on Railo so far, but believe it to work fine on ACF.

This script makes use of a Java class loader and a Java library known as jSoup. Combining these tools, we are able to extract information from a URL relatively easily.

There is only one public function getInfo() which can return either a ColdFusion structure, or JSON, when providing a URL.

The following code assumes that your files are placed in a folder called lib, in your web root.

<pre>
<cfparam name="url.url" type="string" default="" />
<cfset scrape = new lib.scrape() />
<cfdump var="#scrape.getData(url.url, "json")#" />
</pre>

This is my first ever open source project, so I welcome feedback.
