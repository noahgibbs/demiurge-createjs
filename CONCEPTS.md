# DCJS Concepts

Demiurge-CreateJS ("DCJS") is a mapping between Demiurge and a
JavaScript UI. To make things easy to reason about (and test!), it
uses a number of layers of abstraction.

DCJS runs its simulation and displays the results in an HTML Canvas
continually. It accepts control information and feeds it as actions
into the simulation. DCJS also takes care of simple accounts, logins
and authentication.

DCJS intentionally borrows a lot from ManaSource-engine and similar
games like The Mana World, Land of Fire and Source of Tales, as well
as OpenGameArt.org and the Liberated Pixel Cup. Its art style and
sprite sizes, of course, but also things like the format of TMX files
and how it uses the Tiled editor data.

## Demiurge and Players

Demiurge is its own whole world, and DCJS mostly stays out of it -- a
Demiurge engine should mostly run the same whether it's hooked up to a
display library or not... Mostly. The big exception to this is
players.

You can't really run a world with and without players and expect
nothing to change. Instead, Demiurge and DCJS turn players' effects on
the world into items and actions.

A player is normally represented by a Demiurge Agent, and what the
player does normally turns into Agent actions, going through the
normal Agent action queue. There's nothing ironclad about that, but
it's a good system and works well.

Certain administrative actions may turn into more exotic actions.  New
Demiurge items might be created or non-Agent actions might occur, for
instance. A statedump or server reboot won't normally happen as an
Agent action, for instance.

But in general, a player's UI actions will turn into queued actions in
Demiurge, and DCJS is how that happens.

## Architecture

The Demiurge engine runs inside a Ruby EventMachine server, which in
turn uses Faye for websocket protocol to talk to the connected browsers.

The websockets are connected to a browser, which can send control
information *to* the server and receives simulation and feedback
information *from* the server. DCJS puts one or more messages in a
simple JSON-based format into each Websocket message.

## The Cycle of Simulation

When a player takes action (moves, fights, speaks or whatever) the
browser doesn't normally display the result immediately. Instead, that
action is sent to the server, which determines what happens to
it. Demiurge picks it up on the next "tick" of the simulation and
sends out the results of the action.

Would it make more sense to just show the player's actions
immediately? Often not. If a player moves left, they could be blocked
by a wall. A trap could trigger. There might be slippery ground that
makes them move farther than they thought. By having the engine accept
the action and send the results, the user's browser doesn't have to
know about all these things. It can send the action and wait for an
answer.

The down-side of all this is that it limits the speed of
feedback. Very little that the player does can happen faster than once
per tick. You'd never want to build a rhythm game or a fast-paced
platformer this way. This is all designed to have the player make
choices and wait for the results. It's meant for a slower-paced game,
more like Stardew Valley or Dwarf Fortress, where the user's exact,
timed actions aren't make-or-break.

## DisplayObjects on the Server, SpriteStacks on the Client

A DCJS server is providing a lot of views into Demiurge, for a lot of
different clients, at a lot of different times. The same zone or room
looks different to different players, as you'd expect it to.

There is one single Demiurge engine, with one copy of each unique
item. When it moves or changes, it may update several different
players who can all see it.

DCJS keeps a single DisplayObject for each potentially visible
Demiurge object (and for some that will never be visible.) When each
DisplayObject changes, it may send updates to a bunch of players who
can see it.

Those changes happen via Demiurge notifications. The EngineSync object
subscribes to all Demiurge notifications and provides all the players
with a constant, consistent view of what's happening by translating
the notifications into DCJS messages over Websockets. The browsers,
when they get the messages, will show the players what Demiurge has
notified about.

Notifications can cause some complications - more than one thing can
happen to an item during a single tick, for instance. And
notifications go out in a big batch after the tick is over, not
immediately as things happen. So the item's condition when DCJS is
processing a notification may have changed. The player is seeing the
old pre-notification state. The notification tells what happened. But
the item may have changed again in a later notification, so we can't
assume we're just updating it to "current."

We also can't assume every player sees the DisplayObject the same way,
even if they're up to date. If Bob and Jane are standing in two
different parts of the same room, Bob may be able to see different
items than Jane, and they're scrolled to different positions. If Jane
has a better "perception" in some way than Bob, she may even see
things that, in effect, don't exist at all for Bob, and which may not
get sent to his browser.

A particular browser will have items representing some of the
DisplayObjects in DCJS. These in-browser objects include
"spritestacks", which may have multiple layers of tiled sprites. For
instance, a ManaSource-style humanoid like a player or enemy will
normally be several layers of "grids", where each grid is (usually) 1
sprite by 1 sprite, and each sprite is 64x64. The multiple layers, if
present, are for things like hair, clothing and equipment which are
modeled as overlaid layers.

## DisplayObjects and Players

A "Player", in this case, coordinates what gets sent to a particular
browser. It isn't guaranteed to correspond to a single humanoid
creature, or any creature or entity at all. A "player" could be an
observer.

But something has to coordinate important questions like "has this
browser received the necessary information to display this Sprite
Stack before?" and "is the browser currently showing a location where
this action is visible?" That "something" is called a "player" by
DCJS.

When a DisplayObject changes (is created or destroyed or moved or
changed) then the various players need to be updated and send messages
to the browser so that those actions can be shown to the human
audience.

Several objects are involved in this process. The EngineSync object
sees the notification from Demiurge and makes appropriate calls to the
various DisplayObjects to let them know they've changed.
