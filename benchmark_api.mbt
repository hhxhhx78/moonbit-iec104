///|
/// A repeatable benchmark case with a deterministic workload definition.
pub struct BenchmarkCase {
  name : String
  rounds : Int
  payload_size : Int
  target : String
} derive(Eq, Debug)

///|
pub fn BenchmarkCase::new(
  name : String,
  rounds : Int,
  payload_size : Int,
  target : String,
) -> Result[BenchmarkCase, String] {
  if name == "" || target == "" {
    Err("benchmark name and target must not be empty")
  } else if rounds < 1 || payload_size < 1 || payload_size > 249 {
    Err("benchmark workload is outside supported limits")
  } else {
    Ok({ name, rounds, payload_size, target })
  }
}

///|
pub fn BenchmarkCase::name(self : BenchmarkCase) -> String {
  self.name
}

///|
pub fn BenchmarkCase::rounds(self : BenchmarkCase) -> Int {
  self.rounds
}

///|
pub fn BenchmarkCase::payload_size(self : BenchmarkCase) -> Int {
  self.payload_size
}

///|
pub fn BenchmarkCase::target(self : BenchmarkCase) -> String {
  self.target
}

///|
pub struct BenchmarkResult {
  case : BenchmarkCase
  encoded_frames : Int
  encoded_bytes : Int
  checksum : UInt
  elapsed_micros : Int
} derive(Eq, Debug)

///|
pub fn BenchmarkResult::new(
  case : BenchmarkCase,
  workload : BenchmarkWorkload,
  elapsed_micros : Int,
) -> Result[BenchmarkResult, String] {
  if elapsed_micros < 0 {
    Err("benchmark duration cannot be negative")
  } else {
    Ok({
      case,
      encoded_frames: workload.encoded_frames(),
      encoded_bytes: workload.encoded_bytes(),
      checksum: workload.checksum(),
      elapsed_micros,
    })
  }
}

///|
pub fn BenchmarkResult::case(self : BenchmarkResult) -> BenchmarkCase {
  self.case
}

///|
pub fn BenchmarkResult::encoded_frames(self : BenchmarkResult) -> Int {
  self.encoded_frames
}

///|
pub fn BenchmarkResult::encoded_bytes(self : BenchmarkResult) -> Int {
  self.encoded_bytes
}

///|
pub fn BenchmarkResult::checksum(self : BenchmarkResult) -> UInt {
  self.checksum
}

///|
pub fn BenchmarkResult::elapsed_micros(self : BenchmarkResult) -> Int {
  self.elapsed_micros
}

///|
pub fn BenchmarkResult::frames_per_second(self : BenchmarkResult) -> Float {
  if self.elapsed_micros == 0 {
    0.0
  } else {
    Float::from_int(self.encoded_frames) *
    1000000.0 /
    Float::from_int(self.elapsed_micros)
  }
}

///|
pub fn BenchmarkResult::megabytes_per_second(self : BenchmarkResult) -> Float {
  if self.elapsed_micros == 0 {
    0.0
  } else {
    Float::from_int(self.encoded_bytes) *
    1000000.0 /
    Float::from_int(self.elapsed_micros) /
    1000000.0
  }
}

///|
pub struct BenchmarkSuite {
  cases : Array[BenchmarkCase]
} derive(Debug)

///|
pub fn BenchmarkSuite::new() -> BenchmarkSuite {
  { cases: [] }
}

///|
pub fn BenchmarkSuite::add(
  self : BenchmarkSuite,
  case : BenchmarkCase,
) -> Result[Unit, String] {
  for existing in self.cases {
    if existing.name() == case.name() {
      return Err("benchmark case name already exists")
    }
  }
  self.cases.push(case)
  Ok(())
}

///|
pub fn BenchmarkSuite::len(self : BenchmarkSuite) -> Int {
  self.cases.length()
}

///|
pub fn BenchmarkSuite::cases(self : BenchmarkSuite) -> Array[BenchmarkCase] {
  self.cases.copy()
}

///|
/// Run a deterministic benchmark workload; elapsed time is supplied by the host.
pub fn BenchmarkSuite::run(
  self : BenchmarkSuite,
  elapsed_micros : Array[Int],
) -> Result[Array[BenchmarkResult], String] {
  if elapsed_micros.length() != self.cases.length() {
    Err("benchmark timing count does not match case count")
  } else {
    let result : Array[BenchmarkResult] = []
    for index in 0..<self.cases.length() {
      let case = self.cases[index]
      match run_benchmark_workload(case.rounds(), case.payload_size()) {
        Err(error) => return Err(error)
        Ok(workload) =>
          match BenchmarkResult::new(case, workload, elapsed_micros[index]) {
            Err(error) => return Err(error)
            Ok(value) => result.push(value)
          }
      }
    }
    Ok(result)
  }
}

///|
/// Produce the standard local suite used by README benchmark commands.
pub fn default_benchmark_suite() -> BenchmarkSuite {
  let suite = BenchmarkSuite::new()
  ignore(
    suite.add(BenchmarkCase::new("encode-small", 10000, 16, "native").unwrap()),
  )
  ignore(
    suite.add(BenchmarkCase::new("encode-medium", 5000, 128, "native").unwrap()),
  )
  ignore(
    suite.add(
      BenchmarkCase::new("encode-maximum", 1000, 249, "native").unwrap(),
    ),
  )
  suite
}

///|
pub fn benchmark_result_table(results : Array[BenchmarkResult]) -> String {
  let out = StringBuilder()
  out <+ "case,frames,bytes,elapsed_us,frames_per_second,checksum\n"
  for result in results {
    out <+
      "\{result.case().name()},\{result.encoded_frames()},\{result.encoded_bytes()},\{result.elapsed_micros()},\{result.frames_per_second()},\{result.checksum()}\n"
  }
  out.to_string()
}

///|
pub fn benchmark_fixture_checksums() -> Array[UInt] {
  let result : Array[UInt] = []
  for case in default_benchmark_suite().cases() {
    result.push(
      run_benchmark_workload(case.rounds(), case.payload_size())
      .unwrap()
      .checksum(),
    )
  }
  result
}
