# Player Mechanics
A list of all mechanics I want to implement in this prototype.

## Basic Terms
**Plasma**: tint, usually mencioning the one of the player's team color.

**Paint**: blocks colored by **plasma**.

**Adhesion**: holding the button mapped to the `"adhesion"` action.

## Movement
### Terms

**Jump**: holding a button mapped to the `"jump"` action.

**Buffer**: when you press an action, it'll be still valid for a specific 
amount of time (usually in ticks) and the executed as soon as possible if the  
elapsed time is still in the defined tick window.

**Coyote**: the action will still be valid when you press an action after the 
moment you should, but it's more about jumps after going off the ground.

**High Speed Mode**: when `velocity.length() > NORMAL_SPEED` where 
`NORMAL_SPEED` should not be less than 10... Maybe the speed of a [super 
dash](#super-dash) would be fine.

### Walking
Normal directional movement on the ground. We could zero horizontal `velocity` 
when moving towards opposite directions (when `velocity.dot(wishdir) < 0.0`).

Then, we will solve that little slide... Which may be potentially not desired.
> Control (friction) is reduced when in the air.

### Running
[Walking](#walking) with **adhesion**, on floor and above **paint**.

We could keep running mode by touching **adhesion** once and while we don't 
suddenly change desired direction.

### Jumping
With **jump** but also on floor or **buffered** or **coyote** jump. It allows 
variable jump height (fixed in the first tick but still boost you up a little 
if you keep holding jump during a specified tick window).

> The high (initial) jump force must be at least capable of jumping over a 
single block...

I could just keep the player in airbone (not falling) mode instead of doing a 
real variable jump height...

> There is an explaination at [Flip](#flip).

### Air Strafing
Moving in the air, with preserved `velocity` but with less or none friction.

Allowing the player to do (#camera-turns) would be cool... But 
maybe only with **high speed mode**?

### Flip
When you [#jump] in the air without **adhesion**. It is completelly relative 
to the camera. Looking up and down makes difference! It will normally add to 
`velocity`, but if `velocity.dot(wishdir)` is less than 0, it will _set_ the 
`velocity`. It's reset to `true` when you land (and in other cases as well).

> Can be used before landing and after a jump or any kind of dash to boost or 
correct a movement after it has been done!

**NOTE**: when you flip with `direction.length() < MOVE_DEADZONE`, `velocity.y` 
is set to flip force. Giving you vertical boost!

> This can be used to go up stairs very fast!

### Dash
When you [#jump] with **adhesion**. Could be **buffered** and **coyote**'d... 
It will have a special effect: locking any directional input and add a `speed` 
boost with no friction to `velocity` during a defined window. If you're not 
already moving at all, it'll go the way the character is directed to.

> We should limit dash count and reload when the player does something related 
to the combat system. Like killing an enemy or just hitting X times for each 
new dash, until a dash count limit (also variable, based on the weapon used).

### Wall Standing
When you hold **adhesion** after colliding with a wall. It reduces gravity! But 
also locks directional movement.

### Wall Sliding
Wall standing but with vectorial velocity and lower friction. You should keep 
side colliding with the wall. Else, you'll fall!

### Wall Jumping
When you **jump** while wall standing/sliding. It gives horizontal boost towards 
the side opposite to the wall and a little vertical force.

### Wall Bumping
When you hold **adhesion** and **jump** before the end of a window when crashing 
with a wall (in the front), you transfer half of the impact force to the 
vertical axis of the `velocity` before the crash. Just like a tiny **dash** but 
upwards.

### Super Dashing
When you **jump** a little bit before the end of a **dash**. Basically the force 
of a normal horizontal dash added to the vertical momentum (at the moment).

> This is the best and only way to go up by doing dashes...

### Hyper Dashing
When you **dash** at the same time you land. The greatest horizontal boost (I 
don't really know how much yet).
> Tip: you can flip down to touch the ground faster!

## Combat
### Terms
**Trigger**: press or hold `"trigger"` action.

**Fire Rate**: how many times you can **shoot** in one second.

**Fire Time**: time between each shot (`1.0` divided by **fire rate**).

**Tension**: energy causing you to shoot faster (increasing **fire rate**).

**Retake**: hold `"retake"` action.

### Shoot
Successful shot. When you **trigger** while it's not locked and you still have 
`plasma` remaining. You'll lose X amount of plasma in each shot, depending on 
the weapon being used.

### Building Tension
When you dash while holding the trigger and hit an opponent.

### Retaking
When **retaking**, you take back the **plasma** near you.
> This heals your health and reloads your _plasma tank_.

### Important Rule
You can't shoot while in **high speed mode**. You must stop or just decelerating 
down to the normal speed to be able to shoot again.

> This will make you choose what you want, since you won't do everything at the 
same time anyways.

## Game
Don't really know how to win, what the teams or players have to do...

### Showdown
Kill as much enemy team's integrals as possible.
> Main Game Mode?

>> **IMPORTANT**: for the next event, I should develop this game mode but with 
static enemies (they just shoot at you but don't move).

### Domination
Paint as much terrain as possible.

### Zones
Dominate zones for the most time.

### Flags
Capture enemy's flags, bring them to your base while protecting it (and the 
flag too as well).

### Race
A mode more based on the movement system... To finish a course before anyone. 
Moving as fast as possible.
> It should disable combat system and dash limits.
