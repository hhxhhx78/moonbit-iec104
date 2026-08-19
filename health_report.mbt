///|
/// Health state suitable for gateway readiness endpoints.
pub enum HealthState {
  Healthy
  Degraded
  Unready
} derive(Eq, Debug)

///|
pub struct HealthReport {
  state : HealthState
  score : Int
  checks : Array[String]
  warnings : Array[String]
} derive(Eq, Debug)

///|
pub fn HealthReport::new(
  state : HealthState,
  score : Int,
  checks : Array[String],
  warnings : Array[String],
) -> HealthReport {
  { state, score, checks, warnings }
}

///|
pub fn HealthReport::state(self : HealthReport) -> HealthState {
  self.state
}

///|
pub fn HealthReport::score(self : HealthReport) -> Int {
  self.score
}

///|
pub fn HealthReport::checks(self : HealthReport) -> Array[String] {
  self.checks.copy()
}

///|
pub fn HealthReport::warnings(self : HealthReport) -> Array[String] {
  self.warnings.copy()
}

///|
pub fn assess_session(snapshot : SessionSnapshot) -> HealthReport {
  let checks : Array[String] = ["session snapshot available"]
  let warnings : Array[String] = []
  let mut score = 100
  if !snapshot.is_started() {
    score -= 25
    warnings.push("data transfer is not started")
  }
  if snapshot.available() == 0 {
    score -= 20
    warnings.push("send window is full")
  }
  if score >= 80 {
    HealthReport::new(Healthy, score, checks, warnings)
  } else if score >= 50 {
    HealthReport::new(Degraded, score, checks, warnings)
  } else {
    HealthReport::new(Unready, score, checks, warnings)
  }
}

///|
pub fn assess_store(store : PointStore) -> HealthReport {
  let statistics = store.statistics()
  let checks : Array[String] = ["point store readable", "history bounded"]
  let warnings : Array[String] = []
  let mut score = 100
  if statistics.total() == 0 {
    score -= 20
    warnings.push("point store has no values")
  }
  if statistics.invalid() > 0 {
    score -= 10
    warnings.push("invalid quality values are present")
  }
  if score >= 80 {
    HealthReport::new(Healthy, score, checks, warnings)
  } else if score >= 50 {
    HealthReport::new(Degraded, score, checks, warnings)
  } else {
    HealthReport::new(Unready, score, checks, warnings)
  }
}

///|
pub fn assess_metrics(metrics : MetricsSnapshot) -> HealthReport {
  let checks : Array[String] = ["metrics counters readable"]
  let warnings : Array[String] = []
  let mut score = 100
  if metrics.errors() > metrics.frames() {
    score -= 50
    warnings.push("error count exceeds processed frame count")
  }
  if metrics.success_rate() < 0.95 {
    score -= 20
    warnings.push("success rate is below 95 percent")
  }
  if score >= 80 {
    HealthReport::new(Healthy, score, checks, warnings)
  } else if score >= 50 {
    HealthReport::new(Degraded, score, checks, warnings)
  } else {
    HealthReport::new(Unready, score, checks, warnings)
  }
}

///|
pub fn health_state_examples() -> Array[HealthState] {
  [Healthy, Degraded, Unready]
}
