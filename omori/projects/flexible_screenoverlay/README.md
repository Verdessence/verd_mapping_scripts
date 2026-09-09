# Flexible Screenoverlay
> [!WARNING]
> This project was created with the assistance of Gemini 3.1 Pro.

> [!NOTE]
> Tested only in singleplayer. Multiplayer capability unknown

Wrapper for screenoverlay that allows to reuse, go back, skip frames, or customize frames

## Configuration
### `PlayAnim(anim_name, i_forceFps = null, b_isLoop = false)`
```
anim_type (string)  // parent type for anim_name, mostly for organization
anim_name (string)  // child type containing the frames, and the material path
i_forceFps (int)    // override the anim_name's referred fps to this one
b_isLoop (bool)     // is loop or not

```

### `StopAnim(anim_type, anim_name)`
```
anim_type (string)  // parent type for anim_name, mostly for organization
anim_name (string)  // child type containing the frames, and the material path
```

## Prerequisite
You will need a separate file to contain the anim_name and anim_type (in this case, it is stored in [screenoverlay_repo.nut](screenoverlay_repo.nut)), and you need to specify the order the frames should display, in which [cutscene_gen.py](cutscene_gen.py) will assist with it, alongside generating multiple vmts specifying each frame.

## Technical stuff
### General Function
playanim is step one initializing the table from animlib, before storing the info into currentanim as a table, which is then iteratively sequenced by sequenceanim checking for the t_seq boundaries, calculating the framerate as its delay, before rendering it to player. if the array isn't done yet it repeats until its finished. stopanim just stops the sequence and cleans

### Why generate multiple VMTs for each frame?
i tried using material modify control to control the frames beforehand, but it didn't work, probably due to gemini's incompetence and my incompetence at that time. might do a redo when i get to it especially after the font renderer project, to which i can blame more on gemini with it lol
