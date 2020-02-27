ruleset testing_harness {
  meta {
    shares __testing, profiles, temperatures
    use module manage_sensors alias manager
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "profiles" }
      , { "name": "temperatures"}
      ] , "events":
      [ { "domain": "test", "type": "make_sensors" }, { "domain": "test", "type": "delete_sensor" }, 
      { "domain": "test", "type": "send_temps" },
      { "domain": "test", "type": "set_profiles" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    profiles = function(){
      ecis = manager:sensors().values()
      return ecis.reduce(function(a, i){a.append(wrangler:skyQuery( i , "sensor_profile", "sensor_profile"))}, [])
    }
    temperatures = function(){
      return manager:temperatures()
    }
    
  }
  rule make_sensors{
    select when test make_sensors
    always{
      raise sensor event "new_sensor"
      attributes { "name": "Frank"}
      raise sensor event "new_sensor"
      attributes { "name": "Alice"}
      raise sensor event "new_sensor"
      attributes { "name": "Bob"}
      raise sensor event "new_sensor"
      attributes { "name": "Frank"}
    }
  }
  rule delete_sensor{
    select when test delete_sensor
    always{
    raise sensor event "unneeded_sensor"
    attributes { "name": manager:sensors().keys()[0]}
    }
  }
  rule send_temps{
    select when test send_temps
    foreach manager:sensors().values() setting(eci)
      event:send({"eci":eci, "domain":"wovyn", "type":"heartbeat", "attrs":{"genericThing": 80}})
  }
  rule set_profiles{

    select when test set_profiles
    foreach manager:sensors().values() setting(eci)
      event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": "changed", "threshold": 100, "number": "+420"}})
  
  }
}
// creating multiple sensors and deleting at least one sensor. 
// tests the sensors by ensuring they respond correctly to new temperature events. 
// tests the sensor profile to ensure it's getting set reliably.
