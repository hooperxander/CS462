// click on a ruleset name to see its source here
ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    logging on
    shares hello, __testing
  }
   
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
    

    __testing = { "queries": [ { "name": "hello", "args": [ "obj" ] },
                           { "name": "__testing" } ],
              "events": [ { "domain": "echo", "type": "monkey",
                            "attrs": [ "name" ] } ]
    }
  }
   
  rule hello_world {
    select when echo hello 
    send_directive("say", {"something": "Hello World"})
  }
  
  rule hello_monkey {
    select when echo monkey
    pre {
      //name = event:attr("name").defaultsTo("Monkey").klog("our passed in name: ")
      name = event:attr("name") => event:attr("name").klog("our passed in name: ") | "Monkey".klog("our passed in name: ")
    }
    send_directive("say", {"something":"Hello " + name})
    }
   
}

