ruleset sensor_profile {
  meta {
    shares __testing, sensor_profile
    provides sensor_profile
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "sensor_profile"}
      ] , "events":
      [ { "domain": "sensor", "type": "profile_updated", "attrs": ["threshold", "sms_number"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    sensor_profile = function(){
      return {"name" : "Wovyn Sensor", "location" : "Provo, Ut", "threshold" : ent:temp_threshold.defaultsTo(80), "sms_number" : ent:sms_number.defaultsTo("+12082444100")}
    }
  }
  rule update  {
    select when sensor profile_updated
    always{
      ent:temp_threshold := event:attr("threshold")
      ent:sms_number := event:attr("number")
    }
  }
}
