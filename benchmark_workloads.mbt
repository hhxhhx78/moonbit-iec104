///|
/// Benchmark workload families used by the local CLI and CI smoke checks.
pub enum ApplicationBenchmarkWorkload {
  CodecWorkload
  DatabaseWorkload
  TelemetryWorkload
  SchedulerWorkload
  FileWorkload
  ScenarioWorkload
} derive(Eq, Debug)

///|
pub struct WorkloadResult {
  workload : ApplicationBenchmarkWorkload
  iterations : Int
  accepted : Int
  rejected : Int
  bytes : Int
  checksum : UInt
  detail : String
} derive(Eq, Debug)

///|
pub fn WorkloadResult::workload(
  self : WorkloadResult,
) -> ApplicationBenchmarkWorkload {
  self.workload
}

///|
pub fn WorkloadResult::iterations(self : WorkloadResult) -> Int {
  self.iterations
}

///|
pub fn WorkloadResult::accepted(self : WorkloadResult) -> Int {
  self.accepted
}

///|
pub fn WorkloadResult::rejected(self : WorkloadResult) -> Int {
  self.rejected
}

///|
pub fn WorkloadResult::bytes(self : WorkloadResult) -> Int {
  self.bytes
}

///|
pub fn WorkloadResult::checksum(self : WorkloadResult) -> UInt {
  self.checksum
}

///|
pub fn WorkloadResult::detail(self : WorkloadResult) -> String {
  self.detail
}

///|
fn benchmark_address(index : Int) -> InformationAddress {
  InformationAddress::new(index % 4096 + 1).unwrap()
}

///|
pub fn run_database_workload(
  iterations : Int,
) -> Result[WorkloadResult, String] {
  if iterations < 1 {
    return Err("benchmark iterations must be positive")
  }
  let database = StationDatabase::new().unwrap()
  let station = CommonAddress::new(1).unwrap()
  let config = StationConfig::new(station, "benchmark-station").unwrap()
  ignore(database.register(config, 0))
  let mut accepted = 0
  let mut rejected = 0
  let mut checksum : UInt = 0U
  for index in 0..<iterations {
    let object = normalized_object(benchmark_address(index), index % 30000).unwrap()
    match database.write(station, object, index, source="benchmark") {
      Ok(_) => {
        accepted += 1
        checksum = checksum ^ index.reinterpret_as_uint()
      }
      Err(_) => rejected += 1
    }
  }
  Ok({
    workload: DatabaseWorkload,
    iterations,
    accepted,
    rejected,
    bytes: 0,
    checksum,
    detail: "versioned point database writes",
  })
}

///|
pub fn run_telemetry_workload(
  iterations : Int,
) -> Result[WorkloadResult, String] {
  if iterations < 1 {
    return Err("benchmark iterations must be positive")
  }
  let pipeline = TelemetryPipeline::new().unwrap()
  let station = CommonAddress::new(1).unwrap()
  let mut accepted = 0
  let mut rejected = 0
  let mut checksum : UInt = 0U
  for index in 0..<iterations {
    let object = short_float_object(
      benchmark_address(index),
      Float::from_int(index % 100),
    ).unwrap()
    match pipeline.ingest(station, object, index, source="benchmark") {
      Ok(result) =>
        if result.accepted() {
          accepted += 1
          checksum = checksum ^ result.sample().sequence().reinterpret_as_uint()
        } else {
          rejected += 1
        }
      Err(_) => rejected += 1
    }
  }
  Ok({
    workload: TelemetryWorkload,
    iterations,
    accepted,
    rejected,
    bytes: 0,
    checksum,
    detail: "quality-aware telemetry and deadband pipeline",
  })
}

///|
pub fn run_scheduler_workload(
  iterations : Int,
) -> Result[WorkloadResult, String] {
  if iterations < 1 {
    return Err("benchmark iterations must be positive")
  }
  let scheduler = CommandScheduler::new().unwrap()
  let station = CommonAddress::new(1).unwrap()
  let policy = CommandPolicy::allow_all()
  let mut accepted = 0
  let mut rejected = 0
  let mut checksum : UInt = 0U
  for index in 0..<iterations {
    let object = single_command_object(
      benchmark_address(index),
      index % 2 == 0,
      3,
    ).unwrap()
    match
      scheduler.submit(
        station,
        object,
        NormalPriority,
        index,
        index + 60,
        "benchmark-\{index}",
      ) {
      Err(_) => rejected += 1
      Ok(request) =>
        match scheduler.dispatch(policy, index) {
          Ok(Some(dispatch)) => {
            accepted += 1
            checksum = checksum ^ dispatch.ticket().reinterpret_as_uint()
            ignore(scheduler.confirm(request.ticket(), index, true))
          }
          _ => rejected += 1
        }
    }
  }
  Ok({
    workload: SchedulerWorkload,
    iterations,
    accepted,
    rejected,
    bytes: 0,
    checksum,
    detail: "priority command dispatch with confirmation",
  })
}

///|
pub fn run_file_workload(iterations : Int) -> Result[WorkloadResult, String] {
  if iterations < 1 {
    return Err("benchmark iterations must be positive")
  }
  let store = FileStore::new(capacity=iterations + 1, maximum_size=4096).unwrap()
  let station = CommonAddress::new(1).unwrap()
  let mut accepted = 0
  let mut bytes = 0
  let mut checksum : UInt = 0U
  for index in 0..<iterations {
    let identity = FileIdentity::new(station, "benchmark-\{index}.bin", index).unwrap()
    let data : Array[Byte] = []
    for offset in 0..<64 {
      data.push((offset + index).to_byte())
    }
    match store.put(identity, Bytes::from_array(data), index) {
      Ok(file) => {
        accepted += 1
        bytes += file.size()
        checksum = checksum ^ file.checksum()
      }
      Err(_) => ()
    }
  }
  Ok({
    workload: FileWorkload,
    iterations,
    accepted,
    rejected: iterations - accepted,
    bytes,
    checksum,
    detail: "bounded file inventory and checksum writes",
  })
}

///|
pub fn run_scenario_workload(
  iterations : Int,
) -> Result[WorkloadResult, String] {
  if iterations < 1 {
    return Err("benchmark iterations must be positive")
  }
  let scenario = Scenario::new("benchmark-scenario", iterations + 1).unwrap()
  for index in 0..<iterations {
    ignore(scenario.add(HeartbeatScenario(1), index, "heartbeat-\{index}"))
  }
  let runner = ScenarioRunner::new()
  let result = runner.run(scenario)
  Ok({
    workload: ScenarioWorkload,
    iterations,
    accepted: result.observations().length(),
    rejected: result.failures().length(),
    bytes: 0,
    checksum: result.elapsed().reinterpret_as_uint(),
    detail: "deterministic heartbeat scenario",
  })
}

///|
pub fn run_application_workloads(
  iterations : Int,
) -> Result[Array[WorkloadResult], String] {
  match run_database_workload(iterations) {
    Err(error) => Err(error)
    Ok(database) =>
      match run_telemetry_workload(iterations) {
        Err(error) => Err(error)
        Ok(telemetry) =>
          match run_scheduler_workload(iterations) {
            Err(error) => Err(error)
            Ok(scheduler) =>
              match run_file_workload(iterations) {
                Err(error) => Err(error)
                Ok(files) =>
                  match run_scenario_workload(iterations) {
                    Err(error) => Err(error)
                    Ok(scenario) =>
                      Ok([database, telemetry, scheduler, files, scenario])
                  }
              }
          }
      }
  }
}

///|
pub fn benchmark_workload_examples() -> Array[ApplicationBenchmarkWorkload] {
  [
    CodecWorkload,
    DatabaseWorkload,
    TelemetryWorkload,
    SchedulerWorkload,
    FileWorkload,
    ScenarioWorkload,
  ]
}
