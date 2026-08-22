///|
/// Actions available in deterministic station integration scenarios.
pub enum ScenarioAction {
  WaitScenario(Int)
  HeartbeatScenario(Int)
  ReceiveApduScenario(Bytes)
  SendApduScenario(Bytes)
  SetPointScenario(InformationAddress, Int)
  RaiseDiagnosticScenario(String)
  ClearDiagnosticScenario
  CheckpointScenario(String)
} derive(Debug)

///|
pub struct ScenarioStep {
  index : Int
  at : Int
  action : ScenarioAction
  label : String
} derive(Debug)

///|
pub fn ScenarioStep::new(
  index : Int,
  at : Int,
  action : ScenarioAction,
  label : String,
) -> Result[ScenarioStep, String] {
  if index < 0 || at < 0 {
    Err("scenario step coordinates cannot be negative")
  } else if label.length() == 0 {
    Err("scenario step label is empty")
  } else {
    Ok({ index, at, action, label })
  }
}

///|
pub fn ScenarioStep::index(self : ScenarioStep) -> Int {
  self.index
}

///|
pub fn ScenarioStep::at(self : ScenarioStep) -> Int {
  self.at
}

///|
pub fn ScenarioStep::action(self : ScenarioStep) -> ScenarioAction {
  self.action
}

///|
pub fn ScenarioStep::label(self : ScenarioStep) -> String {
  self.label
}

///|
pub struct Scenario {
  name : String
  duration : Int
  steps : Array[ScenarioStep]
  fail_fast : Bool
} derive(Debug)

///|
pub fn Scenario::new(
  name : String,
  duration : Int,
  fail_fast? : Bool = true,
) -> Result[Scenario, String] {
  if name.length() == 0 || duration < 0 {
    Err("scenario name and duration are invalid")
  } else {
    Ok({ name, duration, steps: [], fail_fast })
  }
}

///|
pub fn Scenario::name(self : Scenario) -> String {
  self.name
}

///|
pub fn Scenario::duration(self : Scenario) -> Int {
  self.duration
}

///|
pub fn Scenario::steps(self : Scenario) -> Array[ScenarioStep] {
  self.steps.copy()
}

///|
pub fn Scenario::fail_fast(self : Scenario) -> Bool {
  self.fail_fast
}

///|
pub fn Scenario::add(
  self : Scenario,
  action : ScenarioAction,
  at : Int,
  label : String,
) -> Result[Unit, String] {
  match ScenarioStep::new(self.steps.length(), at, action, label) {
    Err(error) => Err(error)
    Ok(step) =>
      if at > self.duration {
        Err("scenario step exceeds scenario duration")
      } else {
        self.steps.push(step)
        self.steps.sort_by((left, right) => {
          if left.at() != right.at() {
            left.at() - right.at()
          } else {
            left.index() - right.index()
          }
        })
        Ok(())
      }
  }
}

///|
pub struct ScenarioObservation {
  step : Int
  timestamp : Int
  label : String
  success : Bool
  detail : String
} derive(Eq, Debug)

///|
pub fn ScenarioObservation::step(self : ScenarioObservation) -> Int {
  self.step
}

///|
pub fn ScenarioObservation::timestamp(self : ScenarioObservation) -> Int {
  self.timestamp
}

///|
pub fn ScenarioObservation::label(self : ScenarioObservation) -> String {
  self.label
}

///|
pub fn ScenarioObservation::success(self : ScenarioObservation) -> Bool {
  self.success
}

///|
pub fn ScenarioObservation::detail(self : ScenarioObservation) -> String {
  self.detail
}

///|
pub struct ScenarioResult {
  name : String
  completed : Bool
  elapsed : Int
  observations : Array[ScenarioObservation]
  checkpoints : Array[String]
  failures : Array[String]
} derive(Debug)

///|
pub fn ScenarioResult::name(self : ScenarioResult) -> String {
  self.name
}

///|
pub fn ScenarioResult::completed(self : ScenarioResult) -> Bool {
  self.completed
}

///|
pub fn ScenarioResult::elapsed(self : ScenarioResult) -> Int {
  self.elapsed
}

///|
pub fn ScenarioResult::observations(
  self : ScenarioResult,
) -> Array[ScenarioObservation] {
  self.observations.copy()
}

///|
pub fn ScenarioResult::checkpoints(self : ScenarioResult) -> Array[String] {
  self.checkpoints.copy()
}

///|
pub fn ScenarioResult::failures(self : ScenarioResult) -> Array[String] {
  self.failures.copy()
}

///|
pub struct ScenarioContext {
  mut now : Int
  mut received : Int
  mut sent : Int
  mut heartbeats : Int
  points : Map[Int, Int]
  diagnostics : Array[String]
} derive(Debug)

///|
pub fn ScenarioContext::new() -> ScenarioContext {
  { now: 0, received: 0, sent: 0, heartbeats: 0, points: {}, diagnostics: [] }
}

///|
pub fn ScenarioContext::now(self : ScenarioContext) -> Int {
  self.now
}

///|
pub fn ScenarioContext::received(self : ScenarioContext) -> Int {
  self.received
}

///|
pub fn ScenarioContext::sent(self : ScenarioContext) -> Int {
  self.sent
}

///|
pub fn ScenarioContext::heartbeats(self : ScenarioContext) -> Int {
  self.heartbeats
}

///|
pub fn ScenarioContext::point(
  self : ScenarioContext,
  address : InformationAddress,
) -> Int? {
  self.points.get(address.number())
}

///|
pub fn ScenarioContext::diagnostics(self : ScenarioContext) -> Array[String] {
  self.diagnostics.copy()
}

///|
fn apply_scenario_action(
  context : ScenarioContext,
  action : ScenarioAction,
  timestamp : Int,
) -> Result[String, String] {
  context.now = timestamp
  match action {
    WaitScenario(seconds) =>
      if seconds < 0 {
        Err("scenario wait cannot be negative")
      } else {
        context.now += seconds
        Ok("wait completed")
      }
    HeartbeatScenario(count) =>
      if count < 1 {
        Err("scenario heartbeat count must be positive")
      } else {
        context.heartbeats += count
        Ok("heartbeat processed")
      }
    ReceiveApduScenario(data) =>
      if data.length() < 6 {
        Err("scenario APDU is too short")
      } else {
        context.received += 1
        Ok("APDU received")
      }
    SendApduScenario(data) =>
      if data.length() < 6 {
        Err("scenario APDU is too short")
      } else {
        context.sent += 1
        Ok("APDU sent")
      }
    SetPointScenario(address, value) => {
      context.points[address.number()] = value
      Ok("point updated")
    }
    RaiseDiagnosticScenario(message) => {
      context.diagnostics.push(message)
      Err("scenario diagnostic raised")
    }
    ClearDiagnosticScenario => {
      context.diagnostics.clear()
      Ok("diagnostics cleared")
    }
    CheckpointScenario(name) =>
      if name.length() == 0 {
        Err("scenario checkpoint name is empty")
      } else {
        Ok("checkpoint:\{name}")
      }
  }
}

///|
pub struct ScenarioRunner {
  context : ScenarioContext
  results : Array[ScenarioResult]
  mut run_count : Int
} derive(Debug)

///|
pub fn ScenarioRunner::new() -> ScenarioRunner {
  { context: ScenarioContext::new(), results: [], run_count: 0 }
}

///|
pub fn ScenarioRunner::context(self : ScenarioRunner) -> ScenarioContext {
  self.context
}

///|
pub fn ScenarioRunner::results(self : ScenarioRunner) -> Array[ScenarioResult] {
  self.results.copy()
}

///|
pub fn ScenarioRunner::run_count(self : ScenarioRunner) -> Int {
  self.run_count
}

///|
pub fn ScenarioRunner::run(
  self : ScenarioRunner,
  scenario : Scenario,
) -> ScenarioResult {
  let observations : Array[ScenarioObservation] = []
  let checkpoints : Array[String] = []
  let failures : Array[String] = []
  let completed = true
  let mut elapsed = 0
  for step in scenario.steps() {
    if step.at() < elapsed {
      failures.push("scenario steps are out of order")
    } else {
      elapsed = step.at()
    }
    match apply_scenario_action(self.context, step.action(), step.at()) {
      Ok(detail) => {
        observations.push({
          step: step.index(),
          timestamp: self.context.now(),
          label: step.label(),
          success: true,
          detail,
        })
        if step.action() is CheckpointScenario(name) {
          checkpoints.push(name)
        }
      }
      Err(error) => {
        observations.push({
          step: step.index(),
          timestamp: self.context.now(),
          label: step.label(),
          success: false,
          detail: error,
        })
        failures.push(error)
        if scenario.fail_fast() {
          break
        }
      }
    }
  }
  let result = {
    name: scenario.name(),
    completed: completed && failures.length() == 0,
    elapsed,
    observations,
    checkpoints,
    failures,
  }
  self.results.push(result)
  self.run_count += 1
  result
}

///|
pub fn scenario_action_examples() -> Array[ScenarioAction] {
  [
    WaitScenario(1),
    HeartbeatScenario(1),
    ReceiveApduScenario(b"\x68\x04\x00\x00\x00\x00"),
    SendApduScenario(b"\x68\x04\x00\x00\x00\x00"),
    SetPointScenario(InformationAddress::new(1).unwrap(), 1),
    RaiseDiagnosticScenario("test"),
    ClearDiagnosticScenario,
    CheckpointScenario("ready"),
  ]
}
