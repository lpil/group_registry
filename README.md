# process_group

Process groups, useful for pubsub

[![Package Version](https://img.shields.io/hexpm/v/process_group)](https://hex.pm/packages/process_group)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/process_group/)

```sh
gleam add process_group@1
```

Add a group registry to your supervision tree with
`process_group.supervised` and then create groups in that registry with
`process_group.new`.

```gleam
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import process_group

pub fn my_supervisor(name: Name(_)) -> actor.StartResult(_) {
  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(process_group.supervised())
  |> supervisor.start
}
```

Use `process_group.get_registry` to lookup the registry by the name you gave it
and then use `process_group.new` to create groups.

Processes can then use the `process_group.join` function to join a group.

```gleam
import gleam/otp/actor
import process_group.{type ProcessGroup}

pub fn start_actor(group: ProcessGroup(String)) -> actor.StartResult(_) {
  actor.new_with_initialiser(100, fn(_) { 
    // Join a group
    let subject = process_group.join()
    // Add the group subject to the selector so messages will be received
    actor.initialised(Nil)
    |> actor.selecting(process.new_selector() |> process.select(subject))
    |> Ok
  })
  |> actor.on_message(fn(state, message) {
    io.println("Got message: " <> message)
    actor.continue(state)
  })
  |> actor.start
}
```

Other processes can then publish messages to the members of the group. 

```gleam
import gleam/erlang/process
import process_group.{type ProcessGroup}

pub fn publish(group: ProcessGroup(String)) -> Nil {
  process_group.members(group)
  |> list.each(process.send(_, "Hello!"))
}
```

Further documentation can be found at <https://hexdocs.pm/process_group>.
