///|
pub fn frame_kind_name(kind : FrameKind) -> String {
  match kind {
    Information => "I"
    Supervisory => "S"
    Unnumbered => "U"
  }
}

///|
pub fn diagnostic_kind_name(kind : DiagnosticKind) -> String {
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
pub fn health_state_name(state : HealthState) -> String {
  match state {
    Healthy => "healthy"
    Degraded => "degraded"
    Unready => "unready"
  }
}

///|
pub fn service_status_name(status : ServiceStatus) -> String {
  match status {
    IdleService => "idle"
    ActiveService => "active"
    ConfirmedService => "confirmed"
    TerminatedService => "terminated"
    RejectedService => "rejected"
    FailedService => "failed"
  }
}

///|
pub fn transport_mode_name(mode : TransportMode) -> String {
  match mode {
    Tcp => "tcp"
    SerialGateway => "serial-gateway"
    ReplayFile => "replay-file"
    InMemory => "in-memory"
  }
}

///|
pub fn application_value_is_measurement(value : ApplicationValue) -> Bool {
  application_value_type(value).is_monitoring()
}

///|
pub fn application_value_is_command(value : ApplicationValue) -> Bool {
  application_value_type(value).is_control()
}

///|
pub fn safe_apdu_payload(data : Bytes) -> Result[Bytes, Diagnostic] {
  if data.length() > 249 {
    Err(Diagnostic::new(MalformedFrame, "payload exceeds IEC APDU limit"))
  } else {
    Ok(data)
  }
}

///|
pub fn protocol_name() -> String {
  "IEC 60870-5-104"
}

///|
pub fn implementation_version() -> String {
  "0.2.0"
}

///|
pub fn compatibility_examples() -> Array[String] {
  [
    protocol_name(),
    implementation_version(),
    frame_kind_name(Information),
    health_state_name(Healthy),
  ]
}
