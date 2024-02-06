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
		// print(modules.First().ModuleMemorySize.ToString()); // 3092480
		print("EN");
		version = "EN";
	}

	var page = modules.First();
	vars.konokoPtr = game.ReadPointer(page.BaseAddress + 0x00236514);
	vars.Ais = new Dictionary<byte, Tuple<byte, int, byte, byte, byte>>();
	vars.KillsPerLevel = new Dictionary<byte, HashSet<byte>>();
	current.KillsCount = 0;
	current.KillsRecords = "";
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
	
	IntPtr konokoPtr = vars.konokoPtr;
    var gameIsLoading = game.ReadValue<byte>(konokoPtr + 0x14) == 0;	
	
	var page = modules.First();
    var levelId2 = game.ReadValue<byte>(page.BaseAddress + 0x1ED398);
	
	var ais = vars.Ais as Dictionary<byte, Tuple<byte, int, byte, byte, byte>>;
    if (gameIsLoading)
    {
		ais.Clear();
        return;
    }
	
	byte index = 0;
    var isMainChar = true;

	var oniCharsMaximumCount = 128;
	var oniCharsBlockSize = 0x16A0;
	var aiChecked = new byte[oniCharsMaximumCount];
    var aiFoundedCount = 0;

	var killsperLevel = vars.KillsPerLevel as Dictionary<byte, HashSet<byte>>;

    for (var i = 0; i < aiChecked.Length; i++)
    {
        index = game.ReadValue<byte>(konokoPtr);
        
        if (index > 0 || isMainChar)
        {
            var hp = game.ReadValue<int>(konokoPtr + 0x38);
            var objectId = game.ReadValue<byte>(konokoPtr + 0x1);
            aiChecked[aiFoundedCount] = objectId;
            aiFoundedCount++;
            
            var activeState = game.ReadValue<byte>(konokoPtr + 0x1F0); 
            var fraction = game.ReadValue<byte>(konokoPtr + 0x12); 
            
			if (ais.Any() == false)
			{
				foreach (var level in killsperLevel.Keys.Where(x => x >= levelId2).ToArray())
				{
					killsperLevel.Remove(level);
				}
			}

			if (ais.ContainsKey(objectId) == false)
				ais.Add(objectId, Tuple.Create(index, hp, activeState, fraction, levelId2));

			if ((settings["EnableTrainingKillsCount"] || current.levelId != 1 || current.save_point != "")
			&&	hp == 0  && activeState == 0 
			&& (fraction == 2 
				|| (fraction == 1 || fraction == 4) && ais.First(x => x.Value.Item1 == 0).Value.Item4 == 5))
				{
					if (killsperLevel.ContainsKey(levelId2) == false)
						killsperLevel.Add(levelId2, new HashSet<byte>());
					killsperLevel[levelId2].Add(objectId);
				}

        }
        konokoPtr += oniCharsBlockSize;

        isMainChar = false;

    }
	current.KillsCount = killsperLevel.Sum(x => x.Value.Count);
	current.KillsRecords = String.Join(", ", killsperLevel.Select(x => string.Format("{0}:{1}", x.Key, x.Value.Count())));   
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
