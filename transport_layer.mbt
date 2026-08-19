///|
/// Sequence numbers are modulo 32768 in IEC 104.
pub fn sequence_normalize(value : Int) -> Int {
  let mut result = value % 32768
  if result < 0 {
    result += 32768
  }
  result
}

///|
/// Distance from `start` to `end` on the 15-bit sequence ring.
pub fn sequence_distance(start : Int, end : Int) -> Int {
  sequence_normalize(end - start)
}

///|
/// Whether `candidate` is strictly before `limit` from `start`.
pub fn sequence_before(start : Int, candidate : Int, limit : Int) -> Bool {
  sequence_distance(start, candidate) < sequence_distance(start, limit)
}

///|
/// Whether a sequence acknowledgement is valid for a send cursor.
pub fn sequence_acknowledges(send_cursor : Int, acknowledgement : Int) -> Bool {
  sequence_distance(acknowledgement, send_cursor) < 16384
}

///|
/// Return the next sequence number on the IEC ring.
pub fn sequence_next(value : Int) -> Int {
  sequence_normalize(value + 1)
}

///|
/// Return the previous sequence number on the IEC ring.
pub fn sequence_previous(value : Int) -> Int {
  sequence_normalize(value - 1)
}

///|
/// A validated receive/send sequence window.
pub struct SequenceWindow {
  mut first_unacknowledged : Int
  mut next_send : Int
  mut next_receive : Int
  capacity : Int
} derive(Eq, Debug)

///|
pub fn SequenceWindow::new(capacity : Int) -> Result[SequenceWindow, String] {
  if capacity < 1 || capacity > 32767 {
    Err("sequence window capacity must be between 1 and 32767")
  } else {
    Ok({ first_unacknowledged: 0, next_send: 0, next_receive: 0, capacity })
  }
}

///|
pub fn SequenceWindow::pending(self : SequenceWindow) -> Int {
  sequence_distance(self.first_unacknowledged, self.next_send)
}

///|
pub fn SequenceWindow::available(self : SequenceWindow) -> Int {
  self.capacity - self.pending()
}

///|
pub fn SequenceWindow::next_send(self : SequenceWindow) -> Int {
  self.next_send
}

///|
pub fn SequenceWindow::next_receive(self : SequenceWindow) -> Int {
  self.next_receive
}

///|
pub fn SequenceWindow::can_send(self : SequenceWindow) -> Bool {
  self.pending() < self.capacity
}

///|
pub fn SequenceWindow::reserve_send(
  self : SequenceWindow,
) -> Result[Int, String] {
  if !self.can_send() {
    Err("sequence window is full")
  } else {
    let sequence = self.next_send
    self.next_send = sequence_next(self.next_send)
    Ok(sequence)
  }
}

///|
pub fn SequenceWindow::receive(
  self : SequenceWindow,
  sequence : Int,
) -> Result[Unit, String] {
  if sequence_normalize(sequence) != self.next_receive {
    Err("received sequence is outside the receive cursor")
  } else {
    self.next_receive = sequence_next(self.next_receive)
    Ok(())
  }
}

///|
pub fn SequenceWindow::acknowledge(
  self : SequenceWindow,
  sequence : Int,
) -> Result[Int, String] {
  let normalized = sequence_normalize(sequence)
  if !sequence_acknowledges(self.next_send, normalized) {
    Err("acknowledgement is ahead of the send cursor")
  } else if sequence_distance(self.first_unacknowledged, normalized) >
    self.pending() {
    Err("acknowledgement is outside the pending window")
  } else {
    let released = sequence_distance(self.first_unacknowledged, normalized)
    self.first_unacknowledged = normalized
    Ok(released)
  }
}

///|
/// Incremental APDU parsing result for TCP or serial gateway adapters.
pub enum ApduParseResult {
  NeedMore(Int)
  Complete(Frame, Int)
  Invalid(Diagnostic)
} derive(Debug)

///|
/// Parse one APDU from a byte view without requiring a socket implementation.
pub fn parse_apdu_prefix(data : Bytes) -> ApduParseResult {
  if data.length() < 2 {
    NeedMore(2 - data.length())
  } else if data[0] != b'\x68' {
    Invalid(
      Diagnostic::new(MalformedFrame, "APDU start byte is not 0x68", offset=0),
    )
  } else {
    let body_length = data[1].to_int()
    if body_length < 4 || body_length > 253 {
      Invalid(
        Diagnostic::new(
          MalformedFrame,
          "APDU length is outside 4..253",
          offset=1,
        ),
      )
    } else if data.length() < body_length + 2 {
      NeedMore(body_length + 2 - data.length())
    } else {
      let packet = data[:body_length + 2].to_owned()
      match decode_frame(packet) {
        Ok(frame) => Complete(frame, body_length + 2)
        Err(message) => Invalid(Diagnostic::new(MalformedFrame, message))
      }
    }
  }
}

///|
/// A portable byte accumulator for stream transports.
pub struct ApduStreamDecoder {
  mut buffer : Array[Byte]
  max_apdu : Int
} derive(Debug)

///|
pub fn ApduStreamDecoder::new(
  max_apdu? : Int = 255,
) -> Result[ApduStreamDecoder, String] {
  if max_apdu < 6 || max_apdu > 255 {
    Err("maximum APDU size must be between 6 and 255")
  } else {
    Ok({ buffer: [], max_apdu })
  }
}

///|
pub fn ApduStreamDecoder::buffered(self : ApduStreamDecoder) -> Int {
  self.buffer.length()
}

///|
pub fn ApduStreamDecoder::clear(self : ApduStreamDecoder) -> Unit {
  self.buffer.clear()
}

///|
pub fn ApduStreamDecoder::push(
  self : ApduStreamDecoder,
  data : Bytes,
) -> Result[Int, Diagnostic] {
  if self.buffer.length() + data.length() > self.max_apdu * 4 {
    Err(Diagnostic::new(MalformedFrame, "stream decoder buffer limit exceeded"))
  } else {
    for byte in data {
      self.buffer.push(byte)
    }
    Ok(data.length())
  }
}

///|
fn ApduStreamDecoder::decoder_buffer_bytes(self : ApduStreamDecoder) -> Bytes {
  Bytes::from_array(self.buffer)
}

///|
/// Parse and remove the first complete APDU, preserving partial data.
pub fn ApduStreamDecoder::next(self : ApduStreamDecoder) -> ApduParseResult {
  let result = parse_apdu_prefix(self.decoder_buffer_bytes())
  match result {
    Complete(frame, consumed) => {
      self.buffer = self.buffer[consumed:].to_owned()
      Complete(frame, consumed)
    }
    NeedMore(_) => result
    Invalid(error) => {
      if !self.buffer.is_empty() {
        ignore(self.buffer.remove(0))
      }
      Invalid(error)
    }
  }
}

///|
/// Number of complete frames available in a buffered stream.
pub fn ApduStreamDecoder::available_frames(self : ApduStreamDecoder) -> Int {
  let mut count = 0
  let mut offset = 0
  let snapshot = self.decoder_buffer_bytes()
  while offset < snapshot.length() {
    match parse_apdu_prefix(snapshot[offset:].to_owned()) {
      Complete(_, consumed) => {
        count += 1
        offset += consumed
      }
      _ => break
    }
  }
  count
}

///|
/// State of a timer that is driven by a host monotonic clock.
pub enum TimerState {
  Inactive
  Running(Int)
  Expired
} derive(Eq, Debug)

///|
pub struct ProtocolTimers {
  mut t0 : TimerState
  mut t1 : TimerState
  mut t2 : TimerState
  mut t3 : TimerState
} derive(Eq, Debug)

///|
pub fn ProtocolTimers::new() -> ProtocolTimers {
  { t0: Inactive, t1: Inactive, t2: Inactive, t3: Inactive }
}

///|
pub fn ProtocolTimers::start_t0(self : ProtocolTimers, deadline : Int) -> Unit {
  self.t0 = Running(deadline)
}

///|
pub fn ProtocolTimers::start_t1(self : ProtocolTimers, deadline : Int) -> Unit {
  self.t1 = Running(deadline)
}

///|
pub fn ProtocolTimers::start_t2(self : ProtocolTimers, deadline : Int) -> Unit {
  self.t2 = Running(deadline)
}

///|
pub fn ProtocolTimers::start_t3(self : ProtocolTimers, deadline : Int) -> Unit {
  self.t3 = Running(deadline)
}

///|
pub fn ProtocolTimers::stop_t0(self : ProtocolTimers) -> Unit {
  self.t0 = Inactive
}

///|
pub fn ProtocolTimers::stop_t1(self : ProtocolTimers) -> Unit {
  self.t1 = Inactive
}

///|
pub fn ProtocolTimers::stop_t2(self : ProtocolTimers) -> Unit {
  self.t2 = Inactive
}

///|
pub fn ProtocolTimers::stop_t3(self : ProtocolTimers) -> Unit {
  self.t3 = Inactive
}

///|
fn timer_due(timer : TimerState, now : Int) -> Bool {
  match timer {
    Running(deadline) => now >= deadline
    _ => false
  }
}

///|
pub fn ProtocolTimers::expired(
  self : ProtocolTimers,
  now : Int,
) -> Array[String] {
  let result : Array[String] = []
  if timer_due(self.t0, now) {
    result.push("t0")
  }
  if timer_due(self.t1, now) {
    result.push("t1")
  }
  if timer_due(self.t2, now) {
    result.push("t2")
  }
  if timer_due(self.t3, now) {
    result.push("t3")
  }
  result
}

///|
pub fn timer_state_examples() -> Array[TimerState] {
  [Inactive, Running(10), Expired]
}

///|
/// Host-visible session observation.
pub struct SessionSnapshot {
  state : LinkState
  send_sequence : Int
  receive_sequence : Int
  pending : Int
  window_size : Int
} derive(Eq, Debug)

///|
pub fn Session::snapshot(self : Session) -> SessionSnapshot {
  {
    state: self.state,
    send_sequence: self.send_sequence,
    receive_sequence: self.receive_sequence,
    pending: self.pending,
    window_size: self.window_size,
  }
}

///|
pub fn SessionSnapshot::is_started(self : SessionSnapshot) -> Bool {
  self.state == Started
}

///|
pub fn SessionSnapshot::available(self : SessionSnapshot) -> Int {
  self.window_size - self.pending
}

///|
pub fn SessionSnapshot::send_sequence(self : SessionSnapshot) -> Int {
  self.send_sequence
}

///|
pub fn SessionSnapshot::receive_sequence(self : SessionSnapshot) -> Int {
  self.receive_sequence
}

///|
pub fn SessionSnapshot::pending(self : SessionSnapshot) -> Int {
  self.pending
}

///|
/// A deterministic action emitted by a session driver.
pub enum SessionAction {
  SendStart
  SendStop
  SendTest
  SendSupervisory(Int)
  SendInformation(Int)
  DeliverInformation(Bytes)
  Acknowledge(Int)
  Report(Diagnostic)
  NoAction
} derive(Debug)

///|
pub fn session_action_examples() -> Array[SessionAction] {
  [
    SendStart,
    SendStop,
    SendTest,
    SendSupervisory(0),
    SendInformation(0),
    DeliverInformation(b""),
    Acknowledge(0),
    Report(Diagnostic::new(StateViolation, "example")),
    NoAction,
  ]
}

///|
/// Validate a frame against transport-level limits before sending it.
pub fn validate_transport_frame(frame : Frame) -> Result[Unit, Diagnostic] {
  match validate_frame(frame) {
    Ok(_) => Ok(())
    Err(message) => Err(Diagnostic::new(MalformedFrame, message))
  }
}

///|
/// Return the number of octets that an encoded frame will occupy.
pub fn encoded_frame_size(frame : Frame) -> Int {
  6 + frame.payload.length()
}

///|
/// Return a conservative APDU limit check for gateways.
pub fn frame_fits_apdu(frame : Frame, maximum : Int) -> Bool {
  maximum >= 6 && encoded_frame_size(frame) <= maximum
}

///|
pub fn transport_examples() -> Array[ApduParseResult] {
  [
    parse_apdu_prefix(b""),
    parse_apdu_prefix(b"\x68\x04\x07\x00"),
    parse_apdu_prefix(b"\x67\x04\x07\x00"),
  ]
}
