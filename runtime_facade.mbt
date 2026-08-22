///|
/// Runtime event categories exposed by the integration facade.
pub enum RuntimeEventKind {
  RuntimeStarted
  StationRegisteredRuntime
  TelemetryAcceptedRuntime
  TelemetryRejectedRuntime
  CommandSubmittedRuntime
  CommandDispatchedRuntime
  CommandCompletedRuntime
  FileSessionRuntime
  RedundancyRuntime
  RuntimeDiagnostic
} derive(Eq, Debug)

///|
pub struct RuntimeEvent {
  sequence : Int
  timestamp : Int
  kind : RuntimeEventKind
  station : CommonAddress?
  object : InformationAddress?
  correlation : Int
  message : String
} derive(Eq, Debug)

///|
pub fn RuntimeEvent::sequence(self : RuntimeEvent) -> Int {
  self.sequence
}

///|
pub fn RuntimeEvent::timestamp(self : RuntimeEvent) -> Int {
  self.timestamp
}

///|
pub fn RuntimeEvent::kind(self : RuntimeEvent) -> RuntimeEventKind {
  self.kind
}

///|
pub fn RuntimeEvent::station(self : RuntimeEvent) -> CommonAddress? {
  self.station
}

///|
pub fn RuntimeEvent::object(self : RuntimeEvent) -> InformationAddress? {
  self.object
}

///|
pub fn RuntimeEvent::correlation(self : RuntimeEvent) -> Int {
  self.correlation
}

///|
pub fn RuntimeEvent::message(self : RuntimeEvent) -> String {
  self.message
}

///|
/// Runtime-wide limits and policy defaults.
pub struct RuntimeConfig {
  event_limit : Int
  audit_limit : Int
  scheduler_audit_limit : Int
  file_history_limit : Int
  file_capacity : Int
  file_maximum_size : Int
  telemetry_alarm_limit : Int
  redundancy_policy : RedundancyPolicy
} derive(Debug)

///|
pub fn RuntimeConfig::default() -> RuntimeConfig {
  {
    event_limit: 8192,
    audit_limit: 4096,
    scheduler_audit_limit: 4096,
    file_history_limit: 1024,
    file_capacity: 128,
    file_maximum_size: 1048576,
    telemetry_alarm_limit: 4096,
    redundancy_policy: RedundancyPolicy::new().unwrap(),
  }
}

///|
pub fn RuntimeConfig::new(
  event_limit? : Int = 8192,
  audit_limit? : Int = 4096,
  scheduler_audit_limit? : Int = 4096,
  file_history_limit? : Int = 1024,
  file_capacity? : Int = 128,
  file_maximum_size? : Int = 1048576,
  telemetry_alarm_limit? : Int = 4096,
  redundancy_policy? : RedundancyPolicy = RedundancyPolicy::new().unwrap(),
) -> Result[RuntimeConfig, String] {
  if event_limit < 1 ||
    audit_limit < 1 ||
    scheduler_audit_limit < 1 ||
    file_history_limit < 1 ||
    file_capacity < 1 ||
    file_maximum_size < 1 ||
    telemetry_alarm_limit < 1 {
    Err("runtime resource limits must be positive")
  } else {
    Ok({
      event_limit,
      audit_limit,
      scheduler_audit_limit,
      file_history_limit,
      file_capacity,
      file_maximum_size,
      telemetry_alarm_limit,
      redundancy_policy,
    })
  }
}

///|
pub fn RuntimeConfig::event_limit(self : RuntimeConfig) -> Int {
  self.event_limit
}

///|
pub fn RuntimeConfig::audit_limit(self : RuntimeConfig) -> Int {
  self.audit_limit
}

///|
pub fn RuntimeConfig::scheduler_audit_limit(self : RuntimeConfig) -> Int {
  self.scheduler_audit_limit
}

///|
pub fn RuntimeConfig::file_history_limit(self : RuntimeConfig) -> Int {
  self.file_history_limit
}

///|
pub fn RuntimeConfig::file_capacity(self : RuntimeConfig) -> Int {
  self.file_capacity
}

///|
pub fn RuntimeConfig::file_maximum_size(self : RuntimeConfig) -> Int {
  self.file_maximum_size
}

///|
pub fn RuntimeConfig::telemetry_alarm_limit(self : RuntimeConfig) -> Int {
  self.telemetry_alarm_limit
}

///|
pub fn RuntimeConfig::redundancy_policy(
  self : RuntimeConfig,
) -> RedundancyPolicy {
  self.redundancy_policy
}

///|
/// Runtime health summary for control-room endpoints.
pub struct RuntimeHealth {
  timestamp : Int
  revision : Int
  stations : Int
  points : Int
  pending_commands : Int
  active_alarms : Int
  active_sessions : Int
  redundancy_owners : Int
  event_count : Int
  policy_revision : Int
  healthy : Bool
  message : String
} derive(Eq, Debug)

///|
pub fn RuntimeHealth::timestamp(self : RuntimeHealth) -> Int {
  self.timestamp
}

///|
pub fn RuntimeHealth::revision(self : RuntimeHealth) -> Int {
  self.revision
}

///|
pub fn RuntimeHealth::stations(self : RuntimeHealth) -> Int {
  self.stations
}

///|
pub fn RuntimeHealth::points(self : RuntimeHealth) -> Int {
  self.points
}

///|
pub fn RuntimeHealth::pending_commands(self : RuntimeHealth) -> Int {
  self.pending_commands
}

///|
pub fn RuntimeHealth::active_alarms(self : RuntimeHealth) -> Int {
  self.active_alarms
}

///|
pub fn RuntimeHealth::active_sessions(self : RuntimeHealth) -> Int {
  self.active_sessions
}

///|
pub fn RuntimeHealth::redundancy_owners(self : RuntimeHealth) -> Int {
  self.redundancy_owners
}

///|
pub fn RuntimeHealth::event_count(self : RuntimeHealth) -> Int {
  self.event_count
}

///|
pub fn RuntimeHealth::policy_revision(self : RuntimeHealth) -> Int {
  self.policy_revision
}

///|
pub fn RuntimeHealth::healthy(self : RuntimeHealth) -> Bool {
  self.healthy
}

///|
pub fn RuntimeHealth::message(self : RuntimeHealth) -> String {
  self.message
}

///|
/// Aggregated runtime counters.
pub struct RuntimeMetrics {
  mut telemetry_received : Int
  mut telemetry_accepted : Int
  mut telemetry_rejected : Int
  mut commands_submitted : Int
  mut commands_dispatched : Int
  mut commands_completed : Int
  mut diagnostics : Int
} derive(Eq, Debug)

///|
pub fn RuntimeMetrics::new() -> RuntimeMetrics {
  {
    telemetry_received: 0,
    telemetry_accepted: 0,
    telemetry_rejected: 0,
    commands_submitted: 0,
    commands_dispatched: 0,
    commands_completed: 0,
    diagnostics: 0,
  }
}

///|
pub fn RuntimeMetrics::telemetry_received(self : RuntimeMetrics) -> Int {
  self.telemetry_received
}

///|
pub fn RuntimeMetrics::telemetry_accepted(self : RuntimeMetrics) -> Int {
  self.telemetry_accepted
}

///|
pub fn RuntimeMetrics::telemetry_rejected(self : RuntimeMetrics) -> Int {
  self.telemetry_rejected
}

///|
pub fn RuntimeMetrics::commands_submitted(self : RuntimeMetrics) -> Int {
  self.commands_submitted
}

///|
pub fn RuntimeMetrics::commands_dispatched(self : RuntimeMetrics) -> Int {
  self.commands_dispatched
}

///|
pub fn RuntimeMetrics::commands_completed(self : RuntimeMetrics) -> Int {
  self.commands_completed
}

///|
pub fn RuntimeMetrics::diagnostics(self : RuntimeMetrics) -> Int {
  self.diagnostics
}

///|
/// Integration facade connecting data, control, policy and redundancy layers.
pub struct Iec104Runtime {
  database : StationDatabase
  telemetry : TelemetryPipeline
  schedulers : Map[Int, CommandScheduler]
  redundancy : Map[Int, RedundancyManager]
  policy : OperationalPolicy
  redundancy_policy : RedundancyPolicy
  files : FileTransferManager
  clock : VirtualClock
  events : Array[RuntimeEvent]
  event_limit : Int
  mut next_event : Int
  metrics : RuntimeMetrics
} derive(Debug)

///|
pub fn Iec104Runtime::new(
  config? : RuntimeConfig = RuntimeConfig::default(),
) -> Result[Iec104Runtime, String] {
  match StationDatabase::new(event_limit=config.event_limit()) {
    Err(error) => Err(error)
    Ok(database) =>
      match TelemetryPipeline::new(alarm_limit=config.telemetry_alarm_limit()) {
        Err(error) => Err(error)
        Ok(telemetry) =>
          match OperationalPolicy::new(audit_limit=config.audit_limit()) {
            Err(error) => Err(error)
            Ok(policy) =>
              match
                FileStore::new(
                  capacity=config.file_capacity(),
                  maximum_size=config.file_maximum_size(),
                ) {
                Err(error) => Err(error)
                Ok(store) =>
                  match
                    FileTransferManager::new(
                      store,
                      history_limit=config.file_history_limit(),
                    ) {
                    Err(error) => Err(error)
                    Ok(files) =>
                      match VirtualClock::new() {
                        Err(error) => Err(error)
                        Ok(clock) =>
                          Ok({
                            database,
                            telemetry,
                            schedulers: {},
                            redundancy: {},
                            policy,
                            redundancy_policy: config.redundancy_policy(),
                            files,
                            clock,
                            events: [],
                            event_limit: config.event_limit(),
                            next_event: 1,
                            metrics: RuntimeMetrics::new(),
                          })
                      }
                  }
              }
          }
      }
  }
}

///|
pub fn Iec104Runtime::now(self : Iec104Runtime) -> Int {
  self.clock.now()
}

///|
pub fn Iec104Runtime::database(self : Iec104Runtime) -> StationDatabase {
  self.database
}

///|
pub fn Iec104Runtime::telemetry(self : Iec104Runtime) -> TelemetryPipeline {
  self.telemetry
}

///|
pub fn Iec104Runtime::policy(self : Iec104Runtime) -> OperationalPolicy {
  self.policy
}

///|
pub fn Iec104Runtime::files(self : Iec104Runtime) -> FileTransferManager {
  self.files
}

///|
pub fn Iec104Runtime::metrics(self : Iec104Runtime) -> RuntimeMetrics {
  self.metrics
}

///|
pub fn Iec104Runtime::events(self : Iec104Runtime) -> Array[RuntimeEvent] {
  self.events.copy()
}

///|
fn Iec104Runtime::event(
  self : Iec104Runtime,
  timestamp : Int,
  kind : RuntimeEventKind,
  station : CommonAddress?,
  object : InformationAddress?,
  correlation : Int,
  message : String,
) -> RuntimeEvent {
  let value = {
    sequence: self.next_event,
    timestamp,
    kind,
    station,
    object,
    correlation,
    message,
  }
  self.next_event += 1
  self.events.push(value)
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
  value
}

///|
pub fn Iec104Runtime::register_station(
  self : Iec104Runtime,
  config : StationConfig,
) -> Result[StationSummary, String] {
  let timestamp = self.now()
  match self.database.register(config, timestamp) {
    Err(error) => Err(error)
    Ok(summary) =>
      match CommandScheduler::new(audit_limit=self.event_limit) {
        Err(error) => Err(error)
        Ok(scheduler) => {
          self.schedulers[config.common_address().number()] = scheduler
          match
            RedundancyManager::new(
              config.common_address(),
              policy=self.default_redundancy_policy(),
            ) {
            Err(error) => Err(error)
            Ok(manager) => {
              self.redundancy[config.common_address().number()] = manager
              ignore(
                self.event(
                  timestamp,
                  StationRegisteredRuntime,
                  Some(config.common_address()),
                  None,
                  0,
                  "station registered at runtime",
                ),
              )
              Ok(summary)
            }
          }
        }
      }
  }
}

///|
fn Iec104Runtime::default_redundancy_policy(
  self : Iec104Runtime,
) -> RedundancyPolicy {
  self.redundancy_policy
}

///|
pub fn Iec104Runtime::add_peer(
  self : Iec104Runtime,
  peer : RedundantPeer,
) -> Result[Unit, String] {
  match self.redundancy.get(peer.station().number()) {
    None => Err("station has no redundancy manager")
    Some(manager) => manager.add_peer(peer)
  }
}

///|
pub fn Iec104Runtime::ingest(
  self : Iec104Runtime,
  station : CommonAddress,
  object : ApplicationObject,
  source? : String = "protocol",
) -> Result[PipelineResult, Diagnostic] {
  let timestamp = self.now()
  self.metrics.telemetry_received += 1
  match self.telemetry.ingest(station, object, timestamp, source~) {
    Err(error) => {
      self.metrics.telemetry_rejected += 1
      self.metrics.diagnostics += 1
      ignore(
        self.event(
          timestamp,
          TelemetryRejectedRuntime,
          Some(station),
          Some(object.address()),
          0,
          error.to_line(),
        ),
      )
      Err(error)
    }
    Ok(result) =>
      if result.accepted() {
        match self.database.write(station, object, timestamp, source~) {
          Err(error) => {
            self.metrics.telemetry_rejected += 1
            self.metrics.diagnostics += 1
            Err(error)
          }
          Ok(_) => {
            self.metrics.telemetry_accepted += 1
            ignore(
              self.event(
                timestamp,
                TelemetryAcceptedRuntime,
                Some(station),
                Some(object.address()),
                result.sample().sequence(),
                result.message(),
              ),
            )
            Ok(result)
          }
        }
      } else {
        self.metrics.telemetry_rejected += 1
        Ok(result)
      }
  }
}

///|
pub fn Iec104Runtime::heartbeat(
  self : Iec104Runtime,
  station : CommonAddress,
  peer_id : Int,
) -> Result[Unit, String] {
  let timestamp = self.now()
  match self.database.heartbeat(station, timestamp) {
    Err(error) => Err(error)
    Ok(_) =>
      match self.redundancy.get(station.number()) {
        None => Ok(())
        Some(manager) =>
          match manager.heartbeat(peer_id, timestamp) {
            Err(error) => Err(error)
            Ok(_) => {
              ignore(
                self.event(
                  timestamp,
                  RedundancyRuntime,
                  Some(station),
                  None,
                  peer_id,
                  "redundant heartbeat accepted",
                ),
              )
              Ok(())
            }
          }
      }
  }
}

///|
pub fn Iec104Runtime::submit_command(
  self : Iec104Runtime,
  operator_id : String,
  station : CommonAddress,
  object : ApplicationObject,
  priority : CommandPriority,
  deadline : Int,
  idempotency_key : String,
) -> Result[CommandRequest, Diagnostic] {
  let decision = self.policy.authorize(
    operator_id,
    SubmitCommands,
    station,
    Some(object.type_id()),
    self.now(),
  )
  if !decision.allowed() {
    self.metrics.diagnostics += 1
    Err(Diagnostic::new(InvalidQualifier, decision.reason()))
  } else {
    match self.schedulers.get(station.number()) {
      None =>
        Err(Diagnostic::new(InvalidAddress, "station has no command scheduler"))
      Some(scheduler) =>
        match
          scheduler.submit(
            station,
            object,
            priority,
            self.now(),
            deadline,
            idempotency_key,
          ) {
          Err(error) => {
            self.metrics.diagnostics += 1
            Err(error)
          }
          Ok(request) => {
            self.metrics.commands_submitted += 1
            ignore(
              self.event(
                self.now(),
                CommandSubmittedRuntime,
                Some(station),
                Some(object.address()),
                request.ticket(),
                "command submitted",
              ),
            )
            Ok(request)
          }
        }
    }
  }
}

///|
pub fn Iec104Runtime::dispatch_command(
  self : Iec104Runtime,
  station : CommonAddress,
  policy : CommandPolicy,
) -> Result[CommandDispatch?, Diagnostic] {
  match self.schedulers.get(station.number()) {
    None =>
      Err(Diagnostic::new(InvalidAddress, "station has no command scheduler"))
    Some(scheduler) =>
      match scheduler.dispatch(policy, self.now()) {
        Err(error) => Err(error)
        Ok(dispatch) => {
          match dispatch {
            Some(value) => {
              self.metrics.commands_dispatched += 1
              ignore(
                self.event(
                  self.now(),
                  CommandDispatchedRuntime,
                  Some(station),
                  Some(value.object().address()),
                  value.ticket(),
                  "command dispatched",
                ),
              )
            }
            None => ()
          }
          Ok(dispatch)
        }
      }
  }
}

///|
pub fn Iec104Runtime::confirm_command(
  self : Iec104Runtime,
  station : CommonAddress,
  ticket : Int,
  accepted : Bool,
  message? : String = "",
) -> Result[CommandRequest, Diagnostic] {
  match self.schedulers.get(station.number()) {
    None =>
      Err(Diagnostic::new(InvalidAddress, "station has no command scheduler"))
    Some(scheduler) =>
      match scheduler.confirm(ticket, self.now(), accepted, message~) {
        Err(error) => Err(error)
        Ok(request) => {
          if accepted {
            self.metrics.commands_completed += 1
            ignore(
              self.event(
                self.now(),
                CommandCompletedRuntime,
                Some(station),
                Some(request.object().address()),
                ticket,
                message,
              ),
            )
          }
          Ok(request)
        }
      }
  }
}

///|
pub fn Iec104Runtime::tick(
  self : Iec104Runtime,
  seconds : Int,
) -> Result[Unit, String] {
  match self.clock.advance(seconds) {
    Err(error) => Err(error)
    Ok(now) => {
      for _, scheduler in self.schedulers {
        ignore(scheduler.expire(now))
      }
      for _, manager in self.redundancy {
        ignore(manager.tick(now))
        ignore(manager.elect(now))
      }
      Ok(())
    }
  }
}

///|
pub fn Iec104Runtime::health(self : Iec104Runtime) -> RuntimeHealth {
  let points = self.database.query(
    StationQuery::all().with_disabled(true),
    self.now(),
  )
  let mut pending = 0
  let mut owners = 0
  for _, scheduler in self.schedulers {
    pending += scheduler.pending_count()
  }
  for _, manager in self.redundancy {
    if manager.owner() is Some(_) {
      owners += 1
    }
  }
  let alarms = self.telemetry.alarm_history().length()
  let sessions = self.files.session_count()
  {
    timestamp: self.now(),
    revision: self.database.revision(),
    stations: self.database.station_count(),
    points: points.length(),
    pending_commands: pending,
    active_alarms: alarms,
    active_sessions: sessions,
    redundancy_owners: owners,
    event_count: self.events.length(),
    policy_revision: self.policy.revision(),
    healthy: self.metrics.diagnostics == 0,
    message: if self.metrics.diagnostics == 0 {
      "runtime healthy"
    } else {
      "runtime has diagnostics"
    },
  }
}

///|
pub fn runtime_event_kind_examples() -> Array[RuntimeEventKind] {
  [
    RuntimeStarted,
    StationRegisteredRuntime,
    TelemetryAcceptedRuntime,
    TelemetryRejectedRuntime,
    CommandSubmittedRuntime,
    CommandDispatchedRuntime,
    CommandCompletedRuntime,
    FileSessionRuntime,
    RedundancyRuntime,
    RuntimeDiagnostic,
  ]
}
