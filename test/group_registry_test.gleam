import gleam/erlang/process
import gleam/otp/actor
import gleeunit
import group_registry

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hello_world_test() {
  let name = process.new_name("process_group_registry")
  let assert Ok(registry) = group_registry.start(name)
  let registry = registry.data

  // Groups start empty
  assert group_registry.members(registry, "blue") == []
  assert group_registry.members(registry, "red") == []

  // Groups can be joined
  let subject = group_registry.join(registry, "blue", process.self())
  assert group_registry.members(registry, "blue") == [subject]
  assert group_registry.members(registry, "red") == []

  // The subject can be used
  process.send(subject, "Hello")
  assert process.receive(subject, 0) == Ok("Hello")

  // Groups can be joined multiple times
  let subject = group_registry.join(registry, "blue", process.self())
  assert group_registry.members(registry, "blue") == [subject, subject]
  assert group_registry.members(registry, "red") == []

  // Groups can be left
  group_registry.leave(registry, "blue", [process.self()])
  assert group_registry.members(registry, "blue") == [subject]
  assert group_registry.members(registry, "red") == []

  // Processes are automatically removed after they terminate
  let assert Ok(actor) =
    actor.new(Nil) |> actor.on_message(fn(_, _) { actor.stop() }) |> actor.start
  let actor_subject = group_registry.join(registry, "blue", actor.pid)
  assert group_registry.members(registry, "blue") == [actor_subject, subject]
  process.send(actor.data, "stop")
  process.sleep(100)
  assert !process.is_alive(actor.pid)
  assert group_registry.members(registry, "blue") == [subject]
}
