=begin rdoc
   This is FireWatir, Web Application Testing In Ruby using Firefox browser

   Typical usage:
    # include the controller
    require "firewatir"

    # go to the page you want to test
    ff = FireWatir::Firefox.start("http://myserver/mypage")

    # enter "Angrez" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ff.button(:value, "Cancel").click

   FireWatir allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that FireWatir can identify
   include:

   Type         Description
   ===========  ===============================================================
   button       <input> tags, with the type="button" attribute
   check_box    <input> tags, with the type="checkbox" attribute
   div          <div> tags
   form
   frame
   hidden       hidden <input> tags
   image        <img> tags
   label
   link         <a> (anchor) tags
   p            <p> (paragraph) tags
   radio        radio buttons; <input> tags, with the type="radio" attribute
   select_list  <select> tags, known informally as drop-down boxes
   span         <span> tags
   table        <table> tags
   text_field   <input> tags with the type="text" attribute (a single-line
                text field), the type="text_area" attribute (a multi-line
                text field), and the type="password" attribute (a
                single-line field in which the input is replaced with asterisks)

   In general, there are several ways to identify a specific object.  FireWatir's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that FireWatir will seek, as shown in the examples above.  Available "how"
   options depend upon the type of object, but here are a few examples:

   How           Description
   ============  ===============================================================
   :id           Used to find an object that has an "id=" attribute. Since each
                 id should be unique, according to the XHTML specification,
                 this is recommended as the most reliable method to find an
                 object.
   :name         Used to find an object that has a "name=" attribute.  This is
                 useful for older versions of HTML, but "name" is deprecated
                 in XHTML.
   :value        Used to find a text field with a given default value, or a
                 button with a given caption
   :index        Used to find the nth object of the specified type on a page.
                 For example, button(:index, 2) finds the second button.
                 Current versions of FireWatir use 1-based indexing, but future
                 versions will use 0-based indexing.
   :xpath	     The xpath expression for identifying the element.
   
   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  FireWatir doesn't enforce this; FireWatir will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   FireWatir uses JSSh for interacting with the browser.  For further information on 
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/
   
=end

module FireWatir
  include Watir::Exception
  
  class Firefox
    include FireWatir::Container
    
    # XPath Result type. Return only first node that matches the xpath expression.
    # More details: "http://developer.mozilla.org/en/docs/DOM:document.evaluate"
    FIRST_ORDERED_NODE_TYPE = 9
                    
    # Description: 
    #   Starts the firefox browser. 
    #   On windows this starts the first version listed in the registry.
    # 
    # Input:
    #   options  - Hash of any of the following options:
    #     :waitTime - Time to wait for Firefox to start. By default it waits for 2 seconds.
    #                 This is done because if Firefox is not started and we try to connect
    #                 to jssh on port 9997 an exception is thrown.
    #     :profile  - The Firefox profile to use. If none is specified, Firefox will use
    #                 the last used profile. 
    #     :suppress_launch_process - do not create a new firefox process. Connect to an existing one.
    
    # TODO: Start the firefox version given by user.
    
    def initialize(options = {})
      if(options.kind_of?(Integer))
        options = {:waitTime => options}
      end
      
      # check for jssh not running, firefox may be open but not with -jssh
      # if its not open at all, regardless of the :suppress_launch_process option start it
      # error if running without jssh, we don't want to kill their current window (mac only)
      jssh_down = false
      begin
        set_defaults()
      rescue Watir::Exception::UnableToStartJSShException
        jssh_down = true
      end
      
      if not options[:suppress_launch_process]
        launch_browser(options)
      end

      set_defaults()
      get_window_number()
      set_browser_document()
    end
    
    # Launches firebox browser
    # options as .new
    
    def launch_browser(options = {})
      
      if(options[:profile])
        profile_opt = "-no-remote -P #{options[:profile]}"
      else
        profile_opt = ""
      end
      
      bin = path_to_bin()
      @browser_pid = Process.fork do
        $stdout.reopen File.new('/dev/null', 'w')
        $stderr.reopen File.new('/dev/null', 'w')
        $stdin.reopen File.new('/dev/null', 'r')
        exec("#{bin} -jssh #{profile_opt}")
      end
      sleep options[:waitTime] || 5
      
    end
    private :launch_browser
    
    # Creates a new instance of Firefox. Loads the URL and return the instance.
    # Input:
    #   url - url of the page to be loaded.
    def self.start(url)
      ff = Firefox.new
      ff.goto(url)
      return ff
    end
    
    # Gets the window number opened. 
    # Currently, this returns the most recently opened window, which may or may
    # not be the current window.
    def get_window_number()
      # If at any time a non-browser window like the "Downloads" window 
      #   pops up, it will become the topmost window, so make sure we 
      #   ignore it.
      window_count = js_eval("getWindows().length").to_i - 1
      while js_eval("getWindows()[#{window_count}].getBrowser") == ''
        window_count -= 1;
      end
      
      # now correctly handles instances where only browserless windows are open
      # opens one we can use if count is 0
      
      if window_count < 0
        open_window
        window_count = 1
      end
      @window_index = window_count
    end
    private :get_window_number
    
    # Loads the given url in the browser. Waits for the page to get loaded.
    def goto(url)
      get_window_number()
      set_browser_document()
      js_eval "#{browser_var}.loadURI(\"#{escape_javascript(url)}\")"
      wait()
    end
    
    # Loads the previous page (if there is any) in the browser. Waits for the page to get loaded.
    def back()
      js_eval "if(#{browser_var}.canGoBack) #{browser_var}.goBack()"
      wait()
    end
    
    # Loads the next page (if there is any) in the browser. Waits for the page to get loaded.
    def forward()
      js_eval "if(#{browser_var}.canGoForward) #{browser_var}.goForward()"
      wait()
    end
    
    # Reloads the current page in the browser. Waits for the page to get loaded.
    def refresh()
      js_eval "#{browser_var}.reload()"
      wait()
    end
    
    # Executes the given JavaScript string 
    def execute_script(source)
      result = js_eval source.to_s
      wait()
      
      result
    end
    
    def set_cookie(domain, key, value)
      jssh_command = <<EOF
var comp = #{window_var}.Components;
var cs = comp.classes["@mozilla.org/cookieService;1"].getService(comp.interfaces.nsICookieService);
var ios = comp.classes["@mozilla.org/network/io-service;1"].getService(comp.interfaces.nsIIOService);
var uri = ios.newURI("http://#{domain}/", null, null);
cs.setCookieString(uri, null, "#{key}=#{value}", null);
EOF
      js_eval jssh_command
    end
    
    def delete_all_cookies
      jssh_command = <<EOF
var comp = #{window_var}.Components;
comp.classes["@mozilla.org/cookiemanager;1"].getService(comp.interfaces.nsICookieManager).removeAll();
EOF
      js_eval jssh_command
    end
    
    def delete_cookie(domain, name, path = '/')
      jssh_command = <<EOF
var comp = #{window_var}.Components;
comp.classes["@mozilla.org/cookiemanager;1"].getService(comp.interfaces.nsICookieManager).remove("#{domain}", "#{name}", "#{path}", false);
EOF
      js_eval jssh_command
    end
    
    def get_cookies_by_domain(domain)
      if (!domain.nil? && domain[0] != ".")
        domain = "." + domain
      end
      cookies = {}
      i=0
      
      while (i<2)
        jssh_command = <<EOF
var comp = #{window_var}.Components;
var cookieMgr = comp.classes["@mozilla.org/cookiemanager;1"].getService(comp.interfaces.nsICookieManager);
var allcookies='';
for (var e = cookieMgr.enumerator; e.hasMoreElements(); ) {
  var cookie = e.getNext().QueryInterface(comp.interfaces.nsICookie);
  if (cookie.host == "#{domain}") {
    allcookies += "host=" + cookie.host + ";";
    allcookies += "name=" + cookie.name + ";";
    allcookies += "value=" + cookie.value + ";";
    allcookies += "path=" +cookie.path + ";";
    allcookies += "is_secure=" + cookie.isSecure + ";";
    allcookies += "expires=" + cookie.expires + ";";
    allcookies += "p3p=" + cookie.status + ";";
    allcookies += "policy=" + cookie.policy + "\\n";
  }
}

allcookies;
EOF
        js_eval(jssh_command).split("\n").each do |val|
          settings = {}
          val.split(';').each do |key_value|
            key, value = key_value.split('=')
            settings[key] = value
          end
          
          # TODO: Convert expiry date to ruby time object
          cookie_name = settings.delete('name')
          cookies[cookie_name] = settings
        end
        
        i=i+1
        domain = domain[1..domain.length]
      end
      
      cookies
    end
    
    private
    # This function creates a new socket at port 9997 and sets the default values for instance and class variables.
    # Generatesi UnableToStartJSShException if cannot connect to jssh even after 3 tries.
    def set_defaults(no_of_tries = 0)
      # JSSH listens on port 9997. Create a new socket to connect to port 9997.
      begin
        $jssh_socket = TCPSocket::new(MACHINE_IP, "9997")
        $jssh_socket.sync = true
        read_socket()
      rescue
        no_of_tries += 1
        retry if no_of_tries < 3
        raise UnableToStartJSShException, "Unable to connect to machine : #{MACHINE_IP} on port 9997. Make sure that JSSh is properly installed and Firefox is running with '-jssh' option"
      end
      @error_checkers = []
    end
    
    #   Sets the document, window and browser variables to point to correct object in JSSh.
    def set_browser_document
      # Add eventlistener for browser window so that we can reset the document back whenever there is redirect
      # or browser loads on its own after some time. Useful when you are searching for flight results etc and
      # page goes to search page after that it goes automatically to results page.
      # Details : http://zenit.senecac.on.ca/wiki/index.php/Mozilla.dev.tech.xul#What_is_an_example_of_addProgressListener.3F
      jssh_command = "var listObj = new Object();"; # create new object
      jssh_command << "listObj.wpl = Components.interfaces.nsIWebProgressListener;"; # set the web progress listener.
      jssh_command << "listObj.QueryInterface = function(aIID) {
                                  if (aIID.equals(listObj.wpl) || 
                                      aIID.equals(Components.interfaces.nsISupportsWeakReference) ||
                                      aIID.equals(Components.interfaces.nsISupports)) 
                                          return this;
                                  throw Components.results.NS_NOINTERFACE;
                              };" # set function to locate the object via QueryInterface
      jssh_command << "listObj.onStateChange = function(aProgress, aRequest, aFlag, aStatus) { 
                                                if (aFlag & listObj.wpl.STATE_STOP) { 
                                                    if ( aFlag & listObj.wpl.STATE_IS_NETWORK ) {
                                                       #{document_var} = #{browser_var}.contentDocument;
                                                       #{body_var} = #{document_var}.body;
                                                    } 
                                                } 
                                             };" # add function to be called when window state is change. When state is STATE_STOP & 
                                                 # STATE_IS_NETWORK then only everything is loaded. Now we can reset our variables.
      jssh_command.gsub!(/\n/, "")
      js_eval jssh_command

      jssh_command =  "var #{window_var} = getWindows()[#{@window_index}];"
      jssh_command << "var #{browser_var} = #{window_var}.getBrowser();"
      # Add listener create above to browser object
      jssh_command << "#{browser_var}.addProgressListener( listObj,Components.interfaces.nsIWebProgress.NOTIFY_STATE_WINDOW );"
      jssh_command << "var #{document_var} = #{browser_var}.contentDocument;"
      jssh_command << "var #{body_var} = #{document_var}.body;"
      js_eval jssh_command
      
      @window_title = js_eval "#{document_var}.title"
      @window_url = js_eval "#{document_var}.URL"
    end

    public
    def window_var
      "window"
    end
    #private
    def browser_var
      "browser"
    end
    def document_var # unfinished
      "document"
    end
    def body_var # unfinished
      "body"
    end
    
    public
    #   Closes the window.
    def close(terminate=false)
      
      if terminate || js_eval("getWindows().length").to_i == 1
        js_eval("getWindows()[0].close()")
        Process.kill("TERM", @browser_pid)
        
        # wait for the app to close properly
        Process.wait(@browser_pid)
      else
        # Check if window exists, because there may be the case that it has been closed by click event on some element.
        # For e.g: Close Button, Close this Window link etc.
        window_number = find_window(:url, @window_url) 
        
        # If matching window found. Close the window.
        if window_number > 0
          js_eval "getWindows()[#{window_number}].close()"
        end    

      end
    end
    
    #   Used for attaching pop up window to an existing Firefox window, either by url or title.
    #   ff.attach(:url, 'http://www.google.com')
    #   ff.attach(:title, 'Google') 
    #
    # Output:
    #   Instance of newly attached window.
    def attach(how, what)
      
      $stderr.puts("warning: #{self.class}.attach is experimental") if $VERBOSE
      window_number = find_window(how, what)
      
      if(window_number.nil?)
        raise NoMatchingWindowFoundException.new("Unable to locate window, using #{how} and #{what}")  
      elsif(window_number >= 0)
        @window_index = window_number
        set_browser_document()
      end    
      self
    end

    # Class method to return a browser object if a window matches for how
    # and what. Window can be referenced by url or title.
    # The second argument can be either a string or a regular expression. 
    # Watir::Browser.attach(:url, 'http://www.google.com')
    # Watir::Browser.attach(:title, 'Google')
    def self.attach how, what
      br = new :suppress_launch_process => true # don't create window
      br.attach(how, what)
      br
    end
    
    # loads up a new window in an existing process
    # Watir::Browser.attach() with no arguments passed the attach method will create a new window
    # this will only be called one time per instance we're only ever going to run in 1 window
    
    def open_window
      
      if @opened_new_window
        return @opened_new_window
      end

      jssh_command = "var windows = getWindows(); var window = windows[0];
                      window.open();
                      var windows = getWindows(); var window_number = windows.length - 1;
                      window_number;"      
      
      window_number = js_eval(jssh_command).to_i
      @opened_new_window = window_number
      return window_number if window_number >= 0
    end
    private :open_window

    # return the window index for the browser window with the given title or url.
    #   how - :url or :title
    #   what - string or regexp
    def find_window(how, what)
      jssh_command =  "var windows = getWindows(); var window_number = false; var found = false;
                             for(var i = 0; i < windows.length; i++)
                             {
                                var attribute = '';
                                var browser = windows[i].getBrowser();
                                if(!browser)
                                {
                                  continue;
                                }
                                if(\"#{how}\" == \"url\")
                                {
                                    attribute = browser.contentDocument.URL;
                                }
                                if(\"#{how}\" == \"title\")
                                {
                                    attribute = browser.contentDocument.title;
                                }"
      if(what.class == Regexp)                    
        jssh_command << "var regExp = new RegExp(#{what.inspect});
                                 found = regExp.test(attribute);"
      else
        jssh_command << "found = (attribute == \"#{what}\");"
      end
      
      jssh_command <<     "if(found)
                                {
                                    window_number = i;
                                    break;
                                }
                            }
                            window_number;"
      window_number = js_eval(jssh_command).to_s
      return window_number == 'false' ? nil : window_number.to_i
    end
    private :find_window
    
    #
    # Description:
    #   Matches the given text with the current text shown in the browser.
    #
    # Input:
    #   target - Text to match. Can be a string or regex
    #
    # Output:
    #   Returns the index if the specified text was found.
    #   Returns matchdata object if the specified regexp was found.
    #
    def contains_text(target)
      #puts "Text to match is : #{match_text}"
      #puts "Html is : #{self.text}"
      case target
        when Regexp
        self.text.match(target)
        when String
        self.text.index(target)
      else
        raise ArgumentError, "Argument #{target} should be a string or regexp."
      end
    end
    
    # Returns the url of the page currently loaded in the browser.
    def url
      @window_url = js_eval "#{document_var}.URL"
    end 
    
    # Returns the title of the page currently loaded in the browser.
    def title
      @window_title = js_eval "#{document_var}.title"
    end
    
    # Returns the html of the page currently loaded in the browser.
    def html
      result = js_eval("var htmlelem = #{document_var}.getElementsByTagName('html')[0]; htmlelem.innerHTML")
      return "<html>" + result + "</html>"
    end
    
    # Returns the text of the page currently loaded in the browser.
    def text
      js_eval("#{body_var}.textContent").strip
    end
    
    # Maximize the current browser window.
    def maximize()
      js_eval "#{window_var}.maximize()"
    end
    
    # Minimize the current browser window.
    def minimize()
      js_eval "#{window_var}.minimize()"
    end
    
    # Waits for the page to get loaded.
    def wait(last_url = nil)
      #puts "In wait function "
      isLoadingDocument = ""
      start = Time.now
      
      while isLoadingDocument != "false"
        begin
          isLoadingDocument = js_eval("#{browser_var}=#{window_var}.getBrowser(); #{browser_var}.webProgress.isLoadingDocument;")
          #puts "Is browser still loading page: #{isLoadingDocument}"
        rescue
          # We lost the window, e.g. because of a popup that closed itself
          return self
        end
        
        # Raise an exception if the page fails to load
        if (Time.now - start) > 300
          raise "Page Load Timeout"
        end
      end
      # If the redirect is to a download attachment that does not reload this page, this
      # method will loop forever. Therefore, we need to ensure that if this method is called
      # twice with the same URL, we simply accept that we're done.
      url = js_eval("#{browser_var}.contentDocument.URL")
      
      if(url != last_url)
        # Check for Javascript redirect. As we are connected to Firefox via JSSh. JSSh
        # doesn't detect any javascript redirects so check it here.
        # If page redirects to itself that this code will enter in infinite loop.
        # So we currently don't wait for such a page.
        # wait variable in JSSh tells if we should wait more for the page to get loaded
        # or continue. -1 means page is not redirected. Anyother positive values means wait.
        jssh_command = "var wait = -1; var meta = null; meta = #{browser_var}.contentDocument.getElementsByTagName('meta');
                                if(meta != null)
                                {
                                    var doc_url = #{browser_var}.contentDocument.URL;
                                    for(var i=0; i< meta.length;++i)
                                    {
						    			var content = meta[i].content;
							    		var regex = new RegExp(\"^refresh$\", \"i\");
								    	if(regex.test(meta[i].httpEquiv))
									    {
										    var arrContent = content.split(';');
    										var redirect_url = null;
	    									if(arrContent.length > 0)
		    								{
			    								if(arrContent.length > 1)
				    								redirect_url = arrContent[1];
	                                            
							    				if(redirect_url != null)
						    					{
								    				regex = new RegExp(\"^.*\" + redirect_url + \"$\");
									    			if(!regex.test(doc_url))
										    		{
											    		wait = arrContent[0];
												    }
											    }
											    break;
										    }
									    }
								    }
                                }
                                wait;"
        wait_time = js_eval(jssh_command).to_i
        begin
          if(wait_time != -1)
            sleep(wait_time)
            # Call wait again. In case there are multiple redirects.
            js_eval "#{browser_var} = #{window_var}.getBrowser()"
            wait(url)
          end    
        rescue
        end
      end
      set_browser_document()
      run_error_checks()
      return self
    end
    
    # Add an error checker that gets called on every page load.
    # * checker - a Proc object 
    def add_checker(checker)
      @error_checkers << checker
    end
    
    # Disable an error checker
    # * checker - a Proc object that is to be disabled
    def disable_checker(checker)
      @error_checkers.delete(checker)
    end
    
    # Run the predefined error checks. This is automatically called on every page load.
    def run_error_checks
      @error_checkers.each { |e| e.call(self) }
    end
    
    
    #def jspopup_appeared(popupText = "", wait = 2)
    #    winHelper = WindowHelper.new()
    #    return winHelper.hasPopupAppeared(popupText, wait)
    #end
    
    #
    # Description:
    #   Redefines the alert and confirm methods on the basis of button to be clicked.
    #   This is done so that JSSh doesn't get blocked. You should use click_no_wait method before calling this function.
    #
    #   Typical Usage:
    #   ff.button(:id, "button").click_no_wait
    #   ff.click_jspopup_button("OK")
    #
    # Input:
    #   button - JavaScript button to be clicked. Values can be OK or Cancel
    #
    #def click_jspopup_button(button)
    #    button = button.downcase
    #    element = Element.new(nil)
    #    element.click_js_popup(button)
    #end
    
    #
    # Description:
    #   Tells FireWatir to click javascript button in case one comes after performing some action on an element. Matches
    #   text of pop up with one if supplied as parameter. If text matches clicks the button else stop script execution until
    #   pop up is dismissed by manual intervention.
    # 
    # Input:
    #   button      - JavaScript button to be clicked. Values can be OK or Cancel
    #   waitTime    - Time to wait for pop up to come. Not used just for compatibility with Watir.
    #   userInput   - Not used just for compatibility with Watir
    #   text        - Text that should appear on pop up.
    #
    def startClicker(button, waitTime = 1, userInput = nil, text = nil)
      jssh_command = "var win = #{browser_var}.contentWindow;"
      if(button =~ /ok/i)
        jssh_command << "var popuptext = '';
                                 var old_alert = win.alert;
                                 var old_confirm = win.confirm;
                                 win.alert = function(param) {"
        if(text != nil)                 
          jssh_command <<          "if(param == \"#{text}\") {
                                                popuptext = param; 
                                                return true;
                                              }
                                              else {
                                                popuptext = param;
                                                win.alert = old_alert;
                                                win.alert(param);
                                              }"
        else
          jssh_command <<          "popuptext = param; return true;"
        end
        jssh_command << "};
                                 win.confirm = function(param) {"
        if(text != nil)                 
          jssh_command <<          "if(param == \"#{text}\") {
                                                popuptext = param; 
                                                return true;
                                              }
                                              else {
                                                win.confirm = old_confirm;
                                                win.confirm(param);
                                              }"
        else
          jssh_command <<          "popuptext = param; return true;"
        end
        jssh_command << "};"
        
      elsif(button =~ /cancel/i)
        jssh_command = "var old_confirm = win.confirm; 
                                              win.confirm = function(param) {"
        if(text != nil)                 
          jssh_command <<          "if(param == \"#{text}\") {
                                                popuptext = param; 
                                                return false;
                                              }
                                              else {
                                                win.confirm = old_confirm;
                                                win.confirm(param);
                                              }"
        else
          jssh_command <<          "popuptext = param; return false;"
        end
        jssh_command << "};"
      end
      js_eval jssh_command
    end
    
    #
    # Description:
    #   Returns text of javascript pop up in case it comes.
    #
    # Output:
    #   Text shown in javascript pop up.
    #
    def get_popup_text()
      return_value = js_eval "popuptext"
      # reset the variable
      js_eval "popuptext = ''"
      return return_value
    end
    
    # Returns the document element of the page currently loaded in the browser.
    def document
      Document.new("#{document_var}")
    end
    
    # Returns the first element that matches the given xpath expression or query.
    def element_by_xpath(xpath)
      temp = Element.new(nil, self)
      element_name = temp.element_by_xpath(self, xpath)
      return element_factory(element_name)
    end
    
    # Return object of correct Element class while using XPath to get the element.
    def element_factory(element_name)
      jssh_type = Element.new(element_name,self).element_type
      #puts "jssh type is : #{jssh_type}" # DEBUG
      candidate_class = jssh_type =~ /HTML(.*)Element/ ? $1 : ''
      #puts candidate_class # DEBUG
      if candidate_class == 'Input'
        input_type = js_eval("#{element_name}.type").downcase.strip
        firewatir_class = input_class(input_type)
      else
        firewatir_class = jssh2firewatir(candidate_class)
      end
      
      #puts firewatir_class # DEBUG
      klass = FireWatir.const_get(firewatir_class)
      
      if klass == Element
        klass.new(element_name,self)
      elsif klass == CheckBox
        klass.new(self,:jssh_name,element_name,["checkbox"])
      elsif klass == Radio
        klass.new(self,:jssh_name,element_name,["radio"])
      else
        klass.new(self,:jssh_name,element_name)
      end 
    end
    private :element_factory
    
    #   Return the class name for element of input type depending upon its type like checkbox, radio etc.
    def input_class(input_type)
      hash = {
                'select-one' => 'SelectList',
                'select-multiple' => 'SelectList',
                'text' => 'TextField',
                'password' => 'TextField',
                'textarea' => 'TextField',
        # TODO when there's no type, it's a TextField
                'file' => 'FileField',
                'checkbox' => 'CheckBox',
                'radio' => 'Radio',
                'reset' => 'Button',
                'button' => 'Button',
                'submit' => 'Button',
                'image' => 'Button'
      }
      hash.default = 'Element'
      
      hash[input_type]
    end
    private :input_class
    
    # For a provided element type returned by JSSh like HTMLDivElement, 
    # returns its corresponding class in Firewatir.
    def jssh2firewatir(candidate_class)
      hash = {
                'Div' => 'Div',
                'Button' => 'Button',
                'Frame' => 'Frame',
                'Span' => 'Span',
                'Paragraph' => 'P',
                'Label' => 'Label',
                'Form' => 'Form',
                'Image' => 'Image',
                'Table' => 'Table',
                'TableCell' => 'TableCell',
                'TableRow' => 'TableRow',
                'Select' => 'SelectList',
                'Link' => 'Link',
                'Anchor' => 'Link' # FIXME is this right?
        #'Option' => 'Option' #Option uses a different constructor
      }
      hash.default = 'Element'
      hash[candidate_class]
    end
    private :jssh2firewatir
    
    #
    # Description:
    #   Returns the array of elements that matches the xpath query.
    #
    # Input:
    #   Xpath expression or query.
    #
    # Output:
    #   Array of elements matching xpath query.
    #
    def elements_by_xpath(xpath)
      element = Element.new(nil, self)
      elem_names = element.elements_by_xpath(self, xpath)
      elem_names.inject([]) {|elements,name| elements << element_factory(name)}
    end    
    
    #
    # Description:
    #   Show all the forms available on the page.
    #
    # Output:
    #   Name, id, method and action of all the forms available on the page.
    #
    def show_forms
      forms = Document.new(self).get_forms()
      count = forms.length
      puts "There are #{count} forms"
      for i in 0..count - 1 do
        puts "Form name: " + forms[i].name
        puts "       id: " + forms[i].id
        puts "   method: " + forms[i].attribute_value("method")
        puts "   action: " + forms[i].action
      end
    end
    alias showForms show_forms
    
    #
    # Description:
    #   Show all the images available on the page.
    #
    # Output:
    #   Name, id, src and index of all the images available on the page.
    #
    def show_images
      images = Document.new(self).get_images
      puts "There are #{images.length} images"
      index = 1
      images.each do |l|
        puts "image: name: #{l.name}"
        puts "         id: #{l.id}"
        puts "        src: #{l.src}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showImages show_images
    
    #
    # Description:
    #   Show all the links available on the page.
    #
    # Output:
    #   Name, id, href and index of all the links available on the page.
    #
    def show_links
      links = Document.new(self).get_links
      puts "There are #{links.length} links"
      index = 1
      links.each do |l|
        puts "link:  name: #{l.name}"
        puts "         id: #{l.id}"
        puts "       href: #{l.href}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showLinks show_links
    
    #
    # Description:
    #   Show all the divs available on the page.
    #
    # Output:
    #   Name, id, class and index of all the divs available on the page.
    #
    def show_divs
      divs = Document.new(self).get_divs
      puts "There are #{divs.length} divs"
      index = 1
      divs.each do |l|
        puts "div:   name: #{l.name}"
        puts "         id: #{l.id}"
        puts "      class: #{l.className}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showDivs show_divs
    
    #
    # Description:
    #   Show all the tables available on the page.
    #
    # Output:
    #   Id, row count, column count (only first row) and index of all the tables available on the page.
    #
    def show_tables
      tables = Document.new(self).get_tables
      puts "There are #{tables.length} tables"
      index = 1
      tables.each do |l|
        puts "table:   id: #{l.id}"
        puts "       rows: #{l.row_count}"
        puts "    columns: #{l.column_count}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showTables show_tables
    
    #
    # Description:
    #   Show all the pre elements available on the page.
    #
    # Output:
    #   Id, name and index of all the pre elements available on the page.
    #
    def show_pres
      pres = Document.new(self).get_pres
      puts "There are #{pres.length} pres"
      index = 1
      pres.each do |l|
        puts "pre:     id: #{l.id}"
        puts "       name: #{l.name}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showPres show_pres
    
    #
    # Description:
    #   Show all the spans available on the page.
    #
    # Output:
    #   Name, id, class and index of all the spans available on the page.
    #
    def show_spans
      spans = Document.new(self).get_spans
      puts "There are #{spans.length} spans"
      index = 1
      spans.each do |l|
        puts "span:  name: #{l.name}"
        puts "         id: #{l.id}"
        puts "      class: #{l.className}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showSpans show_spans
    
    #
    # Description:
    #   Show all the labels available on the page.
    #
    # Output:
    #   Name, id, for and index of all the labels available on the page.
    #
    def show_labels
      labels = Document.new(self).get_labels
      puts "There are #{labels.length} labels"
      index = 1
      labels.each do |l|
        puts "label: name: #{l.name}"
        puts "         id: #{l.id}"
        puts "        for: #{l.for}"
        puts "      index: #{index}"
        index += 1
      end
    end
    alias showLabels show_labels
    
    #
    # Description:
    #   Show all the frames available on the page. Doesn't show nested frames.
    #
    # Output:
    #   Name, and index of all the frames available on the page.
    #
    def show_frames
      jssh_command = "var frameset = #{window_var}.frames;
                            var elements_frames = new Array();
                            for(var i = 0; i < frameset.length; i++)
                            {
                                var frames = frameset[i].frames;
                                for(var j = 0; j < frames.length; j++)
                                {
                                    elements_frames.push(frames[j].frameElement);    
                                }
                            }
                            elements_frames.length;"
      
      length = js_eval(jssh_command).to_i
      
      puts "There are #{length} frames"
      
      frames = Array.new(length)
      for i in 0..length - 1 do
        frames[i] = Frame.new(self, :jssh_name, "elements_frames[#{i}]")
      end
      
      for i in 0..length - 1 do
        puts "frame: name: #{frames[i].name}"
        puts "      index: #{i+1}"
      end
    end
    alias showFrames show_frames

    private
    
    JS_ESCAPE_MAP = {
      '\\'    => '\\\\',
      '</'    => '<\/',
      "\r\n"  => '\n',
      "\n"    => '\n',
      "\r"    => '\n',
      '"'     => '\\"',
      "'"     => "\\'" }
    
    # Escape carrier returns and single and double quotes for JavaScript segments.
    def escape_javascript(javascript)
      if javascript
        javascript.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }
      else
        ''
      end
    end
    
    def path_to_bin
      path = case current_os()
             when :windows
               path_from_registry
             when :macosx
               path_from_spotlight
             when :linux
               `which firefox`.strip
             end

      raise "unable to locate Firefox executable" if path.nil? || path.empty?

      path
    end

    def current_os
      return @current_os if defined?(@current_os)

      platform = RUBY_PLATFORM =~ /java/ ? java.lang.System.getProperty("os.name") : RUBY_PLATFORM

      @current_os = case platform
                    when /mswin|windows/i
                      :windows
                    when /darwin|mac os/i
                      :macosx
                    when /linux/i
                      :linux
                    end
    end

    def path_from_registry
      raise NotImplementedError, "(need to know how to access windows registry on JRuby)" if RUBY_PLATFORM =~ /java/
      require 'win32/registry.rb'
      lm = Win32::Registry::HKEY_LOCAL_MACHINE
      lm.open('SOFTWARE\Mozilla\Mozilla Firefox') do |reg|
        reg1 = lm.open("SOFTWARE\\Mozilla\\Mozilla Firefox\\#{reg.keys[0]}\\Main")
        if entry = reg1.find { |key, type, data| key =~ /pathtoexe/i }
          return entry.last
        end
      end
    end

    def path_from_spotlight
      ff = %x[mdfind 'kMDItemCFBundleIdentifier == "org.mozilla.firefox"']
      ff = ff.empty? ? '/Applications/Firefox.app' : ff.split("\n").first

      "#{ff}/Contents/MacOS/firefox-bin"
    end
        
  end # Firefox
end # FireWatir
