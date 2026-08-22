///|
/// Roles recognized by the operational authorization layer.
pub enum OperatorRole {
  ViewerRole
  EngineerRole
  DispatcherRole
  AdministratorRole
  ServiceRole
} derive(Eq, Debug)

///|
/// Fine-grained operations that can be authorized.
pub enum OperationalPermission {
  ViewTelemetry
  ViewDiagnostics
  ReadFiles
  WriteFiles
  SubmitCommands
  ConfirmCommands
  ManageStations
  ManageRoutes
  ManagePolicies
  PerformFailover
} derive(Eq, Debug)

///|
pub fn role_permissions(role : OperatorRole) -> Array[OperationalPermission] {
  match role {
    ViewerRole => [ViewTelemetry, ViewDiagnostics]
    EngineerRole => [ViewTelemetry, ViewDiagnostics, ReadFiles, WriteFiles]
    DispatcherRole =>
      [ViewTelemetry, ViewDiagnostics, SubmitCommands, ConfirmCommands]
    AdministratorRole =>
      [
        ViewTelemetry,
        ViewDiagnostics,
        ReadFiles,
        WriteFiles,
        SubmitCommands,
        ConfirmCommands,
        ManageStations,
        ManageRoutes,
        ManagePolicies,
        PerformFailover,
      ]
    ServiceRole => [ViewTelemetry, ViewDiagnostics, ReadFiles]
  }
}

///|
pub struct OperatorIdentity {
  id : String
  display_name : String
  role : OperatorRole
  stations : Array[CommonAddress]
  active : Bool
} derive(Eq, Debug)

///|
pub fn OperatorIdentity::new(
  id : String,
  display_name : String,
  role : OperatorRole,
  stations? : Array[CommonAddress] = [],
  active? : Bool = true,
) -> Result[OperatorIdentity, String] {
  if id.length() == 0 || id.length() > 128 {
    Err("operator id must contain between 1 and 128 characters")
  } else if display_name.length() == 0 {
    Err("operator display name is empty")
  } else {
    Ok({ id, display_name, role, stations: stations.copy(), active })
  }
}

///|
pub fn OperatorIdentity::id(self : OperatorIdentity) -> String {
  self.id
}

///|
pub fn OperatorIdentity::display_name(self : OperatorIdentity) -> String {
  self.display_name
}

///|
pub fn OperatorIdentity::role(self : OperatorIdentity) -> OperatorRole {
  self.role
}

///|
pub fn OperatorIdentity::stations(
  self : OperatorIdentity,
) -> Array[CommonAddress] {
  self.stations.copy()
}

///|
pub fn OperatorIdentity::active(self : OperatorIdentity) -> Bool {
  self.active
}

///|
pub fn OperatorIdentity::covers(
  self : OperatorIdentity,
  station : CommonAddress,
) -> Bool {
  self.stations.length() == 0 || self.stations.contains(station)
}

///|
/// A bounded maintenance interval during which risky actions are blocked.
pub struct MaintenanceWindow {
  id : Int
  station : CommonAddress?
  start : Int
  end : Int
  reason : String
  blocks_commands : Bool
  blocks_file_writes : Bool
  mut enabled : Bool
} derive(Eq, Debug)

///|
pub fn MaintenanceWindow::new(
  id : Int,
  start : Int,
  end : Int,
  reason : String,
  station? : CommonAddress,
  blocks_commands? : Bool = true,
  blocks_file_writes? : Bool = true,
) -> Result[MaintenanceWindow, String] {
  if id < 1 || start < 0 || end <= start {
    Err("maintenance window bounds are invalid")
  } else if reason.length() == 0 {
    Err("maintenance window reason is empty")
  } else {
    Ok({
      id,
      station,
      start,
      end,
      reason,
      blocks_commands,
      blocks_file_writes,
      enabled: true,
    })
  }
}

///|
pub fn MaintenanceWindow::id(self : MaintenanceWindow) -> Int {
  self.id
}

///|
pub fn MaintenanceWindow::station(self : MaintenanceWindow) -> CommonAddress? {
  self.station
}

///|
pub fn MaintenanceWindow::start(self : MaintenanceWindow) -> Int {
  self.start
}

///|
pub fn MaintenanceWindow::end(self : MaintenanceWindow) -> Int {
  self.end
}

///|
pub fn MaintenanceWindow::reason(self : MaintenanceWindow) -> String {
  self.reason
}

///|
pub fn MaintenanceWindow::blocks_commands(self : MaintenanceWindow) -> Bool {
  self.blocks_commands
}

///|
pub fn MaintenanceWindow::blocks_file_writes(self : MaintenanceWindow) -> Bool {
  self.blocks_file_writes
}

///|
pub fn MaintenanceWindow::enabled(self : MaintenanceWindow) -> Bool {
  self.enabled
}

///|
pub fn MaintenanceWindow::contains(
  self : MaintenanceWindow,
  station : CommonAddress,
  timestamp : Int,
) -> Bool {
  let station_ok = match self.station {
    Some(value) => value == station
    None => true
  }
  self.enabled && station_ok && timestamp >= self.start && timestamp < self.end
}

///|
pub fn MaintenanceWindow::disable(self : MaintenanceWindow) -> Unit {
  self.enabled = false
}

///|
/// A station/type-specific policy rule.
pub struct PolicyRule {
  id : Int
  permission : OperationalPermission
  station : CommonAddress?
  type_ids : Array[ApplicationType]
  roles : Array[OperatorRole]
  mut enabled : Bool
  reason : String
} derive(Eq, Debug)

///|
pub fn PolicyRule::new(
  id : Int,
  permission : OperationalPermission,
  reason : String,
  station? : CommonAddress,
  type_ids? : Array[ApplicationType] = [],
  roles? : Array[OperatorRole] = [],
) -> Result[PolicyRule, String] {
  if id < 1 || reason.length() == 0 {
    Err("policy rule id and reason are required")
  } else {
    Ok({
      id,
      permission,
      station,
      type_ids: type_ids.copy(),
      roles: roles.copy(),
      enabled: true,
      reason,
    })
  }
}

///|
pub fn PolicyRule::id(self : PolicyRule) -> Int {
  self.id
}

///|
pub fn PolicyRule::permission(self : PolicyRule) -> OperationalPermission {
  self.permission
}

///|
pub fn PolicyRule::station(self : PolicyRule) -> CommonAddress? {
  self.station
}

///|
pub fn PolicyRule::type_ids(self : PolicyRule) -> Array[ApplicationType] {
  self.type_ids.copy()
}

///|
pub fn PolicyRule::roles(self : PolicyRule) -> Array[OperatorRole] {
  self.roles.copy()
}

///|
pub fn PolicyRule::enabled(self : PolicyRule) -> Bool {
  self.enabled
}

///|
pub fn PolicyRule::reason(self : PolicyRule) -> String {
  self.reason
}

///|
pub fn PolicyRule::disable(self : PolicyRule) -> Unit {
  self.enabled = false
}

///|
pub struct PolicyDecision {
  allowed : Bool
  permission : OperationalPermission
  operator : String
  station : CommonAddress
  rule_id : Int?
  reason : String
} derive(Eq, Debug)

///|
pub fn PolicyDecision::allowed(self : PolicyDecision) -> Bool {
  self.allowed
}

///|
pub fn PolicyDecision::permission(
  self : PolicyDecision,
) -> OperationalPermission {
  self.permission
}

///|
pub fn PolicyDecision::operator(self : PolicyDecision) -> String {
  self.operator
}

///|
pub fn PolicyDecision::station(self : PolicyDecision) -> CommonAddress {
  self.station
}

///|
pub fn PolicyDecision::rule_id(self : PolicyDecision) -> Int? {
  self.rule_id
}

///|
pub fn PolicyDecision::reason(self : PolicyDecision) -> String {
  self.reason
}

///|
pub enum AuditAction {
  AuthorizationChecked
  PolicyChanged
  MaintenanceChanged
  CommandAuthorized
  FileAuthorized
  StationConfigured
  FailoverAuthorized
} derive(Eq, Debug)

///|
pub struct PolicyAudit {
  sequence : Int
  timestamp : Int
  action : AuditAction
  operator : String
  station : CommonAddress?
  object : InformationAddress?
  allowed : Bool
  detail : String
} derive(Eq, Debug)

///|
pub fn PolicyAudit::sequence(self : PolicyAudit) -> Int {
  self.sequence
}

///|
pub fn PolicyAudit::timestamp(self : PolicyAudit) -> Int {
  self.timestamp
}

///|
pub fn PolicyAudit::action(self : PolicyAudit) -> AuditAction {
  self.action
}

///|
pub fn PolicyAudit::operator(self : PolicyAudit) -> String {
  self.operator
}

///|
pub fn PolicyAudit::station(self : PolicyAudit) -> CommonAddress? {
  self.station
}

///|
pub fn PolicyAudit::object(self : PolicyAudit) -> InformationAddress? {
  self.object
}

///|
pub fn PolicyAudit::allowed(self : PolicyAudit) -> Bool {
  self.allowed
}

///|
pub fn PolicyAudit::detail(self : PolicyAudit) -> String {
  self.detail
}

///|
/// Bounded audit journal shared by authorization and management APIs.
pub struct PolicyAuditJournal {
  entries : Array[PolicyAudit]
  limit : Int
  mut next_sequence : Int
} derive(Debug)

///|
pub fn PolicyAuditJournal::new(
  limit? : Int = 4096,
) -> Result[PolicyAuditJournal, String] {
  if limit < 1 {
    Err("policy audit limit must be positive")
  } else {
    Ok({ entries: [], limit, next_sequence: 1 })
  }
}

///|
pub fn PolicyAuditJournal::len(self : PolicyAuditJournal) -> Int {
  self.entries.length()
}

///|
pub fn PolicyAuditJournal::all(self : PolicyAuditJournal) -> Array[PolicyAudit] {
  self.entries.copy()
}

///|
pub fn PolicyAuditJournal::append(
  self : PolicyAuditJournal,
  timestamp : Int,
  action : AuditAction,
  operator : String,
  station : CommonAddress?,
  object : InformationAddress?,
  allowed : Bool,
  detail : String,
) -> PolicyAudit {
  let entry = {
    sequence: self.next_sequence,
    timestamp,
    action,
    operator,
    station,
    object,
    allowed,
    detail,
  }
  self.next_sequence += 1
  self.entries.push(entry)
  while self.entries.length() > self.limit {
    ignore(self.entries.remove(0))
  }
  entry
}

///|
/// Central policy evaluator for operator-facing services.
pub struct OperationalPolicy {
  rules : Array[PolicyRule]
  windows : Array[MaintenanceWindow]
  identities : Map[String, OperatorIdentity]
  journal : PolicyAuditJournal
  mut revision : Int
} derive(Debug)

///|
pub fn OperationalPolicy::new(
  audit_limit? : Int = 4096,
) -> Result[OperationalPolicy, String] {
  match PolicyAuditJournal::new(limit=audit_limit) {
    Err(error) => Err(error)
    Ok(journal) =>
      Ok({ rules: [], windows: [], identities: {}, journal, revision: 0 })
  }
}

///|
pub fn OperationalPolicy::revision(self : OperationalPolicy) -> Int {
  self.revision
}

///|
pub fn OperationalPolicy::journal(
  self : OperationalPolicy,
) -> PolicyAuditJournal {
  self.journal
}

///|
pub fn OperationalPolicy::add_identity(
  self : OperationalPolicy,
  identity : OperatorIdentity,
) -> Result[Unit, String] {
  if self.identities.contains(identity.id()) {
    Err("operator identity already exists")
  } else {
    self.identities[identity.id()] = identity
    self.revision += 1
    Ok(())
  }
}

///|
pub fn OperationalPolicy::remove_identity(
  self : OperationalPolicy,
  id : String,
) -> Result[Unit, String] {
  if self.identities.contains(id) {
    self.identities.remove(id)
    self.revision += 1
    Ok(())
  } else {
    Err("operator identity does not exist")
  }
}

///|
pub fn OperationalPolicy::identity(
  self : OperationalPolicy,
  id : String,
) -> OperatorIdentity? {
  self.identities.get(id)
}

///|
pub fn OperationalPolicy::add_rule(
  self : OperationalPolicy,
  rule : PolicyRule,
) -> Result[Unit, String] {
  for current in self.rules {
    if current.id() == rule.id() {
      return Err("policy rule id already exists")
    }
  }
  self.rules.push(rule)
  self.revision += 1
  Ok(())
}

///|
pub fn OperationalPolicy::add_window(
  self : OperationalPolicy,
  window : MaintenanceWindow,
) -> Result[Unit, String] {
  for current in self.windows {
    if current.id() == window.id() {
      return Err("maintenance window id already exists")
    }
  }
  self.windows.push(window)
  self.windows.sort_by((left, right) => left.start() - right.start())
  self.revision += 1
  Ok(())
}

///|
pub fn OperationalPolicy::windows(
  self : OperationalPolicy,
) -> Array[MaintenanceWindow] {
  self.windows.copy()
}

///|
fn rule_matches(
  rule : PolicyRule,
  identity : OperatorIdentity,
  permission : OperationalPermission,
  station : CommonAddress,
  type_id : ApplicationType?,
) -> Bool {
  let station_ok = match rule.station() {
    Some(value) => value == station
    None => true
  }
  let type_ok = match type_id {
    Some(value) =>
      rule.type_ids().length() == 0 || rule.type_ids().contains(value)
    None => true
  }
  let role_ok = rule.roles().length() == 0 ||
    rule.roles().contains(identity.role())
  rule.enabled() &&
  rule.permission() == permission &&
  station_ok &&
  type_ok &&
  role_ok
}

///|
fn OperationalPolicy::policy_blocked_by_window(
  self : OperationalPolicy,
  permission : OperationalPermission,
  station : CommonAddress,
  timestamp : Int,
) -> Bool {
  for window in self.windows {
    if window.contains(station, timestamp) &&
      (
        (permission == SubmitCommands && window.blocks_commands()) ||
        (permission == WriteFiles && window.blocks_file_writes())
      ) {
      return true
    }
  }
  false
}

///|
pub fn OperationalPolicy::authorize(
  self : OperationalPolicy,
  operator_id : String,
  permission : OperationalPermission,
  station : CommonAddress,
  type_id : ApplicationType?,
  timestamp : Int,
) -> PolicyDecision {
  let identity = self.identities.get(operator_id)
  match identity {
    None => {
      ignore(
        self.journal.append(
          timestamp,
          AuthorizationChecked,
          operator_id,
          None,
          None,
          false,
          "unknown operator",
        ),
      )
      {
        allowed: false,
        permission,
        operator: operator_id,
        station,
        rule_id: None,
        reason: "unknown operator",
      }
    }
    Some(value) =>
      if !value.active() || !value.covers(station) {
        ignore(
          self.journal.append(
            timestamp,
            AuthorizationChecked,
            value.id(),
            Some(station),
            None,
            false,
            "operator is inactive or out of scope",
          ),
        )
        {
          allowed: false,
          permission,
          operator: value.id(),
          station,
          rule_id: None,
          reason: "operator is inactive or out of scope",
        }
      } else if self.policy_blocked_by_window(permission, station, timestamp) {
        ignore(
          self.journal.append(
            timestamp,
            AuthorizationChecked,
            value.id(),
            Some(station),
            None,
            false,
            "maintenance window blocks operation",
          ),
        )
        {
          allowed: false,
          permission,
          operator: value.id(),
          station,
          rule_id: None,
          reason: "maintenance window blocks operation",
        }
      } else {
        let direct = role_permissions(value.role()).contains(permission)
        let mut matched : Int? = None
        for rule in self.rules {
          if rule_matches(rule, value, permission, station, type_id) {
            matched = Some(rule.id())
          }
        }
        let allowed = direct && (matched is Some(_) || self.rules.length() == 0)
        let reason = if allowed {
          "operation authorized"
        } else {
          "operation denied by policy"
        }
        ignore(
          self.journal.append(
            timestamp,
            AuthorizationChecked,
            value.id(),
            Some(station),
            None,
            allowed,
            reason,
          ),
        )
        {
          allowed,
          permission,
          operator: value.id(),
          station,
          rule_id: matched,
          reason,
        }
      }
  }
}

///|
pub fn OperatorRole::examples() -> Array[OperatorRole] {
  [ViewerRole, EngineerRole, DispatcherRole, AdministratorRole, ServiceRole]
}

///|
pub fn operational_permission_examples() -> Array[OperationalPermission] {
  [
    ViewTelemetry,
    ViewDiagnostics,
    ReadFiles,
    WriteFiles,
    SubmitCommands,
    ConfirmCommands,
    ManageStations,
    ManageRoutes,
    ManagePolicies,
    PerformFailover,
  ]
}

///|
pub fn audit_action_examples() -> Array[AuditAction] {
  [
    AuthorizationChecked,
    PolicyChanged,
    MaintenanceChanged,
    CommandAuthorized,
    FileAuthorized,
    StationConfigured,
    FailoverAuthorized,
  ]
}
