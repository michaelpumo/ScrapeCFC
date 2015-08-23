/*

Copyright 2013 Michael Giovanni Pumo
Author: Michael Giovanni Pumo (michaelpumo@live.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.

@displayname ScrapeCFC
@hint A CFC to scrape data from a valid http link.

*/

component output="false" accessors="true" {


    property string     url;
    property string     title;
    property struct     meta;
    property struct     og;
    property array      images;
    property boolean    errors;
    property array      messages;
    property string     mimetype;
    
    
    /**
    * @access public
    * @returnType any
    * @output false
    * @hint Initialises the component.
    **/
    
    public any function init() output = false {
        
        setUrl("");
        setTitle("");
        setMeta({});
        setOg({});
        setImages([]);
        setErrors(false);
        setMessages([]);
        setMimetype("");
        
        return this;
        
    }
    

    /**
    * @access public
    * @returnType any
    * @output false
    * @hint Returns the document properties as either a struct or JSON.
    **/ 
    
    public any function getData(
    
        string url          = "", 
        string returnType   = ""
        
    ) output = false returnformat = "JSON" {
        
        setUrl(arguments.url);
        
        if( not _hasErrors(arguments.url) ) {
            _getInfo(arguments.url);
        }
        
        local.document = {
            
            url         = getUrl(),
            title       = getTitle(),
            meta        = getMeta(),
            og          = getOg(),
            images      = getImages(),
            errors      = getErrors(),
            messages    = getMessages(),
            mimetype    = getMimetype()
            
        };
        
        if( arguments.returnType == "json" ) {
            return serializeJSON(local.document);
        }
        
        return local.document;  
        
    }


    /**
    * @access private
    * @returnType void
    * @output false
    * @hint Scrapes and processes the given document.
    **/ 
    
    private void function _getInfo(
    
        required string url
        
    ) output = true {
    
        local.pageObjects = {};
        local.document = _getHTTP(arguments.url);
        
        if( ! isDefined("local.document.status_code") ) {
            _addMessage("No status code returned.");
            _flagError();
        }
        
        if( isDefined("local.document.errordetail") && len(trim(local.document.errordetail)) ) {
            _addMessage(local.document.errordetail);
            _flagError();
        }
    
        if( isDefined("local.document.statuscode") && local.document.statuscode != "200 ok" ) {
            _addMessage(local.document.statuscode);
            _flagError();
        }
     
        if( ! _hasErrors(getUrl()) ) {
            
            local.jsoupObject               = createObject("component","lib.javaloader.JavaLoader").init([ expandPath('/lib/jsoup-1.7.2.jar') ]);
            local.jsoupCreate               = local.jsoupObject.create("org.jsoup.Jsoup");
            local.jsoupWhitelist            = local.jsoupObject.create("org.jsoup.safety.Whitelist");
            local.jsoupWhiteListTags        = javacast("string[]", ["title","meta"]);
            local.jsoupWhiteListAttributes  = javacast("string[]", ["name","content","property"]);
            local.jsoupClean                = local.jsoupCreate.clean(local.document.filecontent, local.jsoupWhitelist.relaxed().addTags(local.jsoupWhiteListTags).addAttributes(":all", local.jsoupWhiteListAttributes));
            local.parsedDocument            = local.jsoupCreate.parse(local.jsoupClean);
            
            if( listFindNoCase("text/html", local.document.mimetype) ) {
                
                structAppend(local.pageObjects, { title     = parsedDocument.select("title").first() } );
                structAppend(local.pageObjects, { images    = parsedDocument.select("img[src]") } );
                structAppend(local.pageObjects, { meta      = parsedDocument.select("meta[content]") } );
                structAppend(local.pageObjects, { og        = parsedDocument.select("meta[property^=og:]") } );
                
                // Open Graph Meta Tags.
                if( arrayLen(local.pageObjects.og) > 0 ) {
                    
                    local.i = 1;
                    
                    for ( local.j in local.pageObjects.og) {
                        
                        local.ogName = trim(lcase(local.pageObjects.og[local.i].attr("property")));
                        local.ogContent = trim(local.pageObjects.og[local.i].attr("content"));
                        
                        local.i++;
                    
                        if( len(local.ogName) > 0 and len(local.ogContent) > 0 ) {
                            structAppend(getOg(), { "#local.ogName#" = local.ogContent } );
                        }

                    }
                    
                }
                
                // Standard Meta Tags.
                if( arrayLen(local.pageObjects.meta) > 0 ) {
                
                    local.i = 1;
                    
                    for (local.j in local.pageObjects.meta) {
                    
                        local.metaName = trim(lcase(local.pageObjects.meta[local.i].attr("name")));
                        local.metaContent = trim(local.pageObjects.meta[local.i].attr("content"));
                    
                        local.i++;
                    
                        if( len(local.metaName) > 0 and len(local.metaContent) > 0 ) {
                            structAppend(getMeta(), { "#local.metaName#" = local.metaContent } );
                        }

                    }
                    
                }
                
                // Image Tags.
                if( arrayLen(local.pageObjects.images) > 0 ) {
                
                    local.i = 1;
                    local.images = _cleanImages(local.pageObjects.images);

                    for (local.j in local.images) {
                    
                        arrayAppend(getImages(), 
                            { 
                                "url"       = trim(local.images[local.i].attr("src")), 
                                "width"     = trim(local.images[local.i].attr("width")), 
                                "height"    = trim(local.images[local.i].attr("height")), 
                                "alt"       = trim(local.images[local.i].attr("alt"))
                            } 
                        );
                        
                        local.i++;
                        
                    }
                    
                }
                
                // Title Tag.
                if( StructKeyExists(local.pageObjects, "title") ) {
                    setTitle(trim(local.pageObjects.title.text()));
                }
                
                
            } else if ( listFindNoCase("image/gif,image/jpg,image/jpeg,image/pjpeg,image/png", local.document.mimetype) ) {
                
                local.image = ImageNew(arguments.url);
                
                arrayAppend(getImages(), 
                    { 
                        "url"       = trim(arguments.url), 
                        "width"     = imageGetWidth(local.image), 
                        "height"    = imageGetHeight(local.image), 
                        "alt"       = "" 
                    }
                );
                
            }
            
            setMimetype(local.document.mimetype);
            
        }
        
        return;
    
    }
    

    /**
    * @access private
    * @returnType void
    * @output false
    * @hint Adds a message to the message property array.
    **/ 
    
    private void function _addMessage(
    
        required string message
        
    ) output = false {
    
        arrayAppend(getMessages(), arguments.message);
        
        return;
    
    }
    

    /**
    * @access private
    * @returnType void
    * @output false
    * @hint Validates the URL.
    **/ 
    
    private void function _validateURL(
    
        required string url
        
    ) output = false {
    
        // Check a URL is passed to us.
        if( len(trim(arguments.url)) ) {
            
            // Check URL length is longer than 8 (http:// + 1 = 8).
            if( len(trim(arguments.url)) < 8 ) {
                _addMessage("URL must be at least 8 characters.");
                _flagError();
            }
            
            // Check if URL is valid.
            if( ! isValid("url", trim(arguments.url)) ) {
                _addMessage("URL is not valid.");
                _flagError();
            }
            
            // Check that URL starts with 'http'.
            if( ! left(trim(arguments.url), 4) == "http" ) {
                _addMessage("URL protocol must be http.");
                _flagError();
            }
         
        } else {
        
            _addMessage("Please enter a URL.");
            _flagError();
           
        }
        
        return;
    
    }
    

    /**
    * @access private
    * @returnType boolean
    * @output false
    * @hint Validates the URL and then returns the error flag.
    **/
    
    private boolean function _hasErrors(
    
        required string url
        
    ) output = false {
    
        _validateURL(arguments.url);
        return getErrors();
    
    }
    

    /**
    * @access private
    * @returnType void
    * @output false
    * @hint Sets the error flag to true.
    **/
    
    private void function _flagError() output = false {
    
        setErrors(true);
        return;

    }
    

    /**
    * @access private
    * @returnType any
    * @output false
    * @hint Makes the http call to the URL.
    **/ 
    
    private any function _getHTTP(
    
        required string url
        
    ) output = false {
    
        local.result = "";
        
        try {
            
            local.http = new http();
            
            local.http.setMethod("get"); 
            local.http.setCharset("utf-8"); 
            local.http.setUseragent(cgi.http_user_agent);
            local.http.setResolveurl(true);
            local.http.setTimeout(20);
            local.http.setUrl(arguments.url);
            
            local.http.addParam(type="header", name="Accept-Encoding", value="*"); 
            local.http.addParam(type="header", name="TE", value="deflate;q=0");
            
            local.result = local.http.send().getPrefix();
            
        }

        catch(any errors) {
            
            _addMessage("Could not fetch the document: " & errors);
            _flagError();
            
        }
        
        return local.result;

    }


    /**
    * @access private
    * @returnType array
    * @output false
    * @hint Removes duplicate images.
    **/ 
    
    private array function _cleanImages(
    
        required array array
        
    ) output = false {
    
        local.imageURLArray = [];
        local.imageObjectArray = [];
        local.i = 1;

        for (local.j in arguments.array) {
        
            local.imageURL = trim(arguments.array[local.i].attr("src"));
            //local.imageWidth = trim(arguments.array[local.i].attr("width"));
            //local.imageHeight = trim(arguments.array[local.i].attr("height"));
            
            //if( len(local.imageWidth) gt 0 and local.imageWidth gt 100 ) {
            
                if( ! ArrayFindNoCase(local.imageURLArray, local.imageURL) ) {
                    arrayAppend(local.imageURLArray, local.imageURL);
                    arrayAppend(local.imageObjectArray, arguments.array[local.i]);
                }
                
            //}
            
            local.i++;
            
        }
        
        return local.imageObjectArray;
        
    }


}
