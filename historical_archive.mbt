///|
/// Retention policy for historical telemetry samples.
pub struct ArchivePolicy {
  maximum_samples : Int
  maximum_age : Int
  bucket_width : Int
  reject_invalid : Bool
} derive(Eq, Debug)

///|
pub fn ArchivePolicy::new(
  maximum_samples? : Int = 100000,
  maximum_age? : Int = 86400 * 30,
  bucket_width? : Int = 60,
  reject_invalid? : Bool = false,
) -> Result[ArchivePolicy, String] {
  if maximum_samples < 1 || maximum_age < 1 || bucket_width < 1 {
    Err("archive retention values must be positive")
  } else {
    Ok({ maximum_samples, maximum_age, bucket_width, reject_invalid })
  }
}

///|
pub fn ArchivePolicy::maximum_samples(self : ArchivePolicy) -> Int {
  self.maximum_samples
}

///|
pub fn ArchivePolicy::maximum_age(self : ArchivePolicy) -> Int {
  self.maximum_age
}

///|
pub fn ArchivePolicy::bucket_width(self : ArchivePolicy) -> Int {
  self.bucket_width
}

///|
pub fn ArchivePolicy::reject_invalid(self : ArchivePolicy) -> Bool {
  self.reject_invalid
}

///|
/// A durable-shaped historical sample retained in memory by the core.
pub struct ArchivedSample {
  station : CommonAddress
  address : InformationAddress
  type_id : ApplicationType
  value : Float
  quality : QualityDescriptor
  timestamp : Int
  sequence : Int
  source : String
} derive(Debug)

///|
pub fn ArchivedSample::station(self : ArchivedSample) -> CommonAddress {
  self.station
}

///|
pub fn ArchivedSample::address(self : ArchivedSample) -> InformationAddress {
  self.address
}

///|
pub fn ArchivedSample::type_id(self : ArchivedSample) -> ApplicationType {
  self.type_id
}

///|
pub fn ArchivedSample::value(self : ArchivedSample) -> Float {
  self.value
}

///|
pub fn ArchivedSample::quality(self : ArchivedSample) -> QualityDescriptor {
  self.quality
}

///|
pub fn ArchivedSample::timestamp(self : ArchivedSample) -> Int {
  self.timestamp
}

///|
pub fn ArchivedSample::sequence(self : ArchivedSample) -> Int {
  self.sequence
}

///|
pub fn ArchivedSample::source(self : ArchivedSample) -> String {
  self.source
}

///|
pub struct ArchiveBucket {
  station : CommonAddress
  address : InformationAddress
  start : Int
  end : Int
  mut count : Int
  mut minimum : Float
  mut maximum : Float
  mut sum : Float
  mut invalid : Int
} derive(Eq, Debug)

///|
pub fn ArchiveBucket::station(self : ArchiveBucket) -> CommonAddress {
  self.station
}

///|
pub fn ArchiveBucket::address(self : ArchiveBucket) -> InformationAddress {
  self.address
}

///|
pub fn ArchiveBucket::start(self : ArchiveBucket) -> Int {
  self.start
}

///|
pub fn ArchiveBucket::end(self : ArchiveBucket) -> Int {
  self.end
}

///|
pub fn ArchiveBucket::count(self : ArchiveBucket) -> Int {
  self.count
}

///|
pub fn ArchiveBucket::minimum(self : ArchiveBucket) -> Float {
  self.minimum
}

///|
pub fn ArchiveBucket::maximum(self : ArchiveBucket) -> Float {
  self.maximum
}

///|
pub fn ArchiveBucket::sum(self : ArchiveBucket) -> Float {
  self.sum
}

///|
pub fn ArchiveBucket::invalid(self : ArchiveBucket) -> Int {
  self.invalid
}

///|
pub fn ArchiveBucket::average(self : ArchiveBucket) -> Float {
  if self.count == 0 {
    Float::from_int(0)
  } else {
    Float::div(self.sum, Float::from_int(self.count))
  }
}

///|
/// Query over a station/address/time range.
pub struct ArchiveQuery {
  station : CommonAddress?
  first_address : InformationAddress?
  last_address : InformationAddress?
  start : Int?
  end : Int?
  source : String?
  include_invalid : Bool
} derive(Eq, Debug)

///|
pub fn ArchiveQuery::all() -> ArchiveQuery {
  {
    station: None,
    first_address: None,
    last_address: None,
    start: None,
    end: None,
    source: None,
    include_invalid: false,
  }
}

///|
pub fn ArchiveQuery::station(
  self : ArchiveQuery,
  value : CommonAddress,
) -> ArchiveQuery {
  {
    station: Some(value),
    first_address: self.first_address,
    last_address: self.last_address,
    start: self.start,
    end: self.end,
    source: self.source,
    include_invalid: self.include_invalid,
  }
}

///|
pub fn ArchiveQuery::address_range(
  self : ArchiveQuery,
  first : InformationAddress,
  last : InformationAddress,
) -> ArchiveQuery {
  {
    station: self.station,
    first_address: Some(first),
    last_address: Some(last),
    start: self.start,
    end: self.end,
    source: self.source,
    include_invalid: self.include_invalid,
  }
}

///|
pub fn ArchiveQuery::time_range(
  self : ArchiveQuery,
  start : Int,
  end : Int,
) -> ArchiveQuery {
  {
    station: self.station,
    first_address: self.first_address,
    last_address: self.last_address,
    start: Some(start),
    end: Some(end),
    source: self.source,
    include_invalid: self.include_invalid,
  }
}

///|
pub fn ArchiveQuery::from_source(
  self : ArchiveQuery,
  source : String,
) -> ArchiveQuery {
  {
    station: self.station,
    first_address: self.first_address,
    last_address: self.last_address,
    start: self.start,
    end: self.end,
    source: Some(source),
    include_invalid: self.include_invalid,
  }
}

///|
pub fn ArchiveQuery::with_invalid(
  self : ArchiveQuery,
  include_invalid_value : Bool,
) -> ArchiveQuery {
  {
    station: self.station,
    first_address: self.first_address,
    last_address: self.last_address,
    start: self.start,
    end: self.end,
    source: self.source,
    include_invalid: include_invalid_value,
  }
}

///|
fn archive_matches(sample : ArchivedSample, query : ArchiveQuery) -> Bool {
  let station_ok = match query.station {
    Some(value) => value == sample.station()
    None => true
  }
  let first_ok = match query.first_address {
    Some(value) => sample.address().number() >= value.number()
    None => true
  }
  let last_ok = match query.last_address {
    Some(value) => sample.address().number() <= value.number()
    None => true
  }
  let start_ok = match query.start {
    Some(value) => sample.timestamp() >= value
    None => true
  }
  let end_ok = match query.end {
    Some(value) => sample.timestamp() <= value
    None => true
  }
  let source_ok = match query.source {
    Some(value) => sample.source() == value
    None => true
  }
  station_ok &&
  first_ok &&
  last_ok &&
  start_ok &&
  end_ok &&
  source_ok &&
  (query.include_invalid || sample.quality().is_usable())
}

///|
pub struct ArchiveStore {
  samples : Array[ArchivedSample]
  policy : ArchivePolicy
  mut next_sequence : Int
  mut evicted : Int
} derive(Debug)

///|
pub fn ArchiveStore::new(
  policy? : ArchivePolicy = ArchivePolicy::new().unwrap(),
) -> ArchiveStore {
  { samples: [], policy, next_sequence: 1, evicted: 0 }
}

///|
pub fn ArchiveStore::len(self : ArchiveStore) -> Int {
  self.samples.length()
}

///|
pub fn ArchiveStore::evicted(self : ArchiveStore) -> Int {
  self.evicted
}

///|
pub fn ArchiveStore::policy(self : ArchiveStore) -> ArchivePolicy {
  self.policy
}

///|
pub fn ArchiveStore::append(
  self : ArchiveStore,
  sample : TelemetrySample,
) -> Result[Unit, String] {
  if self.policy.reject_invalid() && !sample.quality().is_usable() {
    Err("invalid telemetry is excluded by archive policy")
  } else {
    self.samples.push({
      station: sample.station(),
      address: sample.address(),
      type_id: sample.type_id(),
      value: sample.value(),
      quality: sample.quality(),
      timestamp: sample.timestamp(),
      sequence: self.next_sequence,
      source: sample.source(),
    })
    self.next_sequence += 1
    ignore(self.prune(sample.timestamp()))
    Ok(())
  }
}

///|
pub fn ArchiveStore::append_batch(
  self : ArchiveStore,
  samples : Array[TelemetrySample],
) -> Int {
  let mut accepted = 0
  for sample in samples {
    match self.append(sample) {
      Ok(_) => accepted += 1
      Err(_) => ()
    }
  }
  accepted
}

///|
pub fn ArchiveStore::prune(self : ArchiveStore, now : Int) -> Int {
  let cutoff = now - self.policy.maximum_age()
  let mut removed = 0
  while self.samples.length() > 0 &&
        (
          self.samples.length() > self.policy.maximum_samples() ||
          self.samples[0].timestamp() < cutoff
        ) {
    ignore(self.samples.remove(0))
    removed += 1
    self.evicted += 1
  }
  removed
}

///|
pub fn ArchiveStore::query(
  self : ArchiveStore,
  query : ArchiveQuery,
) -> Array[ArchivedSample] {
  let result : Array[ArchivedSample] = []
  for sample in self.samples {
    if archive_matches(sample, query) {
      result.push(sample)
    }
  }
  result
}

///|
pub fn ArchiveStore::buckets(
  self : ArchiveStore,
  query : ArchiveQuery,
) -> Array[ArchiveBucket] {
  let selected = self.query(query)
  let buckets : Map[(Int, Int), ArchiveBucket] = Map([])
  for sample in selected {
    let start = sample.timestamp() /
      self.policy.bucket_width() *
      self.policy.bucket_width()
    let key = (sample.address().number(), start)
    let bucket = match buckets.get(key) {
      Some(value) => value
      None =>
        {
          station: sample.station(),
          address: sample.address(),
          start,
          end: start + self.policy.bucket_width() - 1,
          count: 0,
          minimum: sample.value(),
          maximum: sample.value(),
          sum: Float::from_int(0),
          invalid: 0,
        }
    }
    if sample.value() < bucket.minimum {
      bucket.minimum = sample.value()
    }
    if sample.value() > bucket.maximum {
      bucket.maximum = sample.value()
    }
    bucket.count += 1
    bucket.sum = Float::add(bucket.sum, sample.value())
    if !sample.quality().is_usable() {
      bucket.invalid += 1
    }
    buckets[key] = bucket
  }
  let result : Array[ArchiveBucket] = []
  for _, bucket in buckets {
    result.push(bucket)
  }
  result.sort_by((left, right) => {
    if left.start() != right.start() {
      left.start() - right.start()
    } else {
      left.address().number() - right.address().number()
    }
  })
  result
}

///|
pub fn ArchiveStore::latest(
  self : ArchiveStore,
  station : CommonAddress,
  address : InformationAddress,
) -> ArchivedSample? {
  let mut result : ArchivedSample? = None
  for sample in self.samples {
    if sample.station() == station && sample.address() == address {
      result = Some(sample)
    }
  }
  result
}

///|
pub fn ArchiveStore::range_count(
  self : ArchiveStore,
  query : ArchiveQuery,
) -> Int {
  self.query(query).length()
}

///|
pub fn archive_policy_examples() -> Array[ArchivePolicy] {
  [
    ArchivePolicy::new().unwrap(),
    ArchivePolicy::new(maximum_samples=10, maximum_age=60, bucket_width=5).unwrap(),
  ]
}
