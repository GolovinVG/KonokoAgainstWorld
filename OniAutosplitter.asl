// 02/17/2024
// ver 1.1.0

state("Oni", "EN")
{
	int levelId : 0x1ED2EC;
	ulong anim : 0x1EB700; // check if it's training or not
	string20 save_point : 0x1ECC10; // "    Save Point 1"
		
	float coord_x : 0x1ECE7C, 0xB0, 0xC4;
	float coord_y : 0x1ECE7C, 0xB0, 0xCC;
	int konoko_hp : 0x236514, 0x38;
	int konoko_shield : 0x230FE8;
	int enemy_hp : 0x23a2a0, 0x38;
	
	int time : 0x2582C0; // ingame time, set 0 on manualy loading level. updates not so frequently, so ignored most times
	bool cutscene : 0x14D64C;
	int dialog : 0x236514, 0x04;
	bool level5_endCutscene : 0x1ECE92;

	//variables below have obscure meaning, so i describe what I have searched with cheat engine
	//I'm not so sure that I found out what it is, that why it often ensured by other conditions
	short igtPause : 0x1ECE7C, 0x1679AC; // My guessing it's locking player mouse but I leave original name for heritage purposes
	long keysLocked: 0x1ECE7C, 0x1679B0; // searched by console command lock_keys that often use in bsl scripts. Technicaly locked all and unlocked pause is state when game not playing
	byte deathLogo : 0x13D878; // tried to catch death screen
	byte startLogo : 0x15FD44; // tried to catch after loading logo
	bool lockedPlayerActivity : 0x1EC0C4; // most likely this flag prevents player from do anything, including call a menu
	bool pausedByPlayer: 0x1E96BC; // anu menu called including F1

	//OBSOLETE
	//int level : 0x1ED398; // conflicts with levelId and changed too late on loading process
	//int cutsceneSegment : 0x2364C4; // not used
}

//TODO need redo mem refs
state("Oni", "RU") 
{
	int levelId : 0x1E8C38;
	ulong anim : 0x1E70C4;
	string20 save_point: 0x1E8580;
	
	bool endcheck : 0x1E7A78;
	
	float coord_x : 0x1e87d4, 0xB0, 0xC4;
	float coord_y : 0x1e87d4, 0xB0, 0xCC;
	int konoko_hp : 0x231e54, 0x38;
	int konoko_shield: 0x22C928;
	int enemy_hp : 0x235be0, 0x38;
	
	int time : 0x253C00;
}

startup {
	vars.TimerModel = new TimerModel { CurrentState = timer };

	settings.Add("EnableKillsCount", true, "Enables Konoko's foe kills cointing", null);
	settings.Add("EnableTrainingKillsCount", false, "Enables training level kills cointing", "EnableKillsCount");
	settings.Add("TimerPerLevel", false, "Time strats on level load and resets on next level", null);
	
	var levels = new List<ExpandoObject>();
	var addLevel = (Action<int, int, string>)((index, igIndex, name) => {
		dynamic level = new ExpandoObject();
		level.Index = index;
		level.InGameIndex = igIndex;
		level.Name = name;
		levels.Add(level);
	});

	addLevel(0, 0, "Training");
	addLevel(1, 1, "Warehouse");
	addLevel(2, 2, "Plant");
	addLevel(3, 3, "Bio Lab");
	addLevel(4, 4, "Airport");
	addLevel(5, 6, "Hangars");
	addLevel(6, 8, "Tctf I");
	addLevel(7, 9, "Atm outter");
	addLevel(8, 10, "Atm inner");
	addLevel(9, 11, "State");
	addLevel(10, 12, "Roofs");
	addLevel(11, 13, "Dreams");
	addLevel(12, 14, "Prison");
	addLevel(13, 18, "Tctf II");
	addLevel(14, 19, "Compound");
	
	vars.Core = new ExpandoObject();

	vars.Core.Levels = levels;
	
	vars.Core.GetLevel = (Func<byte, ExpandoObject>)((index) => 
			levels.First(x => index == ((dynamic)x).Index)
		);

	vars.Core.FindLevel = (Func<byte, ExpandoObject>)((inGameIndex) => 
			levels.First(x => inGameIndex == ((dynamic)x).InGameIndex) 
		);

	vars.Core.RaiseSplit = false; 

	vars.Core.onLevelLoad = (Action)(() => {});
	vars.Core.onLevelProgress = (Action)(() => {});
	vars.Core.onUpdate = (Action)(() => {});
	vars.Core.onTimerStarted = (Action)(() => {});

	vars.Core.Modules = new List<ExpandoObject>();
	vars.Core.NeedStart = false;
	vars.Core.NeedReset = false; 
}
 
init
{	
	game.Exited += (s, e) => timer.IsGameTimePaused = true;
	current.Konoko_Speed = 0;
	current.Konoko_HP_Shield = "0/0";
	current.Enemy_HP = 0;
	
	// Detects current game version.
	if (modules.First().ModuleMemorySize == 3067904)
	{
		print("RU");
		version = "RU";
	}
	else
	{
		print("EN");
		version = "EN";
	}

	var page = modules.First();
	vars.konokoPtr = game.ReadPointer(page.BaseAddress + 0x00236514); // konoko firs in character list

	current.IsLoading = false;
	current.IsLoaded = false;
	current.KillsCount = 0;
	current.LevelIndex = -1;

// on load weird thing is happening
// loading >>> levelId set to 0 >>> levelId set to smth
// >>> no locks but no flags (may be some, but not obvious too shoort to capture with naked eye)
// >>> cutscene locks >>> free to go
// so we capture moment of levelId change to pause timet, and unlock when normal locks available or none if loading from numbered save point
	current.potentialLoadingBlindPoint = false; 
	
	var core = vars.Core;

#region KillsCountModule
	if (settings["EnableKillsCount"]){
		dynamic killModule = new ExpandoObject();
		core.Modules.Add(killModule);
		killModule.Init = (Action)(() => {
			var killsPerLevel =  new HashSet<byte>[15];
			for (var i = 0; i< killsPerLevel.Length; i++ ) killsPerLevel[i] = new HashSet<byte>();
			vars.KillsPerLevel = killsPerLevel;
			current.lv11fix_MuroIndex = 0;
			current.lv11fix_GriffinIndex = 0;

			core.onStart += (Action)(() => {
				var killsperLevel = vars.KillsPerLevel as HashSet<byte>[];
				for (var i = 0; i < killsperLevel.Length; i++)
				if (killsperLevel[i].Any())
					killsperLevel[i].Clear();
			});

			core.onUpdate += (Action)(() => {
				IntPtr konokoPtr = vars.konokoPtr;
				var firstChrMonitored = false;
				var oniCharsMaximumCount = 128;
				var oniCharsBlockSize = 0x16A0;
				var konokoFraction = 0; // 0 - konoko, 1 - TCTF, 2 - Cynd, 3 - Civilian, 4 - guard, 5 - Rogue Konoko, 6 - ?, 7 - unagressive Cyndicate
				var killsperLevel = vars.KillsPerLevel as HashSet<byte>[];

				if (current.IsLoaded){
					for (var i = current.LevelIndex; i < killsperLevel.Length; i++)
						if (killsperLevel[i].Any())
							killsperLevel[i].Clear();
					
					current.KillsCount = killsperLevel.Sum(x => x.Count());
					
				}
				else {
				
					if (current.LevelIndex == 11){
						current.lv11fix_MuroIndex = 0;
						current.lv11fix_GriffinIndex = 0;
					}

					for (var i = 0; i < oniCharsMaximumCount; i++)
					{
						var index = game.ReadValue<byte>(konokoPtr); // Chr list index, from 0 - konoko to max 128. May be gaps, the game could fill gaps.
						
						if (index == 0 && firstChrMonitored){
							konokoPtr += oniCharsBlockSize	;
							continue;
						}

						var hp = game.ReadValue<int>(konokoPtr + 0x38); // HP, yep
						var objectId = game.ReadValue<byte>(konokoPtr + 0x1); // Object ID, id qnique during 1 level session (till load/reload). It's not gurantee same id for same enemy
						var activeState = game.ReadValue<byte>(konokoPtr + 0x1F0); // 0 - dead, 1 - ready to fight, 3 - inactive
						var fraction = game.ReadValue<byte>(konokoPtr + 0x12); // see konoko fraction
						var name = game.ReadString(konokoPtr + 0x14, 10); // I think 10 is enough

						if (firstChrMonitored == false){
							konokoFraction = fraction;
						}
						
						if ((settings["EnableTrainingKillsCount"] || current.LevelIndex != 0)
							&&	hp == 0 
							&& (fraction == 2  
								|| (fraction == 1 || fraction == 4) && konokoFraction == 5
								|| konokoFraction == 2 && current.LevelIndex == 0)) // training level fraction swap 
									killsperLevel[current.LevelIndex].Add(objectId);
						//Muro and Griffin fix. on DD lvl the game just delete them, leaves no record with 0 hp 
						if (current.LevelIndex == 11){
							if (name.Equals("IntroMuro"))  
								current.lv11fix_MuroIndex = index;		

							if (name.Equals("griffin"))
								current.lv11fix_GriffinIndex = index;
						}
						firstChrMonitored = true;
						konokoPtr += oniCharsBlockSize	;
					}

					// on previous update chr was detected but now it is none
					// it's possible to have some issue with muro as it may survive till level ends, 
					// but killing him with ghost makes more potential kills later, he will drawn in acid any way
					if (current.LevelIndex == 11){
						if (old.lv11fix_MuroIndex != 0 && current.lv11fix_MuroIndex == 0)
							killsperLevel[current.LevelIndex].Add(old.lv11fix_MuroIndex);
						if (old.lv11fix_GriffinIndex != 0 && current.lv11fix_GriffinIndex == 0)
							killsperLevel[current.LevelIndex].Add(old.lv11fix_GriffinIndex);
					}

					current.KillsCount = killsperLevel.Sum(x => x.Count());
				}
			});
		});
	}
#endregion

#region PerLevelTimer
	if (settings["TimerPerLevel"]){
		dynamic perLevelModule = new ExpandoObject();
		core.Modules.Add(perLevelModule); 
		perLevelModule.Init = (Action)(() => {
			current.LevelLock = false;

			core.onLevelProgress += (Action)(() =>{
				vars.TimerModel.Pause(); 
				current.LevelLock = true;
				core.RaiseSplit = false;
			});
		
			core.onStart += (Action)(() =>{
				for (var i = 0; i < current.LevelIndex; i++)
					vars.TimerModel.SkipSplit();
			});

			core.onLevelLoad += (Action)(() =>{
				if (old.LevelIndex == -1
					|| old.LevelIndex == current.LevelIndex){
					core.NeedReset = true;
					core.NeedStart = true;
				}
			});
		});
	}
#endregion

#region Core 
		vars.Core.Update = (Action<ExpandoObject, ExpandoObject>)((_c, _o) => {
			dynamic c = _c;
			dynamic o = _o;
			
			IntPtr konokoPtr = vars.konokoPtr;
			var coord_xpow = (float)Math.Pow(c.coord_x, 2);
			var coord_ypow = (float)Math.Pow(c.coord_y, 2);
				
			c.speed = Math.Round((Decimal)(float)Math.Sqrt(coord_xpow + coord_ypow), 2, MidpointRounding.AwayFromZero);
			c.speed = (int)(c.speed * 100);
			c.Konoko_Speed = c.speed;
			c.Konoko_HP_Shield = c.konoko_hp.ToString() + "/" + c.konoko_shield.ToString();
			c.Enemy_HP = c.enemy_hp;

			if (c.levelId == 0){
				// first load or id lag 
			}else{
				var cLevelInGameIndex = core.GetIngameLevelId();
				dynamic cLevel = core.FindLevel((byte)cLevelInGameIndex);
				core.cLevel = cLevel;		
				c.LevelIndex = cLevel.Index;
			}
		 
			c.IsLoading = game.ReadValue<byte>(konokoPtr + 0x14) == 0; // Konoko briefly lose her name on level loading
			c.IsLoaded = o.IsLoaded == false 
				&& c.IsLoading == false && o.IsLoading == true; 

			if (c.IsLoaded && core.onLevelLoad != null)
				core.onLevelLoad(); 
 
			core.NeedReset = c.LevelIndex == 0 
				&& c.anim == 0xC3A90FA5C48C7D82 
				&& o.anim != 0xC3A90FA5C48C7D82;

			core.NeedStart = c.LevelIndex == 0 
				&& c.anim == 0xC3A90FA5C48C7D82 
				&& o.anim != 0xC3A90FA5C48C7D82;

			if (c.IsLoaded && o.potentialLoadingBlindPoint == false)
				c.potentialLoadingBlindPoint = true; 
			
			if (o.LevelIndex != c.LevelIndex
				&& o.LevelIndex + 1 == c.LevelIndex
				//&& (c.save_point == "" || c.save_point == "Syndicate Warehouse") 
				|| c.LevelIndex == 14 
				&& c.save_point.Contains("4") 
				&& c.endcheck == true){
						core.RaiseSplit = true;

					if (core.onLevelProgress != null)
						core.onLevelProgress();
				}

			if (core.onUpdate != null) 
				core.onUpdate();
		});

		vars.Core.SetStart = (Action) (() => {
			current.potentialLoadingBlindPoint = false;
			
			if (core.onTimerStarted != null)
				core.onTimerStarted();
		});

		vars.Core.GamePaused = (Func<bool>)(() =>
			current.pausedByPlayer || current.time == 0
		);
		vars.Core.LevelIsLoading = (Func<bool>)(() =>
			current.lockedPlayerActivity || current.deathLogo != 1 || current.startLogo != 1  || current.IsLoading);
		vars.Core.CutsceneIsPlaying = (Func<bool>)(() =>
			current.level5_endCutscene
		);
		vars.Core.PlayerHasNoMouseControl = (Func<bool>)(() => 
			current.igtPause == 0 
		);
		vars.Core.PlayerHasNoKeyboardControl = (Func<bool>)(() => 
			current.keysLocked == 0x10007 // unlock pause only 
			|| current.keysLocked == 0x10003 // lockall
		);
		vars.Core.UnscippableDialogue = (Func<bool>)(() =>
			current.dialog == 0x1081E000
		);
		
		// first level and training are same, so let introduse fake 0 index
		vars.Core.GetIngameLevelId = (Func<byte>)(() =>
			current.levelId == 1 && current.save_point == "" ? (byte)0 : (byte)current.levelId 
		);
		vars.Core.TrainingLevel = new ExpandoObject();
		vars.Core.TrainingLevel.HelloKonoko = (Func<bool>)(() =>
			current.anim == 0xC3A90FA5C48C7D82
		);

		foreach (var module in core.Modules)
		{
			((dynamic)module).Init(); 
		}
#endregion
	
}

update 
{
	vars.Core.Update(current, old);
}

start
{
	if (vars.Core.NeedStart) 
	{
		vars.Core.NeedStart = false;
		print("START");
		return true;
	}
	return false;
}

onStart{
	vars.Core.SetStart();
}

reset
{
	if (vars.Core.NeedReset) 
	{
		vars.Core.NeedReset = false;
		print("RESET");
		return true;	
	}	
}

split
{
	if (vars.Core.RaiseSplit)
	{		
		vars.Core.RaiseSplit = false;
		return true;
	}
}

isLoading {
	var  currentLevelInGameIndex = vars.Core.GetIngameLevelId(); 

    dynamic currentLevel = vars.Core.FindLevel((byte)currentLevelInGameIndex);
	if (currentLevel.Index == 0){
		if (vars.Core.TrainingLevel.HelloKonoko()
			|| vars.Core.LevelIsLoading()
			|| vars.Core.CutsceneIsPlaying()
			|| vars.Core.PlayerHasNoMouseControl()
			|| vars.Core.UnscippableDialogue())
			return true;
		current.potentialLoadingBlindPoint = false;
		return false; 
	} 
	if (vars.Core.CutsceneIsPlaying()
		
		|| vars.Core.PlayerHasNoMouseControl()
		|| vars.Core.PlayerHasNoKeyboardControl()	
		|| vars.Core.UnscippableDialogue()){ 
			current.potentialLoadingBlindPoint = false;
			return true;	
		}
	// Unconditional pause
	if (vars.Core.LevelIsLoading()|| vars.Core.GamePaused())
		return true;
	
	if (current.save_point != "" && current.save_point != "Syndicate Warehouse")
		current.potentialLoadingBlindPoint = false;

	return current.potentialLoadingBlindPoint ;

} 

gameTime{
	if (current.LevelIndex == 0) 
		if (vars.Core.TrainingLevel.HelloKonoko())
			return TimeSpan.Zero; 
}