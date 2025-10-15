# Limiting memory usage by guest scripts in the VM

**Status**: Implemented

## Summary

Second Life has a relatively odd scripting ecosystem compared to most games. Scripts run in mixed-author
environments, where the creator of scripts "native" to a particular space have to be able to co-exist with scripts
owned and created by people who have no connection to the space, possibly as avatar attachments.

This means that we need to be very careful about limiting resource usage by scripts so servers don't get
overwhelmed. There's no direct equivalent in the MMO space to how SL handles scripts, where tens of thousands
of wholely isolated, untrusted scripts are pre-emptively scheduled and share a resource pool.

This means that SL has unique challenges, because unlike Roblox, each script is treated as an individual
unit that has its own memory limitations, rather than the memory limit applying to an experience as a whole.

Because these are hard limits, that means that our logic for limiting allocations is effectively part of the
API contract for our scripting system. A script should not appear to use more (or less) memory depending on which
other scripts are resident within a region. A script should not appear to use more memory if we modify internal
implementation details like adding a field onto a struct.

This requirement interacts badly with several very useful Lua features, like string interning, where if a string
already existed within the VM because another script used it, another script may appear to be using less memory because
it never had to allocate the string. Ideally, a script at the same point in the script with the same state
should always report the same amount of used memory, no matter where or when it is run.

## Background

### Memory Categories

One thing common to all of our approaches is that we heavily use the Luau memcat system. Memcats allow us to tag
heap allocations with an associated "memory category". All `GCObject`s that Luau manages for you on the heap have
this `memcat` field as part of their struct. We use memcat 0 to tag allocations that aren't the
"fault" of the user. Generally, all the C functions and things in the default globals are assigned memcat 0.

Some things that are meant to be opaque to the user, like the enforced iteration order array for deserialized
tables, are allocated with memcat 0 so a table having been deserialized isn't treated as a penalty.

Everything that is the "fault" of a user (most allocations that happen while user code is in control) is tagged
with a memcat of 2 or above.

This gets us part of the way there, giving us a way to distinguish between objects that contribute to memory limits
and those that don't.

## Proposal

The implementation we've landed on is scanning references from the script "root" using code in `lgctraverse.cpp`.
This allows us to have everything in a single VM with a single heap and a single GC while still enforcing logical
memory limits within a script.

We will deal with the problem of string interning sharing string instances across scripts by "charging" users for
all memcat 2 string instances that do _not_ occur within the bytecode of the current script. If they are constant's
from the user's script, they will be treated as "free" since we already consider bytecode size when deciding how much
a user script may allocate dynamically.

We can do this by ensuring all `luau_load()` calls are done with memcat 2 (giving `Proto`s and all their 
descendants memcat 2), and walking the protos when the script is first loaded to pick up all `GCObject`s that
should be considered "free" for the rest of the runtime.

We can use the existing user thread enumeration to store all memcat 2 objects in an unsorted set just after the script
is loaded, then pre-load that set into the `visited` nodes when later enumerating the user thread. That way we can have
`TString`s that are treated as "free" for some scripts, but not for others, even if they use the same interned
`TString` under the hood, and users aren't "charged" for strings that would be in the `Proto` constants.

Naturally, `lua_userthreadsize` and `luaC_enumreachableuserallocs` must be changed to optionally accept a pointer to
this `std::unordered_set<void *>` full of pointers, and we should add a new API function to build that set which returns
a `std::unordered_set<void *>`.

## Potential Drawbacks

Having all scripts within a single Lua VM with a single GC does have its drawbacks. When bytes get deallocated,
we can't credit that to the currently running script, since deallocations are likely related to another script
that just happened to get its data GC'd at that moment.

Similarly, GC pauses to work on objects within the same VM affect affect scripts seemingly randomly, whenever
the atomic mark and sweep phases happen. This is less of a problem than it would be with most VMs, as mark and
sweep are generally incremental, but we do have to be careful of those atomic phases when considering how long
a script ran in our pre-emptive scheduler.

## Alternatives Considered

### Micro-VMs with const sharing using global memcat byte limits

Previously we went with the approach of using micro-VMs that can use `GCObject`s from a "const" VM. That made them
more lightweight so we wouldn't need copies of the base globals in every single micro-VM. To enforce the memory limit,
we were using checks against a script's current `global->memcatbytes[USER_MEMCAT]` value. As scripts approached the limit,
we sped up GC to try and reap objects which were already dead to regain some bytes.

This worked fine, but had high overhead because each micro-VM had to have their own allocator with their own set of memory
pages. This had relatively high memory overhead due to natural heap fragmentation, and most space allocated by the system
for each micro-VM went totally unused.

It may be possible to have micro-VMs share a heap, but that would would diverge us from upstream Luau pretty heavily.
The heap maintains metadata about of all `GCObject`s within the pages themselves, and the GC assumes that it owns
everything referenced on the heap, which would not be the case with a shared heap. Fixing that would be a non-trivial
task, so we decided to go with approaches that would work in a single VM.
