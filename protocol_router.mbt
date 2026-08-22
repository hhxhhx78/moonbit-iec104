///|
/// Routing action selected for an address-qualified application object.
pub enum RoutingAction {
  RouteStore
  RouteForward
  RouteStoreAndForward
  RouteDrop
  RouteReject
} derive(Eq, Debug)

///|
pub struct RoutingRule {
  id : Int
  source : Int
  destination : Int
  common_address : CommonAddress?
  type_ids : Array[ApplicationType]
  action : RoutingAction
  priority : Int
  mut enabled : Bool
} derive(Eq, Debug)

///|
pub fn RoutingRule::new(
  id : Int,
  source : Int,
  destination : Int,
  action : RoutingAction,
  common_address? : CommonAddress,
  type_ids? : Array[ApplicationType] = [],
  priority? : Int = 0,
) -> Result[RoutingRule, String] {
  if id < 1 || source < 0 || destination < 0 || source == destination {
    Err("routing rule endpoints are invalid")
  } else if priority < 0 || priority > 255 {
    Err("routing rule priority must fit one byte")
  } else {
    Ok({
      id,
      source,
      destination,
      common_address,
      type_ids: type_ids.copy(),
      action,
      priority,
      enabled: true,
    })
  }
}

///|
pub fn RoutingRule::id(self : RoutingRule) -> Int {
  self.id
}

///|
pub fn RoutingRule::source(self : RoutingRule) -> Int {
  self.source
}

///|
pub fn RoutingRule::destination(self : RoutingRule) -> Int {
  self.destination
}

///|
pub fn RoutingRule::common_address(self : RoutingRule) -> CommonAddress? {
  self.common_address
}

///|
pub fn RoutingRule::type_ids(self : RoutingRule) -> Array[ApplicationType] {
  self.type_ids.copy()
}

///|
pub fn RoutingRule::action(self : RoutingRule) -> RoutingAction {
  self.action
}

///|
pub fn RoutingRule::priority(self : RoutingRule) -> Int {
  self.priority
}

///|
pub fn RoutingRule::enabled(self : RoutingRule) -> Bool {
  self.enabled
}

///|
pub fn RoutingRule::disable(self : RoutingRule) -> Unit {
  self.enabled = false
}

///|
pub struct RouteDecision {
  accepted : Bool
  rule_id : Int?
  action : RoutingAction
  source : Int
  destination : Int
  object : ApplicationObject
  reason : String
} derive(Debug)

///|
pub fn RouteDecision::accepted(self : RouteDecision) -> Bool {
  self.accepted
}

///|
pub fn RouteDecision::rule_id(self : RouteDecision) -> Int? {
  self.rule_id
}

///|
pub fn RouteDecision::action(self : RouteDecision) -> RoutingAction {
  self.action
}

///|
pub fn RouteDecision::source(self : RouteDecision) -> Int {
  self.source
}

///|
pub fn RouteDecision::destination(self : RouteDecision) -> Int {
  self.destination
}

///|
pub fn RouteDecision::object(self : RouteDecision) -> ApplicationObject {
  self.object
}

///|
pub fn RouteDecision::reason(self : RouteDecision) -> String {
  self.reason
}

///|
pub struct RoutedObject {
  decision : RouteDecision
  timestamp : Int
  sequence : Int
} derive(Debug)

///|
pub fn RoutedObject::decision(self : RoutedObject) -> RouteDecision {
  self.decision
}

///|
pub fn RoutedObject::timestamp(self : RoutedObject) -> Int {
  self.timestamp
}

///|
pub fn RoutedObject::sequence(self : RoutedObject) -> Int {
  self.sequence
}

///|
pub struct RouterMetrics {
  mut evaluated : Int
  mut forwarded : Int
  mut stored : Int
  mut rejected : Int
  mut dropped : Int
  mut queue_overflow : Int
} derive(Eq, Debug)

///|
pub fn RouterMetrics::new() -> RouterMetrics {
  {
    evaluated: 0,
    forwarded: 0,
    stored: 0,
    rejected: 0,
    dropped: 0,
    queue_overflow: 0,
  }
}

///|
pub fn RouterMetrics::evaluated(self : RouterMetrics) -> Int {
  self.evaluated
}

///|
pub fn RouterMetrics::forwarded(self : RouterMetrics) -> Int {
  self.forwarded
}

///|
pub fn RouterMetrics::stored(self : RouterMetrics) -> Int {
  self.stored
}

///|
pub fn RouterMetrics::rejected(self : RouterMetrics) -> Int {
  self.rejected
}

///|
pub fn RouterMetrics::dropped(self : RouterMetrics) -> Int {
  self.dropped
}

///|
pub fn RouterMetrics::queue_overflow(self : RouterMetrics) -> Int {
  self.queue_overflow
}

///|
/// Address/type-aware router with bounded egress queues.
pub struct ProtocolRouter {
  rules : Array[RoutingRule]
  queues : Map[Int, Array[RoutedObject]]
  queue_capacity : Int
  metrics : RouterMetrics
  mut sequence : Int
} derive(Debug)

///|
pub fn ProtocolRouter::new(
  queue_capacity? : Int = 1024,
) -> Result[ProtocolRouter, String] {
  if queue_capacity < 1 {
    Err("router queue capacity must be positive")
  } else {
    Ok({
      rules: [],
      queues: {},
      queue_capacity,
      metrics: RouterMetrics::new(),
      sequence: 1,
    })
  }
}

///|
pub fn ProtocolRouter::metrics(self : ProtocolRouter) -> RouterMetrics {
  self.metrics
}

///|
pub fn ProtocolRouter::rules(self : ProtocolRouter) -> Array[RoutingRule] {
  self.rules.copy()
}

///|
pub fn ProtocolRouter::queue_count(self : ProtocolRouter) -> Int {
  self.queues.length()
}

///|
pub fn ProtocolRouter::add_rule(
  self : ProtocolRouter,
  rule : RoutingRule,
) -> Result[Unit, String] {
  for current in self.rules {
    if current.id() == rule.id() {
      return Err("routing rule id already exists")
    }
  }
  self.rules.push(rule)
  self.rules.sort_by((left, right) => {
    if left.priority() != right.priority() {
      right.priority() - left.priority()
    } else {
      left.id() - right.id()
    }
  })
  Ok(())
}

///|
fn route_matches(
  rule : RoutingRule,
  source : Int,
  destination : Int,
  object : ApplicationObject,
) -> Bool {
  let common_ok = match rule.common_address() {
    Some(value) => value == address_common(object.address())
    None => true
  }
  let type_ok = rule.type_ids().length() == 0 ||
    rule.type_ids().contains(object.type_id())
  rule.enabled() &&
  rule.source() == source &&
  rule.destination() == destination &&
  common_ok &&
  type_ok
}

///|
fn address_common(address : InformationAddress) -> CommonAddress {
  ignore(address)
  CommonAddress::new(1).unwrap()
}

///|
pub fn ProtocolRouter::evaluate(
  self : ProtocolRouter,
  source : Int,
  destination : Int,
  object : ApplicationObject,
) -> RouteDecision {
  self.metrics.evaluated += 1
  let mut selected : RoutingRule? = None
  for rule in self.rules {
    if route_matches(rule, source, destination, object) {
      selected = Some(rule)
      break
    }
  }
  match selected {
    None => {
      self.metrics.rejected += 1
      {
        accepted: false,
        rule_id: None,
        action: RouteReject,
        source,
        destination,
        object,
        reason: "no routing rule matched",
      }
    }
    Some(rule) => {
      let action = rule.action()
      if action == RouteForward || action == RouteStoreAndForward {
        self.metrics.forwarded += 1
      }
      if action == RouteStore {
        self.metrics.stored += 1
      }
      if action == RouteDrop {
        self.metrics.dropped += 1
      }
      {
        accepted: action != RouteReject && action != RouteDrop,
        rule_id: Some(rule.id()),
        action,
        source,
        destination,
        object,
        reason: "routing rule matched",
      }
    }
  }
}

///|
pub fn ProtocolRouter::route(
  self : ProtocolRouter,
  source : Int,
  destination : Int,
  object : ApplicationObject,
  timestamp : Int,
) -> Result[RouteDecision, Diagnostic] {
  let decision = self.evaluate(source, destination, object)
  if !decision.accepted() {
    Err(Diagnostic::new(UnsupportedFeature, decision.reason()))
  } else if decision.action() == RouteStore ||
    decision.action() == RouteStoreAndForward ||
    decision.action() == RouteForward {
    let queue = self.queues.get(destination).unwrap_or([])
    if queue.length() >= self.queue_capacity {
      self.metrics.queue_overflow += 1
      Err(Diagnostic::new(WindowExhausted, "router egress queue is full"))
    } else {
      queue.push({ decision, timestamp, sequence: self.sequence })
      self.sequence += 1
      self.queues[destination] = queue
      if decision.action() == RouteStore ||
        decision.action() == RouteStoreAndForward {
        self.metrics.stored += 1
      }
      Ok(decision)
    }
  } else {
    Ok(decision)
  }
}

///|
pub fn ProtocolRouter::drain(
  self : ProtocolRouter,
  destination : Int,
  limit : Int,
) -> Array[RoutedObject] {
  let result : Array[RoutedObject] = []
  if limit < 1 {
    result
  } else {
    match self.queues.get(destination) {
      None => result
      Some(queue) => {
        let count = if limit > queue.length() { queue.length() } else { limit }
        for _ in 0..<count {
          let value = queue.remove(0)
          result.push(value)
        }
        self.queues[destination] = queue
        result
      }
    }
  }
}

///|
pub fn routing_action_examples() -> Array[RoutingAction] {
  [RouteStore, RouteForward, RouteStoreAndForward, RouteDrop, RouteReject]
}
