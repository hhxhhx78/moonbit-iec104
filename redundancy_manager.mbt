///|
/// Role of a redundant IEC 104 link endpoint.
pub enum RedundantRole {
  PrimaryLink
  StandbyLink
  CandidateLink
  FencedLink
} derive(Eq, Debug)

///|
/// Health state used by the failover election.
pub enum LinkHealth {
  HealthyLink
  SuspectLink
  FailedLink
  RecoveringLink
} derive(Eq, Debug)

///|
/// Why ownership of a redundant station changed.
pub enum FailoverReason {
  StartupElection
  HeartbeatTimeout
  ProtocolFault
  ManualTakeover
  PeerRecovered
  FencingRequired
} derive(Eq, Debug)

///|
pub struct RedundancyPolicy {
  heartbeat_interval : Int
  failure_threshold : Int
  recovery_threshold : Int
  takeover_cooldown : Int
  require_fencing : Bool
} derive(Eq, Debug)

///|
pub fn RedundancyPolicy::new(
  heartbeat_interval? : Int = 5,
  failure_threshold? : Int = 3,
  recovery_threshold? : Int = 2,
  takeover_cooldown? : Int = 10,
  require_fencing? : Bool = true,
) -> Result[RedundancyPolicy, String] {
  if heartbeat_interval < 1 || failure_threshold < 1 || recovery_threshold < 1 {
    Err("redundancy heartbeat thresholds must be positive")
  } else if takeover_cooldown < 0 {
    Err("redundancy takeover cooldown cannot be negative")
  } else {
    Ok({
      heartbeat_interval,
      failure_threshold,
      recovery_threshold,
      takeover_cooldown,
      require_fencing,
    })
  }
}

///|
pub fn RedundancyPolicy::heartbeat_interval(self : RedundancyPolicy) -> Int {
  self.heartbeat_interval
}

///|
pub fn RedundancyPolicy::failure_threshold(self : RedundancyPolicy) -> Int {
  self.failure_threshold
}

///|
pub fn RedundancyPolicy::recovery_threshold(self : RedundancyPolicy) -> Int {
  self.recovery_threshold
}

///|
pub fn RedundancyPolicy::takeover_cooldown(self : RedundancyPolicy) -> Int {
  self.takeover_cooldown
}

///|
pub fn RedundancyPolicy::require_fencing(self : RedundancyPolicy) -> Bool {
  self.require_fencing
}

///|
/// Peer endpoint participating in station ownership election.
pub struct RedundantPeer {
  id : Int
  station : CommonAddress
  priority : Int
  mut role : RedundantRole
  mut health : LinkHealth
  mut missed_heartbeats : Int
  mut recovered_heartbeats : Int
  mut last_heartbeat : Int
  mut fencing_token : Int
  endpoint : String
} derive(Eq, Debug)

///|
pub fn RedundantPeer::new(
  id : Int,
  station : CommonAddress,
  priority : Int,
  endpoint : String,
) -> Result[RedundantPeer, String] {
  if id < 0 || priority < 0 || priority > 255 {
    Err("redundant peer id and priority must fit configured bounds")
  } else if endpoint.length() == 0 {
    Err("redundant peer endpoint is empty")
  } else {
    Ok({
      id,
      station,
      priority,
      role: CandidateLink,
      health: HealthyLink,
      missed_heartbeats: 0,
      recovered_heartbeats: 0,
      last_heartbeat: 0,
      fencing_token: 0,
      endpoint,
    })
  }
}

///|
pub fn RedundantPeer::id(self : RedundantPeer) -> Int {
  self.id
}

///|
pub fn RedundantPeer::station(self : RedundantPeer) -> CommonAddress {
  self.station
}

///|
pub fn RedundantPeer::priority(self : RedundantPeer) -> Int {
  self.priority
}

///|
pub fn RedundantPeer::role(self : RedundantPeer) -> RedundantRole {
  self.role
}

///|
pub fn RedundantPeer::health(self : RedundantPeer) -> LinkHealth {
  self.health
}

///|
pub fn RedundantPeer::missed_heartbeats(self : RedundantPeer) -> Int {
  self.missed_heartbeats
}

///|
pub fn RedundantPeer::recovered_heartbeats(self : RedundantPeer) -> Int {
  self.recovered_heartbeats
}

///|
pub fn RedundantPeer::last_heartbeat(self : RedundantPeer) -> Int {
  self.last_heartbeat
}

///|
pub fn RedundantPeer::fencing_token(self : RedundantPeer) -> Int {
  self.fencing_token
}

///|
pub fn RedundantPeer::endpoint(self : RedundantPeer) -> String {
  self.endpoint
}

///|
/// Ownership transition emitted by the redundancy manager.
pub struct FailoverEvent {
  station : CommonAddress
  from_peer : Int?
  to_peer : Int?
  reason : FailoverReason
  timestamp : Int
  fencing_token : Int
  message : String
} derive(Eq, Debug)

///|
pub fn FailoverEvent::station(self : FailoverEvent) -> CommonAddress {
  self.station
}

///|
pub fn FailoverEvent::from_peer(self : FailoverEvent) -> Int? {
  self.from_peer
}

///|
pub fn FailoverEvent::to_peer(self : FailoverEvent) -> Int? {
  self.to_peer
}

///|
pub fn FailoverEvent::reason(self : FailoverEvent) -> FailoverReason {
  self.reason
}

///|
pub fn FailoverEvent::timestamp(self : FailoverEvent) -> Int {
  self.timestamp
}

///|
pub fn FailoverEvent::fencing_token(self : FailoverEvent) -> Int {
  self.fencing_token
}

///|
pub fn FailoverEvent::message(self : FailoverEvent) -> String {
  self.message
}

///|
/// Runtime metrics for redundant links.
pub struct RedundancyMetrics {
  mut heartbeats : Int
  mut missed : Int
  mut elections : Int
  mut takeovers : Int
  mut recoveries : Int
  mut fenced : Int
} derive(Eq, Debug)

///|
pub fn RedundancyMetrics::new() -> RedundancyMetrics {
  {
    heartbeats: 0,
    missed: 0,
    elections: 0,
    takeovers: 0,
    recoveries: 0,
    fenced: 0,
  }
}

///|
pub fn RedundancyMetrics::heartbeats(self : RedundancyMetrics) -> Int {
  self.heartbeats
}

///|
pub fn RedundancyMetrics::missed(self : RedundancyMetrics) -> Int {
  self.missed
}

///|
pub fn RedundancyMetrics::elections(self : RedundancyMetrics) -> Int {
  self.elections
}

///|
pub fn RedundancyMetrics::takeovers(self : RedundancyMetrics) -> Int {
  self.takeovers
}

///|
pub fn RedundancyMetrics::recoveries(self : RedundancyMetrics) -> Int {
  self.recoveries
}

///|
pub fn RedundancyMetrics::fenced(self : RedundancyMetrics) -> Int {
  self.fenced
}

///|
/// Deterministic primary/standby ownership manager.
pub struct RedundancyManager {
  station : CommonAddress
  peers : Map[Int, RedundantPeer]
  events : Array[FailoverEvent]
  event_limit : Int
  policy : RedundancyPolicy
  mut owner : Int?
  mut last_takeover : Int
  mut fencing_token : Int
  metrics : RedundancyMetrics
} derive(Debug)

///|
pub fn RedundancyManager::new(
  station : CommonAddress,
  policy? : RedundancyPolicy = RedundancyPolicy::new().unwrap(),
  event_limit? : Int = 1024,
) -> Result[RedundancyManager, String] {
  if event_limit < 1 {
    Err("redundancy event limit must be positive")
  } else {
    Ok({
      station,
      peers: {},
      events: [],
      event_limit,
      policy,
      owner: None,
      last_takeover: 0,
      fencing_token: 0,
      metrics: RedundancyMetrics::new(),
    })
  }
}

///|
pub fn RedundancyManager::station(self : RedundancyManager) -> CommonAddress {
  self.station
}

///|
pub fn RedundancyManager::policy(self : RedundancyManager) -> RedundancyPolicy {
  self.policy
}

///|
pub fn RedundancyManager::owner(self : RedundancyManager) -> Int? {
  self.owner
}

///|
pub fn RedundancyManager::fencing_token(self : RedundancyManager) -> Int {
  self.fencing_token
}

///|
pub fn RedundancyManager::metrics(
  self : RedundancyManager,
) -> RedundancyMetrics {
  self.metrics
}

///|
pub fn RedundancyManager::events(
  self : RedundancyManager,
) -> Array[FailoverEvent] {
  self.events.copy()
}

///|
pub fn RedundancyManager::peer_count(self : RedundancyManager) -> Int {
  self.peers.length()
}

///|
pub fn RedundancyManager::peer(
  self : RedundancyManager,
  id : Int,
) -> RedundantPeer? {
  self.peers.get(id)
}

///|
pub fn RedundancyManager::add_peer(
  self : RedundancyManager,
  peer : RedundantPeer,
) -> Result[Unit, String] {
  if peer.station() != self.station {
    Err("redundant peer belongs to another station")
  } else if self.peers.contains(peer.id()) {
    Err("redundant peer id already exists")
  } else {
    self.peers[peer.id()] = peer
    Ok(())
  }
}

///|
pub fn RedundancyManager::remove_peer(
  self : RedundancyManager,
  id : Int,
) -> Result[Unit, String] {
  match self.peers.get(id) {
    None => Err("redundant peer does not exist")
    Some(_) => {
      self.peers.remove(id)
      if self.owner is Some(value) && value == id {
        self.owner = None
      }
      Ok(())
    }
  }
}

///|
fn RedundancyManager::event(
  self : RedundancyManager,
  from_peer : Int?,
  to_peer : Int?,
  reason : FailoverReason,
  timestamp : Int,
  message : String,
) -> FailoverEvent {
  let value = {
    station: self.station,
    from_peer,
    to_peer,
    reason,
    timestamp,
    fencing_token: self.fencing_token,
    message,
  }
  self.events.push(value)
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
  value
}

///|
fn redundancy_peer_order(left : RedundantPeer, right : RedundantPeer) -> Int {
  if left.priority() != right.priority() {
    right.priority() - left.priority()
  } else {
    left.id() - right.id()
  }
}

///|
fn RedundancyManager::eligible(
  self : RedundancyManager,
  now : Int,
) -> Array[RedundantPeer] {
  let candidates : Array[RedundantPeer] = []
  for _, peer in self.peers {
    let fresh = now - peer.last_heartbeat() <=
      self.policy.heartbeat_interval() * self.policy.failure_threshold()
    if peer.role() != FencedLink &&
      (peer.health() == HealthyLink || peer.health() == RecoveringLink) &&
      fresh {
      candidates.push(peer)
    }
  }
  candidates.sort_by(redundancy_peer_order)
  candidates
}

///|
pub fn RedundancyManager::elect(
  self : RedundancyManager,
  now : Int,
) -> Result[FailoverEvent?, String] {
  let candidates = self.eligible(now)
  self.metrics.elections += 1
  match candidates.get(0) {
    None => {
      self.owner = None
      Ok(
        Some(
          self.event(
            self.owner,
            None,
            FencingRequired,
            now,
            "no healthy redundant peer",
          ),
        ),
      )
    }
    Some(candidate) =>
      if self.owner is Some(current) && current == candidate.id() {
        Ok(None)
      } else if now - self.last_takeover < self.policy.takeover_cooldown() &&
        self.owner is Some(_) {
        Err("redundancy takeover is in cooldown")
      } else {
        let previous = self.owner
        self.fencing_token += 1
        self.last_takeover = now
        self.owner = Some(candidate.id())
        let selected = self.peers[candidate.id()]
        selected.role = PrimaryLink
        selected.fencing_token = self.fencing_token
        self.peers[candidate.id()] = selected
        if previous is Some(old) && self.peers.get(old) is Some(old_peer) {
          old_peer.role = StandbyLink
          self.peers[old] = old_peer
        }
        self.metrics.takeovers += 1
        Ok(
          Some(
            self.event(
              previous,
              Some(candidate.id()),
              StartupElection,
              now,
              "primary link elected",
            ),
          ),
        )
      }
  }
}

///|
pub fn RedundancyManager::heartbeat(
  self : RedundancyManager,
  id : Int,
  now : Int,
) -> Result[LinkHealth, String] {
  match self.peers.get(id) {
    None => Err("unknown redundant peer")
    Some(peer) => {
      peer.last_heartbeat = now
      peer.missed_heartbeats = 0
      peer.recovered_heartbeats += 1
      self.metrics.heartbeats += 1
      if peer.health() == FailedLink || peer.health() == SuspectLink {
        peer.health = RecoveringLink
        if peer.recovered_heartbeats >= self.policy.recovery_threshold() {
          peer.health = HealthyLink
          peer.recovered_heartbeats = 0
          self.metrics.recoveries += 1
        }
      }
      self.peers[id] = peer
      Ok(peer.health())
    }
  }
}

///|
pub fn RedundancyManager::tick(
  self : RedundancyManager,
  now : Int,
) -> Array[FailoverEvent] {
  let transitions : Array[FailoverEvent] = []
  for id, peer in self.peers {
    if now - peer.last_heartbeat > self.policy.heartbeat_interval() {
      peer.missed_heartbeats += 1
      self.metrics.missed += 1
      peer.recovered_heartbeats = 0
      if peer.missed_heartbeats >= self.policy.failure_threshold() {
        peer.health = FailedLink
        if self.owner is Some(owner) && owner == id {
          self.owner = None
          self.fencing_token += 1
          if self.policy.require_fencing() {
            peer.role = FencedLink
            self.metrics.fenced += 1
          }
          transitions.push(
            self.event(
              Some(id),
              None,
              HeartbeatTimeout,
              now,
              "primary heartbeat timeout",
            ),
          )
        }
      } else {
        peer.health = SuspectLink
      }
      self.peers[id] = peer
    }
  }
  transitions
}

///|
pub fn RedundancyManager::manual_takeover(
  self : RedundancyManager,
  id : Int,
  now : Int,
) -> Result[FailoverEvent, String] {
  match self.peers.get(id) {
    None => Err("unknown redundant peer")
    Some(peer) =>
      if peer.role() == FencedLink || peer.health() == FailedLink {
        Err("fenced or failed peer cannot take ownership")
      } else {
        let previous = self.owner
        self.fencing_token += 1
        self.owner = Some(id)
        self.last_takeover = now
        peer.role = PrimaryLink
        peer.fencing_token = self.fencing_token
        self.peers[id] = peer
        self.metrics.takeovers += 1
        Ok(
          self.event(
            previous,
            Some(id),
            ManualTakeover,
            now,
            "manual primary takeover",
          ),
        )
      }
  }
}

///|
pub fn RedundantRole::examples() -> Array[RedundantRole] {
  [PrimaryLink, StandbyLink, CandidateLink, FencedLink]
}

///|
pub fn LinkHealth::examples() -> Array[LinkHealth] {
  [HealthyLink, SuspectLink, FailedLink, RecoveringLink]
}

///|
pub fn failover_reason_examples() -> Array[FailoverReason] {
  [
    StartupElection,
    HeartbeatTimeout,
    ProtocolFault,
    ManualTakeover,
    PeerRecovered,
    FencingRequired,
  ]
}
