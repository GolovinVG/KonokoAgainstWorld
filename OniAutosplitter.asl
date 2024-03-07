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
	bool endcheck : 0x1EC0C4; // check Muro kill
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

	settings.Add("KillsCount_Module", true, "Enables Konoko's foe kills cointing", null);
	settings.Add("EnableTrainingKillsCount", false, "Enables training level kills cointing", "KillsCount_Module");
	settings.Add("TimerPerLevel_Module", false, "Time strats on level load and resets on next level", null);
	
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
	vars.Core.onEnd = (Action)(() => {});
	vars.Core.onUpdateBegins = (Action)(() => {});
	vars.Core.onTimerStarted = (Action)(() => {});
	vars.Core.onUpdateEnds = (Action)(() => {}); // last chance to override standard behaviour
	vars.Core.onAiDetected = (Action<ExpandoObject>)((x) => {}); 

	vars.Core.Modules = new List<ExpandoObject>();
	vars.Core.NeedStart = false;
	vars.Core.NeedReset = false; 
	vars.Core.LevelProgress = 0; // index of where plauer plaed last continiously
	vars.Core.ActivatedModules = new List<string>(); 
	vars.Core.SwitchLevel = false;
	vars.Core.TimerPaused = true;
	vars.Core.MuroKilled = false;
}
 
init
{	
	current.TimerPaused = true; 
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
	vars.KillsCount = 0;
	current.LevelIndex = 0;

// on load weird thing is happening
// loading >>> levelId set to 0 >>> levelId set to smth
// >>> no locks but no flags (may be some, but not obvious too shoort to capture with naked eye)
// >>> cutscene locks >>> free to go
// so we capture moment of levelId change to pause timet, and unlock when normal locks available or none if loading from numbered save point
	current.potentialLoadingBlindPoint = false; 
	current.potentialLoadingBlindPointSwitch = false; 
	
	var core = vars.Core;

	dynamic mainModule = new ExpandoObject();
	core.Modules.Add(mainModule);
	mainModule.EnableTriggerName = "Main";
	mainModule.Init = (Action)(() => {
		core.onLevelProgress += (Action)(() => {
			core.RaiseSplit = true;
		});
		core.onEnd += (Action)(() => {
			core.RaiseSplit = true;
		});
		core.onUpdateBegins += (Action)(() => {
			
			if (core.Current.LevelIndex == 0 
				&& core.Current.anim == 0xC3A90FA5C48C7D82 
				&& core.Old.anim != 0xC3A90FA5C48C7D82){
				core.NeedReset = true;
				core.NeedStart = true;
				core.LevelProgress = 0;
			}

			IntPtr konokoPtr = vars.konokoPtr;
			var coord_xpow = (float)Math.Pow(core.Current.coord_x, 2);
			var coord_ypow = (float)Math.Pow(core.Current.coord_y, 2);
				
			core.Current.speed = Math.Round((Decimal)(float)Math.Sqrt(coord_xpow + coord_ypow), 2, MidpointRounding.AwayFromZero);
			core.Current.speed = (int)(core.Current.speed * 100);
			core.Current.Konoko_Speed = core.Current.speed;
			core.Current.Konoko_HP_Shield = core.Current.konoko_hp.ToString() + "/" + core.Current.konoko_shield.ToString();
			core.Current.Enemy_HP = core.Current.enemy_hp;
		});

	});

#region KillsCountModule
	dynamic killModule = new ExpandoObject();
	core.Modules.Add(killModule);
	killModule.EnableTriggerName = "KillsCount_Module";
	killModule.OnStartHandle = (Action)(() => {
		var killsperLevel = killModule.KillsPerLevel as HashSet<byte>[];
		for (var i = 0; i < killsperLevel.Length; i++)
			if (killsperLevel[i].Any())
				killsperLevel[i].Clear();
		current.KillsCount = 0; // sometimes clear lags 	
		print("Clear Kills");
		});
	killModule.OnLevelLoadHandle = (Action)(() => {
		var killsperLevel = killModule.KillsPerLevel as HashSet<byte>[];
		for (var i = core.Current.LevelIndex; i < killsperLevel.Length; i++)
				if (killsperLevel[i].Any())
					killsperLevel[i].Clear();
		
		if (core.Current.LevelIndex == 11){
			killModule.lv11fix_MuroIndex = 0;
			killModule.lv11fix_GriffinIndex = 0;
			killModule.lv11fix_GriffinDetected = false;
			killModule.lv11fix_MuroDetected = false;
		}
		current.KillsCount = killsperLevel.Sum(x => x.Count());
		print("Clear Kills after level with index " + core.Current.LevelIndex);
	});
	killModule.OnUpdateBeginsHandle = (Action)(() => {
		killModule.lv11fix_GriffinDetected = false;
		killModule.lv11fix_MuroDetected = false;
	});

	killModule.OnAiDetectedHandle = (Action<ExpandoObject>)((_ai) =>{
		var killsperLevel = killModule.KillsPerLevel as HashSet<byte>[];
		dynamic ai = _ai; 

		if (ai.Index == 0){
			killModule.KonokoFraction = ai.Fraction; // 0 - konoko, 1 - TCTF, 2 - Cynd, 3 - Civilian, 4 - guard, 5 - Rogue Konoko, 6 - ?, 7 - unagressive Cyndicate 
		}

		if ((settings["EnableTrainingKillsCount"] || core.Current.LevelIndex != 0)
			&&	ai.Hp == 0 
			&& (ai.Fraction == 2  
				|| (ai.Fraction == 1 || ai.Fraction == 4) && killModule.KonokoFraction == 5
				|| killModule.KonokoFraction == 2 && core.Current.LevelIndex == 0)) // training level fraction swap 
					killsperLevel[current.LevelIndex].Add(ai.ObjectId);
		//Muro and Griffin fix. on DD lvl the game just delete them, leaves no record with 0 hp
		if (core.Current.LevelIndex == 11){
			if (ai.Name.Equals("IntroMuro")) {
					killModule.lv11fix_MuroIndex = ai.Index;
					killModule.lv11fix_MuroDetected = true;
				}	

			if (ai.Name.Equals("griffin")){
				killModule.lv11fix_GriffinIndex = ai.Index;
				killModule.lv11fix_GriffinDetected = true;
			}
				
		}	
	});
	killModule.OnUpdateEndsHandle = (Action)(() =>{		
		var killsperLevel = killModule.KillsPerLevel as HashSet<byte>[];
		// on previous update chr was detected but now it is none
		// it's possible to have some issue with muro as it may survive till level ends, 
		// but killing him with ghost makes more potential kills later, he will drawn in acid any way
		if (core.Current.LevelIndex == 11){
			if (killModule.lv11fix_MuroDetected == false 
				&& killModule.lv11fix_MuroIndex != 0
				&& killsperLevel[core.Current.LevelIndex].Contains(killModule.lv11fix_MuroIndex) == false)
				{
					print("Muro killed by scripts ='(");
					killsperLevel[core.Current.LevelIndex].Add(killModule.lv11fix_MuroIndex);
				}
			if (killModule.lv11fix_GriffinDetected == false 
				&& killModule.lv11fix_GriffinIndex != 0
				&& killsperLevel[core.Current.LevelIndex].Contains(killModule.lv11fix_GriffinIndex) == false)
			{
				print("Griffin killed by scripts ='("); 
				killsperLevel[core.Current.LevelIndex].Add(killModule.lv11fix_GriffinIndex);
			}
		}

		current.KillsCount = killsperLevel.Sum(x => x.Count());
		vars.KillsCount = core.Current.KillsCount;
	});

	killModule.Init = (Action)(() => {
		var killsPerLevel =  new HashSet<byte>[15];
		for (var i = 0; i< killsPerLevel.Length; i++ ) killsPerLevel[i] = new HashSet<byte>();
		killModule.KillsPerLevel = killsPerLevel;
		killModule.lv11fix_MuroIndex = 0;
		killModule.lv11fix_GriffinIndex = 0;
		killModule.lv11fix_GriffinDetected = false;
		killModule.lv11fix_MuroDetected = false;
		killModule.KonokoFraction = 0;

		core.onTimerStarted += killModule.OnStartHandle;
		core.onLevelLoad += killModule.OnLevelLoadHandle;
		core.onAiDetected += killModule.OnAiDetectedHandle;
		core.onUpdateEnds += killModule.OnUpdateEndsHandle;

		core.onUpdateBegins += killModule.OnUpdateBeginsHandle;
		print(killModule.EnableTriggerName + " Activated");
	});
	killModule.Deactivate = (Action)(() => {
		core.onTimerStarted -= killModule.OnStartHandle;
		core.onLevelLoad -= killModule.OnLevelLoadHandle;
		core.onAiDetected -= killModule.OnAiDetectedHandle;
		core.onUpdateEnds -= killModule.OnUpdateEndsHandle;

		core.onUpdateBegins -= killModule.OnUpdateBeginsHandle;
		print(killModule.EnableTriggerName + " Deactivated");
	});
	
#endregion

#region PerLevelTimer
	dynamic perLevelModule = new ExpandoObject();
	core.Modules.Add(perLevelModule); 
	perLevelModule.EnableTriggerName = "TimerPerLevel_Module";
	perLevelModule.OnLevelProgressHandle = (Action)(() =>{ 
		perLevelModule.LockTimer = true;	
	});
	perLevelModule.OnEndHandle = (Action)(() =>{ 
		vars.TimerModel.Pause(); 
		perLevelModule.LockTimer = true;	
	});
	perLevelModule.OnStartHandle = (Action)(() =>{
		for (var i = 0; i < perLevelModule.CurrentRunningLevel; i++)
			vars.TimerModel.SkipSplit();
	});
	perLevelModule.OnLevelLoadHandle = (Action)(() =>{
		if (perLevelModule.CurrentRunningLevel == -1
			|| perLevelModule.CurrentRunningLevel == core.Current.LevelIndex
			|| core.Old.LevelIndex == core.Current.LevelIndex){
			if (core.Current.save_point == "" || core.Current.save_point == "Syndicate Warehouse")
			{
				perLevelModule.PreventDefaultTimerBehavior = true;
				perLevelModule.TimerHasToBeZero = true;
				perLevelModule.CurrentRunningLevel = core.Current.LevelIndex;
				perLevelModule.LoadedLevelIsNotForRun = false; 
				vars.TimerModel.Reset();
				vars.TimerModel.Start();
			}
		}
		else
		if (perLevelModule.CurrentRunningLevel != core.Current.LevelIndex) 
		{
			if (perLevelModule.LoadedLevelIsNotForRun == false){
				perLevelModule.PreventDefaultTimerBehavior = true;		
				perLevelModule.LoadedLevelIsNotForRun = true;	
				vars.TimerModel.Split(); 
				vars.TimerModel.Pause(); 
			}				
		}	
	});
	perLevelModule.OnUpdateBeginsHandle = (Action)(() => {
		perLevelModule.PreventDefaultTimerBehavior = false;
		perLevelModule.TimerHasToBeZero &= core.Current.potentialLoadingBlindPoint; 
	});
	perLevelModule.OnUpdateEndsHandle = (Action)(() => {
		if (perLevelModule.PreventDefaultTimerBehavior){
			core.RaiseSplit = false;
			core.NeedReset = false;
			core.NeedStart = false;
		}
		
		core.FreezeTime = perLevelModule.TimerHasToBeZero;
		
	});
	perLevelModule.Init = (Action)(() => {
		core.onLevelProgress += perLevelModule.OnLevelProgressHandle;
		core.onTimerStarted += perLevelModule.OnStartHandle;
		core.onLevelLoad += perLevelModule.OnLevelLoadHandle;
		core.onUpdateBegins += perLevelModule.OnUpdateBeginsHandle;
		core.onEnd += perLevelModule.OnEndHandle;
		core.onUpdateEnds += perLevelModule.OnUpdateEndsHandle;
		core.LevelProgress = 0;
		perLevelModule.PreventDefaultTimerBehavior = true;
		perLevelModule.TimerHasToBeZero = true;
		perLevelModule.LoadedLevelIsNotForRun = true; // only repeatedly loading same level cause timer to start
		perLevelModule.CurrentRunningLevel = -1;
		vars.TimerModel.Reset();
		print(perLevelModule.EnableTriggerName + " Activated");
	});
	perLevelModule.Deactivate = (Action)(() => {
		core.onLevelProgress -= perLevelModule.OnLevelProgressHandle;
		core.onTimerStarted -= perLevelModule.OnStartHandle;
		core.onLevelLoad -= perLevelModule.OnLevelLoadHandle;
		core.onUpdateBegins -= perLevelModule.OnUpdateBeginsHandle;
		core.onEnd -= perLevelModule.OnEndHandle;
		core.onUpdateEnds -= perLevelModule.OnUpdateEndsHandle;
		core.LevelProgress = 0;
		vars.TimerModel.Reset();
		print(perLevelModule.EnableTriggerName + " Deactivated");
	});
	
#endregion

#region Core 
		vars.Core.CheckPause = (Func<bool>)(() => {
			if (core.Current.LevelIndex == 0)
				return core.TrainingLevel.HelloKonoko() 
					|| vars.Core.GameShowsUnplayebleStuff()
					|| vars.Core.CutsceneIsPlaying()
					|| vars.Core.PlayerHasNoMouseControl()
					|| vars.Core.UnscippableDialogue()
					|| core.Current.potentialLoadingBlindPoint;

			
			return core.CutsceneIsPlaying()
				|| core.PlayerHasNoMouseControl()
				|| core.PlayerHasNoKeyboardControl()	
				|| core.UnscippableDialogue() 
				|| core.GamePaused()
				|| core.GameShowsUnplayebleStuff()
				|| core.Current.potentialLoadingBlindPoint;
		}); 
		vars.Core.CheckModules = (Action)(() => {
			foreach (var module in core.Modules)
			{
				var enabled = module.EnableTriggerName == "Main" || settings.ContainsKey(module.EnableTriggerName) && settings[module.EnableTriggerName]; 

				if (enabled && core.ActivatedModules.Contains(module.EnableTriggerName) == false){
					module.Init();
					core.ActivatedModules.Add(module.EnableTriggerName);
				}
				if (enabled == false && core.ActivatedModules.Contains(module.EnableTriggerName)){
					module.Deactivate();
					core.ActivatedModules.Remove(module.EnableTriggerName);
				}
			}
		});

		// _c - currentState, most likely dont lose it reference, but I chose to transfer ref to standartify approach
		// _o - old state, miss reference each update =(
		vars.Core.Update = (Action<ExpandoObject, ExpandoObject>)((_c, _o) => {
			core.CheckModules();

			core.Old = _o;
			core.Current = _c;

			if (core.onUpdateBegins != null) 
				core.onUpdateBegins();

			IntPtr konokoPtr = vars.konokoPtr;
			if (core.Current.levelId == 0){
				vars.Core.SwitchLevel = true;
				core.Current.potentialLoadingBlindPoint = true;  
				core.Current.potentialLoadingBlindPointSwitch = false;  
			}else{
				var cLevelInGameIndex = core.GetIngameLevelId();
				dynamic cLevel = core.FindLevel((byte)cLevelInGameIndex);
				core.Current.LevelIndex = cLevel.Index;
			}
			var detectedKonoko = game.ReadValue<byte>(konokoPtr + 0x14) != 0; // Konoko briefly lose her name on level loading  
			core.Current.IsLoading |= !detectedKonoko;

			
			core.Current.potentialLoadingBlindPointSwitch |= core.PlayerHasNoMouseControl();
			core.Current.potentialLoadingBlindPoint &= 
				!(core.Current.save_point == ""|| core.Current.save_point == "Syndicate Warehouse") 
				|| !core.Current.potentialLoadingBlindPointSwitch; 


			core.Current.IsLoaded = core.Current.levelId != 0 // level obtain index 
			 	&& vars.Core.SwitchLevel // recently index was 0 
				&& core.Current.IsLoading // konoko 0 info detected
				&& detectedKonoko; // but now it has value

			if (core.Current.IsLoaded){
				print("on level load");
				core.Current.IsLoading = false;
				vars.Core.SwitchLevel = false;
				if(core.onLevelLoad != null)
				{
					core.onLevelLoad(); 						
				}
			}	

			var firstChrMonitored = false;
			var oniCharsMaximumCount = 128;
			var oniCharsBlockSize = 0x16A0;
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

				if (core.onAiDetected != null){
					dynamic ai = new ExpandoObject();

					ai.Hp = hp;
					ai.Index = index;
					ai.ObjectId = objectId;
					ai.ActiveState = activeState;
					ai.Fraction = fraction;
					ai.Name = name;

					core.onAiDetected(ai);
				}

				firstChrMonitored = true;
				konokoPtr += oniCharsBlockSize	;
			}
			
 
			if (core.Current.LevelIndex - 1 == core.LevelProgress && 
				(core.Current.save_point == "" || core.Current.save_point == "Syndicate Warehouse")){ 
					core.LevelProgress = core.Current.LevelIndex;
					if (core.onLevelProgress != null){
						print("on level progress " + core.LevelProgress);
						core.onLevelProgress();
					}
				}

			var muroKilledOld = core.MuroKilled;
			core.MuroKilled |= core.Current.LevelIndex == 14 
				&& core.Current.save_point.Contains("4") 
				&& core.Current.endcheck == true;
			if (muroKilledOld != core.MuroKilled){
				core.LevelProgress = 0;
				if (core.onEnd != null){
					print("RIP MURO");
					core.onEnd();
				}
			}

			core.TimerPaused = core.CheckPause();

			if (vars.Core.TrainingLevel.HelloKonoko())
				core.FreezeTime = true;

			if (core.onUpdateEnds != null)
				core.onUpdateEnds();
		});

		vars.Core.SetStart = (Action) (() => {
			current.potentialLoadingBlindPoint = true;
			core.MuroKilled = false;
			if (core.onTimerStarted != null)
				core.onTimerStarted(); 
		});

		vars.Core.GamePaused = (Func<bool>)(() =>
			current.pausedByPlayer || current.time == 0
		);
		vars.Core.GameShowsUnplayebleStuff = (Func<bool>)(() =>
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
		print("SPLIT" + vars.Core.LevelProgress); 
		return true;
	}
}

isLoading {
	current.TimerPaused = vars.Core.TimerPaused;
	return vars.Core.TimerPaused;
} 

gameTime{
	if (vars.Core.FreezeTime)
		return TimeSpan.Zero; 
}