import gleam/erlang/process
import gleam/otp/actor
import gleeunit
import process_group

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hello_world_test() {
  let name = process.new_name("process_group_registry")
  let assert Ok(registry) = process_group.start_registry(name)

  // Group creation
  let group1 = process_group.new(registry.data)
  let group2 = process_group.new(registry.data)
  assert group1 != group2

  // Groups start empty
  assert process_group.members(group1) == []
  assert process_group.members(group2) == []

  // Groups can be joined
  let subject = process_group.join(group1, process.self())
  assert process_group.members(group1) == [subject]
  assert process_group.members(group2) == []

  // The subject can be used
  process.send(subject, "Hello")
  assert process.receive(subject, 0) == Ok("Hello")

  // Groups can be joined multiple times
  let subject = process_group.join(group1, process.self())
  assert process_group.members(group1) == [subject, subject]
  assert process_group.members(group2) == []

  // Groups can be left
  process_group.leave(group1, [process.self()])
  assert process_group.members(group1) == [subject]
  assert process_group.members(group2) == []

  // Processes are automatically removed after they terminate
  let assert Ok(actor) =
    actor.new(Nil) |> actor.on_message(fn(_, _) { actor.stop() }) |> actor.start
  let actor_subject = process_group.join(group1, actor.pid)
  assert process_group.members(group1) == [actor_subject, subject]
  process.send(actor.data, "stop")
  process.sleep(100)
  assert !process.is_alive(actor.pid)
  assert process_group.members(group1) == [subject]
}
