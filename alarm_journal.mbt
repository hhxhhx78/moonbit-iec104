///|
/// Lifecycle state tracked independently from telemetry threshold evaluation.
pub enum AlarmLifecycle {
  AlarmActive
  AlarmAcknowledged
  AlarmShelved
  AlarmCleared
  AlarmEscalated
} derive(Eq, Debug)

///|
pub struct AlarmRecord {
  key : String
  station : CommonAddress
  address : InformationAddress
  name : String
  severity : AlarmSeverity
  mut lifecycle : AlarmLifecycle
  first_seen : Int
  mut last_seen : Int
  mut occurrences : Int
  mut acknowledged_by : String?
  mut acknowledged_at : Int?
  mut shelf_until : Int?
  mut last_value : Float
  message : String
} derive(Debug)

///|
pub fn AlarmRecord::key(self : AlarmRecord) -> String {
  self.key
}

///|
pub fn AlarmRecord::station(self : AlarmRecord) -> CommonAddress {
  self.station
}

///|
pub fn AlarmRecord::address(self : AlarmRecord) -> InformationAddress {
  self.address
}

///|
pub fn AlarmRecord::name(self : AlarmRecord) -> String {
  self.name
}

///|
pub fn AlarmRecord::severity(self : AlarmRecord) -> AlarmSeverity {
  self.severity
}

///|
pub fn AlarmRecord::lifecycle(self : AlarmRecord) -> AlarmLifecycle {
  self.lifecycle
}

///|
pub fn AlarmRecord::first_seen(self : AlarmRecord) -> Int {
  self.first_seen
}

///|
pub fn AlarmRecord::last_seen(self : AlarmRecord) -> Int {
  self.last_seen
}

///|
pub fn AlarmRecord::occurrences(self : AlarmRecord) -> Int {
  self.occurrences
}

///|
pub fn AlarmRecord::acknowledged_by(self : AlarmRecord) -> String? {
  self.acknowledged_by
}

///|
pub fn AlarmRecord::acknowledged_at(self : AlarmRecord) -> Int? {
  self.acknowledged_at
}

///|
pub fn AlarmRecord::shelf_until(self : AlarmRecord) -> Int? {
  self.shelf_until
}

///|
pub fn AlarmRecord::last_value(self : AlarmRecord) -> Float {
  self.last_value
}

///|
pub fn AlarmRecord::message(self : AlarmRecord) -> String {
  self.message
}

///|
pub enum AlarmJournalAction {
  AlarmOpened
  AlarmUpdated
  AlarmAcknowledgedAction
  AlarmShelvedAction
  AlarmUnshelvedAction
  AlarmEscalatedAction
  AlarmClearedAction
} derive(Eq, Debug)

///|
pub struct AlarmJournalEvent {
  sequence : Int
  timestamp : Int
  key : String
  action : AlarmJournalAction
  operator : String
  detail : String
} derive(Eq, Debug)

///|
pub fn AlarmJournalEvent::sequence(self : AlarmJournalEvent) -> Int {
  self.sequence
}

///|
pub fn AlarmJournalEvent::timestamp(self : AlarmJournalEvent) -> Int {
  self.timestamp
}

///|
pub fn AlarmJournalEvent::key(self : AlarmJournalEvent) -> String {
  self.key
}

///|
pub fn AlarmJournalEvent::action(
  self : AlarmJournalEvent,
) -> AlarmJournalAction {
  self.action
}

///|
pub fn AlarmJournalEvent::operator(self : AlarmJournalEvent) -> String {
  self.operator
}

///|
pub fn AlarmJournalEvent::detail(self : AlarmJournalEvent) -> String {
  self.detail
}

///|
pub struct AlarmJournalMetrics {
  mut opened : Int
  mut acknowledged : Int
  mut shelved : Int
  mut escalated : Int
  mut cleared : Int
} derive(Eq, Debug)

///|
pub fn AlarmJournalMetrics::new() -> AlarmJournalMetrics {
  { opened: 0, acknowledged: 0, shelved: 0, escalated: 0, cleared: 0 }
}

///|
pub fn AlarmJournalMetrics::opened(self : AlarmJournalMetrics) -> Int {
  self.opened
}

///|
pub fn AlarmJournalMetrics::acknowledged(self : AlarmJournalMetrics) -> Int {
  self.acknowledged
}

///|
pub fn AlarmJournalMetrics::shelved(self : AlarmJournalMetrics) -> Int {
  self.shelved
}

///|
pub fn AlarmJournalMetrics::escalated(self : AlarmJournalMetrics) -> Int {
  self.escalated
}

///|
pub fn AlarmJournalMetrics::cleared(self : AlarmJournalMetrics) -> Int {
  self.cleared
}

///|
/// Bounded alarm journal with acknowledge, shelf and escalation workflows.
pub struct AlarmJournal {
  active : Map[String, AlarmRecord]
  events : Array[AlarmJournalEvent]
  event_limit : Int
  mut next_sequence : Int
  metrics : AlarmJournalMetrics
} derive(Debug)

///|
pub fn AlarmJournal::new(
  event_limit? : Int = 8192,
) -> Result[AlarmJournal, String] {
  if event_limit < 1 {
    Err("alarm journal event limit must be positive")
  } else {
    Ok({
      active: {},
      events: [],
      event_limit,
      next_sequence: 1,
      metrics: AlarmJournalMetrics::new(),
    })
  }
}

///|
pub fn AlarmJournal::metrics(self : AlarmJournal) -> AlarmJournalMetrics {
  self.metrics
}

///|
pub fn AlarmJournal::active_count(self : AlarmJournal) -> Int {
  self.active.length()
}

///|
pub fn AlarmJournal::events(self : AlarmJournal) -> Array[AlarmJournalEvent] {
  self.events.copy()
}

///|
pub fn AlarmJournal::all(self : AlarmJournal) -> Array[AlarmRecord] {
  let result : Array[AlarmRecord] = []
  for _, record in self.active {
    result.push(record)
  }
  result.sort_by((left, right) => {
    if left.severity().weight() != right.severity().weight() {
      right.severity().weight() - left.severity().weight()
    } else {
      left.key().compare(right.key())
    }
  })
  result
}

///|
fn AlarmJournal::record_event(
  self : AlarmJournal,
  timestamp : Int,
  key : String,
  action : AlarmJournalAction,
  operator : String,
  detail : String,
) -> Unit {
  self.events.push({
    sequence: self.next_sequence,
    timestamp,
    key,
    action,
    operator,
    detail,
  })
  self.next_sequence += 1
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
}

///|
fn alarm_record_key(event : AlarmEvent) -> String {
  "\{event.station().number()}:\{event.address().number()}:\{event.name()}"
}

///|
pub fn AlarmJournal::ingest(
  self : AlarmJournal,
  event : AlarmEvent,
) -> Result[AlarmRecord, String] {
  let key = alarm_record_key(event)
  if event.active() {
    match self.active.get(key) {
      None => {
        let record = {
          key,
          station: event.station(),
          address: event.address(),
          name: event.name(),
          severity: event.severity(),
          lifecycle: AlarmActive,
          first_seen: event.timestamp(),
          last_seen: event.timestamp(),
          occurrences: 1,
          acknowledged_by: None,
          acknowledged_at: None,
          shelf_until: None,
          last_value: event.value(),
          message: event.message(),
        }
        self.active[key] = record
        self.metrics.opened += 1
        self.record_event(
          event.timestamp(),
          key,
          AlarmOpened,
          "system",
          event.message(),
        )
        Ok(record)
      }
      Some(record) => {
        record.last_seen = event.timestamp()
        record.last_value = event.value()
        record.occurrences += 1
        if record.lifecycle() == AlarmCleared {
          record.lifecycle = AlarmActive
        }
        self.active[key] = record
        self.record_event(
          event.timestamp(),
          key,
          AlarmUpdated,
          "system",
          event.message(),
        )
        Ok(record)
      }
    }
  } else {
    match self.active.get(key) {
      None => Err("cannot clear an unknown alarm")
      Some(record) => {
        record.lifecycle = AlarmCleared
        record.last_seen = event.timestamp()
        record.last_value = event.value()
        self.active.remove(key)
        self.metrics.cleared += 1
        self.record_event(
          event.timestamp(),
          key,
          AlarmClearedAction,
          "system",
          event.message(),
        )
        Ok(record)
      }
    }
  }
}

///|
pub fn AlarmJournal::get(self : AlarmJournal, key : String) -> AlarmRecord? {
  self.active.get(key)
}

///|
pub fn AlarmJournal::acknowledge(
  self : AlarmJournal,
  key : String,
  operator : String,
  timestamp : Int,
) -> Result[AlarmRecord, String] {
  match self.active.get(key) {
    None => Err("alarm does not exist")
    Some(record) =>
      if record.lifecycle() == AlarmAcknowledged {
        Ok(record)
      } else if operator.length() == 0 {
        Err("acknowledging operator is empty")
      } else {
        record.lifecycle = AlarmAcknowledged
        record.acknowledged_by = Some(operator)
        record.acknowledged_at = Some(timestamp)
        self.active[key] = record
        self.metrics.acknowledged += 1
        self.record_event(
          timestamp,
          key,
          AlarmAcknowledgedAction,
          operator,
          "alarm acknowledged",
        )
        Ok(record)
      }
  }
}

///|
pub fn AlarmJournal::shelve(
  self : AlarmJournal,
  key : String,
  operator : String,
  until : Int,
  timestamp : Int,
) -> Result[AlarmRecord, String] {
  if until <= timestamp {
    Err("alarm shelf deadline must be in the future")
  } else {
    match self.active.get(key) {
      None => Err("alarm does not exist")
      Some(record) => {
        record.lifecycle = AlarmShelved
        record.shelf_until = Some(until)
        self.active[key] = record
        self.metrics.shelved += 1
        self.record_event(
          timestamp,
          key,
          AlarmShelvedAction,
          operator,
          "alarm shelved",
        )
        Ok(record)
      }
    }
  }
}

///|
pub fn AlarmJournal::escalate(
  self : AlarmJournal,
  key : String,
  operator : String,
  timestamp : Int,
) -> Result[AlarmRecord, String] {
  match self.active.get(key) {
    None => Err("alarm does not exist")
    Some(record) => {
      record.lifecycle = AlarmEscalated
      self.active[key] = record
      self.metrics.escalated += 1
      self.record_event(
        timestamp,
        key,
        AlarmEscalatedAction,
        operator,
        "alarm escalated",
      )
      Ok(record)
    }
  }
}

///|
pub fn AlarmJournal::unshelve_expired(
  self : AlarmJournal,
  timestamp : Int,
) -> Int {
  let mut count = 0
  for key, record in self.active {
    match record.shelf_until() {
      Some(until) =>
        if timestamp >= until {
          record.shelf_until = None
          record.lifecycle = AlarmActive
          self.active[key] = record
          self.record_event(
            timestamp,
            key,
            AlarmUnshelvedAction,
            "system",
            "alarm shelf expired",
          )
          count += 1
        }
      None => ()
    }
  }
  count
}

///|
pub fn alarm_lifecycle_examples() -> Array[AlarmLifecycle] {
  [AlarmActive, AlarmAcknowledged, AlarmShelved, AlarmCleared, AlarmEscalated]
}

///|
pub fn alarm_journal_action_examples() -> Array[AlarmJournalAction] {
  [
    AlarmOpened,
    AlarmUpdated,
    AlarmAcknowledgedAction,
    AlarmShelvedAction,
    AlarmUnshelvedAction,
    AlarmEscalatedAction,
    AlarmClearedAction,
  ]
}
