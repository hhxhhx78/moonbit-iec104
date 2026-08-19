///|
/// Point direction used by a station data model.
pub enum PointDirection {
  MonitorDirection
  ControlDirection
} derive(Eq, Debug)

///|
pub fn point_direction(type_id : ApplicationType) -> PointDirection {
  if type_id.is_control() {
    ControlDirection
  } else {
    MonitorDirection
  }
}

///|
/// A stored value with its protocol identity and update metadata.
pub struct PointRecord {
  address : InformationAddress
  type_id : ApplicationType
  value : ApplicationValue
  time_tag : TimeTag?
  revision : Int
  updated_at : Int
  source : String
} derive(Eq, Debug)

///|
pub fn PointRecord::new(
  object : ApplicationObject,
  updated_at : Int,
  revision? : Int = 1,
  source? : String = "protocol",
) -> PointRecord {
  {
    address: object.address(),
    type_id: object.type_id(),
    value: object.value(),
    time_tag: object.time_tag(),
    revision,
    updated_at,
    source,
  }
}

///|
pub fn PointRecord::address(self : PointRecord) -> InformationAddress {
  self.address
}

///|
pub fn PointRecord::type_id(self : PointRecord) -> ApplicationType {
  self.type_id
}

///|
pub fn PointRecord::value(self : PointRecord) -> ApplicationValue {
  self.value
}

///|
pub fn PointRecord::time_tag(self : PointRecord) -> TimeTag? {
  self.time_tag
}

///|
pub fn PointRecord::revision(self : PointRecord) -> Int {
  self.revision
}

///|
pub fn PointRecord::updated_at(self : PointRecord) -> Int {
  self.updated_at
}

///|
pub fn PointRecord::source(self : PointRecord) -> String {
  self.source
}

///|
pub fn PointRecord::direction(self : PointRecord) -> PointDirection {
  point_direction(self.type_id)
}

///|
pub fn PointRecord::is_valid(self : PointRecord) -> Bool {
  match self.value {
    SinglePointValue(value) => value.quality().is_usable()
    DoublePointValue(value) => value.quality().is_usable()
    StepPositionValue(value) => value.quality().is_usable()
    NormalizedMeasurement(value) => value.quality().is_usable()
    ScaledMeasurement(value) => value.quality().is_usable()
    ShortFloatMeasurement(value) => value.quality().is_usable()
    BinaryCounterMeasurement(value) => value.flags() < 0x80
    _ => true
  }
}

///|
/// A change recorded by the point store.
pub enum PointChangeKind {
  Inserted
  Updated
  Removed
  Rejected
} derive(Eq, Debug)

///|
pub struct PointChange {
  kind : PointChangeKind
  address : InformationAddress
  revision : Int
  timestamp : Int
  message : String
} derive(Eq, Debug)

///|
pub fn PointChange::new(
  kind : PointChangeKind,
  address : InformationAddress,
  revision : Int,
  timestamp : Int,
  message : String,
) -> PointChange {
  { kind, address, revision, timestamp, message }
}

///|
pub fn PointChange::kind(self : PointChange) -> PointChangeKind {
  self.kind
}

///|
pub fn PointChange::address(self : PointChange) -> InformationAddress {
  self.address
}

///|
pub fn PointChange::revision(self : PointChange) -> Int {
  self.revision
}

///|
pub fn PointChange::timestamp(self : PointChange) -> Int {
  self.timestamp
}

///|
pub fn PointChange::message(self : PointChange) -> String {
  self.message
}

///|
/// Query constraints for a point-store snapshot.
pub struct PointFilter {
  direction : PointDirection?
  type_id : ApplicationType?
  first_address : InformationAddress?
  last_address : InformationAddress?
  only_valid : Bool
  source : String?
} derive(Eq, Debug)

///|
pub fn PointFilter::all() -> PointFilter {
  {
    direction: None,
    type_id: None,
    first_address: None,
    last_address: None,
    only_valid: false,
    source: None,
  }
}

///|
pub fn PointFilter::monitoring() -> PointFilter {
  {
    direction: Some(MonitorDirection),
    type_id: None,
    first_address: None,
    last_address: None,
    only_valid: false,
    source: None,
  }
}

///|
pub fn PointFilter::control() -> PointFilter {
  {
    direction: Some(ControlDirection),
    type_id: None,
    first_address: None,
    last_address: None,
    only_valid: false,
    source: None,
  }
}

///|
pub fn PointFilter::with_type(
  self : PointFilter,
  type_id : ApplicationType,
) -> PointFilter {
  {
    direction: self.direction,
    type_id: Some(type_id),
    first_address: self.first_address,
    last_address: self.last_address,
    only_valid: self.only_valid,
    source: self.source,
  }
}

///|
pub fn PointFilter::with_range(
  self : PointFilter,
  first : InformationAddress,
  last : InformationAddress,
) -> PointFilter {
  {
    direction: self.direction,
    type_id: self.type_id,
    first_address: Some(first),
    last_address: Some(last),
    only_valid: self.only_valid,
    source: self.source,
  }
}

///|
pub fn PointFilter::valid_only(self : PointFilter) -> PointFilter {
  {
    direction: self.direction,
    type_id: self.type_id,
    first_address: self.first_address,
    last_address: self.last_address,
    only_valid: true,
    source: self.source,
  }
}

///|
pub fn PointFilter::from_source(
  self : PointFilter,
  source : String,
) -> PointFilter {
  {
    direction: self.direction,
    type_id: self.type_id,
    first_address: self.first_address,
    last_address: self.last_address,
    only_valid: self.only_valid,
    source: Some(source),
  }
}

///|
fn point_matches_filter(record : PointRecord, filter : PointFilter) -> Bool {
  let direction_ok = match filter.direction {
    Some(value) => record.direction() == value
    None => true
  }
  let type_ok = match filter.type_id {
    Some(value) => record.type_id() == value
    None => true
  }
  let first_ok = match filter.first_address {
    Some(value) => record.address().number() >= value.number()
    None => true
  }
  let last_ok = match filter.last_address {
    Some(value) => record.address().number() <= value.number()
    None => true
  }
  let source_ok = match filter.source {
    Some(value) => record.source() == value
    None => true
  }
  direction_ok &&
  type_ok &&
  first_ok &&
  last_ok &&
  source_ok &&
  (!filter.only_valid || record.is_valid())
}

///|
/// Aggregate counts for an in-memory point store.
pub struct StoreStatistics {
  mut total : Int
  mut monitoring : Int
  mut control : Int
  mut valid : Int
  mut invalid : Int
  mut revisions : Int
  mut changes : Int
} derive(Eq, Debug)

///|
pub fn StoreStatistics::empty() -> StoreStatistics {
  {
    total: 0,
    monitoring: 0,
    control: 0,
    valid: 0,
    invalid: 0,
    revisions: 0,
    changes: 0,
  }
}

///|
pub fn StoreStatistics::total(self : StoreStatistics) -> Int {
  self.total
}

///|
pub fn StoreStatistics::monitoring(self : StoreStatistics) -> Int {
  self.monitoring
}

///|
pub fn StoreStatistics::control(self : StoreStatistics) -> Int {
  self.control
}

///|
pub fn StoreStatistics::valid(self : StoreStatistics) -> Int {
  self.valid
}

///|
pub fn StoreStatistics::invalid(self : StoreStatistics) -> Int {
  self.invalid
}

///|
pub fn StoreStatistics::revisions(self : StoreStatistics) -> Int {
  self.revisions
}

///|
pub fn StoreStatistics::changes(self : StoreStatistics) -> Int {
  self.changes
}

///|
/// Deterministic point store for outstations, simulators and gateways.
pub struct PointStore {
  common_address : CommonAddress
  points : Map[Int, PointRecord]
  history : Array[PointChange]
  history_limit : Int
} derive(Debug)

///|
pub fn PointStore::new(
  common_address : CommonAddress,
  history_limit? : Int = 1024,
) -> Result[PointStore, String] {
  if history_limit < 1 {
    Err("history limit must be positive")
  } else {
    Ok({ common_address, points: {}, history: [], history_limit })
  }
}

///|
pub fn PointStore::common_address(self : PointStore) -> CommonAddress {
  self.common_address
}

///|
pub fn PointStore::len(self : PointStore) -> Int {
  self.points.length()
}

///|
pub fn PointStore::history_len(self : PointStore) -> Int {
  self.history.length()
}

///|
pub fn PointStore::get(
  self : PointStore,
  address : InformationAddress,
) -> PointRecord? {
  self.points.get(address.number())
}

///|
pub fn PointStore::history(self : PointStore) -> Array[PointChange] {
  self.history.copy()
}

///|
fn PointStore::record_change(self : PointStore, change : PointChange) -> Unit {
  self.history.push(change)
  while self.history.length() > self.history_limit {
    ignore(self.history.remove(0))
  }
}

///|
pub fn PointStore::upsert(
  self : PointStore,
  object : ApplicationObject,
  timestamp : Int,
  source? : String = "protocol",
) -> Result[PointChange, Diagnostic] {
  match object.validate() {
    Err(error) => Err(error)
    Ok(_) => {
      let key = object.address().number()
      let existing = self.points.get(key)
      let revision = match existing {
        Some(value) => value.revision() + 1
        None => 1
      }
      let kind = match existing {
        Some(_) => Updated
        None => Inserted
      }
      let record = PointRecord::new(object, timestamp, revision~, source~)
      self.points[key] = record
      let change = PointChange::new(
        kind,
        object.address(),
        revision,
        timestamp,
        if kind == Inserted {
          "point inserted"
        } else {
          "point updated"
        },
      )
      self.record_change(change)
      Ok(change)
    }
  }
}

///|
pub fn PointStore::remove(
  self : PointStore,
  address : InformationAddress,
  timestamp : Int,
) -> Result[PointChange, Diagnostic] {
  match self.points.get(address.number()) {
    None => Err(Diagnostic::new(InvalidAddress, "point does not exist"))
    Some(record) => {
      self.points.remove(address.number())
      let change = PointChange::new(
        Removed,
        address,
        record.revision() + 1,
        timestamp,
        "point removed",
      )
      self.record_change(change)
      Ok(change)
    }
  }
}

///|
pub fn PointStore::query(
  self : PointStore,
  filter : PointFilter,
) -> Array[PointRecord] {
  let result : Array[PointRecord] = []
  for _, record in self.points {
    if point_matches_filter(record, filter) {
      result.push(record)
    }
  }
  result.sort_by((left, right) => {
    left.address().number() - right.address().number()
  })
  result
}

///|
pub fn PointStore::addresses(self : PointStore) -> Array[InformationAddress] {
  let result : Array[InformationAddress] = []
  for value, _ in self.points {
    result.push(InformationAddress::new(value).unwrap())
  }
  result.sort_by((left, right) => left.number() - right.number())
  result
}

///|
pub fn PointStore::statistics(self : PointStore) -> StoreStatistics {
  let result = StoreStatistics::empty()
  result.total = self.points.length()
  result.changes = self.history.length()
  for _, record in self.points {
    result.revisions += record.revision()
    if record.direction() == MonitorDirection {
      result.monitoring += 1
    } else {
      result.control += 1
    }
    if record.is_valid() {
      result.valid += 1
    } else {
      result.invalid += 1
    }
  }
  result
}

///|
/// Convert a store snapshot into application objects for interrogation.
pub fn PointStore::objects(
  self : PointStore,
  filter : PointFilter,
) -> Array[ApplicationObject] {
  let result : Array[ApplicationObject] = []
  for record in self.query(filter) {
    match
      make_application_object(
        record.address(),
        record.value(),
        record.time_tag(),
      ) {
      Ok(object) => result.push(object)
      Err(_) => ()
    }
  }
  result
}

///|
/// A transaction that stages changes before committing them to a store.
pub struct StoreTransaction {
  pending : Array[(ApplicationObject, Int, String)]
  removed : Array[(InformationAddress, Int)]
  mut committed : Bool
} derive(Debug)

///|
pub fn StoreTransaction::new() -> StoreTransaction {
  { pending: [], removed: [], committed: false }
}

///|
pub fn StoreTransaction::stage(
  self : StoreTransaction,
  object : ApplicationObject,
  timestamp : Int,
  source? : String = "transaction",
) -> Result[Unit, Diagnostic] {
  if self.committed {
    Err(Diagnostic::new(StateViolation, "transaction is already committed"))
  } else {
    match object.validate() {
      Err(error) => Err(error)
      Ok(_) => {
        self.pending.push((object, timestamp, source))
        Ok(())
      }
    }
  }
}

///|
pub fn StoreTransaction::stage_remove(
  self : StoreTransaction,
  address : InformationAddress,
  timestamp : Int,
) -> Result[Unit, Diagnostic] {
  if self.committed {
    Err(Diagnostic::new(StateViolation, "transaction is already committed"))
  } else {
    self.removed.push((address, timestamp))
    Ok(())
  }
}

///|
pub fn StoreTransaction::pending_count(self : StoreTransaction) -> Int {
  self.pending.length() + self.removed.length()
}

///|
pub fn StoreTransaction::rollback(self : StoreTransaction) -> Unit {
  self.pending.clear()
  self.removed.clear()
  self.committed = true
}

///|
pub fn StoreTransaction::commit(
  self : StoreTransaction,
  store : PointStore,
) -> Result[Array[PointChange], Diagnostic] {
  if self.committed {
    Err(Diagnostic::new(StateViolation, "transaction is already closed"))
  } else {
    let changes : Array[PointChange] = []
    for pair in self.removed {
      let (address, timestamp) = pair
      match store.remove(address, timestamp) {
        Ok(change) => changes.push(change)
        Err(error) => return Err(error)
      }
    }
    for triple in self.pending {
      let (object, timestamp, source) = triple
      match store.upsert(object, timestamp, source~) {
        Ok(change) => changes.push(change)
        Err(error) => return Err(error)
      }
    }
    self.committed = true
    Ok(changes)
  }
}

///|
pub fn point_store_examples() -> Array[PointDirection] {
  [MonitorDirection, ControlDirection]
}

///|
pub fn point_change_kind_examples() -> Array[PointChangeKind] {
  [Inserted, Updated, Removed, Rejected]
}
