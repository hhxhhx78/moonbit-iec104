///|
/// Runtime service classes exposed by the IEC 104 operational host.
pub enum SupervisorServiceKind {
  TransportService
  StationDatabaseService
  TelemetryService
  CommandService
  ArchiveService
  FileService
  AlarmService
  DiagnosticService
  SimulationService
  ApiService
} derive(Eq, Debug)

///|
/// Lifecycle state used by the service supervisor.
pub enum ServiceLifecycle {
  ServiceRegistered
  ServiceStarting
  ServiceRunning
  ServiceDraining
  ServiceStopped
  ServiceFailed
  ServiceBlocked
} derive(Eq, Debug)

///|
/// Health state reported by a service and evaluated by its dependants.
pub enum ServiceHealth {
  HealthUnknown
  HealthHealthy
  HealthDegraded
  HealthUnhealthy
  HealthStale
} derive(Eq, Debug)

///|
/// Reason for a supervisor event.
pub enum ServiceEventKind {
  ServiceRegisteredEvent
  ServiceStartedEvent
  ServiceStoppedEvent
  ServiceDrainingEvent
  ServiceFailedEvent
  ServiceBlockedEvent
  ServiceHeartbeatEvent
  ServiceHealthEvent
  ServiceRestartEvent
  ServiceLeaseEvent
  ServiceReconciledEvent
} derive(Eq, Debug)

///|
pub fn service_kind_text(kind : SupervisorServiceKind) -> String {
  match kind {
    TransportService => "transport"
    StationDatabaseService => "station-database"
    TelemetryService => "telemetry"
    CommandService => "command"
    ArchiveService => "archive"
    FileService => "file-transfer"
    AlarmService => "alarm"
    DiagnosticService => "diagnostic"
    SimulationService => "simulation"
    ApiService => "api"
  }
}

///|
pub fn service_lifecycle_text(state : ServiceLifecycle) -> String {
  match state {
    ServiceRegistered => "registered"
    ServiceStarting => "starting"
    ServiceRunning => "running"
    ServiceDraining => "draining"
    ServiceStopped => "stopped"
    ServiceFailed => "failed"
    ServiceBlocked => "blocked"
  }
}

///|
pub fn service_health_text(health : ServiceHealth) -> String {
  match health {
    HealthUnknown => "unknown"
    HealthHealthy => "healthy"
    HealthDegraded => "degraded"
    HealthUnhealthy => "unhealthy"
    HealthStale => "stale"
  }
}

///|
pub fn service_event_kind_text(kind : ServiceEventKind) -> String {
  match kind {
    ServiceRegisteredEvent => "registered"
    ServiceStartedEvent => "started"
    ServiceStoppedEvent => "stopped"
    ServiceDrainingEvent => "draining"
    ServiceFailedEvent => "failed"
    ServiceBlockedEvent => "blocked"
    ServiceHeartbeatEvent => "heartbeat"
    ServiceHealthEvent => "health"
    ServiceRestartEvent => "restart"
    ServiceLeaseEvent => "lease"
    ServiceReconciledEvent => "reconciled"
  }
}

///|
/// A dependency edge in the service graph.
pub struct ServiceDependency {
  name : String
  required : Bool
  allow_degraded : Bool
} derive(Eq, Debug)

///|
pub fn ServiceDependency::new(
  name : String,
  required? : Bool = true,
  allow_degraded? : Bool = false,
) -> Result[ServiceDependency, String] {
  if name.length() == 0 || name.length() > 128 {
    Err("service dependency name must contain between 1 and 128 characters")
  } else {
    Ok({ name, required, allow_degraded })
  }
}

///|
pub fn ServiceDependency::name(self : ServiceDependency) -> String {
  self.name
}

///|
pub fn ServiceDependency::required(self : ServiceDependency) -> Bool {
  self.required
}

///|
pub fn ServiceDependency::allow_degraded(self : ServiceDependency) -> Bool {
  self.allow_degraded
}

///|
/// Static policy and timeouts for one managed service.
pub struct ServiceDefinition {
  name : String
  kind : SupervisorServiceKind
  dependencies : Array[ServiceDependency]
  startup_timeout : Int
  shutdown_timeout : Int
  heartbeat_interval : Int
  restart_limit : Int
  restart_backoff : Int
  enabled : Bool
  critical : Bool
  tags : Array[String]
} derive(Eq, Debug)

///|
pub fn ServiceDefinition::new(
  name : String,
  kind : SupervisorServiceKind,
  dependencies? : Array[ServiceDependency] = [],
  startup_timeout? : Int = 30,
  shutdown_timeout? : Int = 30,
  heartbeat_interval? : Int = 10,
  restart_limit? : Int = 3,
  restart_backoff? : Int = 5,
  enabled? : Bool = true,
  critical? : Bool = false,
  tags? : Array[String] = [],
) -> Result[ServiceDefinition, String] {
  if name.length() == 0 || name.length() > 128 {
    Err("service name must contain between 1 and 128 characters")
  } else if startup_timeout < 1 || startup_timeout > 86400 {
    Err("service startup timeout is outside the supported range")
  } else if shutdown_timeout < 1 || shutdown_timeout > 86400 {
    Err("service shutdown timeout is outside the supported range")
  } else if heartbeat_interval < 1 || heartbeat_interval > 86400 {
    Err("service heartbeat interval is outside the supported range")
  } else if restart_limit < 0 || restart_limit > 1000 {
    Err("service restart limit is outside the supported range")
  } else if restart_backoff < 0 || restart_backoff > 86400 {
    Err("service restart backoff is outside the supported range")
  } else {
    Ok({
      name,
      kind,
      dependencies: dependencies.copy(),
      startup_timeout,
      shutdown_timeout,
      heartbeat_interval,
      restart_limit,
      restart_backoff,
      enabled,
      critical,
      tags: tags.copy(),
    })
  }
}

///|
pub fn ServiceDefinition::name(self : ServiceDefinition) -> String {
  self.name
}

///|
pub fn ServiceDefinition::kind(
  self : ServiceDefinition,
) -> SupervisorServiceKind {
  self.kind
}

///|
pub fn ServiceDefinition::dependencies(
  self : ServiceDefinition,
) -> Array[ServiceDependency] {
  self.dependencies.copy()
}

///|
pub fn ServiceDefinition::startup_timeout(self : ServiceDefinition) -> Int {
  self.startup_timeout
}

///|
pub fn ServiceDefinition::shutdown_timeout(self : ServiceDefinition) -> Int {
  self.shutdown_timeout
}

///|
pub fn ServiceDefinition::heartbeat_interval(self : ServiceDefinition) -> Int {
  self.heartbeat_interval
}

///|
pub fn ServiceDefinition::restart_limit(self : ServiceDefinition) -> Int {
  self.restart_limit
}

///|
pub fn ServiceDefinition::restart_backoff(self : ServiceDefinition) -> Int {
  self.restart_backoff
}

///|
pub fn ServiceDefinition::enabled(self : ServiceDefinition) -> Bool {
  self.enabled
}

///|
pub fn ServiceDefinition::critical(self : ServiceDefinition) -> Bool {
  self.critical
}

///|
pub fn ServiceDefinition::tags(self : ServiceDefinition) -> Array[String] {
  self.tags.copy()
}

///|
/// A renewable lease used to fence duplicate service workers.
pub struct ServiceLease {
  owner : String
  acquired_at : Int
  expires_at : Int
  generation : Int
} derive(Eq, Debug)

///|
pub fn ServiceLease::new(
  owner : String,
  acquired_at : Int,
  expires_at : Int,
  generation : Int,
) -> Result[ServiceLease, String] {
  if owner.length() == 0 {
    Err("service lease owner is empty")
  } else if expires_at <= acquired_at {
    Err("service lease expiration must be after acquisition")
  } else if generation < 1 {
    Err("service lease generation must be positive")
  } else {
    Ok({ owner, acquired_at, expires_at, generation })
  }
}

///|
pub fn ServiceLease::owner(self : ServiceLease) -> String {
  self.owner
}

///|
pub fn ServiceLease::acquired_at(self : ServiceLease) -> Int {
  self.acquired_at
}

///|
pub fn ServiceLease::expires_at(self : ServiceLease) -> Int {
  self.expires_at
}

///|
pub fn ServiceLease::generation(self : ServiceLease) -> Int {
  self.generation
}

///|
pub fn ServiceLease::active(self : ServiceLease, timestamp : Int) -> Bool {
  timestamp < self.expires_at
}

///|
/// Mutable operational state retained for one service.
pub struct ServiceRecord {
  definition : ServiceDefinition
  mut lifecycle : ServiceLifecycle
  mut health : ServiceHealth
  mut restart_count : Int
  mut last_transition : Int
  mut last_heartbeat : Int
  mut last_error : String
  mut generation : Int
  mut lease : ServiceLease?
} derive(Debug)

///|
pub fn ServiceRecord::new(
  definition : ServiceDefinition,
  timestamp : Int,
) -> ServiceRecord {
  {
    definition,
    lifecycle: ServiceRegistered,
    health: HealthUnknown,
    restart_count: 0,
    last_transition: timestamp,
    last_heartbeat: timestamp,
    last_error: "",
    generation: 0,
    lease: None,
  }
}

///|
pub fn ServiceRecord::definition(self : ServiceRecord) -> ServiceDefinition {
  self.definition
}

///|
pub fn ServiceRecord::name(self : ServiceRecord) -> String {
  self.definition.name()
}

///|
pub fn ServiceRecord::kind(self : ServiceRecord) -> SupervisorServiceKind {
  self.definition.kind()
}

///|
pub fn ServiceRecord::lifecycle(self : ServiceRecord) -> ServiceLifecycle {
  self.lifecycle
}

///|
pub fn ServiceRecord::health(self : ServiceRecord) -> ServiceHealth {
  self.health
}

///|
pub fn ServiceRecord::restart_count(self : ServiceRecord) -> Int {
  self.restart_count
}

///|
pub fn ServiceRecord::last_transition(self : ServiceRecord) -> Int {
  self.last_transition
}

///|
pub fn ServiceRecord::last_heartbeat(self : ServiceRecord) -> Int {
  self.last_heartbeat
}

///|
pub fn ServiceRecord::last_error(self : ServiceRecord) -> String {
  self.last_error
}

///|
pub fn ServiceRecord::generation(self : ServiceRecord) -> Int {
  self.generation
}

///|
pub fn ServiceRecord::lease(self : ServiceRecord) -> ServiceLease? {
  self.lease
}

///|
pub fn ServiceRecord::is_available(self : ServiceRecord) -> Bool {
  self.lifecycle == ServiceRunning && self.health != HealthUnhealthy
}

///|
pub fn ServiceRecord::is_terminal(self : ServiceRecord) -> Bool {
  self.lifecycle == ServiceStopped || self.lifecycle == ServiceFailed
}

///|
/// One bounded event emitted by the supervisor.
pub struct ServiceEvent {
  sequence : Int
  timestamp : Int
  service : String
  kind : ServiceEventKind
  detail : String
  lifecycle : ServiceLifecycle
  health : ServiceHealth
} derive(Eq, Debug)

///|
pub fn ServiceEvent::sequence(self : ServiceEvent) -> Int {
  self.sequence
}

///|
pub fn ServiceEvent::timestamp(self : ServiceEvent) -> Int {
  self.timestamp
}

///|
pub fn ServiceEvent::service(self : ServiceEvent) -> String {
  self.service
}

///|
pub fn ServiceEvent::kind(self : ServiceEvent) -> ServiceEventKind {
  self.kind
}

///|
pub fn ServiceEvent::detail(self : ServiceEvent) -> String {
  self.detail
}

///|
pub fn ServiceEvent::lifecycle(self : ServiceEvent) -> ServiceLifecycle {
  self.lifecycle
}

///|
pub fn ServiceEvent::health(self : ServiceEvent) -> ServiceHealth {
  self.health
}

///|
pub struct ServiceHealthSummary {
  mut registered : Int
  mut running : Int
  mut degraded : Int
  mut unhealthy : Int
  mut stopped : Int
  mut failed : Int
  mut blocked : Int
  mut critical_failures : Int
} derive(Eq, Debug)

///|
pub fn ServiceHealthSummary::new() -> ServiceHealthSummary {
  {
    registered: 0,
    running: 0,
    degraded: 0,
    unhealthy: 0,
    stopped: 0,
    failed: 0,
    blocked: 0,
    critical_failures: 0,
  }
}

///|
pub fn ServiceHealthSummary::registered(self : ServiceHealthSummary) -> Int {
  self.registered
}

///|
pub fn ServiceHealthSummary::running(self : ServiceHealthSummary) -> Int {
  self.running
}

///|
pub fn ServiceHealthSummary::degraded(self : ServiceHealthSummary) -> Int {
  self.degraded
}

///|
pub fn ServiceHealthSummary::unhealthy(self : ServiceHealthSummary) -> Int {
  self.unhealthy
}

///|
pub fn ServiceHealthSummary::stopped(self : ServiceHealthSummary) -> Int {
  self.stopped
}

///|
pub fn ServiceHealthSummary::failed(self : ServiceHealthSummary) -> Int {
  self.failed
}

///|
pub fn ServiceHealthSummary::blocked(self : ServiceHealthSummary) -> Int {
  self.blocked
}

///|
pub fn ServiceHealthSummary::critical_failures(
  self : ServiceHealthSummary,
) -> Int {
  self.critical_failures
}

///|
/// Bounded service registry and dependency-aware supervisor.
pub struct ServiceRegistry {
  records : Map[String, ServiceRecord]
  events : Array[ServiceEvent]
  event_limit : Int
  mut next_sequence : Int
  mut topology_revision : Int
} derive(Debug)

///|
pub fn ServiceRegistry::new(
  event_limit? : Int = 8192,
) -> Result[ServiceRegistry, String] {
  if event_limit < 1 {
    Err("service registry event limit must be positive")
  } else {
    Ok({
      records: {},
      events: [],
      event_limit,
      next_sequence: 1,
      topology_revision: 0,
    })
  }
}

///|
pub fn ServiceRegistry::len(self : ServiceRegistry) -> Int {
  self.records.length()
}

///|
pub fn ServiceRegistry::topology_revision(self : ServiceRegistry) -> Int {
  self.topology_revision
}

///|
pub fn ServiceRegistry::events(self : ServiceRegistry) -> Array[ServiceEvent] {
  self.events.copy()
}

///|
pub fn ServiceRegistry::definition(
  self : ServiceRegistry,
  name : String,
) -> ServiceDefinition? {
  match self.records.get(name) {
    None => None
    Some(record) => Some(record.definition())
  }
}

///|
pub fn ServiceRegistry::get(
  self : ServiceRegistry,
  name : String,
) -> ServiceRecord? {
  self.records.get(name)
}

///|
pub fn ServiceRegistry::names(self : ServiceRegistry) -> Array[String] {
  let names : Array[String] = []
  for name, _ in self.records {
    names.push(name)
  }
  names.sort_by((left, right) => left.compare(right))
  names
}

///|
pub fn ServiceRegistry::records(self : ServiceRegistry) -> Array[ServiceRecord] {
  let result : Array[ServiceRecord] = []
  for _, record in self.records {
    result.push(record)
  }
  result.sort_by((left, right) => left.name().compare(right.name()))
  result
}

///|
fn ServiceRegistry::append_event(
  self : ServiceRegistry,
  timestamp : Int,
  service : String,
  kind : ServiceEventKind,
  detail : String,
  record : ServiceRecord,
) -> Unit {
  self.events.push({
    sequence: self.next_sequence,
    timestamp,
    service,
    kind,
    detail,
    lifecycle: record.lifecycle(),
    health: record.health(),
  })
  self.next_sequence += 1
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
}

///|
fn ServiceRegistry::store(
  self : ServiceRegistry,
  record : ServiceRecord,
) -> Unit {
  self.records[record.name()] = record
}

///|
fn valid_service_name(name : String) -> Bool {
  if name.length() == 0 || name.length() > 128 {
    false
  } else {
    true
  }
}

///|
fn dependency_names_unique(dependencies : Array[ServiceDependency]) -> Bool {
  let seen : Map[String, Bool] = Map([])
  for dependency in dependencies {
    if seen.contains(dependency.name()) {
      return false
    }
    seen[dependency.name()] = true
  }
  true
}

///|
pub fn ServiceRegistry::register(
  self : ServiceRegistry,
  definition : ServiceDefinition,
  timestamp : Int,
) -> Result[ServiceRecord, String] {
  if !valid_service_name(definition.name()) {
    Err("service name contains unsupported characters")
  } else if self.records.contains(definition.name()) {
    Err("service is already registered")
  } else if !dependency_names_unique(definition.dependencies()) {
    Err("service dependencies must be unique")
  } else {
    for dependency in definition.dependencies() {
      if dependency.name() == definition.name() {
        return Err("service cannot depend on itself")
      }
    }
    let record = ServiceRecord::new(definition, timestamp)
    self.records[record.name()] = record
    self.topology_revision += 1
    self.append_event(
      timestamp,
      record.name(),
      ServiceRegisteredEvent,
      "service registered",
      record,
    )
    Ok(record)
  }
}

///|
pub fn ServiceRegistry::unregister(
  self : ServiceRegistry,
  name : String,
  _timestamp : Int,
) -> Result[Unit, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      if record.lifecycle() == ServiceRunning ||
        record.lifecycle() == ServiceStarting ||
        record.lifecycle() == ServiceDraining {
        Err("running service must be stopped before unregistering")
      } else {
        for _, dependent in self.records {
          for dependency in dependent.definition().dependencies() {
            if dependency.name() == name &&
              dependency.required() &&
              dependent.lifecycle() != ServiceStopped {
              return Err("service is required by an active dependent")
            }
          }
        }
        self.records.remove(name)
        self.topology_revision += 1
        Ok(())
      }
  }
}

///|
fn ServiceRegistry::dependency_state(
  self : ServiceRegistry,
  definition : ServiceDefinition,
) -> Result[Unit, String] {
  for dependency in definition.dependencies() {
    match self.records.get(dependency.name()) {
      None =>
        if dependency.required() {
          return Err("required service dependency is missing")
        }
      Some(record) => {
        let running = record.lifecycle() == ServiceRunning
        let healthy = record.health() == HealthHealthy
        let degraded_ok = dependency.allow_degraded() &&
          record.health() == HealthDegraded
        if dependency.required() && (!running || (!healthy && !degraded_ok)) {
          return Err("required service dependency is not ready")
        }
      }
    }
  }
  Ok(())
}

///|
pub fn ServiceRegistry::dependencies_ready(
  self : ServiceRegistry,
  name : String,
) -> Result[Bool, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      match self.dependency_state(record.definition()) {
        Ok(_) => Ok(true)
        Err(_) => Ok(false)
      }
  }
}

///|
pub fn ServiceRegistry::start(
  self : ServiceRegistry,
  name : String,
  timestamp : Int,
) -> Result[ServiceRecord, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) => {
      if !record.definition().enabled() {
        return Err("service is disabled by configuration")
      }
      if record.lifecycle() == ServiceRunning {
        return Ok(record)
      }
      if record.lifecycle() == ServiceStarting {
        return Err("service start is already in progress")
      }
      match self.dependency_state(record.definition()) {
        Err(message) => {
          record.lifecycle = ServiceBlocked
          record.last_transition = timestamp
          record.last_error = message
          self.store(record)
          self.append_event(
            timestamp,
            name,
            ServiceBlockedEvent,
            "dependency is not ready",
            record,
          )
          Err("service dependencies are not ready")
        }
        Ok(_) => {
          record.lifecycle = ServiceStarting
          record.last_transition = timestamp
          record.last_error = ""
          self.store(record)
          self.append_event(
            timestamp,
            name,
            ServiceStartedEvent,
            "service start requested",
            record,
          )
          record.lifecycle = ServiceRunning
          record.health = HealthHealthy
          record.last_transition = timestamp
          record.last_heartbeat = timestamp
          record.generation += 1
          self.store(record)
          self.append_event(
            timestamp,
            name,
            ServiceStartedEvent,
            "service is running",
            record,
          )
          Ok(record)
        }
      }
    }
  }
}

///|
pub fn ServiceRegistry::stop(
  self : ServiceRegistry,
  name : String,
  timestamp : Int,
  force? : Bool = false,
) -> Result[ServiceRecord, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      if record.lifecycle() == ServiceStopped {
        Ok(record)
      } else if record.lifecycle() == ServiceFailed && !force {
        Err("failed service requires force to stop")
      } else {
        record.lifecycle = ServiceDraining
        record.last_transition = timestamp
        self.store(record)
        self.append_event(
          timestamp,
          name,
          ServiceDrainingEvent,
          "service drain requested",
          record,
        )
        record.lifecycle = ServiceStopped
        record.health = HealthUnknown
        record.last_transition = timestamp
        record.lease = None
        self.store(record)
        self.append_event(
          timestamp,
          name,
          ServiceStoppedEvent,
          "service stopped",
          record,
        )
        Ok(record)
      }
  }
}

///|
pub fn ServiceRegistry::fail(
  self : ServiceRegistry,
  name : String,
  timestamp : Int,
  message : String,
) -> Result[ServiceRecord, String] {
  if message.length() == 0 {
    return Err("service failure message is empty")
  }
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) => {
      record.lifecycle = ServiceFailed
      record.health = HealthUnhealthy
      record.last_transition = timestamp
      record.last_heartbeat = timestamp
      record.last_error = message
      record.lease = None
      self.store(record)
      self.append_event(timestamp, name, ServiceFailedEvent, message, record)
      Ok(record)
    }
  }
}

///|
pub fn ServiceRegistry::heartbeat(
  self : ServiceRegistry,
  name : String,
  timestamp : Int,
) -> Result[ServiceRecord, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) => {
      if record.lifecycle() != ServiceRunning {
        return Err("only a running service can heartbeat")
      }
      record.last_heartbeat = timestamp
      if record.health() == HealthStale {
        record.health = HealthHealthy
        self.append_event(
          timestamp,
          name,
          ServiceHealthEvent,
          "service recovered from stale health",
          record,
        )
      }
      self.store(record)
      self.append_event(
        timestamp,
        name,
        ServiceHeartbeatEvent,
        "service heartbeat accepted",
        record,
      )
      Ok(record)
    }
  }
}

///|
pub fn ServiceRegistry::set_health(
  self : ServiceRegistry,
  name : String,
  health : ServiceHealth,
  timestamp : Int,
  detail? : String = "",
) -> Result[ServiceRecord, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) => {
      if record.lifecycle() == ServiceStopped {
        return Err("stopped service cannot report health")
      }
      record.health = health
      record.last_transition = timestamp
      self.store(record)
      self.append_event(timestamp, name, ServiceHealthEvent, detail, record)
      Ok(record)
    }
  }
}

///|
pub fn ServiceRegistry::restart(
  self : ServiceRegistry,
  name : String,
  timestamp : Int,
  reason? : String = "supervisor restart",
) -> Result[ServiceRecord, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) => {
      if record.restart_count() >= record.definition().restart_limit() {
        record.lifecycle = ServiceFailed
        record.health = HealthUnhealthy
        record.last_error = "restart limit exhausted"
        record.last_transition = timestamp
        self.store(record)
        self.append_event(
          timestamp,
          name,
          ServiceFailedEvent,
          "restart limit exhausted",
          record,
        )
        return Err("service restart limit exhausted")
      }
      record.restart_count += 1
      record.lifecycle = ServiceStarting
      record.health = HealthUnknown
      record.last_transition = timestamp
      record.last_error = reason
      record.generation += 1
      self.store(record)
      self.append_event(timestamp, name, ServiceRestartEvent, reason, record)
      record.lifecycle = ServiceRunning
      record.health = HealthHealthy
      record.last_heartbeat = timestamp
      record.last_transition = timestamp
      self.store(record)
      self.append_event(
        timestamp,
        name,
        ServiceStartedEvent,
        "service restarted",
        record,
      )
      Ok(record)
    }
  }
}

///|
pub fn ServiceRegistry::acquire_lease(
  self : ServiceRegistry,
  name : String,
  owner : String,
  timestamp : Int,
  ttl : Int,
) -> Result[ServiceLease, String] {
  if ttl < 1 {
    return Err("service lease ttl must be positive")
  }
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      match record.lease() {
        Some(existing) =>
          if existing.active(timestamp) && existing.owner() != owner {
            Err("service lease is held by another owner")
          } else {
            let generation = record.generation() + 1
            match
              ServiceLease::new(owner, timestamp, timestamp + ttl, generation) {
              Err(error) => Err(error)
              Ok(lease) => {
                record.lease = Some(lease)
                record.generation = generation
                self.store(record)
                self.append_event(
                  timestamp,
                  name,
                  ServiceLeaseEvent,
                  "service lease acquired",
                  record,
                )
                Ok(lease)
              }
            }
          }
        None => {
          let generation = record.generation() + 1
          match
            ServiceLease::new(owner, timestamp, timestamp + ttl, generation) {
            Err(error) => Err(error)
            Ok(lease) => {
              record.lease = Some(lease)
              record.generation = generation
              self.store(record)
              self.append_event(
                timestamp,
                name,
                ServiceLeaseEvent,
                "service lease acquired",
                record,
              )
              Ok(lease)
            }
          }
        }
      }
  }
}

///|
pub fn ServiceRegistry::renew_lease(
  self : ServiceRegistry,
  name : String,
  owner : String,
  timestamp : Int,
  ttl : Int,
) -> Result[ServiceLease, String] {
  if ttl < 1 {
    return Err("service lease ttl must be positive")
  }
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      match record.lease() {
        None => Err("service does not have a lease")
        Some(existing) =>
          if existing.owner() != owner || !existing.active(timestamp) {
            Err("service lease owner is invalid or lease has expired")
          } else {
            match
              ServiceLease::new(
                owner,
                existing.acquired_at(),
                timestamp + ttl,
                existing.generation(),
              ) {
              Err(error) => Err(error)
              Ok(lease) => {
                record.lease = Some(lease)
                self.store(record)
                self.append_event(
                  timestamp,
                  name,
                  ServiceLeaseEvent,
                  "service lease renewed",
                  record,
                )
                Ok(lease)
              }
            }
          }
      }
  }
}

///|
pub fn ServiceRegistry::release_lease(
  self : ServiceRegistry,
  name : String,
  owner : String,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.records.get(name) {
    None => Err("service is not registered")
    Some(record) =>
      match record.lease() {
        None => Ok(())
        Some(lease) =>
          if lease.owner() != owner && lease.active(timestamp) {
            Err("service lease owner is invalid")
          } else {
            record.lease = None
            self.store(record)
            self.append_event(
              timestamp,
              name,
              ServiceLeaseEvent,
              "service lease released",
              record,
            )
            Ok(())
          }
      }
  }
}

///|
pub fn ServiceRegistry::expire_leases(
  self : ServiceRegistry,
  timestamp : Int,
) -> Array[String] {
  let expired : Array[String] = []
  for name, record in self.records {
    match record.lease() {
      None => ()
      Some(lease) =>
        if !lease.active(timestamp) {
          record.lease = None
          self.store(record)
          expired.push(name)
          self.append_event(
            timestamp,
            name,
            ServiceLeaseEvent,
            "service lease expired",
            record,
          )
        }
    }
  }
  expired.sort_by((left, right) => left.compare(right))
  expired
}

///|
pub fn ServiceRegistry::mark_stale(
  self : ServiceRegistry,
  timestamp : Int,
) -> Array[String] {
  let stale : Array[String] = []
  for name, record in self.records {
    if record.lifecycle() == ServiceRunning &&
      timestamp - record.last_heartbeat() >
      record.definition().heartbeat_interval() {
      record.health = HealthStale
      self.store(record)
      stale.push(name)
      self.append_event(
        timestamp,
        name,
        ServiceHealthEvent,
        "service heartbeat is stale",
        record,
      )
    }
  }
  stale.sort_by((left, right) => left.compare(right))
  stale
}

///|
pub fn ServiceRegistry::dependants(
  self : ServiceRegistry,
  name : String,
) -> Array[String] {
  let result : Array[String] = []
  for candidate, record in self.records {
    for dependency in record.definition().dependencies() {
      if dependency.name() == name {
        result.push(candidate)
      }
    }
  }
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn ServiceRegistry::critical_services(
  self : ServiceRegistry,
) -> Array[String] {
  let result : Array[String] = []
  for name, record in self.records {
    if record.definition().critical() {
      result.push(name)
    }
  }
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn ServiceRegistry::health_summary(
  self : ServiceRegistry,
) -> ServiceHealthSummary {
  let summary = ServiceHealthSummary::new()
  for _, record in self.records {
    match record.lifecycle() {
      ServiceRegistered => summary.registered += 1
      ServiceStarting => summary.registered += 1
      ServiceRunning => summary.running += 1
      ServiceDraining => summary.running += 1
      ServiceStopped => summary.stopped += 1
      ServiceFailed => {
        summary.failed += 1
        if record.definition().critical() {
          summary.critical_failures += 1
        }
      }
      ServiceBlocked => summary.blocked += 1
    }
    match record.health() {
      HealthDegraded => summary.degraded += 1
      HealthUnhealthy => summary.unhealthy += 1
      _ => ()
    }
  }
  summary
}

///|
/// Start enabled services whose required dependencies are already healthy.
pub fn ServiceRegistry::reconcile(
  self : ServiceRegistry,
  timestamp : Int,
) -> Array[String] {
  let started : Array[String] = []
  let names = self.names()
  for name in names {
    match self.records.get(name) {
      None => ()
      Some(record) =>
        if record.definition().enabled() &&
          (
            record.lifecycle() == ServiceRegistered ||
            record.lifecycle() == ServiceBlocked
          ) {
          match self.start(name, timestamp) {
            Ok(_) => started.push(name)
            Err(_) => ()
          }
        }
    }
  }
  self.append_reconcile_events(timestamp)
  started
}

///|
fn ServiceRegistry::append_reconcile_events(
  self : ServiceRegistry,
  timestamp : Int,
) -> Unit {
  for name, record in self.records {
    if record.lifecycle() == ServiceBlocked {
      self.append_event(
        timestamp,
        name,
        ServiceReconciledEvent,
        "service remains blocked",
        record,
      )
    }
  }
}

///|
pub fn ServiceRegistry::running(self : ServiceRegistry) -> Array[String] {
  let result : Array[String] = []
  for name, record in self.records {
    if record.lifecycle() == ServiceRunning {
      result.push(name)
    }
  }
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn ServiceRegistry::failed(self : ServiceRegistry) -> Array[String] {
  let result : Array[String] = []
  for name, record in self.records {
    if record.lifecycle() == ServiceFailed {
      result.push(name)
    }
  }
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn ServiceRegistry::blocked(self : ServiceRegistry) -> Array[String] {
  let result : Array[String] = []
  for name, record in self.records {
    if record.lifecycle() == ServiceBlocked {
      result.push(name)
    }
  }
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn ServiceRegistry::events_since(
  self : ServiceRegistry,
  sequence : Int,
) -> Array[ServiceEvent] {
  let result : Array[ServiceEvent] = []
  for event in self.events {
    if event.sequence() > sequence {
      result.push(event)
    }
  }
  result
}

///|
pub fn ServiceRegistry::event_lines(self : ServiceRegistry) -> Array[String] {
  let lines : Array[String] = []
  for event in self.events {
    lines.push(
      "\{event.sequence()} \{event.timestamp()} \{event.service()} " +
      "\{service_event_kind_text(event.kind())} " +
      "\{service_lifecycle_text(event.lifecycle())} " +
      "\{service_health_text(event.health())} \{event.detail()}",
    )
  }
  lines
}

///|
/// Return services in dependency order for deterministic startup planning.
pub fn ServiceRegistry::startup_order(
  self : ServiceRegistry,
) -> Result[Array[String], String] {
  let order : Array[String] = []
  let visiting : Map[String, Bool] = Map([])
  let visited : Map[String, Bool] = Map([])
  for name in self.names() {
    match self.visit_for_startup(name, visiting, visited, order) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  Ok(order)
}

///|
fn ServiceRegistry::visit_for_startup(
  self : ServiceRegistry,
  name : String,
  visiting : Map[String, Bool],
  visited : Map[String, Bool],
  order : Array[String],
) -> Result[Unit, String] {
  if visited.contains(name) {
    return Ok(())
  }
  if visiting.contains(name) {
    return Err("service dependency cycle detected")
  }
  let record = self.records.get(name)
  match record {
    None => Err("service dependency points to an unknown service")
    Some(value) => {
      visiting[name] = true
      for dependency in value.definition().dependencies() {
        match
          self.visit_for_startup(dependency.name(), visiting, visited, order) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      visiting.remove(name)
      visited[name] = true
      order.push(name)
      Ok(())
    }
  }
}

///|
pub fn service_registry_examples() -> Array[SupervisorServiceKind] {
  [
    TransportService,
    StationDatabaseService,
    TelemetryService,
    CommandService,
    ArchiveService,
    FileService,
    AlarmService,
    DiagnosticService,
    SimulationService,
    ApiService,
  ]
}
