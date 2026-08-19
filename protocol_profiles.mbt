///|
/// A station profile exchanged by deployment configuration and test tools.
pub struct StationProfile {
  name : String
  common_address : CommonAddress
  parameters : ConnectionParameters
  supported_types : Array[ApplicationType]
  max_objects : Int
  tls_required : Bool
} derive(Debug)

///|
pub fn StationProfile::new(
  name : String,
  common_address : CommonAddress,
  parameters : ConnectionParameters,
  supported_types : Array[ApplicationType],
  max_objects? : Int = 127,
  tls_required? : Bool = false,
) -> Result[StationProfile, String] {
  if name == "" {
    Err("station profile name must not be empty")
  } else if max_objects < 1 || max_objects > 127 {
    Err("station profile object limit is outside 1..127")
  } else {
    Ok({
      name,
      common_address,
      parameters,
      supported_types,
      max_objects,
      tls_required,
    })
  }
}

///|
pub fn StationProfile::name(self : StationProfile) -> String {
  self.name
}

///|
pub fn StationProfile::common_address(self : StationProfile) -> CommonAddress {
  self.common_address
}

///|
pub fn StationProfile::parameters(
  self : StationProfile,
) -> ConnectionParameters {
  self.parameters
}

///|
pub fn StationProfile::supports(
  self : StationProfile,
  type_id : ApplicationType,
) -> Bool {
  for supported in self.supported_types {
    if supported == type_id {
      return true
    }
  }
  false
}

///|
pub fn StationProfile::supported_types(
  self : StationProfile,
) -> Array[ApplicationType] {
  self.supported_types.copy()
}

///|
pub fn StationProfile::max_objects(self : StationProfile) -> Int {
  self.max_objects
}

///|
pub fn StationProfile::tls_required(self : StationProfile) -> Bool {
  self.tls_required
}

///|
pub enum NegotiationDecision {
  CompatibleProfile
  IncompatibleProfile(Array[String])
} derive(Debug)

///|
pub fn negotiate_profiles(
  local_profile : StationProfile,
  remote : StationProfile,
) -> NegotiationDecision {
  let issues : Array[String] = []
  if local_profile.parameters().k() > remote.parameters().k() {
    issues.push("local k exceeds remote capacity")
  }
  if local_profile.parameters().w() > remote.parameters().w() {
    issues.push("local w exceeds remote capacity")
  }
  if local_profile.max_objects() > remote.max_objects() {
    issues.push("local object batch exceeds remote capacity")
  }
  for type_id in local_profile.supported_types() {
    if !remote.supports(type_id) {
      issues.push("remote does not support \{type_name(type_id)}")
    }
  }
  if issues.is_empty() {
    CompatibleProfile
  } else {
    IncompatibleProfile(issues)
  }
}

///|
pub struct ProfileRegistry {
  profiles : Map[String, StationProfile]
} derive(Debug)

///|
pub fn ProfileRegistry::new() -> ProfileRegistry {
  { profiles: {} }
}

///|
pub fn ProfileRegistry::put(
  self : ProfileRegistry,
  profile : StationProfile,
) -> Result[Unit, String] {
  if self.profiles.get(profile.name()) is Some(_) {
    Err("station profile already exists")
  } else {
    self.profiles[profile.name()] = profile
    Ok(())
  }
}

///|
pub fn ProfileRegistry::replace(
  self : ProfileRegistry,
  profile : StationProfile,
) -> Unit {
  self.profiles[profile.name()] = profile
}

///|
pub fn ProfileRegistry::get(
  self : ProfileRegistry,
  name : String,
) -> StationProfile? {
  self.profiles.get(name)
}

///|
pub fn ProfileRegistry::remove(self : ProfileRegistry, name : String) -> Bool {
  if self.profiles.get(name) is Some(_) {
    self.profiles.remove(name)
    true
  } else {
    false
  }
}

///|
pub fn ProfileRegistry::len(self : ProfileRegistry) -> Int {
  self.profiles.length()
}

///|
pub fn ProfileRegistry::names(self : ProfileRegistry) -> Array[String] {
  let result : Array[String] = []
  for name, _ in self.profiles {
    result.push(name)
  }
  result.sort()
  result
}

///|
pub enum TransportMode {
  Tcp
  SerialGateway
  ReplayFile
  InMemory
} derive(Eq, Debug)

///|
pub fn transport_mode_examples() -> Array[TransportMode] {
  [Tcp, SerialGateway, ReplayFile, InMemory]
}

///|
pub fn profile_examples() -> Array[StationProfile] {
  [
    StationProfile::new(
      "demo",
      CommonAddress::new(1).unwrap(),
      ConnectionParameters::default(),
      [MSpNa, MDpNa, MMeNa, CScNa],
    ).unwrap(),
  ]
}
