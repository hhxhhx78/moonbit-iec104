///|
/// A deterministic monotonic clock for protocol simulations and tests.
pub struct VirtualClock {
  mut now : Int
} derive(Eq, Debug)

///|
pub fn VirtualClock::new(start? : Int = 0) -> Result[VirtualClock, String] {
  if start < 0 {
    Err("virtual clock cannot start before zero")
  } else {
    Ok({ now: start })
  }
}

///|
pub fn VirtualClock::now(self : VirtualClock) -> Int {
  self.now
}

///|
pub fn VirtualClock::advance(
  self : VirtualClock,
  delta : Int,
) -> Result[Int, String] {
  if delta < 0 {
    Err("virtual clock cannot move backwards")
  } else {
    self.now += delta
    Ok(self.now)
  }
}

///|
pub fn VirtualClock::set(
  self : VirtualClock,
  timestamp : Int,
) -> Result[Unit, String] {
  if timestamp < self.now {
    Err("virtual clock cannot move backwards")
  } else {
    self.now = timestamp
    Ok(())
  }
}

///|
/// Work scheduled for a deterministic simulation tick.
pub enum SimulationAction {
  Receive(Frame)
  Publish(ApplicationObject)
  AdvanceTimer(String)
  Record(String)
} derive(Debug)

///|
pub struct ScheduledAction {
  at : Int
  ordinal : Int
  action : SimulationAction
} derive(Debug)

///|
pub fn ScheduledAction::new(
  at : Int,
  ordinal : Int,
  action : SimulationAction,
) -> ScheduledAction {
  { at, ordinal, action }
}

///|
pub fn ScheduledAction::at(self : ScheduledAction) -> Int {
  self.at
}

///|
pub fn ScheduledAction::ordinal(self : ScheduledAction) -> Int {
  self.ordinal
}

///|
pub fn ScheduledAction::action(self : ScheduledAction) -> SimulationAction {
  self.action
}

///|
/// Results emitted by one simulation step.
pub enum SimulationEvent {
  FrameProduced(Int, Frame)
  ObjectPublished(Int, ApplicationObject)
  TimerAdvanced(Int, String)
  Note(Int, String)
  SimulationFault(Int, Diagnostic)
} derive(Debug)

///|
pub struct Simulation {
  clock : VirtualClock
  actions : Array[ScheduledAction]
  events : Array[SimulationEvent]
  mut next_ordinal : Int
  max_events : Int
} derive(Debug)

///|
pub fn Simulation::new(
  start? : Int = 0,
  max_events? : Int = 100000,
) -> Result[Simulation, String] {
  if max_events < 1 {
    Err("simulation event limit must be positive")
  } else {
    match VirtualClock::new(start~) {
      Ok(clock) =>
        Ok({ clock, actions: [], events: [], next_ordinal: 0, max_events })
      Err(error) => Err(error)
    }
  }
}

///|
pub fn Simulation::now(self : Simulation) -> Int {
  self.clock.now()
}

///|
pub fn Simulation::schedule(
  self : Simulation,
  at : Int,
  action : SimulationAction,
) -> Result[Unit, String] {
  if at < self.clock.now() {
    Err("scheduled action cannot be before current time")
  } else if self.actions.length() + self.events.length() >= self.max_events {
    Err("simulation event limit reached")
  } else {
    self.actions.push(ScheduledAction::new(at, self.next_ordinal, action))
    self.next_ordinal += 1
    self.actions.sort_by((left, right) => {
      if left.at() == right.at() {
        left.ordinal() - right.ordinal()
      } else {
        left.at() - right.at()
      }
    })
    Ok(())
  }
}

///|
pub fn Simulation::pending(self : Simulation) -> Int {
  self.actions.length()
}

///|
pub fn Simulation::events(self : Simulation) -> Array[SimulationEvent] {
  self.events.copy()
}

///|
pub fn Simulation::clear_events(self : Simulation) -> Unit {
  self.events.clear()
}

///|
fn Simulation::emit(self : Simulation, event : SimulationEvent) -> Unit {
  self.events.push(event)
}

///|
fn Simulation::execute(self : Simulation, action : SimulationAction) -> Unit {
  match action {
    Receive(frame) => self.emit(FrameProduced(self.clock.now(), frame))
    Publish(object) => self.emit(ObjectPublished(self.clock.now(), object))
    AdvanceTimer(name) => self.emit(TimerAdvanced(self.clock.now(), name))
    Record(message) => self.emit(Note(self.clock.now(), message))
  }
}

///|
/// Run all scheduled actions up to an inclusive timestamp.
pub fn Simulation::run_until(
  self : Simulation,
  timestamp : Int,
) -> Result[Int, String] {
  if timestamp < self.clock.now() {
    Err("simulation cannot run backwards")
  } else {
    let _ = self.clock.set(timestamp)
    let mut executed = 0
    while !self.actions.is_empty() && self.actions[0].at() <= timestamp {
      let scheduled = self.actions.remove(0)
      let _ = self.clock.set(scheduled.at())
      self.execute(scheduled.action())
      executed += 1
    }
    let _ = self.clock.set(timestamp)
    Ok(executed)
  }
}

///|
/// Run the next scheduled action, if any.
pub fn Simulation::step(self : Simulation) -> Result[Bool, String] {
  if self.actions.is_empty() {
    Ok(false)
  } else {
    let action = self.actions.remove(0)
    let _ = self.clock.set(action.at())
    self.execute(action.action())
    Ok(true)
  }
}

///|
/// A deterministic station simulation composed from a point store and session.
pub struct StationSimulation {
  store : PointStore
  session : Session
  simulation : Simulation
  metrics : FrameMetrics
  trace : TraceLog
} derive(Debug)

///|
pub fn StationSimulation::new(
  common_address : CommonAddress,
  window_size? : Int = 12,
) -> Result[StationSimulation, String] {
  match PointStore::new(common_address) {
    Err(error) => Err(error)
    Ok(store) =>
      match Simulation::new() {
        Err(error) => Err(error)
        Ok(simulation) =>
          match TraceLog::new() {
            Err(error) => Err(error)
            Ok(trace) =>
              Ok({
                store,
                session: Session::new(window_size~),
                simulation,
                metrics: FrameMetrics::new(),
                trace,
              })
          }
      }
  }
}

///|
pub fn StationSimulation::store(self : StationSimulation) -> PointStore {
  self.store
}

///|
pub fn StationSimulation::session(self : StationSimulation) -> SessionSnapshot {
  self.session.snapshot()
}

///|
pub fn StationSimulation::metrics(self : StationSimulation) -> MetricsSnapshot {
  self.metrics.snapshot()
}

///|
pub fn StationSimulation::trace(self : StationSimulation) -> Array[TraceEvent] {
  self.trace.all()
}

///|
pub fn StationSimulation::start(self : StationSimulation) -> Frame {
  let frame = self.session.start()
  self.metrics.record_encoded(frame)
  self.trace.push(TraceEvent::new(self.simulation.now(), FrameSent, "STARTDT"))
  frame
}

///|
pub fn StationSimulation::stop(self : StationSimulation) -> Frame {
  let frame = self.session.stop()
  self.metrics.record_encoded(frame)
  self.trace.push(TraceEvent::new(self.simulation.now(), FrameSent, "STOPDT"))
  frame
}

///|
pub fn StationSimulation::ingest(
  self : StationSimulation,
  object : ApplicationObject,
  timestamp : Int,
) -> Result[PointChange, Diagnostic] {
  match self.store.upsert(object, timestamp, source="simulation") {
    Err(error) => {
      self.metrics.record_service_failure()
      Err(error)
    }
    Ok(change) => {
      self.trace.push(
        TraceEvent::new(
          timestamp,
          PointUpdated,
          change.message(),
          correlation=change.revision(),
        ),
      )
      Ok(change)
    }
  }
}

///|
pub fn StationSimulation::send(
  self : StationSimulation,
  payload : Bytes,
) -> Result[Frame, String] {
  match self.session.send(payload) {
    Err(error) => {
      self.metrics.record_service_failure()
      Err(error)
    }
    Ok(frame) => {
      self.metrics.record_encoded(frame)
      self.trace.push(
        TraceEvent::new(
          self.simulation.now(),
          FrameSent,
          "I-frame",
          correlation=frame.send_sequence,
        ),
      )
      Ok(frame)
    }
  }
}

///|
pub fn StationSimulation::receive(
  self : StationSimulation,
  frame : Frame,
) -> Result[Unit, String] {
  self.metrics.record_decoded(frame)
  match self.session.receive(frame) {
    Err(error) => {
      self.metrics.record_sequence_error()
      self.trace.push(
        TraceEvent::new(self.simulation.now(), DiagnosticRaised, error),
      )
      Err(error)
    }
    Ok(_) => {
      self.trace.push(
        TraceEvent::new(self.simulation.now(), FrameReceived, "accepted"),
      )
      Ok(())
    }
  }
}

///|
pub fn StationSimulation::schedule(
  self : StationSimulation,
  at : Int,
  action : SimulationAction,
) -> Result[Unit, String] {
  self.simulation.schedule(at, action)
}

///|
pub fn StationSimulation::run_until(
  self : StationSimulation,
  timestamp : Int,
) -> Result[Int, String] {
  self.simulation.run_until(timestamp)
}

///|
pub fn StationSimulation::events(
  self : StationSimulation,
) -> Array[SimulationEvent] {
  self.simulation.events()
}

///|
/// A repeatable workload used by local benchmark runs.
pub struct BenchmarkWorkload {
  rounds : Int
  payload_size : Int
  encoded_frames : Int
  encoded_bytes : Int
  checksum : UInt
} derive(Eq, Debug)

///|
pub fn run_benchmark_workload(
  rounds : Int,
  payload_size : Int,
) -> Result[BenchmarkWorkload, String] {
  if rounds < 1 || payload_size < 1 || payload_size > 249 {
    Err("benchmark rounds or payload size is outside the supported range")
  } else {
    let payload : Array[Byte] = []
    for index in 0..<payload_size {
      payload.push((index % 251).to_byte())
    }
    let bytes = Bytes::from_array(payload)
    let mut encoded_frames = 0
    let mut encoded_bytes = 0
    let mut checksum = 0U
    for index in 0..<rounds {
      let frame = information_frame(index % 32768, index % 32768, bytes)
      let encoded = encode_frame(frame)
      encoded_frames += 1
      encoded_bytes += encoded.length()
      checksum = checksum ^ crc32_ieee(encoded)
    }
    Ok({ rounds, payload_size, encoded_frames, encoded_bytes, checksum })
  }
}

///|
pub fn BenchmarkWorkload::rounds(self : BenchmarkWorkload) -> Int {
  self.rounds
}

///|
pub fn BenchmarkWorkload::payload_size(self : BenchmarkWorkload) -> Int {
  self.payload_size
}

///|
pub fn BenchmarkWorkload::encoded_frames(self : BenchmarkWorkload) -> Int {
  self.encoded_frames
}

///|
pub fn BenchmarkWorkload::encoded_bytes(self : BenchmarkWorkload) -> Int {
  self.encoded_bytes
}

///|
pub fn BenchmarkWorkload::checksum(self : BenchmarkWorkload) -> UInt {
  self.checksum
}

///|
pub fn simulation_action_examples() -> Array[SimulationAction] {
  let value = application_value_examples()[0]
  let object = ApplicationObject::new(
    InformationAddress::new(1).unwrap(),
    value,
  ).unwrap()
  [
    Receive(supervisory_frame(0)),
    Publish(object),
    AdvanceTimer("t1"),
    Record("sample"),
  ]
}

///|
pub fn simulation_event_examples() -> Array[SimulationEvent] {
  [SimulationFault(0, Diagnostic::new(MalformedFrame, "sample"))]
}
