///|
/// Quality state normalized for downstream telemetry and alarm consumers.
pub enum TelemetryState {
  GoodTelemetry
  DegradedTelemetry
  InvalidTelemetry
} derive(Eq, Debug)

///|
pub fn TelemetryState::usable(self : TelemetryState) -> Bool {
  self == GoodTelemetry
}

///|
/// Alarm severity emitted by a threshold stage.
pub enum AlarmSeverity {
  InformationalAlarm
  WarningAlarm
  MajorAlarm
  CriticalAlarm
} derive(Eq, Debug)

///|
pub fn AlarmSeverity::weight(self : AlarmSeverity) -> Int {
  match self {
    InformationalAlarm => 0
    WarningAlarm => 1
    MajorAlarm => 2
    CriticalAlarm => 3
  }
}

///|
/// A sample normalized to a numeric value while retaining IEC identity.
pub struct TelemetrySample {
  station : CommonAddress
  address : InformationAddress
  type_id : ApplicationType
  value : Float
  quality : QualityDescriptor
  state : TelemetryState
  timestamp : Int
  source : String
  sequence : Int
} derive(Debug)

///|
pub fn TelemetrySample::station(self : TelemetrySample) -> CommonAddress {
  self.station
}

///|
pub fn TelemetrySample::address(self : TelemetrySample) -> InformationAddress {
  self.address
}

///|
pub fn TelemetrySample::type_id(self : TelemetrySample) -> ApplicationType {
  self.type_id
}

///|
pub fn TelemetrySample::value(self : TelemetrySample) -> Float {
  self.value
}

///|
pub fn TelemetrySample::quality(self : TelemetrySample) -> QualityDescriptor {
  self.quality
}

///|
pub fn TelemetrySample::state(self : TelemetrySample) -> TelemetryState {
  self.state
}

///|
pub fn TelemetrySample::timestamp(self : TelemetrySample) -> Int {
  self.timestamp
}

///|
pub fn TelemetrySample::source(self : TelemetrySample) -> String {
  self.source
}

///|
pub fn TelemetrySample::sequence(self : TelemetrySample) -> Int {
  self.sequence
}

///|
/// Deadband rule that prevents unchanged analog values from flooding a link.
pub struct DeadbandRule {
  absolute : Float
  relative_percent : Float
  minimum_interval : Int
} derive(Eq, Debug)

///|
pub fn DeadbandRule::new(
  absolute? : Float = 0.0,
  relative_percent? : Float = 0.0,
  minimum_interval? : Int = 0,
) -> Result[DeadbandRule, String] {
  if absolute < 0.0 || relative_percent < 0.0 {
    Err("deadband values cannot be negative")
  } else if relative_percent > 100.0 {
    Err("relative deadband cannot exceed 100 percent")
  } else if minimum_interval < 0 {
    Err("deadband minimum interval cannot be negative")
  } else {
    Ok({ absolute, relative_percent, minimum_interval })
  }
}

///|
pub fn DeadbandRule::absolute(self : DeadbandRule) -> Float {
  self.absolute
}

///|
pub fn DeadbandRule::relative_percent(self : DeadbandRule) -> Float {
  self.relative_percent
}

///|
pub fn DeadbandRule::minimum_interval(self : DeadbandRule) -> Int {
  self.minimum_interval
}

///|
pub fn DeadbandRule::changed(
  self : DeadbandRule,
  previous : TelemetrySample,
  current : TelemetrySample,
) -> Bool {
  let zero : Float = Float::from_int(0)
  let hundred : Float = Float::from_int(100)
  let difference = if current.value() >= previous.value() {
    current.value() - previous.value()
  } else {
    previous.value() - current.value()
  }
  let base = if previous.value() >= zero {
    previous.value()
  } else {
    Float::neg(previous.value())
  }
  let relative : Float = if base == zero {
    if difference == zero {
      zero
    } else {
      hundred
    }
  } else {
    Float::div(Float::mul(difference, hundred), base)
  }
  let elapsed = current.timestamp() - previous.timestamp()
  difference >= self.absolute ||
  relative >= self.relative_percent ||
  elapsed >= self.minimum_interval
}

///|
/// Rate-of-change rule for detecting stale or physically implausible updates.
pub struct RateRule {
  maximum_per_second : Float
  minimum_interval : Int
} derive(Eq, Debug)

///|
pub fn RateRule::new(
  maximum_per_second : Float,
  minimum_interval? : Int = 1,
) -> Result[RateRule, String] {
  if maximum_per_second <= 0.0 {
    Err("maximum rate must be positive")
  } else if minimum_interval < 1 {
    Err("rate rule interval must be positive")
  } else {
    Ok({ maximum_per_second, minimum_interval })
  }
}

///|
pub fn RateRule::maximum_per_second(self : RateRule) -> Float {
  self.maximum_per_second
}

///|
pub fn RateRule::minimum_interval(self : RateRule) -> Int {
  self.minimum_interval
}

///|
pub fn RateRule::within(
  self : RateRule,
  previous : TelemetrySample,
  current : TelemetrySample,
) -> Bool {
  let elapsed = current.timestamp() - previous.timestamp()
  if elapsed < self.minimum_interval {
    false
  } else {
    let difference = if current.value() >= previous.value() {
      current.value() - previous.value()
    } else {
      previous.value() - current.value()
    }
    difference / Float::from_int(elapsed) <= self.maximum_per_second
  }
}

///|
/// Threshold used for alarm creation and clearing.
pub struct AlarmRule {
  low : Float?
  high : Float?
  severity : AlarmSeverity
  hysteresis : Float
  name : String
} derive(Eq, Debug)

///|
pub fn AlarmRule::new(
  name : String,
  severity : AlarmSeverity,
  low? : Float,
  high? : Float,
  hysteresis? : Float = 0.0,
) -> Result[AlarmRule, String] {
  if name.length() == 0 {
    Err("alarm rule name is empty")
  } else if hysteresis < 0.0 {
    Err("alarm hysteresis cannot be negative")
  } else {
    match (low, high) {
      (Some(low_value), Some(high_value)) =>
        if low_value > high_value {
          Err("alarm low threshold exceeds high threshold")
        } else {
          Ok({ name, low, high, severity, hysteresis })
        }
      _ => Ok({ name, low, high, severity, hysteresis })
    }
  }
}

///|
pub fn AlarmRule::name(self : AlarmRule) -> String {
  self.name
}

///|
pub fn AlarmRule::severity(self : AlarmRule) -> AlarmSeverity {
  self.severity
}

///|
pub fn AlarmRule::low(self : AlarmRule) -> Float? {
  self.low
}

///|
pub fn AlarmRule::high(self : AlarmRule) -> Float? {
  self.high
}

///|
pub fn AlarmRule::hysteresis(self : AlarmRule) -> Float {
  self.hysteresis
}

///|
fn AlarmRule::level(self : AlarmRule, value : Float) -> AlarmSeverity? {
  match self.high {
    Some(limit) => if value >= limit { Some(self.severity) } else { None }
    None =>
      match self.low {
        Some(limit) => if value <= limit { Some(self.severity) } else { None }
        None => None
      }
  }
}

///|
/// An alarm lifecycle event.
pub struct AlarmEvent {
  station : CommonAddress
  address : InformationAddress
  name : String
  severity : AlarmSeverity
  active : Bool
  value : Float
  timestamp : Int
  message : String
} derive(Eq, Debug)

///|
pub fn AlarmEvent::station(self : AlarmEvent) -> CommonAddress {
  self.station
}

///|
pub fn AlarmEvent::address(self : AlarmEvent) -> InformationAddress {
  self.address
}

///|
pub fn AlarmEvent::name(self : AlarmEvent) -> String {
  self.name
}

///|
pub fn AlarmEvent::severity(self : AlarmEvent) -> AlarmSeverity {
  self.severity
}

///|
pub fn AlarmEvent::active(self : AlarmEvent) -> Bool {
  self.active
}

///|
pub fn AlarmEvent::value(self : AlarmEvent) -> Float {
  self.value
}

///|
pub fn AlarmEvent::timestamp(self : AlarmEvent) -> Int {
  self.timestamp
}

///|
pub fn AlarmEvent::message(self : AlarmEvent) -> String {
  self.message
}

///|
/// Subscription route for stream consumers.
pub struct TelemetrySubscription {
  id : Int
  station : CommonAddress?
  first_address : InformationAddress?
  last_address : InformationAddress?
  minimum_state : TelemetryState
  include_unchanged : Bool
} derive(Eq, Debug)

///|
pub fn TelemetrySubscription::new(
  id : Int,
  station? : CommonAddress,
  first_address? : InformationAddress,
  last_address? : InformationAddress,
  minimum_state? : TelemetryState = GoodTelemetry,
  include_unchanged? : Bool = false,
) -> Result[TelemetrySubscription, String] {
  match (first_address, last_address) {
    (Some(first), Some(last)) =>
      if first.number() > last.number() {
        Err("telemetry subscription range is inverted")
      } else {
        Ok({
          id,
          station,
          first_address,
          last_address,
          minimum_state,
          include_unchanged,
        })
      }
    _ =>
      Ok({
        id,
        station,
        first_address,
        last_address,
        minimum_state,
        include_unchanged,
      })
  }
}

///|
pub fn TelemetrySubscription::id(self : TelemetrySubscription) -> Int {
  self.id
}

///|
pub fn TelemetrySubscription::station(
  self : TelemetrySubscription,
) -> CommonAddress? {
  self.station
}

///|
pub fn TelemetrySubscription::first_address(
  self : TelemetrySubscription,
) -> InformationAddress? {
  self.first_address
}

///|
pub fn TelemetrySubscription::last_address(
  self : TelemetrySubscription,
) -> InformationAddress? {
  self.last_address
}

///|
pub fn TelemetrySubscription::minimum_state(
  self : TelemetrySubscription,
) -> TelemetryState {
  self.minimum_state
}

///|
pub fn TelemetrySubscription::include_unchanged(
  self : TelemetrySubscription,
) -> Bool {
  self.include_unchanged
}

///|
fn TelemetrySubscription::accepts(
  self : TelemetrySubscription,
  sample : TelemetrySample,
  changed : Bool,
) -> Bool {
  let station_ok = match self.station {
    Some(value) => value == sample.station()
    None => true
  }
  let first_ok = match self.first_address {
    Some(value) => sample.address().number() >= value.number()
    None => true
  }
  let last_ok = match self.last_address {
    Some(value) => sample.address().number() <= value.number()
    None => true
  }
  let state_ok = match self.minimum_state {
    GoodTelemetry => sample.state() == GoodTelemetry
    DegradedTelemetry => sample.state() != InvalidTelemetry
    InvalidTelemetry => true
  }
  station_ok &&
  first_ok &&
  last_ok &&
  state_ok &&
  (changed || self.include_unchanged)
}

///|
/// Aggregate statistics maintained per point.
pub struct TelemetryAggregate {
  mut count : Int
  mut first_timestamp : Int
  mut last_timestamp : Int
  mut minimum : Float
  mut maximum : Float
  mut sum : Float
  mut invalid_count : Int
} derive(Eq, Debug)

///|
pub fn TelemetryAggregate::empty() -> TelemetryAggregate {
  {
    count: 0,
    first_timestamp: 0,
    last_timestamp: 0,
    minimum: 0.0,
    maximum: 0.0,
    sum: 0.0,
    invalid_count: 0,
  }
}

///|
pub fn TelemetryAggregate::count(self : TelemetryAggregate) -> Int {
  self.count
}

///|
pub fn TelemetryAggregate::first_timestamp(self : TelemetryAggregate) -> Int {
  self.first_timestamp
}

///|
pub fn TelemetryAggregate::last_timestamp(self : TelemetryAggregate) -> Int {
  self.last_timestamp
}

///|
pub fn TelemetryAggregate::minimum(self : TelemetryAggregate) -> Float {
  self.minimum
}

///|
pub fn TelemetryAggregate::maximum(self : TelemetryAggregate) -> Float {
  self.maximum
}

///|
pub fn TelemetryAggregate::sum(self : TelemetryAggregate) -> Float {
  self.sum
}

///|
pub fn TelemetryAggregate::invalid_count(self : TelemetryAggregate) -> Int {
  self.invalid_count
}

///|
pub fn TelemetryAggregate::average(self : TelemetryAggregate) -> Float {
  if self.count == 0 {
    0.0
  } else {
    self.sum / Float::from_int(self.count)
  }
}

///|
fn TelemetryAggregate::add(
  self : TelemetryAggregate,
  sample : TelemetrySample,
) -> Unit {
  if self.count == 0 {
    self.minimum = sample.value()
    self.maximum = sample.value()
    self.first_timestamp = sample.timestamp()
  } else {
    if sample.value() < self.minimum {
      self.minimum = sample.value()
    }
    if sample.value() > self.maximum {
      self.maximum = sample.value()
    }
  }
  self.count += 1
  self.last_timestamp = sample.timestamp()
  self.sum += sample.value()
  if !sample.state().usable() {
    self.invalid_count += 1
  }
}

///|
/// Result of processing one application object.
pub struct PipelineResult {
  sample : TelemetrySample
  accepted : Bool
  changed : Bool
  rate_valid : Bool
  alarms : Array[AlarmEvent]
  subscribers : Array[Int]
  message : String
} derive(Debug)

///|
pub fn PipelineResult::sample(self : PipelineResult) -> TelemetrySample {
  self.sample
}

///|
pub fn PipelineResult::accepted(self : PipelineResult) -> Bool {
  self.accepted
}

///|
pub fn PipelineResult::changed(self : PipelineResult) -> Bool {
  self.changed
}

///|
pub fn PipelineResult::rate_valid(self : PipelineResult) -> Bool {
  self.rate_valid
}

///|
pub fn PipelineResult::alarms(self : PipelineResult) -> Array[AlarmEvent] {
  self.alarms.copy()
}

///|
pub fn PipelineResult::subscribers(self : PipelineResult) -> Array[Int] {
  self.subscribers.copy()
}

///|
pub fn PipelineResult::message(self : PipelineResult) -> String {
  self.message
}

///|
/// Pipeline metrics for rate, quality, deadband and alarm stages.
pub struct TelemetryMetrics {
  mut received : Int
  mut emitted : Int
  mut suppressed : Int
  mut invalid : Int
  mut rate_rejected : Int
  mut alarms_raised : Int
  mut alarms_cleared : Int
} derive(Eq, Debug)

///|
pub fn TelemetryMetrics::new() -> TelemetryMetrics {
  {
    received: 0,
    emitted: 0,
    suppressed: 0,
    invalid: 0,
    rate_rejected: 0,
    alarms_raised: 0,
    alarms_cleared: 0,
  }
}

///|
pub fn TelemetryMetrics::received(self : TelemetryMetrics) -> Int {
  self.received
}

///|
pub fn TelemetryMetrics::emitted(self : TelemetryMetrics) -> Int {
  self.emitted
}

///|
pub fn TelemetryMetrics::suppressed(self : TelemetryMetrics) -> Int {
  self.suppressed
}

///|
pub fn TelemetryMetrics::invalid(self : TelemetryMetrics) -> Int {
  self.invalid
}

///|
pub fn TelemetryMetrics::rate_rejected(self : TelemetryMetrics) -> Int {
  self.rate_rejected
}

///|
pub fn TelemetryMetrics::alarms_raised(self : TelemetryMetrics) -> Int {
  self.alarms_raised
}

///|
pub fn TelemetryMetrics::alarms_cleared(self : TelemetryMetrics) -> Int {
  self.alarms_cleared
}

///|
fn telemetry_quality(value : ApplicationValue) -> QualityDescriptor {
  match value {
    SinglePointValue(point) => point.quality().as_measurement()
    DoublePointValue(point) => point.quality().as_measurement()
    StepPositionValue(point) => point.quality().as_measurement()
    NormalizedMeasurement(point) => point.quality()
    ScaledMeasurement(point) => point.quality()
    ShortFloatMeasurement(point) => point.quality()
    BinaryCounterMeasurement(point) =>
      QualityDescriptor::clear().with_invalid(point.flags() >= 0x80)
    _ => QualityDescriptor::clear().with_invalid(true)
  }
}

///|
fn telemetry_number(value : ApplicationValue) -> Result[Float, String] {
  match value {
    SinglePointValue(point) =>
      Ok(Float::from_int(if point.state() { 1 } else { 0 }))
    DoublePointValue(point) => Ok(Float::from_int(point.state()))
    StepPositionValue(point) => Ok(Float::from_int(point.position()))
    NormalizedMeasurement(point) => Ok(Float::from_int(point.value()))
    ScaledMeasurement(point) => Ok(Float::from_int(point.value()))
    ShortFloatMeasurement(point) => Ok(point.value())
    _ => Err("application value is not a numeric telemetry measurement")
  }
}

///|
fn telemetry_state(quality : QualityDescriptor) -> TelemetryState {
  if quality.invalid {
    InvalidTelemetry
  } else if quality.has_status_change() {
    DegradedTelemetry
  } else {
    GoodTelemetry
  }
}

///|
/// A quality-aware, deterministic telemetry processing pipeline.
pub struct TelemetryPipeline {
  samples : Map[Int, TelemetrySample]
  aggregates : Map[Int, TelemetryAggregate]
  deadbands : Map[Int, DeadbandRule]
  rates : Map[Int, RateRule]
  alarms : Map[Int, Array[AlarmRule]]
  active_alarms : Map[String, Bool]
  subscriptions : Array[TelemetrySubscription]
  alarm_history : Array[AlarmEvent]
  alarm_limit : Int
  mut sequence : Int
  metrics : TelemetryMetrics
} derive(Debug)

///|
pub fn TelemetryPipeline::new(
  alarm_limit? : Int = 4096,
) -> Result[TelemetryPipeline, String] {
  if alarm_limit < 1 {
    Err("telemetry alarm limit must be positive")
  } else {
    Ok({
      samples: {},
      aggregates: {},
      deadbands: {},
      rates: {},
      alarms: {},
      active_alarms: {},
      subscriptions: [],
      alarm_history: [],
      alarm_limit,
      sequence: 0,
      metrics: TelemetryMetrics::new(),
    })
  }
}

///|
pub fn TelemetryPipeline::metrics(self : TelemetryPipeline) -> TelemetryMetrics {
  self.metrics
}

///|
pub fn TelemetryPipeline::sample_count(self : TelemetryPipeline) -> Int {
  self.samples.length()
}

///|
pub fn TelemetryPipeline::alarm_history(
  self : TelemetryPipeline,
) -> Array[AlarmEvent] {
  self.alarm_history.copy()
}

///|
pub fn TelemetryPipeline::subscribe(
  self : TelemetryPipeline,
  subscription : TelemetrySubscription,
) -> Result[Unit, String] {
  for current in self.subscriptions {
    if current.id() == subscription.id() {
      return Err("telemetry subscription id already exists")
    }
  }
  self.subscriptions.push(subscription)
  self.subscriptions.sort_by((left, right) => left.id() - right.id())
  Ok(())
}

///|
pub fn TelemetryPipeline::unsubscribe(
  self : TelemetryPipeline,
  id : Int,
) -> Bool {
  for index, subscription in self.subscriptions {
    if subscription.id() == id {
      ignore(self.subscriptions.remove(index))
      return true
    }
  }
  false
}

///|
pub fn TelemetryPipeline::set_deadband(
  self : TelemetryPipeline,
  address : InformationAddress,
  rule : DeadbandRule,
) -> Unit {
  self.deadbands[address.number()] = rule
}

///|
pub fn TelemetryPipeline::set_rate_rule(
  self : TelemetryPipeline,
  address : InformationAddress,
  rule : RateRule,
) -> Unit {
  self.rates[address.number()] = rule
}

///|
pub fn TelemetryPipeline::set_alarm_rules(
  self : TelemetryPipeline,
  address : InformationAddress,
  rules : Array[AlarmRule],
) -> Unit {
  self.alarms[address.number()] = rules.copy()
}

///|
pub fn TelemetryPipeline::latest(
  self : TelemetryPipeline,
  address : InformationAddress,
) -> TelemetrySample? {
  self.samples.get(address.number())
}

///|
pub fn TelemetryPipeline::aggregate(
  self : TelemetryPipeline,
  address : InformationAddress,
) -> TelemetryAggregate {
  self.aggregates.get(address.number()).unwrap_or(TelemetryAggregate::empty())
}

///|
fn telemetry_alarm_key(sample : TelemetrySample, rule : AlarmRule) -> String {
  "\{sample.station().number()}:\{sample.address().number()}:\{rule.name()}"
}

///|
fn TelemetryPipeline::emit_alarm(
  self : TelemetryPipeline,
  sample : TelemetrySample,
  rule : AlarmRule,
  active : Bool,
  message : String,
) -> AlarmEvent {
  let event = {
    station: sample.station(),
    address: sample.address(),
    name: rule.name(),
    severity: rule.severity(),
    active,
    value: sample.value(),
    timestamp: sample.timestamp(),
    message,
  }
  self.alarm_history.push(event)
  while self.alarm_history.length() > self.alarm_limit {
    ignore(self.alarm_history.remove(0))
  }
  if active {
    self.metrics.alarms_raised += 1
  } else {
    self.metrics.alarms_cleared += 1
  }
  event
}

///|
fn TelemetryPipeline::evaluate_alarms(
  self : TelemetryPipeline,
  sample : TelemetrySample,
) -> Array[AlarmEvent] {
  let result : Array[AlarmEvent] = []
  match self.alarms.get(sample.address().number()) {
    None => result
    Some(rules) => {
      for rule in rules {
        let key = telemetry_alarm_key(sample, rule)
        let was_active = self.active_alarms.get(key).unwrap_or(false)
        let threshold = rule.level(sample.value()) is Some(_)
        if threshold && !was_active {
          self.active_alarms[key] = true
          result.push(self.emit_alarm(sample, rule, true, "alarm raised"))
        } else if !threshold && was_active {
          self.active_alarms[key] = false
          result.push(self.emit_alarm(sample, rule, false, "alarm cleared"))
        }
      }
      result
    }
  }
}

///|
pub fn TelemetryPipeline::ingest(
  self : TelemetryPipeline,
  station : CommonAddress,
  object : ApplicationObject,
  timestamp : Int,
  source? : String = "protocol",
) -> Result[PipelineResult, Diagnostic] {
  self.metrics.received += 1
  match telemetry_number(object.value()) {
    Err(error) => Err(Diagnostic::new(InvalidType, error))
    Ok(number) => {
      let quality = telemetry_quality(object.value())
      let sample = {
        station,
        address: object.address(),
        type_id: object.type_id(),
        value: number,
        quality,
        state: telemetry_state(quality),
        timestamp,
        source,
        sequence: self.sequence + 1,
      }
      self.sequence += 1
      if sample.state() == InvalidTelemetry {
        self.metrics.invalid += 1
      }
      let previous = self.samples.get(sample.address().number())
      let changed = match previous {
        None => true
        Some(value) =>
          match self.deadbands.get(sample.address().number()) {
            Some(rule) => rule.changed(value, sample)
            None =>
              value.value() != sample.value() || value.state() != sample.state()
          }
      }
      let rate_valid = match previous {
        Some(value) =>
          match self.rates.get(sample.address().number()) {
            Some(rule) => rule.within(value, sample)
            None => true
          }
        None => true
      }
      if !rate_valid {
        self.metrics.rate_rejected += 1
      }
      let accepted = rate_valid
      if accepted {
        self.samples[sample.address().number()] = sample
        let aggregate = self.aggregates
          .get(sample.address().number())
          .unwrap_or(TelemetryAggregate::empty())
        aggregate.add(sample)
        self.aggregates[sample.address().number()] = aggregate
        if changed {
          self.metrics.emitted += 1
        } else {
          self.metrics.suppressed += 1
        }
      }
      let alarm_events = if accepted {
        self.evaluate_alarms(sample)
      } else {
        []
      }
      let recipients : Array[Int] = []
      for subscription in self.subscriptions {
        if subscription.accepts(sample, changed && accepted) {
          recipients.push(subscription.id())
        }
      }
      Ok({
        sample,
        accepted,
        changed,
        rate_valid,
        alarms: alarm_events,
        subscribers: recipients,
        message: if accepted {
          if changed {
            "telemetry emitted"
          } else {
            "telemetry suppressed by deadband"
          }
        } else {
          "telemetry rejected by rate rule"
        },
      })
    }
  }
}

///|
pub fn telemetry_state_examples() -> Array[TelemetryState] {
  [GoodTelemetry, DegradedTelemetry, InvalidTelemetry]
}

///|
pub fn alarm_severity_examples() -> Array[AlarmSeverity] {
  [InformationalAlarm, WarningAlarm, MajorAlarm, CriticalAlarm]
}
