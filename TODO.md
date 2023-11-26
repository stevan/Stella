
## Remote Actors

### In ActorRef

- we need to add
    - way to stringify
    - identifier for lookup
    - url for external communications

### Stella::Remove::*

- the PostOffice will create an ActorProps for RemoteActors
    - the ActorProps will create a RemoteActor instance
        - has a link to the PostOffice so it can send messages
        - which will provide a `behavior`
            - that will send all messages to the post-office

- they will be normal ActorRef objects in the system
    - so no changes need happen to the ActorSystem

### In Stell::ActorSystem

- need to add a LOOP-FOREVER feature


<!--------------------------------------------------------------------->

## Linked Actors

The ActorRef can maintain a list of linked actors so that they can be notified when one exits.

This would improve/simplify the PingPong example.

## Behaviors

Since receivers are now just methods, it would be nice to be able to mark them as such. Opt-in, instead of opt-out.

```
package Stella::Actor::Attributes {
    use v5.38;
    use decorators ':for_providers';
    sub receiver : Decorator : TagMethod { () }
}
```

This would allow this to be written:

```
class Foo :isa(Stella::Actor) {
    method Bar :receiver ($ctx, $message) { ... }
}
```

An alternate would also be something like this:
```
class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        *Bar,
        *Baz,
    }
}
```
 The `behaviors` method would be implemented in `Actor` as a no-op, but would need to be overriden in
 subclasses.

Taking this one step further, this could be where we handle the type checking the messages.
```
class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        *Bar => [ *Int, *Int ],
        *Baz => [ *Str ],
    }
}
```

Or go full on Protocol ...
```
class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        event *Bar => [ *Int, *Int ];
        event *Baz => [ *Str ];
        event *Foo => [ *Str, *Int ];

        accepts *Bar, returns *Foo;
        accepts *Baz, returns *Foo;
    }
}
```

All three of these can be supported with some kind of type signature ish thingy mah bob.

```
class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        Stella::Behavior::Methods->new(symbols => [
            *Bar,
            *Baz,
        ])
    }
}

class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        Stella::Behavior::Events->new(events => {
            *Bar => [ *Int, *Int ],
            *Baz => [ *Str ],
        })
    }
}

class Foo :isa(Stella::Actor) {
    method Bar ($ctx, $message) { ... }
    method Baz ($ctx, $message) { ... }

    method behaviors {
        Stella::Behavior::Protocol
            ->builder
                ->add_event( *Bar => [ *Int, *Int ] )
                ->add_event( *Baz => [ *Str ] )
                ->add_event( *Foo => [ *Str, *Int ] )
            ->accepts(*Bar)->returns(*Foo)
            ->accepts(*Baz)->returns(*Foo)
        ;
    }
}
```

