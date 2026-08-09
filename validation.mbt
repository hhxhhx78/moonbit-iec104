///|
/// Validate invariants that are independent of a concrete transport.
pub fn validate_frame(frame : Frame) -> Result[Unit, String] {
  if frame.send_sequence < 0 || frame.send_sequence >= 32768 {
    return Err("send sequence must fit 15 bits")
  }
  if frame.receive_sequence < 0 || frame.receive_sequence >= 32768 {
    return Err("receive sequence must fit 15 bits")
  }
  if frame.payload.length() > 249 {
    return Err("APDU payload exceeds 249 bytes")
  }
  match frame.kind {
    Information =>
      if frame.payload.is_empty() {
        Err("I frame payload must not be empty")
      } else {
        Ok(())
      }
    Supervisory =>
      if frame.payload.is_empty() {
        Ok(())
      } else {
        Err("S frame cannot contain an ASDU")
      }
    Unnumbered => {
      let control = frame.control.to_int()
      if (control & 1) != 0 && (control & 2) != 0 {
        Ok(())
      } else {
        Err("invalid U frame control bits")
      }
    }
  }
}

///|
/// A protocol event useful for deterministic simulation and diagnostics.
pub enum ProtocolEvent {
  Connected
  Started
  Stopped
  Sent(Int)
  Received(Int)
  Acknowledged(Int)
  Fault(String)
} derive(Eq, Debug)

///|
/// Standard event constructors for host integrations.
pub fn protocol_event_examples() -> Array[ProtocolEvent] {
  [
    Connected,
    Started,
    Stopped,
    Sent(0),
    Received(0),
    Acknowledged(0),
    Fault("example"),
  ]
}

///|
/// In-memory event log for examples, tests and host applications.
pub struct EventLog {
  events : Array[ProtocolEvent]
}

///|
pub fn EventLog::new() -> EventLog {
  { events: [] }
}

///|
pub fn EventLog::push(self : EventLog, event : ProtocolEvent) -> Unit {
  self.events.push(event)
}

///|
pub fn EventLog::len(self : EventLog) -> Int {
  self.events.length()
}

///|
pub fn EventLog::all(self : EventLog) -> Array[ProtocolEvent] {
  self.events.copy()
}
