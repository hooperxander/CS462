ruleset manage_sensors {
  meta {
    shares __testing, sensors, temperatures
    provides sensors, temperatures
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
    use module twilio_interface alias twilio
    use module sensor_profile alias profile
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, { "name": "sensors"}
        ,{ "name": "temperatures" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["name"] }
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name"] }
      , { "domain": "sensor", "type": "register_sensor", "attrs": [ "eci"] }
      ]
    }
    sensors = function(){
      return Subscriptions:established("Tx_role","sensor")
    }
    temperatures = function(){
      return Subscriptions:established("Tx_role","sensor").reduce(function(a, i){a.append(wrangler:skyQuery( i{"Tx"} , "temperature_store", "temperatures"))}, [])
    }
  }
  rule register_sensor{
    select when sensor register_sensor
    pre{
      eci = event:attr("eci")
      my_eci = meta:eci
    }
     event:send(
      { "eci": my_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "temp_ sensor",
                   "Rx_role": "manager",
                   "Tx_role": "sensor",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci } } )
  }
  rule new_sensor{
    select when sensor new_sensor
      pre {
        name = event:attr("name")
      }
      fired{
        raise wrangler event "child_creation"
        attributes { "name": name,
                    "color": "#ffff00",
                    "rids": ["temperature_store", "wovyn_base", "sensor_profile", "io.picolabs.logging"]}
      }
  }
  rule store_new_pico {
  select when wrangler new_child_created
    pre {
      eci = event:attr("eci")
      name = event:attr("name")
      my_eci = meta:eci
    }
    event:send(
      { "eci": my_eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "temp_ sensor",
                   "Rx_role": "manager",
                   "Tx_role": "sensor",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci } } )
  }
  rule delete_pico {
    select when sensor unneeded_sensor
    pre{
      name = event:attr("name")
    }
    always{
      raise wrangler event "child_deletion"
        attributes {"name": name};
    }
  }
  rule rulesets_installed {
    select when child installed
    pre{
      eci = event:attr("eci")
    }
    event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": "im a sensor", "threshold": 80, "number": "+12082444100"}})
  }
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
      fired {
        raise wrangler event "pending_subscription_approval"
          attributes event:attrs
        }
  }
  rule notify_violation {
    select when wovyn threshold_violation
    pre{
      temp = event:attrs.get("temp")
      time = event:attrs.get("time")
      prof = profile:sensor_profile().klog("profile")
      to = prof.get("sms_number").klog("number")
    }
    always{
      raise test event "new_message"
      attributes {"to": to, "from": "+12016227478", "message": "Threshold exceeded temp: " + temp + " at: " + time}
    }
    
    //twilio:send_sms(to, "+12016227478", "Threshold exceeded temp: " + temp + " at: " + time)

  }
}
