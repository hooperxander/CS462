ruleset wovyn_base {
  meta {
    use module keys
    use module twilio_module alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module sensor_profile
    shares __testing
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "wovyn", "type": "heartbeat", "attrs": ["genericThing"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    //url for wovyn to use http://192.168.43.171:8080/sky/event/Aj4W2vq6SHsxPUrYWCQuCG/none/wovyn/heartbeat
  }
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
        temp = event:attrs.get("genericThing").as("Number")
        //temp = event:attrs.get(["genericThing", "data", "temperature"])[0].get("temperatureF").klog("temperature in fahrenheit")
        time_now = time:now()
    }
    if event:attr("genericThing") then 
      noop()
    fired {
      raise wovyn event "new_temperature_reading"
        attributes {"temperature": temp, "timestamp": time_now}
    } else {
    
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
        temperature_threshold = sensor_profile:sensor_profile().get("threshold").klog()
        temp = event:attrs.get("temperature").klog("temp: ")
        timestamp = event:attrs.get("timestamp").klog("time: ")
        did_exceed = event:attrs.get("temperature") < temperature_threshold => "didn't exceed" | "exceeded".klog("threshold: ") 
        message = "Temperature " + did_exceed + " threshold"
    }
    send_directive("temperature_threshold", {"body":message})
    fired {
      raise wovyn event "threshold_violation"
      attributes {"temperature": temp, "timestamp": timestamp}
      if temp > temperature_threshold
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    foreach Subscriptions:established("Tx_role","manager") setting (subscription)
    pre {
      temp = event:attrs.get("temperature")
      timestamp = event:attrs.get("timestamp")
    }
    event:send(
      { "eci": subscription{"Tx"}, "eid": "violation",
        "domain": "wovyn", "type": "threshold_violation", 
        "attrs": {"temp": temp, "time": timestamp} }
    )
    //foreach 
     //event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": "im a sensor", "threshold": 80, "number": "+12082444100"}})
    //twilio:send_sms(sensor_profile:sensor_profile().get("sms_number").klog(), "+12016227478", "Threshold exceeded temp: " + temp + " at: " + timestamp)
  }
  
}
