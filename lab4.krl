ruleset temperature_store {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "temperatures"}
      , { "name": "threshold_violations"}
      , { "name": "inrange_temperatures"}
      ] , "events":
      [ { "domain": "sensor", "type": "reading_reset" }
      , { "domain": "wovyn", "type": "new_temperature_reading", "attrs": [ "temperature", "timestamp" ] }
      ]
    }
    temperatures = function(){
      return ent:temps
    }
    threshold_violations = function(){
      return ent:violations
    }
    inrange_temperatures = function(){
      return ent:temps.filter(function(v,k){ent:violations{k}.isnull()})
    }
  }
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre{
      temp = event:attrs.get("temperature")
      time = event:attrs.get("timestamp")
    }
    always{
      ent:temps{time} := temp
    }

  }
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre{
      temp = event:attrs.get("temperature")
      time = event:attrs.get("timestamp")
    }
    always{
      ent:violations{time} := temp
    }
  }
  rule clear_temperatures {
    select when sensor reading_reset
    always{
      clear ent:violations
      clear ent:temps
    }
  }
}
