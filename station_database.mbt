///|
/// Lifecycle state of an IEC 104 station in the local operational database.
pub enum StationStatus {
  Provisioned
  Online
  Degraded
  Offline
  Quarantined
} derive(Eq, Debug)

///|
/// The reason recorded when the station state changes.
pub enum StationStateReason {
  ProvisionedByOperator
  LinkEstablished
  LinkLost
  HeartbeatMissed
  ProtocolError
  QualityDegraded
  ManualQuarantine
  ManualRelease
  MaintenanceWindow
} derive(Eq, Debug)

///|
/// An immutable station identity and deployment configuration.
pub struct StationConfig {
  common_address : CommonAddress
  name : String
  location : String
  owner : String
  point_capacity : Int
  history_limit : Int
  heartbeat_interval : Int
  tags : Array[String]
  enabled : Bool
} derive(Eq, Debug)

///|
/// Build a station configuration with conservative operational defaults.
pub fn StationConfig::new(
  common_address : CommonAddress,
  name : String,
  location? : String = "",
  owner? : String = "",
  point_capacity? : Int = 4096,
  history_limit? : Int = 4096,
  heartbeat_interval? : Int = 20,
  tags? : Array[String] = [],
  enabled? : Bool = true,
) -> Result[StationConfig, String] {
  if common_address.is_global() {
    Err("station configuration cannot use the global common address")
  } else if name.length() == 0 || name.length() > 128 {
    Err("station name must contain between 1 and 128 characters")
  } else if point_capacity < 1 {
    Err("station point capacity must be positive")
  } else if history_limit < 1 {
    Err("station history limit must be positive")
  } else if heartbeat_interval < 1 || heartbeat_interval > 86400 {
    Err("heartbeat interval must be between 1 and 86400 seconds")
  } else {
    Ok({
      common_address,
      name,
      location,
      owner,
      point_capacity,
      history_limit,
      heartbeat_interval,
      tags: tags.copy(),
      enabled,
    })
  }
}

///|
pub fn StationConfig::common_address(self : StationConfig) -> CommonAddress {
  self.common_address
}

///|
pub fn StationConfig::name(self : StationConfig) -> String {
  self.name
}

///|
pub fn StationConfig::location(self : StationConfig) -> String {
  self.location
}

///|
pub fn StationConfig::owner(self : StationConfig) -> String {
  self.owner
}

///|
pub fn StationConfig::point_capacity(self : StationConfig) -> Int {
  self.point_capacity
}

///|
pub fn StationConfig::history_limit(self : StationConfig) -> Int {
  self.history_limit
}

///|
pub fn StationConfig::heartbeat_interval(self : StationConfig) -> Int {
  self.heartbeat_interval
}

///|
pub fn StationConfig::tags(self : StationConfig) -> Array[String] {
  self.tags.copy()
}

///|
pub fn StationConfig::enabled(self : StationConfig) -> Bool {
  self.enabled
}

///|
pub fn StationConfig::with_tags(
  self : StationConfig,
  tags : Array[String],
) -> StationConfig {
  {
    common_address: self.common_address,
    name: self.name,
    location: self.location,
    owner: self.owner,
    point_capacity: self.point_capacity,
    history_limit: self.history_limit,
    heartbeat_interval: self.heartbeat_interval,
    tags: tags.copy(),
    enabled: self.enabled,
  }
}

///|
pub fn StationConfig::with_enabled(
  self : StationConfig,
  enabled : Bool,
) -> StationConfig {
  {
    common_address: self.common_address,
    name: self.name,
    location: self.location,
    owner: self.owner,
    point_capacity: self.point_capacity,
    history_limit: self.history_limit,
    heartbeat_interval: self.heartbeat_interval,
    tags: self.tags.copy(),
    enabled,
  }
}

///|
/// A state transition stored in the station audit stream.
pub struct StationStateChange {
  common_address : CommonAddress
  from : StationStatus
  to : StationStatus
  reason : StationStateReason
  timestamp : Int
  revision : Int
  message : String
} derive(Eq, Debug)

///|
pub fn StationStateChange::new(
  common_address : CommonAddress,
  from : StationStatus,
  to : StationStatus,
  reason : StationStateReason,
  timestamp : Int,
  revision : Int,
  message? : String = "",
) -> StationStateChange {
  { common_address, from, to, reason, timestamp, revision, message }
}

///|
pub fn StationStateChange::common_address(
  self : StationStateChange,
) -> CommonAddress {
  self.common_address
}

///|
pub fn StationStateChange::from(self : StationStateChange) -> StationStatus {
  self.from
}

///|
pub fn StationStateChange::to(self : StationStateChange) -> StationStatus {
  self.to
}

///|
pub fn StationStateChange::reason(
  self : StationStateChange,
) -> StationStateReason {
  self.reason
}

///|
pub fn StationStateChange::timestamp(self : StationStateChange) -> Int {
  self.timestamp
}

///|
pub fn StationStateChange::revision(self : StationStateChange) -> Int {
  self.revision
}

///|
pub fn StationStateChange::message(self : StationStateChange) -> String {
  self.message
}

///|
/// Operational counters for one station.
pub struct StationCounters {
  mut received_updates : Int
  mut accepted_updates : Int
  mut rejected_updates : Int
  mut commands : Int
  mut command_failures : Int
  mut heartbeat_misses : Int
  mut quality_events : Int
  mut bytes_received : Int
  mut bytes_sent : Int
} derive(Eq, Debug)

///|
pub fn StationCounters::new() -> StationCounters {
  {
    received_updates: 0,
    accepted_updates: 0,
    rejected_updates: 0,
    commands: 0,
    command_failures: 0,
    heartbeat_misses: 0,
    quality_events: 0,
    bytes_received: 0,
    bytes_sent: 0,
  }
}

///|
pub fn StationCounters::received_updates(self : StationCounters) -> Int {
  self.received_updates
}

///|
pub fn StationCounters::accepted_updates(self : StationCounters) -> Int {
  self.accepted_updates
}

///|
pub fn StationCounters::rejected_updates(self : StationCounters) -> Int {
  self.rejected_updates
}

///|
pub fn StationCounters::commands(self : StationCounters) -> Int {
  self.commands
}

///|
pub fn StationCounters::command_failures(self : StationCounters) -> Int {
  self.command_failures
}

///|
pub fn StationCounters::heartbeat_misses(self : StationCounters) -> Int {
  self.heartbeat_misses
}

///|
pub fn StationCounters::quality_events(self : StationCounters) -> Int {
  self.quality_events
}

///|
pub fn StationCounters::bytes_received(self : StationCounters) -> Int {
  self.bytes_received
}

///|
pub fn StationCounters::bytes_sent(self : StationCounters) -> Int {
  self.bytes_sent
}

///|
pub fn StationCounters::record_command(self : StationCounters) -> Unit {
  self.commands += 1
}

///|
pub fn StationCounters::record_command_failure(self : StationCounters) -> Unit {
  self.command_failures += 1
}

///|
pub fn StationCounters::record_quality_event(self : StationCounters) -> Unit {
  self.quality_events += 1
}

///|
pub fn StationCounters::record_bytes_received(
  self : StationCounters,
  bytes : Int,
) -> Unit {
  if bytes > 0 {
    self.bytes_received += bytes
  }
}

///|
pub fn StationCounters::record_bytes_sent(
  self : StationCounters,
  bytes : Int,
) -> Unit {
  if bytes > 0 {
    self.bytes_sent += bytes
  }
}

///|
/// Record for a provisioned station and its point store.
pub struct StationRecord {
  config : StationConfig
  store : PointStore
  mut status : StationStatus
  mut last_seen : Int
  mut revision : Int
  counters : StationCounters
  transitions : Array[StationStateChange]
} derive(Debug)

///|
fn station_record_new(config : StationConfig) -> Result[StationRecord, String] {
  match
    PointStore::new(
      config.common_address(),
      history_limit=config.history_limit(),
    ) {
    Err(error) => Err(error)
    Ok(store) =>
      Ok({
        config,
        store,
        status: Provisioned,
        last_seen: 0,
        revision: 1,
        counters: StationCounters::new(),
        transitions: [],
      })
  }
}

///|
pub fn StationRecord::config(self : StationRecord) -> StationConfig {
  self.config
}

///|
pub fn StationRecord::store(self : StationRecord) -> PointStore {
  self.store
}

///|
pub fn StationRecord::status(self : StationRecord) -> StationStatus {
  self.status
}

///|
pub fn StationRecord::last_seen(self : StationRecord) -> Int {
  self.last_seen
}

///|
pub fn StationRecord::revision(self : StationRecord) -> Int {
  self.revision
}

///|
pub fn StationRecord::counters(self : StationRecord) -> StationCounters {
  self.counters
}

///|
pub fn StationRecord::transitions(
  self : StationRecord,
) -> Array[StationStateChange] {
  self.transitions.copy()
}

///|
fn StationRecord::touch(self : StationRecord, timestamp : Int) -> Unit {
  self.last_seen = timestamp
  self.counters.received_updates += 1
}

///|
fn StationRecord::set_status(
  self : StationRecord,
  status : StationStatus,
  reason : StationStateReason,
  timestamp : Int,
  message : String,
) -> StationStateChange {
  let change = StationStateChange::new(
    self.config.common_address(),
    self.status,
    status,
    reason,
    timestamp,
    self.revision + 1,
    message~,
  )
  self.status = status
  self.revision += 1
  self.transitions.push(change)
  while self.transitions.length() > 256 {
    ignore(self.transitions.remove(0))
  }
  change
}

///|
fn StationRecord::apply(
  self : StationRecord,
  object : ApplicationObject,
  timestamp : Int,
  source : String,
) -> Result[PointChange, Diagnostic] {
  self.counters.received_updates += 1
  if self.store.len() >= self.config.point_capacity() &&
    self.store.get(object.address()) is None {
    self.counters.rejected_updates += 1
    Err(Diagnostic::new(UnsupportedFeature, "station point capacity reached"))
  } else {
    match self.store.upsert(object, timestamp, source~) {
      Err(error) => {
        self.counters.rejected_updates += 1
        Err(error)
      }
      Ok(change) => {
        self.counters.accepted_updates += 1
        self.revision += 1
        Ok(change)
      }
    }
  }
}

///|
/// A compact summary suitable for a health endpoint or dashboard.
pub struct StationSummary {
  common_address : CommonAddress
  name : String
  status : StationStatus
  point_count : Int
  last_seen : Int
  revision : Int
  valid_points : Int
  invalid_points : Int
  heartbeat_age : Int
} derive(Eq, Debug)

///|
pub fn StationSummary::common_address(self : StationSummary) -> CommonAddress {
  self.common_address
}

///|
pub fn StationSummary::name(self : StationSummary) -> String {
  self.name
}

///|
pub fn StationSummary::status(self : StationSummary) -> StationStatus {
  self.status
}

///|
pub fn StationSummary::point_count(self : StationSummary) -> Int {
  self.point_count
}

///|
pub fn StationSummary::last_seen(self : StationSummary) -> Int {
  self.last_seen
}

///|
pub fn StationSummary::revision(self : StationSummary) -> Int {
  self.revision
}

///|
pub fn StationSummary::valid_points(self : StationSummary) -> Int {
  self.valid_points
}

///|
pub fn StationSummary::invalid_points(self : StationSummary) -> Int {
  self.invalid_points
}

///|
pub fn StationSummary::heartbeat_age(self : StationSummary) -> Int {
  self.heartbeat_age
}

///|
/// A bounded journal entry for changes to the station database.
pub enum DatabaseEventKind {
  StationAdded
  StationRemoved
  StationStateChanged
  PointChanged
  DatabaseCompacted
  TransactionCommitted
  TransactionRejected
} derive(Eq, Debug)

///|
pub struct DatabaseEvent {
  sequence : Int
  timestamp : Int
  kind : DatabaseEventKind
  common_address : CommonAddress?
  point_address : InformationAddress?
  message : String
} derive(Eq, Debug)

///|
pub fn DatabaseEvent::new(
  sequence : Int,
  timestamp : Int,
  kind : DatabaseEventKind,
  common_address? : CommonAddress,
  point_address? : InformationAddress,
  message? : String = "",
) -> DatabaseEvent {
  { sequence, timestamp, kind, common_address, point_address, message }
}

///|
pub fn DatabaseEvent::sequence(self : DatabaseEvent) -> Int {
  self.sequence
}

///|
pub fn DatabaseEvent::timestamp(self : DatabaseEvent) -> Int {
  self.timestamp
}

///|
pub fn DatabaseEvent::kind(self : DatabaseEvent) -> DatabaseEventKind {
  self.kind
}

///|
pub fn DatabaseEvent::common_address(self : DatabaseEvent) -> CommonAddress? {
  self.common_address
}

///|
pub fn DatabaseEvent::point_address(
  self : DatabaseEvent,
) -> InformationAddress? {
  self.point_address
}

///|
pub fn DatabaseEvent::message(self : DatabaseEvent) -> String {
  self.message
}

///|
/// Query used by database readers and supervisory dashboards.
pub struct StationQuery {
  status : StationStatus?
  tag : String?
  name_prefix : String?
  include_disabled : Bool
  min_points : Int?
  max_heartbeat_age : Int?
} derive(Eq, Debug)

///|
pub fn StationQuery::all() -> StationQuery {
  {
    status: None,
    tag: None,
    name_prefix: None,
    include_disabled: false,
    min_points: None,
    max_heartbeat_age: None,
  }
}

///|
pub fn StationQuery::with_status(
  self : StationQuery,
  status : StationStatus,
) -> StationQuery {
  {
    status: Some(status),
    tag: self.tag,
    name_prefix: self.name_prefix,
    include_disabled: self.include_disabled,
    min_points: self.min_points,
    max_heartbeat_age: self.max_heartbeat_age,
  }
}

///|
pub fn StationQuery::with_tag(
  self : StationQuery,
  tag : String,
) -> StationQuery {
  {
    status: self.status,
    tag: Some(tag),
    name_prefix: self.name_prefix,
    include_disabled: self.include_disabled,
    min_points: self.min_points,
    max_heartbeat_age: self.max_heartbeat_age,
  }
}

///|
pub fn StationQuery::with_name_prefix(
  self : StationQuery,
  prefix : String,
) -> StationQuery {
  {
    status: self.status,
    tag: self.tag,
    name_prefix: Some(prefix),
    include_disabled: self.include_disabled,
    min_points: self.min_points,
    max_heartbeat_age: self.max_heartbeat_age,
  }
}

///|
pub fn StationQuery::with_disabled(
  self : StationQuery,
  include_disabled_value : Bool,
) -> StationQuery {
  {
    status: self.status,
    tag: self.tag,
    name_prefix: self.name_prefix,
    include_disabled: include_disabled_value,
    min_points: self.min_points,
    max_heartbeat_age: self.max_heartbeat_age,
  }
}

///|
pub fn StationQuery::with_min_points(
  self : StationQuery,
  count : Int,
) -> StationQuery {
  {
    status: self.status,
    tag: self.tag,
    name_prefix: self.name_prefix,
    include_disabled: self.include_disabled,
    min_points: Some(count),
    max_heartbeat_age: self.max_heartbeat_age,
  }
}

///|
pub fn StationQuery::with_max_heartbeat_age(
  self : StationQuery,
  age : Int,
) -> StationQuery {
  {
    status: self.status,
    tag: self.tag,
    name_prefix: self.name_prefix,
    include_disabled: self.include_disabled,
    min_points: self.min_points,
    max_heartbeat_age: Some(age),
  }
}

///|
fn station_matches_query(
  record : StationRecord,
  query : StationQuery,
  now : Int,
) -> Bool {
  let config = record.config()
  let status_ok = match query.status {
    Some(value) => record.status() == value
    None => true
  }
  let tag_ok = match query.tag {
    Some(value) => config.tags().contains(value)
    None => true
  }
  let prefix_ok = match query.name_prefix {
    Some(value) => config.name().has_prefix(value)
    None => true
  }
  let enabled_ok = query.include_disabled || config.enabled()
  let min_points_ok = match query.min_points {
    Some(value) => record.store().len() >= value
    None => true
  }
  let age = if now >= record.last_seen() { now - record.last_seen() } else { 0 }
  let age_ok = match query.max_heartbeat_age {
    Some(value) => age <= value
    None => true
  }
  status_ok && tag_ok && prefix_ok && enabled_ok && min_points_ok && age_ok
}

///|
/// A read-only point snapshot associated with one database revision.
pub struct StationPointSnapshot {
  common_address : CommonAddress
  database_revision : Int
  station_revision : Int
  points : Array[PointRecord]
} derive(Debug)

///|
pub fn StationPointSnapshot::common_address(
  self : StationPointSnapshot,
) -> CommonAddress {
  self.common_address
}

///|
pub fn StationPointSnapshot::database_revision(
  self : StationPointSnapshot,
) -> Int {
  self.database_revision
}

///|
pub fn StationPointSnapshot::station_revision(
  self : StationPointSnapshot,
) -> Int {
  self.station_revision
}

///|
pub fn StationPointSnapshot::points(
  self : StationPointSnapshot,
) -> Array[PointRecord] {
  self.points.copy()
}

///|
/// A database snapshot used by exports and optimistic readers.
pub struct DatabaseSnapshot {
  revision : Int
  timestamp : Int
  stations : Array[StationSummary]
  events : Array[DatabaseEvent]
} derive(Debug)

///|
pub fn DatabaseSnapshot::revision(self : DatabaseSnapshot) -> Int {
  self.revision
}

///|
pub fn DatabaseSnapshot::timestamp(self : DatabaseSnapshot) -> Int {
  self.timestamp
}

///|
pub fn DatabaseSnapshot::stations(
  self : DatabaseSnapshot,
) -> Array[StationSummary] {
  self.stations.copy()
}

///|
pub fn DatabaseSnapshot::events(
  self : DatabaseSnapshot,
) -> Array[DatabaseEvent] {
  self.events.copy()
}

///|
/// A transaction over station configuration and point updates.
pub struct DatabaseTransaction {
  base_revision : Int
  timestamp : Int
  additions : Array[StationConfig]
  removals : Array[CommonAddress]
  states : Array[(CommonAddress, StationStatus, StationStateReason, String)]
  points : Array[(CommonAddress, ApplicationObject, String)]
  mut closed : Bool
} derive(Debug)

///|
pub fn DatabaseTransaction::new(
  base_revision : Int,
  timestamp : Int,
) -> DatabaseTransaction {
  {
    base_revision,
    timestamp,
    additions: [],
    removals: [],
    states: [],
    points: [],
    closed: false,
  }
}

///|
pub fn DatabaseTransaction::base_revision(self : DatabaseTransaction) -> Int {
  self.base_revision
}

///|
pub fn DatabaseTransaction::timestamp(self : DatabaseTransaction) -> Int {
  self.timestamp
}

///|
pub fn DatabaseTransaction::operation_count(self : DatabaseTransaction) -> Int {
  self.additions.length() +
  self.removals.length() +
  self.states.length() +
  self.points.length()
}

///|
pub fn DatabaseTransaction::add_station(
  self : DatabaseTransaction,
  config : StationConfig,
) -> Result[Unit, String] {
  if self.closed {
    Err("database transaction is closed")
  } else {
    self.additions.push(config)
    Ok(())
  }
}

///|
pub fn DatabaseTransaction::remove_station(
  self : DatabaseTransaction,
  common_address : CommonAddress,
) -> Result[Unit, String] {
  if self.closed {
    Err("database transaction is closed")
  } else {
    self.removals.push(common_address)
    Ok(())
  }
}

///|
pub fn DatabaseTransaction::set_state(
  self : DatabaseTransaction,
  common_address : CommonAddress,
  status : StationStatus,
  reason : StationStateReason,
  message? : String = "",
) -> Result[Unit, String] {
  if self.closed {
    Err("database transaction is closed")
  } else {
    self.states.push((common_address, status, reason, message))
    Ok(())
  }
}

///|
pub fn DatabaseTransaction::write_point(
  self : DatabaseTransaction,
  common_address : CommonAddress,
  object : ApplicationObject,
  source? : String = "transaction",
) -> Result[Unit, Diagnostic] {
  if self.closed {
    Err(Diagnostic::new(StateViolation, "database transaction is closed"))
  } else {
    match object.validate() {
      Err(error) => Err(error)
      Ok(_) => {
        self.points.push((common_address, object, source))
        Ok(())
      }
    }
  }
}

///|
pub fn DatabaseTransaction::rollback(self : DatabaseTransaction) -> Unit {
  self.additions.clear()
  self.removals.clear()
  self.states.clear()
  self.points.clear()
  self.closed = true
}

///|
/// The normalized, bounded in-memory operational database.
pub struct StationDatabase {
  stations : Map[Int, StationRecord]
  events : Array[DatabaseEvent]
  event_limit : Int
  mut revision : Int
  mut next_sequence : Int
} derive(Debug)

///|
pub fn StationDatabase::new(
  event_limit? : Int = 8192,
) -> Result[StationDatabase, String] {
  if event_limit < 1 {
    Err("database event limit must be positive")
  } else {
    Ok({ stations: {}, events: [], event_limit, revision: 0, next_sequence: 1 })
  }
}

///|
pub fn StationDatabase::revision(self : StationDatabase) -> Int {
  self.revision
}

///|
pub fn StationDatabase::station_count(self : StationDatabase) -> Int {
  self.stations.length()
}

///|
pub fn StationDatabase::event_count(self : StationDatabase) -> Int {
  self.events.length()
}

///|
fn StationDatabase::append_event(
  self : StationDatabase,
  timestamp : Int,
  kind : DatabaseEventKind,
  common_address : CommonAddress?,
  point_address : InformationAddress?,
  message : String,
) -> Unit {
  let event = {
    sequence: self.next_sequence,
    timestamp,
    kind,
    common_address,
    point_address,
    message,
  }
  self.next_sequence += 1
  self.events.push(event)
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
}

///|
pub fn StationDatabase::events(self : StationDatabase) -> Array[DatabaseEvent] {
  self.events.copy()
}

///|
pub fn StationDatabase::events_since(
  self : StationDatabase,
  sequence : Int,
) -> Array[DatabaseEvent] {
  let result : Array[DatabaseEvent] = []
  for event in self.events {
    if event.sequence() >= sequence {
      result.push(event)
    }
  }
  result
}

///|
pub fn StationDatabase::register(
  self : StationDatabase,
  config : StationConfig,
  timestamp : Int,
) -> Result[StationSummary, String] {
  let key = config.common_address().number()
  if self.stations.contains(key) {
    Err("station common address is already registered")
  } else {
    match station_record_new(config) {
      Err(error) => Err(error)
      Ok(record) => {
        let address = config.common_address()
        self.stations[key] = record
        self.revision += 1
        self.append_event(
          timestamp,
          StationAdded,
          Some(address),
          None,
          "station registered",
        )
        self.summary(address, timestamp)
      }
    }
  }
}

///|
pub fn StationDatabase::unregister(
  self : StationDatabase,
  common_address : CommonAddress,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(_) => {
      self.stations.remove(common_address.number())
      self.revision += 1
      self.append_event(
        timestamp,
        StationRemoved,
        Some(common_address),
        None,
        "station removed",
      )
      Ok(())
    }
  }
}

///|
pub fn StationDatabase::get(
  self : StationDatabase,
  common_address : CommonAddress,
) -> StationRecord? {
  self.stations.get(common_address.number())
}

///|
pub fn StationDatabase::contains(
  self : StationDatabase,
  common_address : CommonAddress,
) -> Bool {
  self.stations.contains(common_address.number())
}

///|
pub fn StationDatabase::summary(
  self : StationDatabase,
  common_address : CommonAddress,
  now : Int,
) -> Result[StationSummary, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) => {
      let statistics = record.store().statistics()
      let age = if now >= record.last_seen() {
        now - record.last_seen()
      } else {
        0
      }
      Ok({
        common_address,
        name: record.config().name(),
        status: record.status(),
        point_count: record.store().len(),
        last_seen: record.last_seen(),
        revision: record.revision(),
        valid_points: statistics.valid(),
        invalid_points: statistics.invalid(),
        heartbeat_age: age,
      })
    }
  }
}

///|
pub fn StationDatabase::query(
  self : StationDatabase,
  query : StationQuery,
  now : Int,
) -> Array[StationSummary] {
  let result : Array[StationSummary] = []
  for _, record in self.stations {
    if station_matches_query(record, query, now) {
      match self.summary(record.config().common_address(), now) {
        Ok(summary) => result.push(summary)
        Err(_) => ()
      }
    }
  }
  result.sort_by((left, right) => {
    left.common_address().number() - right.common_address().number()
  })
  result
}

///|
pub fn StationDatabase::set_state(
  self : StationDatabase,
  common_address : CommonAddress,
  status : StationStatus,
  reason : StationStateReason,
  timestamp : Int,
  message? : String = "",
) -> Result[StationStateChange, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) =>
      if record.status() == status {
        Ok(
          StationStateChange::new(
            common_address,
            status,
            status,
            reason,
            timestamp,
            record.revision(),
            message="station state unchanged",
          ),
        )
      } else {
        let change = record.set_status(status, reason, timestamp, message)
        self.revision += 1
        self.append_event(
          timestamp,
          StationStateChanged,
          Some(common_address),
          None,
          "station state changed",
        )
        Ok(change)
      }
  }
}

///|
pub fn StationDatabase::heartbeat(
  self : StationDatabase,
  common_address : CommonAddress,
  timestamp : Int,
) -> Result[StationStateChange?, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) => {
      record.touch(timestamp)
      if record.status() == Provisioned || record.status() == Offline {
        match
          self.set_state(
            common_address,
            Online,
            LinkEstablished,
            timestamp,
            message="heartbeat received",
          ) {
          Ok(change) => Ok(Some(change))
          Err(error) => Err(error)
        }
      } else {
        Ok(None)
      }
    }
  }
}

///|
pub fn StationDatabase::miss_heartbeat(
  self : StationDatabase,
  common_address : CommonAddress,
  timestamp : Int,
) -> Result[StationStateChange?, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) => {
      record.counters.heartbeat_misses += 1
      if record.status() == Online {
        match
          self.set_state(
            common_address,
            Degraded,
            HeartbeatMissed,
            timestamp,
            message="heartbeat missed",
          ) {
          Ok(change) => Ok(Some(change))
          Err(error) => Err(error)
        }
      } else {
        Ok(None)
      }
    }
  }
}

///|
pub fn StationDatabase::write(
  self : StationDatabase,
  common_address : CommonAddress,
  object : ApplicationObject,
  timestamp : Int,
  source? : String = "protocol",
) -> Result[PointChange, Diagnostic] {
  match self.stations.get(common_address.number()) {
    None => Err(Diagnostic::new(InvalidAddress, "station is not registered"))
    Some(record) =>
      if object.address().number() < 0 {
        Err(Diagnostic::new(InvalidAddress, "information address is invalid"))
      } else {
        match record.apply(object, timestamp, source) {
          Err(error) => Err(error)
          Ok(change) => {
            self.revision += 1
            self.append_event(
              timestamp,
              PointChanged,
              Some(common_address),
              Some(object.address()),
              "point update accepted",
            )
            Ok(change)
          }
        }
      }
  }
}

///|
pub fn StationDatabase::read(
  self : StationDatabase,
  common_address : CommonAddress,
  filter : PointFilter,
) -> Result[Array[PointRecord], String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) => Ok(record.store().query(filter))
  }
}

///|
pub fn StationDatabase::point_snapshot(
  self : StationDatabase,
  common_address : CommonAddress,
  filter : PointFilter,
) -> Result[StationPointSnapshot, String] {
  match self.stations.get(common_address.number()) {
    None => Err("station is not registered")
    Some(record) =>
      Ok({
        common_address,
        database_revision: self.revision,
        station_revision: record.revision(),
        points: record.store().query(filter),
      })
  }
}

///|
pub fn StationDatabase::snapshot(
  self : StationDatabase,
  timestamp : Int,
) -> DatabaseSnapshot {
  {
    revision: self.revision,
    timestamp,
    stations: self.query(StationQuery::all().with_disabled(true), timestamp),
    events: self.events.copy(),
  }
}

///|
/// Commit an optimistic transaction atomically from the caller's perspective.
pub fn StationDatabase::commit(
  self : StationDatabase,
  transaction : DatabaseTransaction,
) -> Result[Array[DatabaseEvent], Diagnostic] {
  if transaction.closed {
    Err(Diagnostic::new(StateViolation, "database transaction is closed"))
  } else if transaction.base_revision() != self.revision {
    transaction.closed = true
    Err(
      Diagnostic::new(
        StateViolation,
        "database revision changed during transaction",
      ),
    )
  } else {
    let before = self.next_sequence
    for config in transaction.additions {
      match self.register(config, transaction.timestamp()) {
        Ok(_) => ()
        Err(error) => {
          transaction.closed = true
          self.append_event(
            transaction.timestamp(),
            TransactionRejected,
            None,
            None,
            error,
          )
          return Err(
            Diagnostic::new(
              StateViolation,
              "transaction station addition rejected",
            ),
          )
        }
      }
    }
    for address in transaction.removals {
      match self.unregister(address, transaction.timestamp()) {
        Ok(_) => ()
        Err(_) => {
          transaction.closed = true
          self.append_event(
            transaction.timestamp(),
            TransactionRejected,
            None,
            None,
            "transaction removal rejected",
          )
          return Err(
            Diagnostic::new(
              StateViolation,
              "transaction station removal rejected",
            ),
          )
        }
      }
    }
    for state in transaction.states {
      let (address, status, reason, message) = state
      match
        self.set_state(
          address,
          status,
          reason,
          transaction.timestamp(),
          message~,
        ) {
        Ok(_) => ()
        Err(_) => {
          transaction.closed = true
          self.append_event(
            transaction.timestamp(),
            TransactionRejected,
            None,
            None,
            "transaction state change rejected",
          )
          return Err(
            Diagnostic::new(StateViolation, "transaction state change rejected"),
          )
        }
      }
    }
    for point in transaction.points {
      let (address, object, source) = point
      match self.write(address, object, transaction.timestamp(), source~) {
        Ok(_) => ()
        Err(_) => {
          transaction.closed = true
          self.append_event(
            transaction.timestamp(),
            TransactionRejected,
            None,
            None,
            "transaction point update rejected",
          )
          return Err(
            Diagnostic::new(StateViolation, "transaction point update rejected"),
          )
        }
      }
    }
    transaction.closed = true
    self.append_event(
      transaction.timestamp(),
      TransactionCommitted,
      None,
      None,
      "transaction committed",
    )
    let result : Array[DatabaseEvent] = []
    for event in self.events {
      if event.sequence() >= before {
        result.push(event)
      }
    }
    Ok(result)
  }
}

///|
pub fn StationDatabase::compact_events(
  self : StationDatabase,
  keep : Int,
  timestamp : Int,
) -> Result[Unit, String] {
  if keep < 1 {
    Err("event retention must be positive")
  } else {
    while self.events.length() > keep {
      ignore(self.events.remove(0))
    }
    self.append_event(
      timestamp,
      DatabaseCompacted,
      None,
      None,
      "event journal compacted",
    )
    Ok(())
  }
}

///|
pub fn station_status_examples() -> Array[StationStatus] {
  [Provisioned, Online, Degraded, Offline, Quarantined]
}

///|
pub fn station_state_reason_examples() -> Array[StationStateReason] {
  [
    ProvisionedByOperator,
    LinkEstablished,
    LinkLost,
    HeartbeatMissed,
    ProtocolError,
    QualityDegraded,
    ManualQuarantine,
    ManualRelease,
    MaintenanceWindow,
  ]
}

///|
pub fn database_event_kind_examples() -> Array[DatabaseEventKind] {
  [
    StationAdded,
    StationRemoved,
    StationStateChanged,
    PointChanged,
    DatabaseCompacted,
    TransactionCommitted,
    TransactionRejected,
  ]
}
