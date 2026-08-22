///|
/// Validation profile for station and protocol admission checks.
pub struct ValidationProfile {
  max_points : Int
  max_history : Int
  require_time_tag_for_events : Bool
  reject_unknown_types : Bool
  require_non_global_station : Bool
} derive(Eq, Debug)

///|
pub fn ValidationProfile::default() -> ValidationProfile {
  {
    max_points: 4096,
    max_history: 4096,
    require_time_tag_for_events: false,
    reject_unknown_types: true,
    require_non_global_station: true,
  }
}

///|
pub fn ValidationProfile::new(
  max_points? : Int = 4096,
  max_history? : Int = 4096,
  require_time_tag_for_events? : Bool = false,
  reject_unknown_types? : Bool = true,
  require_non_global_station? : Bool = true,
) -> Result[ValidationProfile, String] {
  if max_points < 1 || max_history < 1 {
    Err("validation limits must be positive")
  } else {
    Ok({
      max_points,
      max_history,
      require_time_tag_for_events,
      reject_unknown_types,
      require_non_global_station,
    })
  }
}

///|
pub fn ValidationProfile::max_points(self : ValidationProfile) -> Int {
  self.max_points
}

///|
pub fn ValidationProfile::max_history(self : ValidationProfile) -> Int {
  self.max_history
}

///|
pub fn ValidationProfile::require_time_tag_for_events(
  self : ValidationProfile,
) -> Bool {
  self.require_time_tag_for_events
}

///|
pub fn ValidationProfile::reject_unknown_types(
  self : ValidationProfile,
) -> Bool {
  self.reject_unknown_types
}

///|
pub fn ValidationProfile::require_non_global_station(
  self : ValidationProfile,
) -> Bool {
  self.require_non_global_station
}

///|
pub enum ValidationIssueKind {
  ValidationMissing
  ValidationOutOfRange
  ValidationType
  ValidationCapacity
  ValidationQuality
  ValidationPolicy
} derive(Eq, Debug)

///|
pub struct ValidationIssue {
  kind : ValidationIssueKind
  path : String
  message : String
  address : InformationAddress?
  fatal : Bool
} derive(Eq, Debug)

///|
pub fn ValidationIssue::kind(self : ValidationIssue) -> ValidationIssueKind {
  self.kind
}

///|
pub fn ValidationIssue::path(self : ValidationIssue) -> String {
  self.path
}

///|
pub fn ValidationIssue::message(self : ValidationIssue) -> String {
  self.message
}

///|
pub fn ValidationIssue::address(self : ValidationIssue) -> InformationAddress? {
  self.address
}

///|
pub fn ValidationIssue::fatal(self : ValidationIssue) -> Bool {
  self.fatal
}

///|
pub struct ValidationReport {
  subject : String
  valid : Bool
  issues : Array[ValidationIssue]
  checked : Int
} derive(Debug)

///|
pub fn ValidationReport::subject(self : ValidationReport) -> String {
  self.subject
}

///|
pub fn ValidationReport::valid(self : ValidationReport) -> Bool {
  self.valid
}

///|
pub fn ValidationReport::issues(
  self : ValidationReport,
) -> Array[ValidationIssue] {
  self.issues.copy()
}

///|
pub fn ValidationReport::checked(self : ValidationReport) -> Int {
  self.checked
}

///|
fn validation_issue(
  kind : ValidationIssueKind,
  path : String,
  message : String,
  address : InformationAddress?,
  fatal : Bool,
) -> ValidationIssue {
  { kind, path, message, address, fatal }
}

///|
pub fn validate_application_object(
  object : ApplicationObject,
  profile : ValidationProfile,
) -> ValidationReport {
  let issues : Array[ValidationIssue] = []
  match object.validate() {
    Ok(_) => ()
    Err(error) =>
      issues.push(
        validation_issue(
          ValidationType,
          "object",
          error.message(),
          Some(object.address()),
          true,
        ),
      )
  }
  if profile.reject_unknown_types() && object.type_id() is UnknownType(_) {
    issues.push(
      validation_issue(
        ValidationType,
        "type-id",
        "unknown application type",
        Some(object.address()),
        true,
      ),
    )
  }
  {
    subject: "application-object",
    valid: issues.length() == 0,
    issues,
    checked: 1,
  }
}

///|
pub fn validate_station_config(
  config : StationConfig,
  profile : ValidationProfile,
) -> ValidationReport {
  let issues : Array[ValidationIssue] = []
  if profile.require_non_global_station() && config.common_address().is_global() {
    issues.push(
      validation_issue(
        ValidationPolicy,
        "common-address",
        "global address is not a station identity",
        None,
        true,
      ),
    )
  }
  if config.point_capacity() > profile.max_points() {
    issues.push(
      validation_issue(
        ValidationCapacity,
        "point-capacity",
        "point capacity exceeds validation profile",
        None,
        false,
      ),
    )
  }
  if config.history_limit() > profile.max_history() {
    issues.push(
      validation_issue(
        ValidationCapacity,
        "history-limit",
        "history limit exceeds validation profile",
        None,
        false,
      ),
    )
  }
  { subject: config.name(), valid: issues.length() == 0, issues, checked: 1 }
}

///|
pub fn validate_point_store(
  store : PointStore,
  profile : ValidationProfile,
) -> ValidationReport {
  let issues : Array[ValidationIssue] = []
  let points = store.query(PointFilter::all())
  if points.length() > profile.max_points() {
    issues.push(
      validation_issue(
        ValidationCapacity,
        "points",
        "point store exceeds configured capacity",
        None,
        true,
      ),
    )
  }
  if store.history_len() > profile.max_history() {
    issues.push(
      validation_issue(
        ValidationCapacity,
        "history",
        "point history exceeds configured capacity",
        None,
        false,
      ),
    )
  }
  let mut checked = 0
  for record in points {
    checked += 1
    if !record.is_valid() {
      issues.push(
        validation_issue(
          ValidationQuality,
          "quality",
          "point quality is unusable",
          Some(record.address()),
          false,
        ),
      )
    }
  }
  { subject: "point-store", valid: issues.length() == 0, issues, checked }
}

///|
pub fn validate_transport_frame_admission(
  data : Bytes,
  limits : ResourceLimits,
) -> ValidationReport {
  let issues : Array[ValidationIssue] = []
  if data.length() > limits.max_apdu() {
    issues.push(
      validation_issue(
        ValidationCapacity,
        "apdu",
        "APDU exceeds resource limit",
        None,
        true,
      ),
    )
  }
  match decode_frame(data) {
    Ok(frame) =>
      if frame.kind == Information && frame.payload.length() > limits.max_asdu() {
        issues.push(
          validation_issue(
            ValidationCapacity,
            "asdu",
            "ASDU exceeds resource limit",
            None,
            true,
          ),
        )
      }
    Err(error) =>
      issues.push(validation_issue(ValidationType, "frame", error, None, true))
  }
  {
    subject: "transport-frame",
    valid: issues.length() == 0,
    issues,
    checked: 1,
  }
}

///|
pub fn validation_issue_kind_examples() -> Array[ValidationIssueKind] {
  [
    ValidationMissing,
    ValidationOutOfRange,
    ValidationType,
    ValidationCapacity,
    ValidationQuality,
    ValidationPolicy,
  ]
}
