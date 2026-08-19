///|
/// Resource limits prevent malformed peers from exhausting a gateway.
pub struct ResourceLimits {
  max_apdu : Int
  max_asdu : Int
  max_objects : Int
  max_history : Int
  max_commands : Int
  max_trace_events : Int
} derive(Eq, Debug)

///|
pub fn ResourceLimits::default() -> ResourceLimits {
  {
    max_apdu: 255,
    max_asdu: 249,
    max_objects: 127,
    max_history: 4096,
    max_commands: 256,
    max_trace_events: 4096,
  }
}

///|
pub fn ResourceLimits::new(
  max_apdu : Int,
  max_asdu : Int,
  max_objects : Int,
  max_history : Int,
  max_commands : Int,
  max_trace_events : Int,
) -> Result[ResourceLimits, String] {
  if max_apdu < 6 || max_apdu > 255 {
    Err("APDU resource limit is outside 6..255")
  } else if max_asdu < 1 || max_asdu > 249 {
    Err("ASDU resource limit is outside 1..249")
  } else if max_objects < 1 || max_objects > 127 {
    Err("object resource limit is outside 1..127")
  } else if max_history < 1 || max_commands < 1 || max_trace_events < 1 {
    Err("resource limits must be positive")
  } else {
    Ok({
      max_apdu,
      max_asdu,
      max_objects,
      max_history,
      max_commands,
      max_trace_events,
    })
  }
}

///|
pub fn ResourceLimits::max_apdu(self : ResourceLimits) -> Int {
  self.max_apdu
}

///|
pub fn ResourceLimits::max_asdu(self : ResourceLimits) -> Int {
  self.max_asdu
}

///|
pub fn ResourceLimits::max_objects(self : ResourceLimits) -> Int {
  self.max_objects
}

///|
pub fn ResourceLimits::max_history(self : ResourceLimits) -> Int {
  self.max_history
}

///|
pub fn ResourceLimits::max_commands(self : ResourceLimits) -> Int {
  self.max_commands
}

///|
pub fn ResourceLimits::max_trace_events(self : ResourceLimits) -> Int {
  self.max_trace_events
}

///|
pub enum AdmissionDecision {
  AcceptedAdmission
  RejectedAdmission(Diagnostic)
} derive(Debug)

///|
pub fn admit_frame(frame : Frame, limits : ResourceLimits) -> AdmissionDecision {
  if encoded_frame_size(frame) > limits.max_apdu() {
    RejectedAdmission(
      Diagnostic::new(MalformedFrame, "APDU exceeds configured resource limit"),
    )
  } else if frame.payload.length() > limits.max_asdu() {
    RejectedAdmission(
      Diagnostic::new(MalformedFrame, "ASDU exceeds configured resource limit"),
    )
  } else {
    AcceptedAdmission
  }
}

///|
pub fn admit_envelope(
  envelope : AsduEnvelope,
  limits : ResourceLimits,
) -> AdmissionDecision {
  if envelope.count() > limits.max_objects() {
    RejectedAdmission(
      Diagnostic::new(
        InvalidQualifier,
        "ASDU object count exceeds configured limit",
      ),
    )
  } else {
    AcceptedAdmission
  }
}

///|
/// A fixed-window rate limiter for commands and diagnostics.
pub struct RateLimiter {
  mut window_start : Int
  window_size : Int
  limit : Int
  mut used : Int
} derive(Eq, Debug)

///|
pub fn RateLimiter::new(
  window_size : Int,
  limit : Int,
) -> Result[RateLimiter, String] {
  if window_size < 1 || limit < 1 {
    Err("rate limiter parameters must be positive")
  } else {
    Ok({ window_start: 0, window_size, limit, used: 0 })
  }
}

///|
pub fn RateLimiter::allow(self : RateLimiter, now : Int) -> Bool {
  if now < self.window_start {
    false
  } else {
    if now - self.window_start >= self.window_size {
      self.window_start = now
      self.used = 0
    }
    if self.used >= self.limit {
      false
    } else {
      self.used += 1
      true
    }
  }
}

///|
pub fn RateLimiter::used(self : RateLimiter) -> Int {
  self.used
}

///|
pub fn RateLimiter::remaining(self : RateLimiter) -> Int {
  self.limit - self.used
}

///|
/// Replay guard keyed by APDU checksum and a bounded time interval.
pub struct ReplayGuard {
  seen : Map[UInt, Int]
  ttl : Int
  limit : Int
} derive(Debug)

///|
pub fn ReplayGuard::new(ttl : Int, limit : Int) -> Result[ReplayGuard, String] {
  if ttl < 1 || limit < 1 {
    Err("replay guard parameters must be positive")
  } else {
    Ok({ seen: {}, ttl, limit })
  }
}

///|
pub fn ReplayGuard::is_replay(
  self : ReplayGuard,
  frame : Bytes,
  now : Int,
) -> Bool {
  let fingerprint = crc32_ieee(frame)
  match self.seen.get(fingerprint) {
    Some(previous) => now - previous <= self.ttl
    None => false
  }
}

///|
pub fn ReplayGuard::remember(
  self : ReplayGuard,
  frame : Bytes,
  now : Int,
) -> Result[Unit, String] {
  if self.seen.length() >= self.limit &&
    self.seen.get(crc32_ieee(frame)) is None {
    Err("replay guard capacity is full")
  } else {
    self.seen[crc32_ieee(frame)] = now
    Ok(())
  }
}

///|
pub fn ReplayGuard::purge(self : ReplayGuard, now : Int) -> Int {
  let expired : Array[UInt] = []
  for fingerprint, timestamp in self.seen {
    if now - timestamp > self.ttl {
      expired.push(fingerprint)
    }
  }
  for fingerprint in expired {
    self.seen.remove(fingerprint)
  }
  expired.length()
}

///|
pub fn ReplayGuard::len(self : ReplayGuard) -> Int {
  self.seen.length()
}

///|
/// Admission pipeline for an inbound APDU.
pub fn admit_inbound(
  data : Bytes,
  limits : ResourceLimits,
  replay : ReplayGuard,
  now : Int,
) -> Result[Frame, Diagnostic] {
  if replay.is_replay(data, now) {
    Err(
      Diagnostic::new(MalformedFrame, "duplicate APDU rejected by replay guard"),
    )
  } else if data.length() > limits.max_apdu() {
    Err(Diagnostic::new(MalformedFrame, "APDU exceeds inbound limit"))
  } else {
    match decode_frame(data) {
      Err(message) => Err(Diagnostic::new(MalformedFrame, message))
      Ok(frame) =>
        match admit_frame(frame, limits) {
          AcceptedAdmission => {
            let _ = replay.remember(data, now)
            Ok(frame)
          }
          RejectedAdmission(error) => Err(error)
        }
    }
  }
}

///|
pub fn security_examples() -> Array[AdmissionDecision] {
  let limits = ResourceLimits::default()
  [
    admit_frame(supervisory_frame(0), limits),
    admit_frame(information_frame(0, 0, b"x"), limits),
  ]
}
