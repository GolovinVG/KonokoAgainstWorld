Hello! I hope you will enjoy this variant of Autospliiter scripts. I had idea to patch and extend possiblities of original script https://github.com/Barnacle/OniAutosplitter.<br>
I have in mind some features outside classic speedrun idea, but I think this script may be viable to use in common runs, you should ask in discord channel and insure that this will be valid.

# How to use
This is unofficial sripts so it cannot be automatically dowloaded by using official spits file 
1) So you have to deactivate mentioned above variant at splits configuration
<b>&lt;Left Click&gt; -&gt; Edit Splits -&gt; [Deactivate]</b>

2) You have to add custom .asl scripts module to layout as new layer
<b>&&lt;Left Click&gt; -&gt; Edit Layout -&gt; [+] -&gt; Control -&gt; Scriptable Auto Splitter</b>
scipt path should lead to downloaded OniAutosplitter.asl file from this repository

3) You may chose some mods by checking Advanced settings

# Modes
### Kills Counter
This mode writes into current state how many foes have died while we continiously running the game. That mean if level restarts or checkpoint reload allkill records that detected on levels subsequent and including current will be ereased.
Reseting and starting timer will erase all records as well.<br>
To add varibale info on layot use <b>[+] -&gt; Information -&gt; Asl Var Viewer -&gt; State:"KillsCount"</b><br>
Ai's foe status to Konoko based on [teams logic](https://wiki.oni2.net/OBD_talk:BINA/OBJC/CHAR). During gameplay process ai can change team so as your character, it may lead to kill counter glitches, you should make a bug report, I'll be very grateful! <br>
Some enemies insted of dying removed instantly from game (Muro and Griffin on Hasegawa Lab). If some special ai's death evaluation are missed by scrip you should inform me. Barabas stays at 1 hp on first encounter instead of death =)<br>

Konoko may be in her seft team "Rogue" and "Syndicate" on last part of training<br>

Known Issue! On level reloading instead of update new counter value it stucks. To fix it you may add something additional on layaut like "Hp" or "Speed". For some reason state not updating sometimes when "KillsCount" is single variable to show

### Per level timer
As it's written it allows to use timer to evaluate single level walkthrough speed. Timer will be reset on continiously reloading level from "zero" checkpoint (from cutscene). If any level will be loloaded differ from last tracked one (by hand or by normal progressing) timer will split time and pause. On last level it just pauses. If new level will be reloaded from zero checkpoint it will become new tracked level. You may also return to last tracked level instead and continue measure time cycle.<br>

This will be conflict with your classic speedrunning splits so Irecommend to make copy of splits file for such runs and not use this file as external resource to not confuse any aggregator services

# Further ideas
Some useful info "in air time", "Tric positioning help". <br>
Custom, "Cool" looking kill counter, probably without described issue. <br>
Extended debug window for development purposes. <br>
How may kills left on level.
