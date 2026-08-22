///|
/// Configuration value types accepted by the runtime registry.
pub enum ConfigValue {
  ConfigInt(Int)
  ConfigBool(Bool)
  ConfigText(String)
  ConfigDuration(Int)
  ConfigAddress(CommonAddress)
  ConfigAddressList(Array[CommonAddress])
} derive(Eq, Debug)

///|
pub fn ConfigValue::type_name(self : ConfigValue) -> String {
  match self {
    ConfigInt(_) => "int"
    ConfigBool(_) => "bool"
    ConfigText(_) => "text"
    ConfigDuration(_) => "duration"
    ConfigAddress(_) => "address"
    ConfigAddressList(_) => "address-list"
  }
}

///|
pub struct ConfigDefinition {
  key : String
  description : String
  default_value : ConfigValue
  required : Bool
  minimum : Int?
  maximum : Int?
  secret : Bool
  restart_required : Bool
} derive(Eq, Debug)

///|
pub fn ConfigDefinition::new(
  key : String,
  description : String,
  default_value : ConfigValue,
  required? : Bool = true,
  minimum? : Int,
  maximum? : Int,
  secret? : Bool = false,
  restart_required? : Bool = false,
) -> Result[ConfigDefinition, String] {
  if key.length() == 0 || key.length() > 128 {
    Err("configuration key must contain between 1 and 128 characters")
  } else if description.length() == 0 {
    Err("configuration description is empty")
  } else {
    match (minimum, maximum) {
      (Some(low), Some(high)) =>
        if low > high {
          Err("configuration bounds are inverted")
        } else {
          Ok({
            key,
            description,
            default_value,
            required,
            minimum,
            maximum,
            secret,
            restart_required,
          })
        }
      _ =>
        Ok({
          key,
          description,
          default_value,
          required,
          minimum,
          maximum,
          secret,
          restart_required,
        })
    }
  }
}

///|
pub fn ConfigDefinition::key(self : ConfigDefinition) -> String {
  self.key
}

///|
pub fn ConfigDefinition::description(self : ConfigDefinition) -> String {
  self.description
}

///|
pub fn ConfigDefinition::default_value(self : ConfigDefinition) -> ConfigValue {
  self.default_value
}

///|
pub fn ConfigDefinition::required(self : ConfigDefinition) -> Bool {
  self.required
}

///|
pub fn ConfigDefinition::minimum(self : ConfigDefinition) -> Int? {
  self.minimum
}

///|
pub fn ConfigDefinition::maximum(self : ConfigDefinition) -> Int? {
  self.maximum
}

///|
pub fn ConfigDefinition::secret(self : ConfigDefinition) -> Bool {
  self.secret
}

///|
pub fn ConfigDefinition::restart_required(self : ConfigDefinition) -> Bool {
  self.restart_required
}

///|
/// Value and source revision stored for one key.
pub struct ConfigEntry {
  definition : ConfigDefinition
  value : ConfigValue
  revision : Int
  updated_at : Int
  updated_by : String
} derive(Eq, Debug)

///|
pub fn ConfigEntry::definition(self : ConfigEntry) -> ConfigDefinition {
  self.definition
}

///|
pub fn ConfigEntry::value(self : ConfigEntry) -> ConfigValue {
  self.value
}

///|
pub fn ConfigEntry::revision(self : ConfigEntry) -> Int {
  self.revision
}

///|
pub fn ConfigEntry::updated_at(self : ConfigEntry) -> Int {
  self.updated_at
}

///|
pub fn ConfigEntry::updated_by(self : ConfigEntry) -> String {
  self.updated_by
}

///|
pub enum ConfigChangeKind {
  ConfigAdded
  ConfigUpdated
  ConfigReset
  ConfigRejected
} derive(Eq, Debug)

///|
pub struct ConfigChange {
  key : String
  kind : ConfigChangeKind
  from : ConfigValue?
  to : ConfigValue?
  revision : Int
  timestamp : Int
  operator : String
  message : String
} derive(Eq, Debug)

///|
pub fn ConfigChange::key(self : ConfigChange) -> String {
  self.key
}

///|
pub fn ConfigChange::kind(self : ConfigChange) -> ConfigChangeKind {
  self.kind
}

///|
pub fn ConfigChange::from(self : ConfigChange) -> ConfigValue? {
  self.from
}

///|
pub fn ConfigChange::to(self : ConfigChange) -> ConfigValue? {
  self.to
}

///|
pub fn ConfigChange::revision(self : ConfigChange) -> Int {
  self.revision
}

///|
pub fn ConfigChange::timestamp(self : ConfigChange) -> Int {
  self.timestamp
}

///|
pub fn ConfigChange::operator(self : ConfigChange) -> String {
  self.operator
}

///|
pub fn ConfigChange::message(self : ConfigChange) -> String {
  self.message
}

///|
fn config_int(value : ConfigValue) -> Int? {
  match value {
    ConfigInt(number) => Some(number)
    ConfigDuration(number) => Some(number)
    _ => None
  }
}

///|
fn config_value_valid(
  definition : ConfigDefinition,
  value : ConfigValue,
) -> Bool {
  if definition.default_value().type_name() != value.type_name() {
    false
  } else {
    match config_int(value) {
      None => true
      Some(number) => {
        let low_ok = match definition.minimum() {
          Some(low) => number >= low
          None => true
        }
        let high_ok = match definition.maximum() {
          Some(high) => number <= high
          None => true
        }
        low_ok && high_ok
      }
    }
  }
}

///|
pub struct ConfigTransaction {
  base_revision : Int
  operator : String
  timestamp : Int
  updates : Array[(String, ConfigValue)]
  resets : Array[String]
  mut closed : Bool
} derive(Debug)

///|
pub fn ConfigTransaction::new(
  base_revision : Int,
  operator : String,
  timestamp : Int,
) -> ConfigTransaction {
  { base_revision, operator, timestamp, updates: [], resets: [], closed: false }
}

///|
pub fn ConfigTransaction::base_revision(self : ConfigTransaction) -> Int {
  self.base_revision
}

///|
pub fn ConfigTransaction::operator(self : ConfigTransaction) -> String {
  self.operator
}

///|
pub fn ConfigTransaction::timestamp(self : ConfigTransaction) -> Int {
  self.timestamp
}

///|
pub fn ConfigTransaction::count(self : ConfigTransaction) -> Int {
  self.updates.length() + self.resets.length()
}

///|
pub fn ConfigTransaction::set(
  self : ConfigTransaction,
  key : String,
  value : ConfigValue,
) -> Result[Unit, String] {
  if self.closed {
    Err("configuration transaction is closed")
  } else {
    self.updates.push((key, value))
    Ok(())
  }
}

///|
pub fn ConfigTransaction::reset(
  self : ConfigTransaction,
  key : String,
) -> Result[Unit, String] {
  if self.closed {
    Err("configuration transaction is closed")
  } else {
    self.resets.push(key)
    Ok(())
  }
}

///|
pub fn ConfigTransaction::rollback(self : ConfigTransaction) -> Unit {
  self.updates.clear()
  self.resets.clear()
  self.closed = true
}

///|
/// Versioned configuration registry with atomic transaction commits.
pub struct ConfigurationRegistry {
  definitions : Map[String, ConfigDefinition]
  values : Map[String, ConfigEntry]
  history : Array[ConfigChange]
  history_limit : Int
  mut revision : Int
} derive(Debug)

///|
pub fn ConfigurationRegistry::new(
  history_limit? : Int = 4096,
) -> Result[ConfigurationRegistry, String] {
  if history_limit < 1 {
    Err("configuration history limit must be positive")
  } else {
    Ok({ definitions: {}, values: {}, history: [], history_limit, revision: 0 })
  }
}

///|
pub fn ConfigurationRegistry::revision(self : ConfigurationRegistry) -> Int {
  self.revision
}

///|
pub fn ConfigurationRegistry::len(self : ConfigurationRegistry) -> Int {
  self.values.length()
}

///|
pub fn ConfigurationRegistry::history(
  self : ConfigurationRegistry,
) -> Array[ConfigChange] {
  self.history.copy()
}

///|
pub fn ConfigurationRegistry::register_definition(
  self : ConfigurationRegistry,
  definition : ConfigDefinition,
  timestamp : Int,
  operator : String,
) -> Result[Unit, String] {
  if self.definitions.contains(definition.key()) {
    Err("configuration definition already exists")
  } else if !config_value_valid(definition, definition.default_value()) {
    Err("configuration default value violates definition")
  } else {
    self.definitions[definition.key()] = definition
    self.values[definition.key()] = {
      definition,
      value: definition.default_value(),
      revision: 1,
      updated_at: timestamp,
      updated_by: operator,
    }
    self.revision += 1
    self.record(
      definition.key(),
      ConfigAdded,
      None,
      Some(definition.default_value()),
      timestamp,
      operator,
      "configuration defined",
    )
    Ok(())
  }
}

///|
pub fn ConfigurationRegistry::definition(
  self : ConfigurationRegistry,
  key : String,
) -> ConfigDefinition? {
  self.definitions.get(key)
}

///|
pub fn ConfigurationRegistry::get(
  self : ConfigurationRegistry,
  key : String,
) -> ConfigEntry? {
  self.values.get(key)
}

///|
fn ConfigurationRegistry::record(
  self : ConfigurationRegistry,
  key : String,
  kind : ConfigChangeKind,
  from : ConfigValue?,
  to : ConfigValue?,
  timestamp : Int,
  operator : String,
  message : String,
) -> Unit {
  self.history.push({
    key,
    kind,
    from,
    to,
    revision: self.revision,
    timestamp,
    operator,
    message,
  })
  while self.history.length() > self.history_limit {
    ignore(self.history.remove(0))
  }
}

///|
pub fn ConfigurationRegistry::set(
  self : ConfigurationRegistry,
  key : String,
  value : ConfigValue,
  timestamp : Int,
  operator : String,
) -> Result[ConfigEntry, String] {
  match self.values.get(key) {
    None => Err("configuration key is undefined")
    Some(entry) =>
      if !config_value_valid(entry.definition(), value) {
        self.record(
          key,
          ConfigRejected,
          Some(entry.value()),
          None,
          timestamp,
          operator,
          "value violates configuration definition",
        )
        Err("configuration value violates definition")
      } else {
        let updated = {
          definition: entry.definition(),
          value,
          revision: entry.revision() + 1,
          updated_at: timestamp,
          updated_by: operator,
        }
        self.values[key] = updated
        self.revision += 1
        self.record(
          key,
          ConfigUpdated,
          Some(entry.value()),
          Some(value),
          timestamp,
          operator,
          "configuration updated",
        )
        Ok(updated)
      }
  }
}

///|
pub fn ConfigurationRegistry::reset(
  self : ConfigurationRegistry,
  key : String,
  timestamp : Int,
  operator : String,
) -> Result[ConfigEntry, String] {
  match self.values.get(key) {
    None => Err("configuration key is undefined")
    Some(entry) =>
      self.set(key, entry.definition().default_value(), timestamp, operator)
  }
}

///|
pub fn ConfigurationRegistry::commit(
  self : ConfigurationRegistry,
  transaction : ConfigTransaction,
) -> Result[Array[ConfigChange], String] {
  if transaction.closed {
    Err("configuration transaction is closed")
  } else if transaction.base_revision() != self.revision {
    transaction.closed = true
    Err("configuration revision conflict")
  } else {
    let first = self.history.length()
    for update in transaction.updates {
      let (key, value) = update
      match
        self.set(key, value, transaction.timestamp(), transaction.operator()) {
        Ok(_) => ()
        Err(error) => {
          transaction.closed = true
          return Err(error)
        }
      }
    }
    for key in transaction.resets {
      match self.reset(key, transaction.timestamp(), transaction.operator()) {
        Ok(_) => ()
        Err(error) => {
          transaction.closed = true
          return Err(error)
        }
      }
    }
    transaction.closed = true
    let result : Array[ConfigChange] = []
    for index in first..<self.history.length() {
      result.push(self.history[index])
    }
    Ok(result)
  }
}

///|
pub fn ConfigurationRegistry::keys(
  self : ConfigurationRegistry,
) -> Array[String] {
  let result : Array[String] = []
  for key, _ in self.values {
    result.push(key)
  }
  result.sort()
  result
}

///|
pub fn ConfigurationRegistry::export_lines(
  self : ConfigurationRegistry,
) -> Array[String] {
  let result : Array[String] = []
  for key in self.keys() {
    match self.values.get(key) {
      None => ()
      Some(entry) => result.push("\{key}=\{config_value_text(entry.value())}")
    }
  }
  result
}

///|
fn config_value_text(value : ConfigValue) -> String {
  match value {
    ConfigInt(number) => "int:\{number}"
    ConfigBool(flag) => if flag { "bool:true" } else { "bool:false" }
    ConfigText(text) => "text:\{text}"
    ConfigDuration(number) => "duration:\{number}"
    ConfigAddress(address) => "address:\{address.number()}"
    ConfigAddressList(addresses) => {
      let mut text = ""
      for address in addresses {
        text = "\{text}\{address.number()},"
      }
      "addresses:\{text}"
    }
  }
}

///|
pub fn config_value_examples() -> Array[ConfigValue] {
  [
    ConfigInt(1),
    ConfigBool(true),
    ConfigText("iec104"),
    ConfigDuration(10),
    ConfigAddress(CommonAddress::new(1).unwrap()),
    ConfigAddressList([CommonAddress::new(1).unwrap()]),
  ]
}

///|
pub fn config_change_kind_examples() -> Array[ConfigChangeKind] {
  [ConfigAdded, ConfigUpdated, ConfigReset, ConfigRejected]
}
