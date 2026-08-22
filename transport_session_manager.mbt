///|
/// State of a managed transport endpoint.
pub enum ManagedTransportState {
  TransportCreated
  TransportConnecting
  TransportStarted
  TransportStopping
  TransportStopped
  TransportFailed
  TransportClosed
} derive(Eq, Debug)

///|
pub enum TransportEventKind {
  TransportOpened
  TransportStartedEvent
  TransportFrameSent
  TransportFrameReceived
  TransportAcknowledged
  TransportTimerExpired
  TransportFault
  TransportClosedEvent
} derive(Eq, Debug)

///|
pub struct TransportEvent {
  sequence : Int
  timestamp : Int
  kind : TransportEventKind
  endpoint : Int
  frame_size : Int
  detail : String
} derive(Eq, Debug)

///|
pub fn TransportEvent::sequence(self : TransportEvent) -> Int {
  self.sequence
}

///|
pub fn TransportEvent::timestamp(self : TransportEvent) -> Int {
  self.timestamp
}

///|
pub fn TransportEvent::kind(self : TransportEvent) -> TransportEventKind {
  self.kind
}

///|
pub fn TransportEvent::endpoint(self : TransportEvent) -> Int {
  self.endpoint
}

///|
pub fn TransportEvent::frame_size(self : TransportEvent) -> Int {
  self.frame_size
}

///|
pub fn TransportEvent::detail(self : TransportEvent) -> String {
  self.detail
}

///|
pub struct TransportEndpoint {
  id : Int
  station : CommonAddress
  parameters : ConnectionParameters
  window : SequenceWindow
  decoder : ApduStreamDecoder
  mut state : ManagedTransportState
  mut last_activity : Int
  mut last_send : Int
  mut last_receive : Int
  mut sent_frames : Int
  mut received_frames : Int
  mut malformed_frames : Int
} derive(Debug)

///|
pub fn TransportEndpoint::new(
  id : Int,
  station : CommonAddress,
  parameters : ConnectionParameters,
  window_capacity : Int,
  max_apdu? : Int = 255,
) -> Result[TransportEndpoint, String] {
  match SequenceWindow::new(window_capacity) {
    Err(error) => Err(error)
    Ok(window) =>
      match ApduStreamDecoder::new(max_apdu~) {
        Err(error) => Err(error)
        Ok(decoder) =>
          Ok({
            id,
            station,
            parameters,
            window,
            decoder,
            state: TransportCreated,
            last_activity: 0,
            last_send: 0,
            last_receive: 0,
            sent_frames: 0,
            received_frames: 0,
            malformed_frames: 0,
          })
      }
  }
}

///|
pub fn TransportEndpoint::id(self : TransportEndpoint) -> Int {
  self.id
}

///|
pub fn TransportEndpoint::station(self : TransportEndpoint) -> CommonAddress {
  self.station
}

///|
pub fn TransportEndpoint::parameters(
  self : TransportEndpoint,
) -> ConnectionParameters {
  self.parameters
}

///|
pub fn TransportEndpoint::state(
  self : TransportEndpoint,
) -> ManagedTransportState {
  self.state
}

///|
pub fn TransportEndpoint::last_activity(self : TransportEndpoint) -> Int {
  self.last_activity
}

///|
pub fn TransportEndpoint::last_send(self : TransportEndpoint) -> Int {
  self.last_send
}

///|
pub fn TransportEndpoint::last_receive(self : TransportEndpoint) -> Int {
  self.last_receive
}

///|
pub fn TransportEndpoint::sent_frames(self : TransportEndpoint) -> Int {
  self.sent_frames
}

///|
pub fn TransportEndpoint::received_frames(self : TransportEndpoint) -> Int {
  self.received_frames
}

///|
pub fn TransportEndpoint::malformed_frames(self : TransportEndpoint) -> Int {
  self.malformed_frames
}

///|
pub fn TransportEndpoint::open(
  self : TransportEndpoint,
  timestamp : Int,
) -> Result[Frame, String] {
  if self.state != TransportCreated && self.state != TransportStopped {
    Err("transport endpoint is not openable")
  } else {
    self.state = TransportConnecting
    self.last_activity = timestamp
    Ok(unnumbered_frame(UCommand::control(StartDataTransfer)))
  }
}

///|
pub fn TransportEndpoint::start(
  self : TransportEndpoint,
  timestamp : Int,
) -> Result[Frame, String] {
  if self.state != TransportConnecting {
    Err("transport endpoint is not connecting")
  } else {
    self.state = TransportStarted
    self.last_activity = timestamp
    Ok(unnumbered_frame(UCommand::control(StartDataTransfer)))
  }
}

///|
pub fn TransportEndpoint::stop(
  self : TransportEndpoint,
  timestamp : Int,
) -> Result[Frame, String] {
  if self.state != TransportStarted {
    Err("transport endpoint is not started")
  } else {
    self.state = TransportStopping
    self.last_activity = timestamp
    Ok(unnumbered_frame(UCommand::control(StopDataTransfer)))
  }
}

///|
pub fn TransportEndpoint::close(
  self : TransportEndpoint,
  timestamp : Int,
) -> Unit {
  self.state = TransportClosed
  self.last_activity = timestamp
}

///|
pub fn TransportEndpoint::send(
  self : TransportEndpoint,
  payload : Bytes,
  timestamp : Int,
) -> Result[Bytes, Diagnostic] {
  if self.state != TransportStarted {
    Err(Diagnostic::new(StateViolation, "transport endpoint is not started"))
  } else {
    match self.window.reserve_send() {
      Err(_) =>
        Err(Diagnostic::new(WindowExhausted, "transport send window is full"))
      Ok(sequence) => {
        let frame = information_frame(
          sequence,
          self.window.next_receive(),
          payload,
        )
        let encoded = encode_frame(frame)
        self.last_send = timestamp
        self.last_activity = timestamp
        self.sent_frames += 1
        Ok(encoded)
      }
    }
  }
}

///|
pub fn TransportEndpoint::receive(
  self : TransportEndpoint,
  data : Bytes,
  timestamp : Int,
) -> Result[Array[Frame], Diagnostic] {
  if self.state != TransportStarted && self.state != TransportConnecting {
    Err(
      Diagnostic::new(
        StateViolation,
        "transport endpoint cannot receive in current state",
      ),
    )
  } else {
    match self.decoder.push(data) {
      Err(error) => Err(error)
      Ok(_) => {
        let frames : Array[Frame] = []
        while self.decoder.available_frames() > 0 {
          match self.decoder.next() {
            ApduParseResult::Complete(frame, _) => {
              self.received_frames += 1
              self.last_receive = timestamp
              self.last_activity = timestamp
              match frame.kind {
                Information => ignore(self.window.receive(frame.send_sequence))
                Supervisory =>
                  ignore(self.window.acknowledge(frame.receive_sequence))
                Unnumbered =>
                  if u_command(frame.control) == StartDataTransfer {
                    self.state = TransportStarted
                  }
              }
              frames.push(frame)
            }
            ApduParseResult::Invalid(error) => {
              self.malformed_frames += 1
              return Err(error)
            }
            ApduParseResult::NeedMore(_) => break
          }
        }
        Ok(frames)
      }
    }
  }
}

///|
pub fn TransportEndpoint::poll(
  self : TransportEndpoint,
  timestamp : Int,
) -> Result[Unit, Diagnostic] {
  if self.state == TransportStarted &&
    timestamp - self.last_activity > self.parameters.t3() {
    self.state = TransportFailed
    Err(Diagnostic::new(TimerExpired, "transport idle timer expired"))
  } else {
    Ok(())
  }
}

///|
pub struct TransportManagerMetrics {
  mut opened : Int
  mut sent : Int
  mut received : Int
  mut failures : Int
  mut closed : Int
} derive(Eq, Debug)

///|
pub fn TransportManagerMetrics::new() -> TransportManagerMetrics {
  { opened: 0, sent: 0, received: 0, failures: 0, closed: 0 }
}

///|
pub fn TransportManagerMetrics::opened(self : TransportManagerMetrics) -> Int {
  self.opened
}

///|
pub fn TransportManagerMetrics::sent(self : TransportManagerMetrics) -> Int {
  self.sent
}

///|
pub fn TransportManagerMetrics::received(self : TransportManagerMetrics) -> Int {
  self.received
}

///|
pub fn TransportManagerMetrics::failures(self : TransportManagerMetrics) -> Int {
  self.failures
}

///|
pub fn TransportManagerMetrics::closed(self : TransportManagerMetrics) -> Int {
  self.closed
}

///|
pub struct TransportManager {
  endpoints : Map[Int, TransportEndpoint]
  events : Array[TransportEvent]
  event_limit : Int
  mut next_event : Int
  metrics : TransportManagerMetrics
} derive(Debug)

///|
pub fn TransportManager::new(
  event_limit? : Int = 4096,
) -> Result[TransportManager, String] {
  if event_limit < 1 {
    Err("transport event limit must be positive")
  } else {
    Ok({
      endpoints: {},
      events: [],
      event_limit,
      next_event: 1,
      metrics: TransportManagerMetrics::new(),
    })
  }
}

///|
pub fn TransportManager::metrics(
  self : TransportManager,
) -> TransportManagerMetrics {
  self.metrics
}

///|
pub fn TransportManager::events(
  self : TransportManager,
) -> Array[TransportEvent] {
  self.events.copy()
}

///|
pub fn TransportManager::endpoint_count(self : TransportManager) -> Int {
  self.endpoints.length()
}

///|
pub fn TransportManager::endpoint(
  self : TransportManager,
  id : Int,
) -> TransportEndpoint? {
  self.endpoints.get(id)
}

///|
fn TransportManager::record(
  self : TransportManager,
  timestamp : Int,
  kind : TransportEventKind,
  endpoint : Int,
  frame_size : Int,
  detail : String,
) -> Unit {
  self.events.push({
    sequence: self.next_event,
    timestamp,
    kind,
    endpoint,
    frame_size,
    detail,
  })
  self.next_event += 1
  while self.events.length() > self.event_limit {
    ignore(self.events.remove(0))
  }
}

///|
pub fn TransportManager::add(
  self : TransportManager,
  endpoint : TransportEndpoint,
) -> Result[Unit, String] {
  if self.endpoints.contains(endpoint.id()) {
    Err("transport endpoint id already exists")
  } else {
    self.endpoints[endpoint.id()] = endpoint
    Ok(())
  }
}

///|
pub fn TransportManager::open(
  self : TransportManager,
  id : Int,
  timestamp : Int,
) -> Result[Bytes, String] {
  match self.endpoints.get(id) {
    None => Err("unknown transport endpoint")
    Some(endpoint) =>
      match endpoint.open(timestamp) {
        Err(error) => Err(error)
        Ok(frame) => {
          self.endpoints[id] = endpoint
          self.metrics.opened += 1
          self.record(
            timestamp,
            TransportOpened,
            id,
            encoded_frame_size(frame),
            "transport opened",
          )
          Ok(encode_frame(frame))
        }
      }
  }
}

///|
pub fn TransportManager::send(
  self : TransportManager,
  id : Int,
  payload : Bytes,
  timestamp : Int,
) -> Result[Bytes, Diagnostic] {
  match self.endpoints.get(id) {
    None => Err(Diagnostic::new(InvalidAddress, "unknown transport endpoint"))
    Some(endpoint) =>
      match endpoint.send(payload, timestamp) {
        Err(error) => {
          self.metrics.failures += 1
          Err(error)
        }
        Ok(data) => {
          self.endpoints[id] = endpoint
          self.metrics.sent += 1
          self.record(
            timestamp,
            TransportFrameSent,
            id,
            data.length(),
            "APDU sent",
          )
          Ok(data)
        }
      }
  }
}

///|
pub fn TransportManager::receive(
  self : TransportManager,
  id : Int,
  data : Bytes,
  timestamp : Int,
) -> Result[Array[Frame], Diagnostic] {
  match self.endpoints.get(id) {
    None => Err(Diagnostic::new(InvalidAddress, "unknown transport endpoint"))
    Some(endpoint) =>
      match endpoint.receive(data, timestamp) {
        Err(error) => {
          self.metrics.failures += 1
          Err(error)
        }
        Ok(frames) => {
          self.endpoints[id] = endpoint
          self.metrics.received += frames.length()
          self.record(
            timestamp,
            TransportFrameReceived,
            id,
            data.length(),
            "APDU received",
          )
          Ok(frames)
        }
      }
  }
}

///|
pub fn TransportManager::close(
  self : TransportManager,
  id : Int,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.endpoints.get(id) {
    None => Err("unknown transport endpoint")
    Some(endpoint) => {
      endpoint.close(timestamp)
      self.endpoints[id] = endpoint
      self.metrics.closed += 1
      self.record(timestamp, TransportClosedEvent, id, 0, "transport closed")
      Ok(())
    }
  }
}

///|
pub fn TransportManager::poll(
  self : TransportManager,
  timestamp : Int,
) -> Array[Diagnostic] {
  let errors : Array[Diagnostic] = []
  for id, endpoint in self.endpoints {
    match endpoint.poll(timestamp) {
      Ok(_) => ()
      Err(error) => {
        self.metrics.failures += 1
        errors.push(error)
        self.record(timestamp, TransportTimerExpired, id, 0, error.to_line())
      }
    }
  }
  errors
}

///|
pub fn managed_transport_state_examples() -> Array[ManagedTransportState] {
  [
    TransportCreated,
    TransportConnecting,
    TransportStarted,
    TransportStopping,
    TransportStopped,
    TransportFailed,
    TransportClosed,
  ]
}

///|
pub fn transport_event_kind_examples() -> Array[TransportEventKind] {
  [
    TransportOpened,
    TransportStartedEvent,
    TransportFrameSent,
    TransportFrameReceived,
    TransportAcknowledged,
    TransportTimerExpired,
    TransportFault,
    TransportClosedEvent,
  ]
}
