// 10 october 2022

state("Oni", "EN")
{
	int levelId : 0x1ED2EC;
	ulong anim : 0x1EB700; // check if it's training or not
	string20 save_point : 0x1ECC10; // "    Save Point 1"
	
	bool endcheck : 0x1EC0C4; // check Muro kill
	
	float coord_x : 0x1ECE7C, 0xB0, 0xC4;
	float coord_y : 0x1ECE7C, 0xB0, 0xCC;
	int konoko_hp : 0x236514, 0x38;
	int konoko_shield : 0x230FE8;
	int enemy_hp : 0x23a2a0, 0x38;
	
	int time : 0x2582C0;	
	bool cutscene : 0x0014D64C;
	int cutsceneSegment : 0x2364C4;
	short igtPause : 0x1ECE7C, 0x1679AC;
	int dialog : 0x236514, 0x04;
	int level : 0x1ED398;
	bool level5_endCutscene : 0x1ECE92;
}

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
	level0.LocalIndex = 0;
	level0.Name = "Training";

	dynamic level1 = new ExpandoObject();
	level1.Index = 1;
	level1.LocalIndex = 1;
	level1.Name = "Warehouse";

	dynamic level2 = new ExpandoObject();
	level2.Index = 2;
	level2.LocalIndex = 2;
	level2.Name = "Plant";

	dynamic level3 = new ExpandoObject();
	level3.Index = 3;
	level3.LocalIndex = 3;
	level3.Name = "Bio Lab";

	dynamic level4 = new ExpandoObject();
	level4.Index = 4;
	level4.LocalIndex = 4;
	level4.Name = "Airport";

	dynamic level5 = new ExpandoObject();
	level5.Index = 5;
	level5.LocalIndex = 6;
	level5.Name = "Hangars";

	dynamic level6 = new ExpandoObject();
	level6.Index = 6;
	level6.LocalIndex = 8;
	level6.Name = "Tctf I";

	dynamic level7 = new ExpandoObject();
	level7.Index = 7;
	level7.LocalIndex = 9;
	level7.Name = "Atm outter";

	dynamic level8 = new ExpandoObject();
	level8.Index = 8;
	level8.LocalIndex = 10;
	level8.Name = "Atm inner";

	dynamic level9 = new ExpandoObject();
	level9.Index = 9;
	level9.LocalIndex = 11;
	level9.Name = "State";

	dynamic level10 = new ExpandoObject();
	level10.Index = 10;
	level10.LocalIndex = 12;
	level10.Name = "Roofs";

	dynamic level11 = new ExpandoObject();
	level11.Index = 11;
	level11.LocalIndex = 13;
	level11.Name = "Dreams";

	dynamic level12 = new ExpandoObject();
	level12.Index = 12;
	level12.LocalIndex = 14;
	level12.Name = "Prison";

	dynamic level13 = new ExpandoObject();
	level13.Index = 13;
	level13.LocalIndex = 18;
	level13.Name = "Tctf II";

	dynamic level14 = new ExpandoObject();
	level14.Index = 14;
	level14.LocalIndex = 19;
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

	vars.Core.GetLevel = (Func<byte, bool, ExpandoObject>)((index, isLocal) => 
			levels.First(x => index == (isLocal 
			?((dynamic)x).LocalIndex 
			: ((dynamic)x).Index))
		);
}

init
{	
	timer.IsGameTimePaused = false;
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
	vars.konokoPtr = game.ReadPointer(page.BaseAddress + 0x00236514);

	var killsPerLevel =  new HashSet<byte>[15];
	for (var i = 0; i< killsPerLevel.Length; i++ ) killsPerLevel[i] = new HashSet<byte>();
	vars.KillsPerLevel =killsPerLevel;
	vars.lv13fix_MuroIndex = 0;
	vars.lv13fix_GriffinIndex = 0;
	current.KillsCount = 0;
	current.KillsRecords = "";
	vars.IsLoading = false;
}

update
{
	current.coord_xpow = (float)Math.Pow(current.coord_x, 2);
	current.coord_ypow = (float)Math.Pow(current.coord_y, 2);
	current.speed = Math.Round((Decimal)(float)Math.Sqrt(current.coord_xpow + current.coord_ypow), 2, MidpointRounding.AwayFromZero);
	current.speed = (int)(current.speed * 100);
	
	vars.Konoko_Speed = current.speed;
	vars.Konoko_HP_Shield = current.konoko_hp.ToString() + "/" + current.konoko_shield.ToString();
	vars.Enemy_HP = current.enemy_hp;
	

	/// Kills Counting Block 
	
	if (settings["EnableKillsCount"] == false)
		return;
	
	var page = modules.First();
    var firstChrMonitored = false;
	var oniCharsMaximumCount = 128;
	var oniCharsBlockSize = 0x16A0;
	var konokoFraction = 0;

	dynamic core = vars.Core;


	var currentLevelLocalIndex = current.levelId == 1 && current.save_point == "" ? 0 : current.levelId;

	IntPtr konokoPtr = vars.konokoPtr;
    var gameIsLoading = game.ReadValue<byte>(konokoPtr + 0x14) == 0 || current.levelId == 0;	
	var killsperLevel = vars.KillsPerLevel as HashSet<byte>[];

    if (gameIsLoading)
    {
		vars.IsLoading = true;
        return;
    }

    dynamic currentLevel = core.GetLevel((byte)currentLevelLocalIndex, true);
	int curentLevelIndex = currentLevel.Index;
	if (vars.IsLoading){
		print("postload");
		for (var i = curentLevelIndex; i < killsperLevel.Length; i++)
			if (killsperLevel[i].Any()) 
				killsperLevel[i].Clear();

		if (curentLevelIndex == 13){
			vars.lv13fix_MuroIndex = 0;
			vars.lv13fix_GriffinIndex = 0;
		}

	}
	
	vars.IsLoading = false;

	var lv13fix_MuroIndex = 0;
	var lv13fix_GriffinIndex = 0;
    for (var i = 0; i < oniCharsMaximumCount; i++)
    {
        var index = game.ReadValue<byte>(konokoPtr);
        
		if (index == 0 && firstChrMonitored){
			break;
		}

		var hp = game.ReadValue<int>(konokoPtr + 0x38);
		var objectId = game.ReadValue<byte>(konokoPtr + 0x1);		
		var activeState = game.ReadValue<byte>(konokoPtr + 0x1F0); 
		var fraction = game.ReadValue<byte>(konokoPtr + 0x12); 
		var name = game.ReadString(konokoPtr + 0x14, 10);

		if (firstChrMonitored == false){
			konokoFraction = fraction;
		}
		
		if ((settings["EnableTrainingKillsCount"] || curentLevelIndex != 0)
			&&	hp == 0 
			&& (fraction == 2 
				|| (fraction == 1 || fraction == 4) && konokoFraction == 5))
				{
					killsperLevel[curentLevelIndex].Add(objectId);
				}		
			
		//Muro and Griffin fix
		if (curentLevelIndex == 11){
			if (name.StartsWith("IntroMuro"))
			{
				vars.lv13fix_MuroIndex = index;			
				lv13fix_MuroIndex = index;	
			}		

			if (name.StartsWith("griffin"))
			{
				vars.lv13fix_GriffinIndex = index;
				lv13fix_GriffinIndex = index;
			}
		}
		firstChrMonitored = true;
        konokoPtr += oniCharsBlockSize;
    }

	if (curentLevelIndex == 11){
		if (vars.lv13fix_MuroIndex != 0 && lv13fix_MuroIndex == 0) killsperLevel[curentLevelIndex].Add(vars.lv13fix_MuroIndex);
		if (vars.lv13fix_GriffinIndex != 0 && lv13fix_GriffinIndex == 0) killsperLevel[curentLevelIndex].Add(vars.lv13fix_GriffinIndex);
	}
	current.KillsCount = killsperLevel.Take(curentLevelIndex + 1).Sum(x => x.Count());
	for	(var i = 0; i < killsperLevel.Length; i++){
		//print("" +string.Join(",", killsperLevel[i]));
	} 
}

start
{
	current.GameTime = TimeSpan.Zero;
	vars.totalGameTime = 0;
	vars.subtractTime = 0;
	vars.cutsceneTime = 0;
	vars.cutsceneTimeStamp = 0;
	vars.currentTime = 0;
	
	if (current.levelId == 1 &&
		current.save_point == "" &&
		current.anim == 0xC3A90FA5C48C7D82)
	{
		vars.split = 0;
		vars.totalGameTime = 0.01;
		vars.juststarted = true;
		vars.justsplitted = false;
		print("START");
		return true;
	}
	
	current.KillsCount = 0;
	current.KillsRecords = "";
}

split
{
	if (vars.split == 0 && current.levelId == 1) // Level 1
	{
		if (current.endcheck == true && current.anim != 0xC3A90FA5C48C7D82)
		{
			vars.split++;
			vars.justsplitted = true;
			return true;
		}
	}
	else if (
				(vars.split == 1 && current.levelId == 2) ||
				(vars.split == 2 && current.levelId == 3) ||
				(vars.split == 3 && current.levelId == 4) ||
				(vars.split == 4 && current.levelId == 6) ||
				(vars.split == 5 && current.levelId == 8) ||
				(vars.split == 6 && current.levelId == 9) ||
				(vars.split == 7 && current.levelId == 10) ||
				(vars.split == 8 && current.levelId == 11) ||
				(vars.split == 9 && current.levelId == 12) ||
				(vars.split == 10 && current.levelId == 13) ||
				(vars.split == 11 && current.levelId == 14) ||
				(vars.split == 12 && current.levelId == 18) ||
				(vars.split == 13 && current.levelId == 19)
			)
	{
		if (current.save_point == "")
		{
			vars.split++;
			vars.justsplitted = true;
			return true;
		}
	}
	else if (vars.split == 14 && current.levelId == 19 && current.save_point.Contains("4") ) // END
	{
		if (current.endcheck == true)
		{
			print("THE END");
			vars.split++; 
			return true;
		}
	}
}

reset
{
	if(vars.juststarted == false)
	{
		if (current.levelId == 1 &&
			current.save_point == "" &&
			current.anim == 0xC3A90FA5C48C7D82)
		{
			current.GameTime = TimeSpan.Zero;
			vars.totalGameTime = 0.01;
			vars.subtractTime = 0;
			vars.cutsceneTime = 0;
			vars.cutsceneTimeStamp = 0;
			vars.currentTime = 0;
			vars.juststarted = true;
			vars.justsplitted = false;			
			vars.split = 0;
			
			print("RESET");
			return true;
		}
	}
	
}

gameTime
{
	try{
		if(vars.totalGameTime > 0)
		{
			if (current.anim != 0xC3A90FA5C48C7D82)
			{
				vars.juststarted = false;
			}
			
			if(Convert.ToSingle(current.time) / 60 == 0)
			{
				vars.totalGameTime += vars.currentTime;	
				vars.totalGameTime -= vars.subtractTime;
				vars.totalGameTime -= vars.cutsceneTime;
				vars.currentTime = 0;
				vars.subtractTime = 0;
				vars.cutsceneTime = 0;
				vars.cutsceneTimeStamp = 0;			
			}
			else
			{
				vars.currentTime = Convert.ToSingle(current.time) / 60;
			}
			
			// Pause during Shinatama intro on training
			if (vars.split == 0 && vars.totalGameTime == 0.01)
			{
				if (current.igtPause == 0)
				{
					vars.subtractTime = vars.currentTime;
					return TimeSpan.FromSeconds(0);
				}
			}
			
			// Fix timer not paused between L0 and L1
			if (vars.split == 0 && vars.currentTime < 1)
			{
				vars.justsplitted = true;
			}
			
			if (current.igtPause == 0 || !current.cutscene || current.dialog == 0x1081E000 || vars.justsplitted || (current.level == 6 && !current.save_point.Contains("0") && current.level5_endCutscene))
			{
				if (vars.cutsceneTimeStamp == 0)
					vars.cutsceneTimeStamp = vars.currentTime;
					
				vars.cutsceneTime = vars.currentTime - vars.cutsceneTimeStamp;
			}
			else
			{
				vars.subtractTime += vars.cutsceneTime;
				vars.cutsceneTime = 0;
				vars.cutsceneTimeStamp = 0;
			}
			
			// Fix timer not paused somewhere between loading screen and cutscene on a new level
			if (vars.justsplitted)
			{
				if (old.igtPause == 0 && current.igtPause != 0)
					vars.justsplitted = false;
			}
			
			// print("ONI TIME " + vars.totalGameTime.ToString() + " " + vars.currentTime.ToString() + " " + vars.subtractTime.ToString() + " " + vars.cutsceneTime.ToString());
				
			return TimeSpan.FromSeconds(vars.totalGameTime + vars.currentTime - vars.subtractTime - vars.cutsceneTime);
		}
	}
	catch {}
}
