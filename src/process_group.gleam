//// Groups that can be joined and left by processes, and the members of which
//// can be listed on request. This may be useful for publish-subscribe
//// patterns, where many processes want to receive messages another.
////
//// This module is implemented using Erlang's [`pg`][pg] module and uses ETS
//// for storage, so listing the members of a group is optimised for speed.
////
//// Groups are tracked by group registry processes, which you should add to
//// your supervision tree. Each registry is independant from each other.
////
//// If a member terminates, it is automatically removed from the group.
////
//// If a group registry terminates the groups are lost and will need to be
//// recreated. Restarting the group registry will not recover the groups.
////
//// There is no memory cost to the registry of a group without any members.
////
//// ## Publish-subscribe
////
//// This module is useful for pubsub, but it does not offer any functions for
//// sending messages itself. To perform pubsub add the subscriber messages to
//// a group, then the publishers can use the `members` function to get a
//// list of subjects for the subscribers and send messages to them.
////
//// ## Distributed groups
////
//// If two nodes in an Erlang cluster have process registries or `pg`
//// instances created with the same name (called a "scope" in the `pg`
//// documentation) they will share group membership in an eventually
//// consistent way. See the `pg` documentation for more information. Note that
//// names created with the `process.new_name` are unique, so calling that
//// function with the same prefix string on each node in an Erlang cluster
//// will result in distinct names.
////
//// [pg]: https://www.erlang.org/doc/apps/kernel/pg.html
////
//// ## Scalability
////
//// Inserting members or getting all the members of a group `pg` is fast, but
//// removing members from large groups with thousands of members in them is
//// much slower.
////
//// If you need larger groups and members to be removed or to terminate
//// frequently you may want to experiment with other registries. Always
//// benchmark and profile your code when performance matters.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Name, type Pid, type Subject}
import gleam/erlang/reference.{type Reference}
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision

//
// Group registry
//

pub type GroupRegistry

pub type GroupRegistryMessage

pub fn start_registry(
  name: Name(GroupRegistryMessage),
) -> actor.StartResult(GroupRegistry) {
  case erlang_start(name) {
    Ok(pid) -> Ok(actor.Started(pid:, data: get_registry(name)))
    Error(reason) -> Error(actor.InitExited(process.Abnormal(reason)))
  }
}

pub fn supervised_registry(
  name: Name(GroupRegistryMessage),
) -> supervision.ChildSpecification(GroupRegistry) {
  supervision.worker(fn() { start_registry(name) })
}

@external(erlang, "gleam@function", "identity")
pub fn get_registry(name: Name(GroupRegistryMessage)) -> GroupRegistry

//
// Groups
//

pub opaque type ProcessGroup(message) {
  Group(tag: reference.Reference, registry: GroupRegistry)
}

pub fn new(registry: GroupRegistry) -> ProcessGroup(message) {
  Group(tag: reference.new(), registry:)
}

/// Add a process to the group.
///
/// A process can join a group many times and must then leave the group the
/// same number of times.
///
/// A subject is returned which can be used to send to messages to the member,
/// or for the member to receive messages.
///
pub fn join(group: ProcessGroup(message), new_member: Pid) -> Subject(message) {
  erlang_join(group.registry, group.tag, new_member)
  subject_for_group(group, new_member)
}

/// Remove the given processes from the group, if they are members.
///
pub fn leave(group: ProcessGroup(message), members: List(Pid)) -> Nil {
  erlang_leave(group.registry, group.tag, members)
  Nil
}

/// Returns subjects for all processes in the group. They are returned in
/// no specific order.
///
/// If a process joined the group multiple times it will be present in the list
/// that number of times.
///
pub fn members(group: ProcessGroup(message)) -> List(Subject(message)) {
  erlang_members(group.registry, group.tag)
  |> list.map(subject_for_group(group, _))
}

//
// Helpers
//

fn subject_for_group(group: ProcessGroup(message), pid: Pid) -> Subject(message) {
  let tag = reference_to_dynamic(group.tag)
  process.unsafely_create_subject(pid, tag)
}

//
// Erlang FFI
//

type DoNotLeak

@external(erlang, "pg", "start_link")
fn erlang_start(name: Name(GroupRegistryMessage)) -> Result(Pid, Dynamic)

@external(erlang, "pg", "join")
fn erlang_join(
  registry: GroupRegistry,
  group: Reference,
  new_members: Pid,
) -> DoNotLeak

@external(erlang, "pg", "leave")
fn erlang_leave(
  registry: GroupRegistry,
  group: Reference,
  members: List(Pid),
) -> DoNotLeak

@external(erlang, "pg", "get_members")
fn erlang_members(registry: GroupRegistry, group: Reference) -> List(Pid)

@external(erlang, "gleam@function", "identity")
fn reference_to_dynamic(a: Reference) -> Dynamic
