// 02/17/2024
// ver 1.0.0

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
	vars.juststarted = false;
	vars.split = 0;

	settings.Add("EnableKillsCount", true, "Enables Konoko's foe kills cointing", null);
	settings.Add("EnableTrainingKillsCount", false, "Enables training level kills cointing", "EnableKillsCount");
	
	dynamic level0 = new ExpandoObject();
	level0.Index = 0;
	level0.InGameIndex = 0;
	level0.Name = "Training";

	dynamic level1 = new ExpandoObject();
	level1.Index = 1;
	level1.InGameIndex = 1;
	level1.Name = "Warehouse";

	dynamic level2 = new ExpandoObject();
	level2.Index = 2;
	level2.InGameIndex = 2;
	level2.Name = "Plant";

	dynamic level3 = new ExpandoObject();
	level3.Index = 3;
	level3.InGameIndex = 3;
	level3.Name = "Bio Lab";

	dynamic level4 = new ExpandoObject();
	level4.Index = 4;
	level4.InGameIndex = 4;
	level4.Name = "Airport";

	dynamic level5 = new ExpandoObject();
	level5.Index = 5;
	level5.InGameIndex = 6;
	level5.Name = "Hangars";

	dynamic level6 = new ExpandoObject();
	level6.Index = 6;
	level6.InGameIndex = 8;
	level6.Name = "Tctf I";

	dynamic level7 = new ExpandoObject();
	level7.Index = 7;
	level7.InGameIndex = 9;
	level7.Name = "Atm outter";

	dynamic level8 = new ExpandoObject();
	level8.Index = 8;
	level8.InGameIndex = 10;
	level8.Name = "Atm inner";

	dynamic level9 = new ExpandoObject();
	level9.Index = 9;
	level9.InGameIndex = 11;
	level9.Name = "State";

	dynamic level10 = new ExpandoObject();
	level10.Index = 10;
	level10.InGameIndex = 12;
	level10.Name = "Roofs";

	dynamic level11 = new ExpandoObject();
	level11.Index = 11;
	level11.InGameIndex = 13;
	level11.Name = "Dreams";

	dynamic level12 = new ExpandoObject();
	level12.Index = 12;
	level12.InGameIndex = 14;
	level12.Name = "Prison";

	dynamic level13 = new ExpandoObject();
	level13.Index = 13;
	level13.InGameIndex = 18;
	level13.Name = "Tctf II";

	dynamic level14 = new ExpandoObject();
	level14.Index = 14;
	level14.InGameIndex = 19;
	level14.Name = "Compound";

	vars.Core = new ExpandoObject();

	var levels = new List<ExpandoObject>();
	vars.Core.Levels = levels;
	
	levels.Add(level0);
	levels.Add(level1);
	levels.Add(level2);
	levels.Add(level3);
	levels.Add(level4);
	levels.Add(level5);
	levels.Add(level6);
	levels.Add(level7);
	levels.Add(level8);
	levels.Add(level9);
	levels.Add(level10);
	levels.Add(level11);
	levels.Add(level12);
	levels.Add(level13);
	levels.Add(level14);

	vars.Core.GetLevel = (Func<byte, ExpandoObject>)((index) => 
			levels.First(x => index == ((dynamic)x).Index)
		);

	vars.Core.FindLevel = (Func<byte, ExpandoObject>)((inGameIndex) => 
			levels.First(x => inGameIndex == ((dynamic)x).InGameIndex) 
		);
}
 
init
{	
	game.Exited += (s, e) => timer.IsGameTimePaused = true;
	vars.Konoko_Speed = 0;
	vars.Konoko_HP_Shield = "0/0";
	vars.Enemy_HP = 0;
	
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
	current.LevelIndex = 0;
	current.split = 0;
	current.dbg_isLoading = 0;
	current.dbg_update = 0;

// on load weird thing is happening
// loading >>> levelId set to 0 >>> levelId set to smth
// >>> no locks but no flags (may be some, but not obvious too shoort to capture with naked eye)
// >>> cutscene locks >>> free to go
// so we capture moment of levelId change to pause timet, and unlock when normal locks available or none if loading from numbered save point
	current.potentialLoadingBlindPoint = false; 

	var killsPerLevel =  new HashSet<byte>[15];
	for (var i = 0; i< killsPerLevel.Length; i++ ) killsPerLevel[i] = new HashSet<byte>();
	vars.KillsPerLevel = killsPerLevel;
	current.lv11fix_MuroIndex = 0;
	current.lv11fix_GriffinIndex = 0;
	
	vars.Core.GamePaused = (Func<bool>)(() =>
		current.pausedByPlayer || current.time == 0
	);
	vars.Core.LevelIsLoading = (Func<bool>)(() =>
		current.lockedPlayerActivity || current.deathLogo != 1|| current.startLogo != 1  || current.IsLoading);
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
}

update 
{
	dynamic core = vars.Core;
	IntPtr konokoPtr = vars.konokoPtr;

	var coord_xpow = (float)Math.Pow(current.coord_x, 2);
	var coord_ypow = (float)Math.Pow(current.coord_y, 2);
	current.speed = Math.Round((Decimal)(float)Math.Sqrt(coord_xpow + coord_ypow), 2, MidpointRounding.AwayFromZero);
	current.speed = (int)(current.speed * 100);
	
	vars.Konoko_Speed = current.speed;
	vars.Konoko_HP_Shield = current.konoko_hp.ToString() + "/" + current.konoko_shield.ToString();
	vars.Enemy_HP = current.enemy_hp;

	var currentLevelInGameIndex = current.levelId == 1 && current.save_point == "" ? 0 : current.levelId;

    dynamic currentLevel = core.FindLevel((byte)currentLevelInGameIndex);
	int curentLevelIndex = currentLevel.Index;
	current.LevelIndex = curentLevelIndex;
	
	current.IsLoading = game.ReadValue<byte>(konokoPtr + 0x14) == 0; // Konoko briefly lose her name on level loading
	current.IsLoaded = old.IsLoaded == false && (current.LevelIndex != old.LevelIndex && current.LevelIndex != 0
		|| (current.LevelIndex == 0 && current.save_point == "" &&
			current.anim == 0xC3A90FA5C48C7D82)); 

	if (current.IsLoaded && old.potentialLoadingBlindPoint == false)
		current.potentialLoadingBlindPoint = true; 

	/// Kills Counting Block  
	if (settings["EnableKillsCount"] == false) 
		return; 
	
	var page = modules.First();
    var firstChrMonitored = false;
	var oniCharsMaximumCount = 128;
	var oniCharsBlockSize = 0x16A0;
	var konokoFraction = 0; // 0 - konoko, 1 - TCTF, 2 - Cynd, 3 - Civilian, 4 - guard, 5 - Rogue Konoko, 6 - ?, 7 - unagressive Cyndicate
	var killsperLevel = vars.KillsPerLevel as HashSet<byte>[];

	if (current.IsLoaded){
		for (var i = curentLevelIndex; i < killsperLevel.Length; i++)
			if (killsperLevel[i].Any())
				killsperLevel[i].Clear();
		
		current.KillsCount = killsperLevel.Sum(x => x.Count());
		return;
	}
	
	if (curentLevelIndex == 11){
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
		
		if ((settings["EnableTrainingKillsCount"] || curentLevelIndex != 0)
			&&	hp == 0 
			&& (fraction == 2  
				|| (fraction == 1 || fraction == 4) && konokoFraction == 5
				|| konokoFraction == 2 && curentLevelIndex == 0)) // training level fraction swap 
					killsperLevel[curentLevelIndex].Add(objectId);

		//Muro and Griffin fix. on DD lvl the game just delete them, leaves no record with 0 hp 
		if (curentLevelIndex == 11){
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
	if (curentLevelIndex == 11){
		if (old.lv11fix_MuroIndex != 0 && current.lv11fix_MuroIndex == 0)
			killsperLevel[curentLevelIndex].Add(old.lv11fix_MuroIndex);
		if (old.lv11fix_GriffinIndex != 0 && current.lv11fix_GriffinIndex == 0)
			killsperLevel[curentLevelIndex].Add(old.lv11fix_GriffinIndex);
	}

	current.KillsCount = killsperLevel.Sum(x => x.Count());
}

start
{
	if (current.levelId == 1 &&
		current.save_point == "" &&
		current.anim == 0xC3A90FA5C48C7D82 && (
			old.levelId != 1 ||
			old.save_point != "" ||
			old.anim != 0xC3A90FA5C48C7D82
		))
	{
		print("START");
		return true;
	}
	return false;
}

onStart{
	current.split = 0;
	current.potentialLoadingBlindPoint = false;
	var killsperLevel = vars.KillsPerLevel as HashSet<byte>[];
	for (var i = 0; i < killsperLevel.Length; i++)
			if (killsperLevel[i].Any())
				killsperLevel[i].Clear();
}

reset
{
	if (current.levelId == 1 &&
		current.save_point == "" &&
		current.anim == 0xC3A90FA5C48C7D82 && (
			old.levelId != 1 ||
			old.save_point != "" ||
			old.anim != 0xC3A90FA5C48C7D82
		)) 
	{
		print("RESET");
		return true;	
	}	
}

split
{
	if (old.LevelIndex == 0 && current.LevelIndex != 0 
		&& current.split + 1 == current.LevelIndex 
		&& (current.save_point == "" || current.save_point == "Syndicate Warehouse") 
		|| current.LevelIndex == 14 
		&& current.save_point.Contains("4") 
		&& current.endcheck == true)
	{
		current.split++;
		print("Split");
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
	// no extra milliseconds on start
	var  currentLevelInGameIndex = vars.Core.GetIngameLevelId(); 
    dynamic currentLevel = vars.Core.FindLevel((byte)currentLevelInGameIndex);
	if (currentLevel.Index == 0) 
		if (vars.Core.TrainingLevel.HelloKonoko())
			return TimeSpan.Zero; 
}