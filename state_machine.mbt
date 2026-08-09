///|
/// Link-layer state used by a master or outstation session.
pub enum LinkState {
  Disconnected
  Connecting
  Started
  Stopped
  TestPending
} derive(Eq, Debug)

///|
/// A deterministic session state machine. Transport I/O is intentionally injected by callers.
pub struct Session {
  mut state : LinkState
  mut send_sequence : Int
  mut receive_sequence : Int
  window_size : Int
  mut pending : Int
} derive(Debug)

///|
pub fn Session::new(window_size? : Int = 12) -> Session {
  {
    state: Disconnected,
    send_sequence: 0,
    receive_sequence: 0,
    window_size: if window_size < 1 {
      1
    } else {
      window_size
    },
    pending: 0,
  }
}

///|
pub fn Session::start(self : Session) -> Frame {
  self.state = Connecting
  unnumbered_frame(UCommand::control(StartDataTransfer))
}

///|
pub fn Session::stop(self : Session) -> Frame {
  self.state = Stopped
  unnumbered_frame(UCommand::control(StopDataTransfer))
}

///|
pub fn Session::test_link(self : Session) -> Frame {
  self.state = TestPending
  unnumbered_frame(UCommand::control(TestFrame))
}

///|
pub fn Session::send(self : Session, payload : Bytes) -> Result[Frame, String] {
  if self.state != Started {
    return Err("data transfer is not started")
  }
  if self.pending >= self.window_size {
    return Err("send window is full")
  }
  let frame = information_frame(
    self.send_sequence,
    self.receive_sequence,
    payload,
  )
  self.send_sequence = (self.send_sequence + 1) % 32768
  self.pending += 1
  Ok(frame)
}

///|
pub fn Session::receive(self : Session, frame : Frame) -> Result[Unit, String] {
  match frame.kind {
    Information => {
      if frame.send_sequence != self.receive_sequence {
        return Err("receive sequence mismatch")
      }
      self.receive_sequence = (self.receive_sequence + 1) % 32768
    }
    Supervisory => {
      if frame.receive_sequence > self.send_sequence {
        return Err("acknowledgement exceeds send sequence")
      }
      self.pending = self.send_sequence - frame.receive_sequence
    }
    Unnumbered =>
      match u_command(frame.control) {
        StartDataTransfer => self.state = Started
        StopDataTransfer => self.state = Stopped
        TestFrame => self.state = Started
        Unknown(_) => ()
      }
  }
  Ok(())
}
