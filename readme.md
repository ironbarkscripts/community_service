# Ironbark Community Service - 1.0

Community service system for FiveM by **[Ironbark Scripts](https://github.com/ironbarkscripts)**.

Sentence players to a series of tasks at a designated area. Sentences persist across disconnects, framework detection is automatic, and all task validation happens server-side.

---

## Dependencies

| Resource | Purpose |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | Notifications, progress bars, locale |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [ox_target](https://github.com/overextended/ox_target) or [qb-target](https://github.com/qb-core/qb-target) | Interaction zones |
| **qbx_core** or **qb-core** | Player data |

ox_target is preferred over qb-target. qbx_core is preferred over qb-core. Both are detected automatically at runtime — no config change needed.

---

## Installation

1. Drop `community_service` into your resources folder.
2. Add to `server.cfg`, after your framework and `ox_lib`:
   ```
   ensure community_service
   ```
3. Start your server. Database tables are created automatically on first run.

---

## Commands

| Command | Who | Description |
|---|---|---|
| `/sentence [id] [tasks] [reason]` | Authorised job or console | Sentence a player to community service |
| `/clearsentence [id]` | Authorised job or console | Clear a player's active sentence immediately |
| `/mysentence` | Any player | Check your own sentence progress |

Stacking is supported — sentencing a player who already has an active sentence adds tasks up to `Config.MaxTasks`.

All commands are also available from the server console.

---

## Configuration

All options are in `shared/config.lua`.

### Core options

| Key | Default | Description |
|---|---|---|
| `Config.AuthorisedJobs` | `{ 'police', 'sheriff', 'state' }` | Jobs allowed to issue and clear sentences |
| `Config.MinTasks` | `3` | Minimum tasks per sentence |
| `Config.MaxTasks` | `50` | Maximum tasks, including stacked sentences |
| `Config.TaskCooldown` | `10` | Cooldown in seconds between tasks |
| `Config.TaskRadius` | `5.0` | Server-side proximity in metres required to start and complete a task |
| `Config.ConfinementCoords` | Sandy Shores area | Centre of the permitted community service zone |
| `Config.ConfinementRadius` | `120.0` | Players outside this radius are returned to the centre |

### Marker options

| Key | Default | Description |
|---|---|---|
| `Config.MarkerType` | `1` | GTA marker type integer |
| `Config.MarkerColour` | `{ r=255, g=165, b=0, a=180 }` | RGBA colour of task markers |
| `Config.MarkerSize` | `{ x=1.5, y=1.5, z=0.5 }` | Dimensions of task markers |

Drop-off markers on prop-carry tasks use a fixed green tint regardless of `Config.MarkerColour`.

### Adding a task

Basic task (progress bar with animation):

```lua
{
    id        = 'my_task',
    label     = 'Do something',
    coords    = vector3(x, y, z),
    animation = { dict = 'anim_dict', anim = 'anim_name', flag = 49 },
    duration  = 15000,
    icon      = 'fas fa-broom',
},
```

Prop carry task (player picks up a prop and carries it to a drop-off point):

```lua
{
    id         = 'take_trash_out',
    label      = 'Take the trash out',
    coords     = vector3(x, y, z),      -- pickup location
    dropCoords = vector3(x, y, z),      -- drop-off location
    prop = {
        model    = 'prop_rub_binbag_01',
        bone     = 57005,
        offset   = vector3(0.12, 0.0, -0.05),
        rotation = vector3(0.0, 0.0, 0.0),
    },
    animation = { dict = 'anim_dict', anim = 'anim_name', flag = 49 },
    duration  = 2500,   -- pickup progress bar duration
    icon      = 'fas fa-trash',
},
```

Optional looping sound for non-prop tasks:

```lua
sound = { name = 'SOUND_NAME', set = 'SOUND_SET', interval = 3000 },
```

Tasks cycle without repeating — a player sees every configured task before any task repeats.

---

## Localisation

Strings are in `locales/en.json`. To add a language, duplicate the file and rename it (e.g. `fr.json`). The active locale is controlled by the `ox:locale` ConVar in your `server.cfg`:

```
setr ox:locale fr
```

---

## Database

Two tables are created automatically on resource start.

| Table | Purpose |
|---|---|
| `kg_cs_sentences` | Active sentences — one row per player, deleted when the sentence is served |
| `kg_cs_log` | Audit log of every completed and cleared task |

---

## Known Limitations

- The confinement boundary check runs every 2 seconds on the client. A very fast teleport exploit could slip through a single tick before the player is returned.
- Task markers are client-side and are not visible to other players.
- Only one task is active per player at a time. Parallel tasks are not supported.
- The `/sentence` command requires the target player to be online. Offline sentencing is not supported.

---

[github.com/ironbarkscripts/community_service](https://github.com/ironbarkscripts/community_service)
[Discord](https://discord.gg/HkQYCYEcyv)
