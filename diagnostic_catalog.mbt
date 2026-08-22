///|
/// Operational severity for normalized protocol diagnostics.
pub enum DiagnosticSeverity {
  NoticeDiagnostic
  WarningDiagnostic
  ErrorDiagnostic
  CriticalDiagnostic
} derive(Eq, Debug)

///|
pub fn DiagnosticSeverity::weight(self : DiagnosticSeverity) -> Int {
  match self {
    NoticeDiagnostic => 0
    WarningDiagnostic => 1
    ErrorDiagnostic => 2
    CriticalDiagnostic => 3
  }
}

///|
pub struct DiagnosticRecord {
  key : String
  kind : DiagnosticKind
  severity : DiagnosticSeverity
  message : String
  station : CommonAddress?
  first_seen : Int
  mut last_seen : Int
  mut occurrences : Int
  mut active : Bool
  mut acknowledged : Bool
  mut acknowledged_by : String?
} derive(Eq, Debug)

///|
pub fn DiagnosticRecord::key(self : DiagnosticRecord) -> String {
  self.key
}

///|
pub fn DiagnosticRecord::kind(self : DiagnosticRecord) -> DiagnosticKind {
  self.kind
}

///|
pub fn DiagnosticRecord::severity(
  self : DiagnosticRecord,
) -> DiagnosticSeverity {
  self.severity
}

///|
pub fn DiagnosticRecord::message(self : DiagnosticRecord) -> String {
  self.message
}

///|
pub fn DiagnosticRecord::station(self : DiagnosticRecord) -> CommonAddress? {
  self.station
}

///|
pub fn DiagnosticRecord::first_seen(self : DiagnosticRecord) -> Int {
  self.first_seen
}

///|
pub fn DiagnosticRecord::last_seen(self : DiagnosticRecord) -> Int {
  self.last_seen
}

///|
pub fn DiagnosticRecord::occurrences(self : DiagnosticRecord) -> Int {
  self.occurrences
}

///|
pub fn DiagnosticRecord::active(self : DiagnosticRecord) -> Bool {
  self.active
}

///|
pub fn DiagnosticRecord::acknowledged(self : DiagnosticRecord) -> Bool {
  self.acknowledged
}

///|
pub fn DiagnosticRecord::acknowledged_by(self : DiagnosticRecord) -> String? {
  self.acknowledged_by
}

///|
pub struct DiagnosticCatalogMetrics {
  mut raised : Int
  mut resolved : Int
  mut acknowledged : Int
  mut deduplicated : Int
} derive(Eq, Debug)

///|
pub fn DiagnosticCatalogMetrics::new() -> DiagnosticCatalogMetrics {
  { raised: 0, resolved: 0, acknowledged: 0, deduplicated: 0 }
}

///|
pub fn DiagnosticCatalogMetrics::raised(self : DiagnosticCatalogMetrics) -> Int {
  self.raised
}

///|
pub fn DiagnosticCatalogMetrics::resolved(
  self : DiagnosticCatalogMetrics,
) -> Int {
  self.resolved
}

///|
pub fn DiagnosticCatalogMetrics::acknowledged(
  self : DiagnosticCatalogMetrics,
) -> Int {
  self.acknowledged
}

///|
pub fn DiagnosticCatalogMetrics::deduplicated(
  self : DiagnosticCatalogMetrics,
) -> Int {
  self.deduplicated
}

///|
pub struct DiagnosticCatalog {
  records : Map[String, DiagnosticRecord]
  history : Array[DiagnosticRecord]
  history_limit : Int
  metrics : DiagnosticCatalogMetrics
} derive(Debug)

///|
pub fn DiagnosticCatalog::new(
  history_limit? : Int = 4096,
) -> Result[DiagnosticCatalog, String] {
  if history_limit < 1 {
    Err("diagnostic history limit must be positive")
  } else {
    Ok({
      records: {},
      history: [],
      history_limit,
      metrics: DiagnosticCatalogMetrics::new(),
    })
  }
}

///|
pub fn DiagnosticCatalog::metrics(
  self : DiagnosticCatalog,
) -> DiagnosticCatalogMetrics {
  self.metrics
}

///|
pub fn DiagnosticCatalog::len(self : DiagnosticCatalog) -> Int {
  self.records.length()
}

///|
pub fn DiagnosticCatalog::history(
  self : DiagnosticCatalog,
) -> Array[DiagnosticRecord] {
  self.history.copy()
}

///|
pub fn DiagnosticCatalog::get(
  self : DiagnosticCatalog,
  key : String,
) -> DiagnosticRecord? {
  self.records.get(key)
}

///|
pub fn DiagnosticCatalog::active(
  self : DiagnosticCatalog,
) -> Array[DiagnosticRecord] {
  let result : Array[DiagnosticRecord] = []
  for _, record in self.records {
    if record.active() {
      result.push(record)
    }
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
fn diagnostic_kind_text(kind : DiagnosticKind) -> String {
  match kind {
    MalformedFrame => "malformed-frame"
    InvalidSequence => "invalid-sequence"
    InvalidAddress => "invalid-address"
    InvalidType => "invalid-type"
    InvalidQualifier => "invalid-qualifier"
    UnsupportedFeature => "unsupported-feature"
    WindowExhausted => "window-exhausted"
    TimerExpired => "timer-expired"
    StateViolation => "state-violation"
    TransportFailure => "transport-failure"
  }
}

///|
fn diagnostic_key(
  kind : DiagnosticKind,
  station : CommonAddress?,
  message : String,
) -> String {
  let station_text = match station {
    Some(value) => "\{value.number()}"
    None => "global"
  }
  "\{diagnostic_kind_text(kind)}:\{station_text}:\{message}"
}

///|
pub fn DiagnosticCatalog::record_diagnostic(
  self : DiagnosticCatalog,
  diagnostic : Diagnostic,
  severity : DiagnosticSeverity,
  station : CommonAddress?,
  timestamp : Int,
) -> DiagnosticRecord {
  let key = diagnostic_key(diagnostic.kind(), station, diagnostic.message())
  match self.records.get(key) {
    None => {
      let record = {
        key,
        kind: diagnostic.kind(),
        severity,
        message: diagnostic.message(),
        station,
        first_seen: timestamp,
        last_seen: timestamp,
        occurrences: 1,
        active: true,
        acknowledged: false,
        acknowledged_by: None,
      }
      self.records[key] = record
      self.metrics.raised += 1
      self.history.push(record)
      while self.history.length() > self.history_limit {
        ignore(self.history.remove(0))
      }
      record
    }
    Some(record) => {
      record.last_seen = timestamp
      record.occurrences += 1
      record.active = true
      self.records[key] = record
      self.metrics.deduplicated += 1
      record
    }
  }
}

///|
pub fn DiagnosticCatalog::resolve(
  self : DiagnosticCatalog,
  key : String,
  timestamp : Int,
) -> Result[DiagnosticRecord, String] {
  match self.records.get(key) {
    None => Err("diagnostic record does not exist")
    Some(record) => {
      record.active = false
      record.last_seen = timestamp
      self.records[key] = record
      self.metrics.resolved += 1
      self.history.push(record)
      while self.history.length() > self.history_limit {
        ignore(self.history.remove(0))
      }
      Ok(record)
    }
  }
}

///|
pub fn DiagnosticCatalog::acknowledge(
  self : DiagnosticCatalog,
  key : String,
  operator : String,
) -> Result[DiagnosticRecord, String] {
  if operator.length() == 0 {
    Err("diagnostic acknowledging operator is empty")
  } else {
    match self.records.get(key) {
      None => Err("diagnostic record does not exist")
      Some(record) => {
        record.acknowledged = true
        record.acknowledged_by = Some(operator)
        self.records[key] = record
        self.metrics.acknowledged += 1
        Ok(record)
      }
    }
  }
}

///|
pub fn DiagnosticCatalog::purge_resolved(self : DiagnosticCatalog) -> Int {
  let mut count = 0
  let keys : Array[String] = []
  for key, record in self.records {
    if !record.active() {
      keys.push(key)
    }
  }
  for key in keys {
    self.records.remove(key)
    count += 1
  }
  count
}

///|
pub fn diagnostic_severity_examples() -> Array[DiagnosticSeverity] {
  [NoticeDiagnostic, WarningDiagnostic, ErrorDiagnostic, CriticalDiagnostic]
}
