ruleset manage_sensors {
  meta {
    shares __testing, sensors, temperatures
    provides sensors, temperatures
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, { "name": "sensors"}
        ,{ "name": "temperatures" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["name"] }
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name"] }
      ]
    }
    sensors = function(){
      return ent:picos
    }
    temperatures = function(){
      ecis = ent:picos.values()
      return ecis.reduce(function(a, i){a.append(wrangler:skyQuery( i , "temperature_store", "temperatures"))}, [])
      
    }
  }
  rule new_sensor{
    select when sensor new_sensor
      pre {
        name = event:attr("name")
        unique = ent:picos{name}.isnull().klog("name found")
      }
      fired{
        ent:picos := ent:picos.defaultsTo({})
        ent:picos{name} := 0
        if unique
        raise wrangler event "child_creation"
        attributes { "name": name,
                    "color": "#ffff00",
                    "rids": ["temperature_store", "wovyn_base", "sensor_profile", "io.picolabs.logging"]}
        if unique
      }
    
  }
  rule store_new_pico {
  select when wrangler new_child_created
    pre {
      eci = event:attr("eci")
      name = event:attr("name")
    }
    if name.klog("found name")
    then
      noop()
    fired {
      ent:picos{name} := eci
    }
  }
  rule delete_pico {
    select when sensor unneeded_sensor
    pre{
      name = event:attr("name")
    }
    always{
      raise wrangler event "child_deletion"
        attributes {"name": name};
      clear ent:picos{name}
    }
  }
  rule rulesets_installed {
    select when child installed
    pre{
      eci = event:attr("eci")
      name = ent:picos.filter(function(v,k){v == eci}).keys().klog("name of pico made")
    }
    event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": name[0], "threshold": 80, "number": "+12082444100"}})
  }
}
