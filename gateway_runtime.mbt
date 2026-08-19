///|
/// Lifecycle of an in-memory IEC 104 gateway runtime.
pub enum GatewayMode {
  Stopped
  Starting
  Running
  Draining
  Faulted(String)
} derive(Eq, Debug)

///|
pub fn GatewayMode::is_accepting(self : GatewayMode) -> Bool {
  self == Running
}

///|
pub fn GatewayMode::is_quiescent(self : GatewayMode) -> Bool {
  self == Stopped || self == Draining || self is Faulted(_)
}

///|
pub fn GatewayMode::name(self : GatewayMode) -> String {
  match self {
    Stopped => "stopped"
    Starting => "starting"
    Running => "running"
    Draining => "draining"
    Faulted(_) => "faulted"
  }
}

///|
/// Admission policy applied before a gateway accepts an ASDU.
pub struct GatewayAdmissionPolicy {
  max_objects : Int
  allow_monitoring : Bool
  allow_control : Bool
  allowed_types : Array[ApplicationType]
  denied_types : Array[ApplicationType]
} derive(Eq, Debug)

///|
pub fn GatewayAdmissionPolicy::default() -> GatewayAdmissionPolicy {
  {
    max_objects: 127,
    allow_monitoring: true,
    allow_control: true,
    allowed_types: [],
    denied_types: [],
  }
}

///|
pub fn GatewayAdmissionPolicy::new(
  max_objects : Int,
  allow_monitoring? : Bool = true,
  allow_control? : Bool = true,
) -> Result[GatewayAdmissionPolicy, String] {
  if max_objects < 1 || max_objects > 127 {
    Err("gateway object limit must be between 1 and 127")
  } else {
    Ok({
      max_objects,
      allow_monitoring,
      allow_control,
      allowed_types: [],
      denied_types: [],
    })
  }
}

///|
pub fn GatewayAdmissionPolicy::max_objects(
  self : GatewayAdmissionPolicy,
) -> Int {
  self.max_objects
}

///|
pub fn GatewayAdmissionPolicy::allow_type(
  self : GatewayAdmissionPolicy,
  type_id : ApplicationType,
) -> Unit {
  if !self.allowed_types.contains(type_id) {
    self.allowed_types.push(type_id)
  }
}

///|
pub fn GatewayAdmissionPolicy::deny_type(
  self : GatewayAdmissionPolicy,
  type_id : ApplicationType,
) -> Unit {
  if !self.denied_types.contains(type_id) {
    self.denied_types.push(type_id)
  }
}

///|
fn gateway_type_allowed(
  policy : GatewayAdmissionPolicy,
  type_id : ApplicationType,
) -> Bool {
  let direction_allowed = if type_id.is_monitoring() {
    policy.allow_monitoring
  } else {
    policy.allow_control
  }
  let allow_list_matches = policy.allowed_types.length() == 0 ||
    policy.allowed_types.contains(type_id)
  direction_allowed &&
  allow_list_matches &&
  !policy.denied_types.contains(type_id)
}

///|
pub fn GatewayAdmissionPolicy::evaluate(
  self : GatewayAdmissionPolicy,
  envelope : AsduEnvelope,
) -> Result[Unit, String] {
  if envelope.count() < 1 {
    Err("gateway cannot admit an empty ASDU")
  } else if envelope.count() > self.max_objects {
    Err("ASDU object count exceeds gateway admission limit")
  } else if !gateway_type_allowed(self, envelope.type_id()) {
    Err("ASDU type is not allowed by the gateway policy")
  } else {
    for object in envelope.objects() {
      if object.type_id() != envelope.type_id() {
        return Err("ASDU object type does not match its envelope")
      }
    }
    Ok(())
  }
}

///|
/// A route between two logical gateway endpoints.
pub struct GatewayRoute {
  id : Int
  source : Int
  destination : Int
  common_address : CommonAddress?
  type_ids : Array[ApplicationType]
  mut enabled : Bool
  priority : Int
} derive(Eq, Debug)

///|
pub fn GatewayRoute::new(
  id : Int,
  source : Int,
  destination : Int,
  common_address? : CommonAddress,
  type_ids? : Array[ApplicationType] = [],
  priority? : Int = 0,
) -> Result[GatewayRoute, String] {
  if id < 0 {
    Err("route id cannot be negative")
  } else if source < 0 || destination < 0 || source == destination {
    Err("route endpoints must be distinct non-negative values")
  } else if priority < 0 || priority > 255 {
    Err("route priority must fit one byte")
  } else {
    Ok({
      id,
      source,
      destination,
      common_address,
      type_ids: type_ids.copy(),
      enabled: true,
      priority,
    })
  }
}

///|
pub fn GatewayRoute::id(self : GatewayRoute) -> Int {
  self.id
}

///|
pub fn GatewayRoute::source(self : GatewayRoute) -> Int {
  self.source
}

///|
pub fn GatewayRoute::destination(self : GatewayRoute) -> Int {
  self.destination
}

///|
pub fn GatewayRoute::priority(self : GatewayRoute) -> Int {
  self.priority
}

///|
pub fn GatewayRoute::enabled(self : GatewayRoute) -> Bool {
  self.enabled
}

///|
pub fn GatewayRoute::set_enabled(self : GatewayRoute, enabled : Bool) -> Unit {
  self.enabled = enabled
}

///|
pub fn GatewayRoute::common_address(self : GatewayRoute) -> CommonAddress? {
  self.common_address
}

///|
pub fn GatewayRoute::type_ids(self : GatewayRoute) -> Array[ApplicationType] {
  self.type_ids.copy()
}

///|
fn GatewayRoute::matches(
  self : GatewayRoute,
  source : Int,
  common_address : CommonAddress,
  type_id : ApplicationType,
) -> Bool {
  let source_ok = self.source == source
  let common_ok = match self.common_address {
    Some(value) => value == common_address
    None => true
  }
  let type_ok = self.type_ids.length() == 0 || self.type_ids.contains(type_id)
  self.enabled && source_ok && common_ok && type_ok
}

///|
pub fn GatewayRoute::describe(self : GatewayRoute) -> String {
  let common = match self.common_address {
    Some(value) => " common=\{value.number()}"
    None => ""
  }
  "route#\{self.id} \{self.source}->\{self.destination} priority=\{self.priority} enabled=\{self.enabled}\{common}"
}

///|
/// Deterministic route table. Higher priority wins; ties use the lower route id.
pub struct GatewayRouteTable {
  routes : Array[GatewayRoute]
  capacity : Int
} derive(Debug)

///|
pub fn GatewayRouteTable::new(
  capacity? : Int = 256,
) -> Result[GatewayRouteTable, String] {
  if capacity < 1 || capacity > 4096 {
    Err("route table capacity must be between 1 and 4096")
  } else {
    Ok({ routes: [], capacity })
  }
}

///|
pub fn GatewayRouteTable::len(self : GatewayRouteTable) -> Int {
  self.routes.length()
}

///|
pub fn GatewayRouteTable::capacity(self : GatewayRouteTable) -> Int {
  self.capacity
}

///|
pub fn GatewayRouteTable::routes(
  self : GatewayRouteTable,
) -> Array[GatewayRoute] {
  self.routes.copy()
}

///|
pub fn GatewayRouteTable::add(
  self : GatewayRouteTable,
  route : GatewayRoute,
) -> Result[Unit, String] {
  if self.routes.length() >= self.capacity {
    Err("route table is full")
  } else {
    for existing in self.routes {
      if existing.id() == route.id() {
        return Err("route id already exists")
      }
    }
    self.routes.push(route)
    Ok(())
  }
}

///|
pub fn GatewayRouteTable::remove(
  self : GatewayRouteTable,
  route_id : Int,
) -> Bool {
  for index in 0..<self.routes.length() {
    if self.routes[index].id() == route_id {
      ignore(self.routes.remove(index))
      return true
    }
  }
  false
}

///|
pub fn GatewayRouteTable::set_enabled(
  self : GatewayRouteTable,
  route_id : Int,
  enabled : Bool,
) -> Bool {
  for route in self.routes {
    if route.id() == route_id {
      route.set_enabled(enabled)
      return true
    }
  }
  false
}

///|
pub fn GatewayRouteTable::select(
  self : GatewayRouteTable,
  source : Int,
  common_address : CommonAddress,
  type_id : ApplicationType,
) -> GatewayRoute? {
  let mut selected : GatewayRoute? = None
  for route in self.routes {
    if route.matches(source, common_address, type_id) {
      match selected {
        None => selected = Some(route)
        Some(current) =>
          if route.priority() > current.priority() ||
            (
              route.priority() == current.priority() &&
              route.id() < current.id()
            ) {
            selected = Some(route)
          }
      }
    }
  }
  selected
}

///|
/// An ASDU together with gateway ingress metadata.
pub struct GatewayEnvelope {
  ingress : Int
  egress : Int
  common_address : CommonAddress
  asdu : AsduEnvelope
  received_at : Int
  trace_id : String
} derive(Debug)

///|
pub fn GatewayEnvelope::new(
  ingress : Int,
  egress : Int,
  asdu : AsduEnvelope,
  received_at : Int,
  trace_id? : String = "",
) -> Result[GatewayEnvelope, String] {
  if ingress < 0 || egress < 0 || ingress == egress {
    Err("gateway envelope endpoints are invalid")
  } else if received_at < 0 {
    Err("gateway envelope timestamp cannot be negative")
  } else if asdu.count() < 1 {
    Err("gateway envelope cannot contain an empty ASDU")
  } else if trace_id.length() > 128 {
    Err("gateway trace id is too long")
  } else {
    Ok({
      ingress,
      egress,
      common_address: asdu.common_address(),
      asdu,
      received_at,
      trace_id,
    })
  }
}

///|
pub fn GatewayEnvelope::ingress(self : GatewayEnvelope) -> Int {
  self.ingress
}

///|
pub fn GatewayEnvelope::egress(self : GatewayEnvelope) -> Int {
  self.egress
}

///|
pub fn GatewayEnvelope::common_address(self : GatewayEnvelope) -> CommonAddress {
  self.common_address
}

///|
pub fn GatewayEnvelope::asdu(self : GatewayEnvelope) -> AsduEnvelope {
  self.asdu
}

///|
pub fn GatewayEnvelope::received_at(self : GatewayEnvelope) -> Int {
  self.received_at
}

///|
pub fn GatewayEnvelope::trace_id(self : GatewayEnvelope) -> String {
  self.trace_id
}

///|
pub fn GatewayEnvelope::object_count(self : GatewayEnvelope) -> Int {
  self.asdu.count()
}

///|
fn GatewayEnvelope::forward_to(
  self : GatewayEnvelope,
  destination : Int,
  route_id : Int,
) -> GatewayEnvelope {
  {
    ingress: self.ingress,
    egress: destination,
    common_address: self.common_address,
    asdu: self.asdu,
    received_at: self.received_at,
    trace_id: if self.trace_id == "" {
      "route-\{route_id}"
    } else {
      "\{self.trace_id} via route-\{route_id}"
    },
  }
}

///|
pub enum GatewayDispatch {
  Forwarded(GatewayEnvelope, GatewayRoute)
  Dropped(GatewayEnvelope, String)
} derive(Debug)

///|
pub fn GatewayDispatch::envelope(self : GatewayDispatch) -> GatewayEnvelope {
  match self {
    Forwarded(envelope, _) => envelope
    Dropped(envelope, _) => envelope
  }
}

///|
pub fn GatewayDispatch::is_forwarded(self : GatewayDispatch) -> Bool {
  self is Forwarded(_, _)
}

///|
pub fn GatewayDispatch::message(self : GatewayDispatch) -> String {
  match self {
    Forwarded(_, route) => route.describe()
    Dropped(_, reason) => reason
  }
}

///|
/// Counters exposed by the gateway for operational dashboards.
pub struct GatewayCounters {
  mut accepted : Int
  mut forwarded : Int
  mut dropped : Int
  mut rejected : Int
  mut stored : Int
} derive(Eq, Debug)

///|
pub fn GatewayCounters::empty() -> GatewayCounters {
  { accepted: 0, forwarded: 0, dropped: 0, rejected: 0, stored: 0 }
}

///|
pub fn GatewayCounters::accepted(self : GatewayCounters) -> Int {
  self.accepted
}

///|
pub fn GatewayCounters::forwarded(self : GatewayCounters) -> Int {
  self.forwarded
}

///|
pub fn GatewayCounters::dropped(self : GatewayCounters) -> Int {
  self.dropped
}

///|
pub fn GatewayCounters::rejected(self : GatewayCounters) -> Int {
  self.rejected
}

///|
pub fn GatewayCounters::stored(self : GatewayCounters) -> Int {
  self.stored
}

///|
pub fn GatewayCounters::total(self : GatewayCounters) -> Int {
  self.accepted + self.forwarded + self.dropped + self.rejected
}

///|
/// A point store attached to one common address in the gateway.
pub struct GatewayStoreBinding {
  common_address : CommonAddress
  store : PointStore
  mut accepted : Int
  mut rejected : Int
} derive(Debug)

///|
pub fn GatewayStoreBinding::new(
  common_address : CommonAddress,
  history_limit? : Int = 1024,
) -> Result[GatewayStoreBinding, String] {
  match PointStore::new(common_address, history_limit~) {
    Err(error) => Err(error)
    Ok(store) => Ok({ common_address, store, accepted: 0, rejected: 0 })
  }
}

///|
pub fn GatewayStoreBinding::common_address(
  self : GatewayStoreBinding,
) -> CommonAddress {
  self.common_address
}

///|
pub fn GatewayStoreBinding::store(self : GatewayStoreBinding) -> PointStore {
  self.store
}

///|
pub fn GatewayStoreBinding::accepted(self : GatewayStoreBinding) -> Int {
  self.accepted
}

///|
pub fn GatewayStoreBinding::rejected(self : GatewayStoreBinding) -> Int {
  self.rejected
}

///|
pub fn GatewayStoreBinding::ingest(
  self : GatewayStoreBinding,
  envelope : GatewayEnvelope,
) -> Result[Int, String] {
  if envelope.common_address() != self.common_address {
    Err("envelope common address does not match attached point store")
  } else {
    let mut count = 0
    for object in envelope.asdu().objects() {
      match
        self.store.upsert(object, envelope.received_at(), source="gateway") {
        Err(error) => {
          self.rejected += 1
          return Err(error.to_line())
        }
        Ok(_) => {
          self.accepted += 1
          count += 1
        }
      }
    }
    Ok(count)
  }
}

///|
/// Snapshot suitable for a health endpoint or a periodic metrics export.
pub struct GatewaySnapshot {
  mode : GatewayMode
  routes : Int
  queue : Int
  outbound : Int
  dead_letters : Int
  counters : GatewayCounters
  last_error : String?
} derive(Eq, Debug)

///|
pub fn GatewaySnapshot::mode(self : GatewaySnapshot) -> GatewayMode {
  self.mode
}

///|
pub fn GatewaySnapshot::routes(self : GatewaySnapshot) -> Int {
  self.routes
}

///|
pub fn GatewaySnapshot::queue(self : GatewaySnapshot) -> Int {
  self.queue
}

///|
pub fn GatewaySnapshot::outbound(self : GatewaySnapshot) -> Int {
  self.outbound
}

///|
pub fn GatewaySnapshot::dead_letters(self : GatewaySnapshot) -> Int {
  self.dead_letters
}

///|
pub fn GatewaySnapshot::counters(self : GatewaySnapshot) -> GatewayCounters {
  self.counters
}

///|
pub fn GatewaySnapshot::last_error(self : GatewaySnapshot) -> String? {
  self.last_error
}

///|
/// Deterministic in-memory routing runtime. Network adapters can feed its queue
/// and poll the outbound queue without coupling protocol logic to a socket API.
pub struct GatewayRuntime {
  mut mode : GatewayMode
  routes : GatewayRouteTable
  mut policy : GatewayAdmissionPolicy
  inbound : Array[GatewayEnvelope]
  outbound : Array[GatewayEnvelope]
  dead_letters : Array[GatewayEnvelope]
  stores : Array[GatewayStoreBinding]
  counters : GatewayCounters
  max_queue : Int
  mut last_error : String?
} derive(Debug)

///|
pub fn GatewayRuntime::new(
  max_queue : Int,
  route_capacity? : Int = 256,
  policy? : GatewayAdmissionPolicy = GatewayAdmissionPolicy::default(),
) -> Result[GatewayRuntime, String] {
  if max_queue < 1 || max_queue > 65536 {
    Err("gateway queue limit must be between 1 and 65536")
  } else {
    match GatewayRouteTable::new(capacity=route_capacity) {
      Err(error) => Err(error)
      Ok(routes) =>
        Ok({
          mode: Stopped,
          routes,
          policy,
          inbound: [],
          outbound: [],
          dead_letters: [],
          stores: [],
          counters: GatewayCounters::empty(),
          max_queue,
          last_error: None,
        })
    }
  }
}

///|
pub fn GatewayRuntime::mode(self : GatewayRuntime) -> GatewayMode {
  self.mode
}

///|
pub fn GatewayRuntime::start(self : GatewayRuntime) -> Result[Unit, String] {
  match self.mode {
    Stopped => {
      self.mode = Starting
      self.mode = Running
      Ok(())
    }
    Running => Err("gateway is already running")
    Starting => Err("gateway is already starting")
    Draining => Err("gateway is draining")
    Faulted(message) => Err("gateway is faulted: \{message}")
  }
}

///|
pub fn GatewayRuntime::begin_drain(
  self : GatewayRuntime,
) -> Result[Unit, String] {
  if self.mode == Running {
    self.mode = Draining
    Ok(())
  } else {
    Err("gateway must be running before draining")
  }
}

///|
pub fn GatewayRuntime::stop(self : GatewayRuntime) -> Result[Unit, String] {
  if self.inbound.length() != 0 {
    Err("gateway has pending inbound envelopes")
  } else {
    self.mode = Stopped
    Ok(())
  }
}

///|
pub fn GatewayRuntime::fail(self : GatewayRuntime, message : String) -> Unit {
  self.last_error = Some(message)
  self.mode = Faulted(message)
}

///|
pub fn GatewayRuntime::routes(self : GatewayRuntime) -> GatewayRouteTable {
  self.routes
}

///|
pub fn GatewayRuntime::add_route(
  self : GatewayRuntime,
  route : GatewayRoute,
) -> Result[Unit, String] {
  self.routes.add(route)
}

///|
pub fn GatewayRuntime::remove_route(
  self : GatewayRuntime,
  route_id : Int,
) -> Bool {
  self.routes.remove(route_id)
}

///|
pub fn GatewayRuntime::attach_store(
  self : GatewayRuntime,
  binding : GatewayStoreBinding,
) -> Result[Unit, String] {
  for existing in self.stores {
    if existing.common_address() == binding.common_address() {
      return Err("point store is already attached to this common address")
    }
  }
  self.stores.push(binding)
  Ok(())
}

///|
pub fn GatewayRuntime::store_count(self : GatewayRuntime) -> Int {
  self.stores.length()
}

///|
pub fn GatewayRuntime::set_policy(
  self : GatewayRuntime,
  policy : GatewayAdmissionPolicy,
) -> Unit {
  self.policy = policy
}

///|
pub fn GatewayRuntime::queue_len(self : GatewayRuntime) -> Int {
  self.inbound.length()
}

///|
pub fn GatewayRuntime::outbound_len(self : GatewayRuntime) -> Int {
  self.outbound.length()
}

///|
pub fn GatewayRuntime::dead_letter_len(self : GatewayRuntime) -> Int {
  self.dead_letters.length()
}

///|
pub fn GatewayRuntime::counters(self : GatewayRuntime) -> GatewayCounters {
  self.counters
}

///|
pub fn GatewayRuntime::last_error(self : GatewayRuntime) -> String? {
  self.last_error
}

///|
pub fn GatewayRuntime::enqueue(
  self : GatewayRuntime,
  envelope : GatewayEnvelope,
) -> Result[Unit, String] {
  if !self.mode.is_accepting() {
    self.counters.rejected += 1
    Err("gateway is not accepting envelopes")
  } else if self.inbound.length() >= self.max_queue {
    self.counters.rejected += 1
    Err("gateway inbound queue is full")
  } else {
    match self.policy.evaluate(envelope.asdu()) {
      Err(error) => {
        self.counters.rejected += 1
        self.last_error = Some(error)
        Err(error)
      }
      Ok(_) => {
        self.inbound.push(envelope)
        self.counters.accepted += 1
        Ok(())
      }
    }
  }
}

///|
pub fn GatewayRuntime::ingest_to_store(
  self : GatewayRuntime,
  envelope : GatewayEnvelope,
) -> Result[Int, String] {
  match self.find_store(envelope.common_address()) {
    None => Err("no point store is attached to the envelope common address")
    Some(binding) =>
      match binding.ingest(envelope) {
        Err(error) => Err(error)
        Ok(count) => {
          self.counters.stored += count
          Ok(count)
        }
      }
  }
}

///|
fn GatewayRuntime::find_store(
  self : GatewayRuntime,
  common_address : CommonAddress,
) -> GatewayStoreBinding? {
  for binding in self.stores {
    if binding.common_address() == common_address {
      return Some(binding)
    }
  }
  None
}

///|
fn GatewayRuntime::process_one(self : GatewayRuntime) -> GatewayDispatch? {
  if self.inbound.length() == 0 {
    None
  } else {
    let envelope = self.inbound.remove(0)
    match
      self.routes.select(
        envelope.ingress(),
        envelope.common_address(),
        envelope.asdu().type_id(),
      ) {
      None => {
        self.counters.dropped += 1
        self.dead_letters.push(envelope)
        Some(Dropped(envelope, "no matching gateway route"))
      }
      Some(route) => {
        let forwarded = envelope.forward_to(route.destination(), route.id())
        self.outbound.push(forwarded)
        self.counters.forwarded += envelope.object_count()
        Some(Forwarded(forwarded, route))
      }
    }
  }
}

///|
pub fn GatewayRuntime::drain(
  self : GatewayRuntime,
  max_dispatches? : Int = 1024,
) -> Array[GatewayDispatch] {
  let limit = if max_dispatches < 1 { 1 } else { max_dispatches }
  let result : Array[GatewayDispatch] = []
  let mut count = 0
  while count < limit {
    match self.process_one() {
      None => break
      Some(dispatch) => {
        result.push(dispatch)
        count += 1
      }
    }
  }
  result
}

///|
pub fn GatewayRuntime::poll_outbound(self : GatewayRuntime) -> GatewayEnvelope? {
  if self.outbound.length() == 0 {
    None
  } else {
    Some(self.outbound.remove(0))
  }
}

///|
pub fn GatewayRuntime::take_dead_letter(
  self : GatewayRuntime,
) -> GatewayEnvelope? {
  if self.dead_letters.length() == 0 {
    None
  } else {
    Some(self.dead_letters.remove(0))
  }
}

///|
pub fn GatewayRuntime::snapshot(self : GatewayRuntime) -> GatewaySnapshot {
  {
    mode: self.mode,
    routes: self.routes.len(),
    queue: self.inbound.length(),
    outbound: self.outbound.length(),
    dead_letters: self.dead_letters.length(),
    counters: self.counters,
    last_error: self.last_error,
  }
}

///|
/// Return a stable, line-oriented diagnostics report for logs and health probes.
pub fn GatewayRuntime::diagnostics(self : GatewayRuntime) -> String {
  let snapshot = self.snapshot()
  "mode=\{snapshot.mode().name()} routes=\{snapshot.routes()} queue=\{snapshot.queue()} outbound=\{snapshot.outbound()} dead_letters=\{snapshot.dead_letters()} accepted=\{snapshot.counters().accepted()} forwarded=\{snapshot.counters().forwarded()} dropped=\{snapshot.counters().dropped()} rejected=\{snapshot.counters().rejected()} stored=\{snapshot.counters().stored()}"
}
