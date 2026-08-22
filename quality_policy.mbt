///|
/// Result applied when an incoming point violates an operational quality gate.
pub enum QualityDisposition {
  QualityAccepted
  QualityDegraded
  QualityRejected
} derive(Eq, Debug)

///|
/// Machine-readable findings retained in the quality audit stream.
pub enum QualityFinding {
  QualityInvalidValue
  QualityStaleValue
  QualityFutureTimestamp
  QualityMissingSource
  QualityUnknownStation
  QualityControlBlocked
  QualityNoFinding
} derive(Eq, Debug)

///|
pub fn quality_disposition_text(disposition : QualityDisposition) -> String {
  match disposition {
    QualityAccepted => "accepted"
    QualityDegraded => "degraded"
    QualityRejected => "rejected"
  }
}

///|
pub fn quality_finding_text(finding : QualityFinding) -> String {
  match finding {
    QualityInvalidValue => "invalid-value"
    QualityStaleValue => "stale-value"
    QualityFutureTimestamp => "future-timestamp"
    QualityMissingSource => "missing-source"
    QualityUnknownStation => "unknown-station"
    QualityControlBlocked => "control-blocked"
    QualityNoFinding => "none"
  }
}

///|
/// A configurable quality gate for one station or an entire deployment.
pub struct QualityGateRule {
  id : Int
  name : String
  max_age : Int
  future_skew : Int
  require_source : Bool
  reject_invalid : Bool
  reject_stale : Bool
  reject_future : Bool
  reject_control : Bool
  invalid_penalty : Int
  stale_penalty : Int
  future_penalty : Int
  missing_source_penalty : Int
  enabled : Bool
} derive(Eq, Debug)

///|
pub fn QualityGateRule::new(
  id : Int,
  name : String,
  max_age? : Int = 300,
  future_skew? : Int = 30,
  require_source? : Bool = false,
  reject_invalid? : Bool = true,
  reject_stale? : Bool = false,
  reject_future? : Bool = true,
  reject_control? : Bool = false,
  invalid_penalty? : Int = 40,
  stale_penalty? : Int = 30,
  future_penalty? : Int = 20,
  missing_source_penalty? : Int = 15,
  enabled? : Bool = true,
) -> Result[QualityGateRule, String] {
  if id < 1 {
    Err("quality gate id must be positive")
  } else if name.length() == 0 || name.length() > 128 {
    Err("quality gate name must contain between 1 and 128 characters")
  } else if max_age < 0 || max_age > 31536000 {
    Err("quality gate maximum age is outside the supported range")
  } else if future_skew < 0 || future_skew > 31536000 {
    Err("quality gate future skew is outside the supported range")
  } else if invalid_penalty < 0 ||
    invalid_penalty > 100 ||
    stale_penalty < 0 ||
    stale_penalty > 100 ||
    future_penalty < 0 ||
    future_penalty > 100 ||
    missing_source_penalty < 0 ||
    missing_source_penalty > 100 {
    Err("quality gate penalty must be between 0 and 100")
  } else {
    Ok({
      id,
      name,
      max_age,
      future_skew,
      require_source,
      reject_invalid,
      reject_stale,
      reject_future,
      reject_control,
      invalid_penalty,
      stale_penalty,
      future_penalty,
      missing_source_penalty,
      enabled,
    })
  }
}

///|
pub fn QualityGateRule::default_rule() -> QualityGateRule {
  QualityGateRule::new(1, "default").unwrap()
}

///|
pub fn QualityGateRule::id(self : QualityGateRule) -> Int {
  self.id
}

///|
pub fn QualityGateRule::name(self : QualityGateRule) -> String {
  self.name
}

///|
pub fn QualityGateRule::max_age(self : QualityGateRule) -> Int {
  self.max_age
}

///|
pub fn QualityGateRule::future_skew(self : QualityGateRule) -> Int {
  self.future_skew
}

///|
pub fn QualityGateRule::require_source(self : QualityGateRule) -> Bool {
  self.require_source
}

///|
pub fn QualityGateRule::reject_invalid(self : QualityGateRule) -> Bool {
  self.reject_invalid
}

///|
pub fn QualityGateRule::reject_stale(self : QualityGateRule) -> Bool {
  self.reject_stale
}

///|
pub fn QualityGateRule::reject_future(self : QualityGateRule) -> Bool {
  self.reject_future
}

///|
pub fn QualityGateRule::reject_control(self : QualityGateRule) -> Bool {
  self.reject_control
}

///|
pub fn QualityGateRule::invalid_penalty(self : QualityGateRule) -> Int {
  self.invalid_penalty
}

///|
pub fn QualityGateRule::stale_penalty(self : QualityGateRule) -> Int {
  self.stale_penalty
}

///|
pub fn QualityGateRule::future_penalty(self : QualityGateRule) -> Int {
  self.future_penalty
}

///|
pub fn QualityGateRule::missing_source_penalty(self : QualityGateRule) -> Int {
  self.missing_source_penalty
}

///|
pub fn QualityGateRule::enabled(self : QualityGateRule) -> Bool {
  self.enabled
}

///|
pub fn QualityGateRule::with_enabled(
  self : QualityGateRule,
  enabled : Bool,
) -> QualityGateRule {
  {
    id: self.id,
    name: self.name,
    max_age: self.max_age,
    future_skew: self.future_skew,
    require_source: self.require_source,
    reject_invalid: self.reject_invalid,
    reject_stale: self.reject_stale,
    reject_future: self.reject_future,
    reject_control: self.reject_control,
    invalid_penalty: self.invalid_penalty,
    stale_penalty: self.stale_penalty,
    future_penalty: self.future_penalty,
    missing_source_penalty: self.missing_source_penalty,
    enabled,
  }
}

///|
/// Evaluation of one point, including all reasons retained for audit.
pub struct QualityEvaluation {
  station : CommonAddress?
  address : InformationAddress?
  disposition : QualityDisposition
  score : Int
  age : Int
  evaluated_at : Int
  rule_id : Int
  findings : Array[QualityFinding]
  message : String
} derive(Eq, Debug)

///|
pub fn QualityEvaluation::station(self : QualityEvaluation) -> CommonAddress? {
  self.station
}

///|
pub fn QualityEvaluation::address(
  self : QualityEvaluation,
) -> InformationAddress? {
  self.address
}

///|
pub fn QualityEvaluation::disposition(
  self : QualityEvaluation,
) -> QualityDisposition {
  self.disposition
}

///|
pub fn QualityEvaluation::accepted(self : QualityEvaluation) -> Bool {
  self.disposition != QualityRejected
}

///|
pub fn QualityEvaluation::score(self : QualityEvaluation) -> Int {
  self.score
}

///|
pub fn QualityEvaluation::age(self : QualityEvaluation) -> Int {
  self.age
}

///|
pub fn QualityEvaluation::evaluated_at(self : QualityEvaluation) -> Int {
  self.evaluated_at
}

///|
pub fn QualityEvaluation::rule_id(self : QualityEvaluation) -> Int {
  self.rule_id
}

///|
pub fn QualityEvaluation::findings(
  self : QualityEvaluation,
) -> Array[QualityFinding] {
  self.findings.copy()
}

///|
pub fn QualityEvaluation::message(self : QualityEvaluation) -> String {
  self.message
}

///|
/// Aggregate counters used by dashboards and acceptance reports.
pub struct QualityPolicyMetrics {
  mut evaluated : Int
  mut accepted : Int
  mut degraded : Int
  mut rejected : Int
  mut invalid : Int
  mut stale : Int
  mut future : Int
  mut missing_source : Int
  mut control_blocked : Int
} derive(Eq, Debug)

///|
pub fn QualityPolicyMetrics::new() -> QualityPolicyMetrics {
  {
    evaluated: 0,
    accepted: 0,
    degraded: 0,
    rejected: 0,
    invalid: 0,
    stale: 0,
    future: 0,
    missing_source: 0,
    control_blocked: 0,
  }
}

///|
pub fn QualityPolicyMetrics::evaluated(self : QualityPolicyMetrics) -> Int {
  self.evaluated
}

///|
pub fn QualityPolicyMetrics::accepted(self : QualityPolicyMetrics) -> Int {
  self.accepted
}

///|
pub fn QualityPolicyMetrics::degraded(self : QualityPolicyMetrics) -> Int {
  self.degraded
}

///|
pub fn QualityPolicyMetrics::rejected(self : QualityPolicyMetrics) -> Int {
  self.rejected
}

///|
pub fn QualityPolicyMetrics::invalid(self : QualityPolicyMetrics) -> Int {
  self.invalid
}

///|
pub fn QualityPolicyMetrics::stale(self : QualityPolicyMetrics) -> Int {
  self.stale
}

///|
pub fn QualityPolicyMetrics::future(self : QualityPolicyMetrics) -> Int {
  self.future
}

///|
pub fn QualityPolicyMetrics::missing_source(self : QualityPolicyMetrics) -> Int {
  self.missing_source
}

///|
pub fn QualityPolicyMetrics::control_blocked(
  self : QualityPolicyMetrics,
) -> Int {
  self.control_blocked
}

///|
/// Summary returned after evaluating a point-store snapshot.
pub struct QualityPolicyReport {
  total : Int
  accepted : Int
  degraded : Int
  rejected : Int
  evaluations : Array[QualityEvaluation]
} derive(Debug)

///|
pub fn QualityPolicyReport::total(self : QualityPolicyReport) -> Int {
  self.total
}

///|
pub fn QualityPolicyReport::accepted(self : QualityPolicyReport) -> Int {
  self.accepted
}

///|
pub fn QualityPolicyReport::degraded(self : QualityPolicyReport) -> Int {
  self.degraded
}

///|
pub fn QualityPolicyReport::rejected(self : QualityPolicyReport) -> Int {
  self.rejected
}

///|
pub fn QualityPolicyReport::evaluations(
  self : QualityPolicyReport,
) -> Array[QualityEvaluation] {
  self.evaluations.copy()
}

///|
/// Bounded policy engine keyed by rule id and station common address.
pub struct QualityPolicyEngine {
  rules : Map[Int, QualityGateRule]
  station_rules : Map[Int, Int]
  history : Array[QualityEvaluation]
  history_limit : Int
  metrics : QualityPolicyMetrics
} derive(Debug)

///|
pub fn QualityPolicyEngine::new(
  history_limit? : Int = 8192,
) -> Result[QualityPolicyEngine, String] {
  if history_limit < 1 {
    Err("quality policy history limit must be positive")
  } else {
    let engine = {
      rules: Map([]),
      station_rules: Map([]),
      history: [],
      history_limit,
      metrics: QualityPolicyMetrics::new(),
    }
    engine.rules[1] = QualityGateRule::default_rule()
    Ok(engine)
  }
}

///|
pub fn QualityPolicyEngine::metrics(
  self : QualityPolicyEngine,
) -> QualityPolicyMetrics {
  self.metrics
}

///|
pub fn QualityPolicyEngine::history(
  self : QualityPolicyEngine,
) -> Array[QualityEvaluation] {
  self.history.copy()
}

///|
pub fn QualityPolicyEngine::rule(
  self : QualityPolicyEngine,
  id : Int,
) -> QualityGateRule? {
  self.rules.get(id)
}

///|
pub fn QualityPolicyEngine::rule_ids(self : QualityPolicyEngine) -> Array[Int] {
  let result : Array[Int] = []
  for id, _ in self.rules {
    result.push(id)
  }
  result.sort()
  result
}

///|
pub fn QualityPolicyEngine::register_rule(
  self : QualityPolicyEngine,
  rule : QualityGateRule,
) -> Result[Unit, String] {
  if self.rules.contains(rule.id()) {
    Err("quality gate rule already exists")
  } else {
    self.rules[rule.id()] = rule
    Ok(())
  }
}

///|
pub fn QualityPolicyEngine::replace_rule(
  self : QualityPolicyEngine,
  rule : QualityGateRule,
) -> Result[Unit, String] {
  if !self.rules.contains(rule.id()) {
    Err("quality gate rule does not exist")
  } else {
    self.rules[rule.id()] = rule
    Ok(())
  }
}

///|
pub fn QualityPolicyEngine::remove_rule(
  self : QualityPolicyEngine,
  id : Int,
) -> Result[Unit, String] {
  if id == 1 {
    Err("default quality gate rule cannot be removed")
  } else if !self.rules.contains(id) {
    Err("quality gate rule does not exist")
  } else {
    for _, assigned in self.station_rules {
      if assigned == id {
        return Err("quality gate rule is assigned to a station")
      }
    }
    self.rules.remove(id)
    Ok(())
  }
}

///|
pub fn QualityPolicyEngine::assign(
  self : QualityPolicyEngine,
  station : CommonAddress,
  rule_id : Int,
) -> Result[Unit, String] {
  if station.is_global() {
    Err("quality gate assignment cannot target the global station")
  } else if !self.rules.contains(rule_id) {
    Err("quality gate rule does not exist")
  } else {
    self.station_rules[station.number()] = rule_id
    Ok(())
  }
}

///|
pub fn QualityPolicyEngine::unassign(
  self : QualityPolicyEngine,
  station : CommonAddress,
) -> Unit {
  self.station_rules.remove(station.number())
}

///|
pub fn QualityPolicyEngine::assigned_rule(
  self : QualityPolicyEngine,
  station : CommonAddress,
) -> Int {
  match self.station_rules.get(station.number()) {
    None => 1
    Some(id) => id
  }
}

///|
fn clamp_quality_score(score : Int) -> Int {
  if score < 0 {
    0
  } else if score > 100 {
    100
  } else {
    score
  }
}

///|
fn quality_message(findings : Array[QualityFinding]) -> String {
  if findings.length() == 0 {
    "quality gate accepted value"
  } else {
    let parts : Array[String] = []
    for finding in findings {
      parts.push(quality_finding_text(finding))
    }
    "quality gate findings: " + parts.join(",")
  }
}

///|
fn QualityPolicyEngine::record_evaluation(
  self : QualityPolicyEngine,
  evaluation : QualityEvaluation,
) -> Unit {
  self.history.push(evaluation)
  while self.history.length() > self.history_limit {
    ignore(self.history.remove(0))
  }
  self.metrics.evaluated += 1
  match evaluation.disposition() {
    QualityAccepted => self.metrics.accepted += 1
    QualityDegraded => self.metrics.degraded += 1
    QualityRejected => self.metrics.rejected += 1
  }
  for finding in evaluation.findings() {
    match finding {
      QualityInvalidValue => self.metrics.invalid += 1
      QualityStaleValue => self.metrics.stale += 1
      QualityFutureTimestamp => self.metrics.future += 1
      QualityMissingSource => self.metrics.missing_source += 1
      QualityControlBlocked => self.metrics.control_blocked += 1
      QualityUnknownStation => ()
      QualityNoFinding => ()
    }
  }
}

///|
fn evaluate_quality_fields(
  station : CommonAddress?,
  address : InformationAddress?,
  valid : Bool,
  control : Bool,
  timestamp : Int,
  now : Int,
  source : String,
  rule : QualityGateRule,
) -> QualityEvaluation {
  let findings : Array[QualityFinding] = []
  let mut score = 100
  let age = if now >= timestamp { now - timestamp } else { 0 }
  if !valid {
    findings.push(QualityInvalidValue)
    score -= rule.invalid_penalty()
  }
  if age > rule.max_age() {
    findings.push(QualityStaleValue)
    score -= rule.stale_penalty()
  }
  if timestamp > now + rule.future_skew() {
    findings.push(QualityFutureTimestamp)
    score -= rule.future_penalty()
  }
  if rule.require_source() && source.length() == 0 {
    findings.push(QualityMissingSource)
    score -= rule.missing_source_penalty()
  }
  if control && rule.reject_control() {
    findings.push(QualityControlBlocked)
    score = 0
  }
  let mut rejected = false
  for finding in findings {
    match finding {
      QualityInvalidValue => rejected = rejected || rule.reject_invalid()
      QualityStaleValue => rejected = rejected || rule.reject_stale()
      QualityFutureTimestamp => rejected = rejected || rule.reject_future()
      QualityControlBlocked => rejected = true
      _ => ()
    }
  }
  let disposition = if rejected {
    QualityRejected
  } else if findings.length() > 0 {
    QualityDegraded
  } else {
    QualityAccepted
  }
  {
    station,
    address,
    disposition,
    score: clamp_quality_score(score),
    age,
    evaluated_at: now,
    rule_id: rule.id(),
    findings: if findings.length() == 0 {
      [QualityNoFinding]
    } else {
      findings
    },
    message: quality_message(findings),
  }
}

///|
pub fn QualityPolicyEngine::evaluate_point(
  self : QualityPolicyEngine,
  station : CommonAddress,
  record : PointRecord,
  now : Int,
) -> QualityEvaluation {
  let rule_id = self.assigned_rule(station)
  let rule = self.rules.get(rule_id).unwrap()
  let evaluation = evaluate_quality_fields(
    Some(station),
    Some(record.address()),
    record.is_valid(),
    record.direction() == ControlDirection,
    record.updated_at(),
    now,
    record.source(),
    rule,
  )
  self.record_evaluation(evaluation)
  evaluation
}

///|
pub fn QualityPolicyEngine::evaluate_sample(
  self : QualityPolicyEngine,
  sample : TelemetrySample,
  now : Int,
) -> QualityEvaluation {
  let rule_id = self.assigned_rule(sample.station())
  let rule = self.rules.get(rule_id).unwrap()
  let evaluation = evaluate_quality_fields(
    Some(sample.station()),
    Some(sample.address()),
    sample.state() != InvalidTelemetry,
    false,
    sample.timestamp(),
    now,
    sample.source(),
    rule,
  )
  self.record_evaluation(evaluation)
  evaluation
}

///|
pub fn QualityPolicyEngine::evaluate_store(
  self : QualityPolicyEngine,
  store : PointStore,
  now : Int,
) -> QualityPolicyReport {
  let evaluations : Array[QualityEvaluation] = []
  let mut accepted = 0
  let mut degraded = 0
  let mut rejected = 0
  for record in store.query(PointFilter::all()) {
    let evaluation = self.evaluate_point(store.common_address(), record, now)
    evaluations.push(evaluation)
    match evaluation.disposition() {
      QualityAccepted => accepted += 1
      QualityDegraded => degraded += 1
      QualityRejected => rejected += 1
    }
  }
  { total: evaluations.length(), accepted, degraded, rejected, evaluations }
}

///|
pub fn QualityPolicyEngine::history_since(
  self : QualityPolicyEngine,
  evaluated_at : Int,
) -> Array[QualityEvaluation] {
  let result : Array[QualityEvaluation] = []
  for evaluation in self.history {
    if evaluation.evaluated_at() >= evaluated_at {
      result.push(evaluation)
    }
  }
  result
}

///|
pub fn QualityPolicyEngine::rejected_history(
  self : QualityPolicyEngine,
) -> Array[QualityEvaluation] {
  let result : Array[QualityEvaluation] = []
  for evaluation in self.history {
    if evaluation.disposition() == QualityRejected {
      result.push(evaluation)
    }
  }
  result
}

///|
pub fn QualityPolicyEngine::audit_lines(
  self : QualityPolicyEngine,
) -> Array[String] {
  let result : Array[String] = []
  for evaluation in self.history {
    let station_text = match evaluation.station() {
      None => "global"
      Some(station) => "\{station.number()}"
    }
    let address_text = match evaluation.address() {
      None => "none"
      Some(address) => "\{address.number()}"
    }
    result.push(
      "\{evaluation.evaluated_at()} station=\{station_text} " +
      "address=\{address_text} rule=\{evaluation.rule_id()} " +
      "disposition=\{quality_disposition_text(evaluation.disposition())} " +
      "score=\{evaluation.score()} \{evaluation.message()}",
    )
  }
  result
}

///|
pub fn quality_finding_examples() -> Array[QualityFinding] {
  [
    QualityInvalidValue,
    QualityStaleValue,
    QualityFutureTimestamp,
    QualityMissingSource,
    QualityUnknownStation,
    QualityControlBlocked,
    QualityNoFinding,
  ]
}

///|
pub fn quality_policy_examples() -> Array[QualityDisposition] {
  [QualityAccepted, QualityDegraded, QualityRejected]
}

///|
pub fn QualityEvaluation::finding_count(self : QualityEvaluation) -> Int {
  self.findings.length()
}

///|
pub fn QualityEvaluation::has_finding(
  self : QualityEvaluation,
  finding : QualityFinding,
) -> Bool {
  for candidate in self.findings {
    if candidate == finding {
      return true
    }
  }
  false
}

///|
pub fn QualityEvaluation::is_hard_failure(self : QualityEvaluation) -> Bool {
  self.disposition == QualityRejected ||
  self.has_finding(QualityInvalidValue) ||
  self.has_finding(QualityControlBlocked)
}

///|
pub fn QualityEvaluation::worst_finding(
  self : QualityEvaluation,
) -> QualityFinding {
  if self.has_finding(QualityInvalidValue) {
    QualityInvalidValue
  } else if self.has_finding(QualityControlBlocked) {
    QualityControlBlocked
  } else if self.has_finding(QualityFutureTimestamp) {
    QualityFutureTimestamp
  } else if self.has_finding(QualityStaleValue) {
    QualityStaleValue
  } else if self.has_finding(QualityMissingSource) {
    QualityMissingSource
  } else {
    QualityNoFinding
  }
}

///|
pub fn QualityEvaluation::summary_line(self : QualityEvaluation) -> String {
  let station_text = match self.station {
    None => "global"
    Some(station) => "\{station.number()}"
  }
  let address_text = match self.address {
    None => "none"
    Some(address) => "\{address.number()}"
  }
  "\{station_text}/\{address_text} \{quality_disposition_text(self.disposition)} " +
  "score=\{self.score} age=\{self.age} \{self.message}"
}

///|
pub fn QualityPolicyMetrics::has_rejections(
  self : QualityPolicyMetrics,
) -> Bool {
  self.rejected > 0
}

///|
pub fn QualityPolicyMetrics::total_findings(self : QualityPolicyMetrics) -> Int {
  self.invalid +
  self.stale +
  self.future +
  self.missing_source +
  self.control_blocked
}

///|
pub fn QualityPolicyMetrics::acceptance_percent(
  self : QualityPolicyMetrics,
) -> Int {
  if self.evaluated == 0 {
    100
  } else {
    self.accepted * 100 / self.evaluated
  }
}

///|
pub fn QualityPolicyMetrics::quality_percent(
  self : QualityPolicyMetrics,
) -> Int {
  if self.evaluated == 0 {
    100
  } else {
    (self.accepted * 100 + self.degraded * 50) / self.evaluated
  }
}

///|
pub fn QualityPolicyReport::has_rejections(self : QualityPolicyReport) -> Bool {
  self.rejected > 0
}

///|
pub fn QualityPolicyReport::quality_percent(self : QualityPolicyReport) -> Int {
  if self.total == 0 {
    100
  } else {
    (self.accepted * 100 + self.degraded * 50) / self.total
  }
}

///|
pub fn QualityPolicyEngine::assigned_stations(
  self : QualityPolicyEngine,
) -> Array[CommonAddress] {
  let result : Array[CommonAddress] = []
  for number, _ in self.station_rules {
    match CommonAddress::new(number) {
      Ok(station) => result.push(station)
      Err(_) => ()
    }
  }
  result.sort_by((left, right) => left.number() - right.number())
  result
}

///|
pub fn QualityPolicyEngine::stations_for_rule(
  self : QualityPolicyEngine,
  rule_id : Int,
) -> Array[CommonAddress] {
  let result : Array[CommonAddress] = []
  for number, assigned in self.station_rules {
    if assigned == rule_id {
      match CommonAddress::new(number) {
        Ok(station) => result.push(station)
        Err(_) => ()
      }
    }
  }
  result.sort_by((left, right) => left.number() - right.number())
  result
}

///|
pub fn QualityPolicyEngine::remove_assignment(
  self : QualityPolicyEngine,
  station : CommonAddress,
) -> Bool {
  if self.station_rules.contains(station.number()) {
    self.station_rules.remove(station.number())
    true
  } else {
    false
  }
}

///|
pub fn QualityPolicyEngine::clear_history(self : QualityPolicyEngine) -> Unit {
  self.history.clear()
}

///|
pub fn QualityPolicyEngine::history_len(self : QualityPolicyEngine) -> Int {
  self.history.length()
}

///|
pub fn QualityPolicyEngine::enabled_rule_ids(
  self : QualityPolicyEngine,
) -> Array[Int] {
  let result : Array[Int] = []
  for id, rule in self.rules {
    if rule.enabled() {
      result.push(id)
    }
  }
  result.sort()
  result
}

///|
pub fn QualityPolicyEngine::validate_configuration(
  self : QualityPolicyEngine,
) -> Array[String] {
  let issues : Array[String] = []
  if !self.rules.contains(1) {
    issues.push("default quality gate is missing")
  }
  for station, rule_id in self.station_rules {
    if !self.rules.contains(rule_id) {
      issues.push(
        "station \{station} points to unknown quality gate \{rule_id}",
      )
    }
  }
  for id, rule in self.rules {
    if !rule.enabled() {
      for _, assigned in self.station_rules {
        if assigned == id {
          issues.push("disabled quality gate is still assigned")
        }
      }
    }
  }
  issues.sort_by((left, right) => left.compare(right))
  issues
}

///|
pub struct QualityPolicySnapshot {
  rule_count : Int
  assignment_count : Int
  history_count : Int
  metrics : QualityPolicyMetrics
  configuration_issues : Array[String]
} derive(Debug)

///|
pub fn QualityPolicySnapshot::rule_count(self : QualityPolicySnapshot) -> Int {
  self.rule_count
}

///|
pub fn QualityPolicySnapshot::assignment_count(
  self : QualityPolicySnapshot,
) -> Int {
  self.assignment_count
}

///|
pub fn QualityPolicySnapshot::history_count(
  self : QualityPolicySnapshot,
) -> Int {
  self.history_count
}

///|
pub fn QualityPolicySnapshot::metrics(
  self : QualityPolicySnapshot,
) -> QualityPolicyMetrics {
  self.metrics
}

///|
pub fn QualityPolicySnapshot::configuration_issues(
  self : QualityPolicySnapshot,
) -> Array[String] {
  self.configuration_issues.copy()
}

///|
pub fn QualityPolicyEngine::snapshot(
  self : QualityPolicyEngine,
) -> QualityPolicySnapshot {
  {
    rule_count: self.rules.length(),
    assignment_count: self.station_rules.length(),
    history_count: self.history.length(),
    metrics: self.metrics,
    configuration_issues: self.validate_configuration(),
  }
}

///|
pub fn QualityPolicyEngine::evaluate_records(
  self : QualityPolicyEngine,
  station : CommonAddress,
  records : Array[PointRecord],
  now : Int,
) -> QualityPolicyReport {
  let evaluations : Array[QualityEvaluation] = []
  let mut accepted = 0
  let mut degraded = 0
  let mut rejected = 0
  for record in records {
    let evaluation = self.evaluate_point(station, record, now)
    evaluations.push(evaluation)
    match evaluation.disposition() {
      QualityAccepted => accepted += 1
      QualityDegraded => degraded += 1
      QualityRejected => rejected += 1
    }
  }
  { total: evaluations.length(), accepted, degraded, rejected, evaluations }
}

///|
pub fn QualityPolicyEngine::evaluate_object(
  self : QualityPolicyEngine,
  station : CommonAddress,
  object : ApplicationObject,
  source : String,
  timestamp : Int,
  now : Int,
) -> QualityEvaluation {
  let valid = match object.validate() {
    Ok(_) => true
    Err(_) => false
  }
  let rule_id = self.assigned_rule(station)
  let rule = self.rules.get(rule_id).unwrap()
  let evaluation = evaluate_quality_fields(
    Some(station),
    Some(object.address()),
    valid,
    object.type_id().is_control(),
    timestamp,
    now,
    source,
    rule,
  )
  self.record_evaluation(evaluation)
  evaluation
}

///|
pub fn QualityPolicyEngine::filter_accepted(
  _self : QualityPolicyEngine,
  evaluations : Array[QualityEvaluation],
) -> Array[QualityEvaluation] {
  let result : Array[QualityEvaluation] = []
  for evaluation in evaluations {
    if evaluation.accepted() {
      result.push(evaluation)
    }
  }
  result
}

///|
pub fn QualityPolicyEngine::filter_rejected(
  _self : QualityPolicyEngine,
  evaluations : Array[QualityEvaluation],
) -> Array[QualityEvaluation] {
  let result : Array[QualityEvaluation] = []
  for evaluation in evaluations {
    if !evaluation.accepted() {
      result.push(evaluation)
    }
  }
  result
}

///|
pub fn QualityPolicyEngine::finding_counts(
  _self : QualityPolicyEngine,
  evaluations : Array[QualityEvaluation],
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for evaluation in evaluations {
    for finding in evaluation.findings() {
      let key = quality_finding_text(finding)
      match counts.get(key) {
        None => counts[key] = 1
        Some(count) => counts[key] = count + 1
      }
    }
  }
  counts
}

///|
pub fn QualityPolicyEngine::rule_lines(
  self : QualityPolicyEngine,
) -> Array[String] {
  let lines : Array[String] = []
  for id in self.rule_ids() {
    let rule = self.rules.get(id).unwrap()
    lines.push(
      "\{rule.id()} \{rule.name()} age=\{rule.max_age()} " +
      "future=\{rule.future_skew()} source=\{rule.require_source()} " +
      "enabled=\{rule.enabled()}",
    )
  }
  lines
}

///|
pub fn QualityPolicyEngine::station_rule(
  self : QualityPolicyEngine,
  station : CommonAddress,
) -> QualityGateRule {
  let id = self.assigned_rule(station)
  self.rules.get(id).unwrap()
}

///|
pub fn QualityPolicyEngine::accepts_point(
  self : QualityPolicyEngine,
  station : CommonAddress,
  record : PointRecord,
  now : Int,
) -> Bool {
  self.evaluate_point(station, record, now).accepted()
}

///|
pub fn QualityPolicyEngine::accepts_sample(
  self : QualityPolicyEngine,
  sample : TelemetrySample,
  now : Int,
) -> Bool {
  self.evaluate_sample(sample, now).accepted()
}
