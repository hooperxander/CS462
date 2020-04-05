ruleset gossip {
  meta {
    shares __testing, getTemps, getPeers, getPeer, prepareMessage
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "getTemps"}
      , { "name": "getPeers"}
      , { "name": "getPeer"}
      , { "name": "prepareMessage"}
      ] , "events":
      [ { "domain": "gossip", "type": "heartbeat" }
      , { "domain": "gossip", "type": "clear" }
      , { "domain": "gossip", "type": "rumor", "attrs": [ "MessageID", "SensorID", "Timestamp", "Temperature" ] }
      , { "domain": "gossip", "type": "seen", "attrs": [ "origin", "sequence"] }
      , { "domain": "gossip", "type": "process", "attrs": [ "process"] }
      , { "domain": "gossip", "type": "n", "attrs": [ "n"] }
      ]
    }
    getPeers = function(){
      return ent:peers
    }
    getTemps = function(){
      return ent:logs
    }
    getPeer = function(){
      peer = ent:peers.keys().length() == 0 => -1 | ent:peers.keys()[random:integer(ent:peers.keys().length()-1)]
      return peer
      // needed = peers.map(function(v,k){ v.filter(function(v,k){ent:logs.get(k).keys().reverse()[0].as("Number") > v.as("Number").klog("testing")}) }).klog("needed info")
      // index = needed.keys().length() == 0 => -1 |  needed.keys()[random:integer(needed.keys().length().klog("length")-1).klog()]
      // return index
    }
    prepareMessage = function(type, subscriber){
      //find if the node has no readings from a sensor i know about
      mySequences = ent:logs.map(function(v,k){ v.keys().reverse()[0] }).klog("mySequences")
      seen = ent:peers{subscriber}.klog("what has been seen")
      missingSensors = mySequences.keys().filter(function(x){ ent:peers{subscriber}.keys().index(x) < 0}).klog("missing sensors")
      
      //if not then find what it needs
      needed = ent:peers.map(function(v,k){ v.filter(function(v,k){ent:logs.get(k).keys().reverse()[0].as("Number") > v.as("Number")}) }).klog("needed info")
      nonEmpty = needed.keys().filter(function(x){needed{x}.keys().length() > 0}).klog("nonEmpty needed")
      neededFrom = needed{nonEmpty[0]}.klog("neededFrom")
      
      //if a sensor is missing just send reading 0 from it, else send the first needed reading
      sensor = missingSensors.length() => missingSensors[0] | neededFrom.keys()[0].as("String").klog("sensor")
      sequence = missingSensors.length() => 0 | (neededFrom{sensor}.as("Number") + 1).as("String").klog("sequence")
      
      // ent:logs.map(function(v,k){ v.keys().reverse()[0] })[0].isnull() => {} | 
      sequences = mySequences
      pp = type => ent:logs{[sensor, sequence]} | {"sequences" : sequences, "origin": meta:picoId}
      seq = type => sequence | -1
      retval = {"sensor" : sensor, "sequence" : seq, "message": pp}
      // raise gossip event update
      //   attributes {"sub" : subscriber, "sensor" : sensor, "sequence" : sequence} if type == 0
      return retval
    }
  }
  rule gossip{
    select when gossip heartbeat where ent:process == "on"
      pre{
        subscriber = getPeer().klog("peer")   
        eci = Subscriptions:established("Tx_role","node").filter(function(x){x{"Id"} == subscriber})[0]{"Tx"}.klog("subscribers")
        type = random:integer(1)
        typeName = type => "rumor" | "seen"
        returnVal = prepareMessage(type, subscriber).klog("message")      
        m = returnVal{"message"}
        sequence = returnVal{"sequence"}.klog("sequence")
        sensor = returnVal{"sensor"}.klog("sensor")
      }
      if subscriber > -1 then
          event:send({"eci":eci, "domain":"gossip", "type":typeName.klog("type"), "attrs": m})
      fired{
          ent:peers{[subscriber, sensor]} := sequence
            if (type == 1) && (sensor != "null")
      } finally {
        schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n}) 
      }
  }
  rule seen{
    select when gossip seen where ent:process == "on"
    pre{
      sender = event:attrs.get("origin")
      sequences = event:attrs.get("sequences")
      eci = meta:eci
      subId = Subscriptions:established("Tx_role","node").filter(function(x){x{"Rx"} == eci})[0]{"Id"}
    }
    always{
      ent:peers{subId} := sequences
    }
  }
  rule rumor{
    select when gossip rumor where ent:process == "on"
    pre{
      sequence = event:attrs.get("MessageID").extract(re#:(\w+)#)[0].klog("sequence")
      origin = event:attrs.get("SensorID")
      time = event:attrs.get("Timestamp")
      temp = event:attrs.get("Temperature")
    }
    if sequence.isnull() then
      noop()
    fired{

    }else{
        ent:peers := ent:peers.defaultsTo(Subscriptions:established("Tx_role","node").reduce(function(a,b){ a.put(b{"Id"}, {}) }, {})).klog("peers")
        ent:logs{[origin, sequence]} := {"MessageID" : event:attrs.get("MessageID"), "SensorID" : origin, "Timestamp" : time, "Temperature" : temp}
    }
  }
  rule setProcess{
    select when gossip process
    always{
      ent:process := event:attrs{"process"}.klog("new process val")
    }
  }
  rule setN{
    select when gossip n
    always{
      ent:n := event:attrs{"n"}.klog("new n")
    }
  }
  rule clear{
    select when gossip clear
    always{
      clear ent:logs
      clear ent:peers
      clear ent:temps
      ent:peers := ent:peers.defaultsTo(Subscriptions:established("Tx_role","node").reduce(function(a,b){ a.put(b{"Id"}, {}) }, {})).klog("peers")
      ent:n := 5
      ent:process := "on"
    }
  }
}
