package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;

import objects.HealthIcon;
import states.editors.ChartingState;
import flixel.util.FlxSave;
import flixel.effects.FlxFlicker;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import objects.HealthIcon;
import objects.MusicPlayer;
import objects.CoolScrollText;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	public var isFreeplayState:Bool = false;
	// public var variables:Map<String, Dynamic> = new Map();

	public var paused:Bool = false;
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	public static var selectedItem:String = '';
	public static var selectedDifficulty:String = '';
	public static var curAlbum:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<CoolScrollText>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	public static var instance:FreeplayState;

	public var bg:FlxSprite;

	public var songList:Array<String> = [];
	public var iconList:Array<String> = [];

	public var camMain:FlxCamera;
	public var camText:FlxCamera;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var player:MusicPlayer;
	var bottomText:FlxText;
	var bottomString:String;
	var bottomTextBG:FlxSprite;

	var albumCover:FlxSprite;
	var discThing:FlxSprite;

	override function create()
	{
		instance = this;
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		camMain = new FlxCamera();
		camText = new FlxCamera();
		camText.bgColor.alpha = 0;

		FlxG.cameras.reset(camMain);
		// FlxG.cameras.add(camText, false);
		FlxG.cameras.setDefaultDrawTarget(camMain, true);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (i in 0...WeekData.weeksList.length) {
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leAlbums:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leAlbums.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				addSong(song[0], i, song[1]);
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuFreeplay'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<CoolScrollText>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:CoolScrollText = new CoolScrollText(30, (100 * i) + 400, 0, songs[i].songName, true, 46);
			songText.targetY = i;
			songText.antialiasing = true;
			songText.ID = i;
			grpSongs.add(songText);

			Mods.currentModDirectory = songs[i].folder;
			songList.push(songs[i].songName);
		}
		WeekData.setDirectoryFromWeek();

		discThing = new FlxSprite(700, 240).loadGraphic(Paths.image('albums/album-disc'));
		discThing.setGraphicSize(Std.int(discThing.width * 0.5));
		discThing.updateHitbox();
		discThing.angle = 0;
		add(discThing);

		albumCover = new FlxSprite(565, 240);
		if (songs[curSelected].album == '' || songs[curSelected].album == null)
			albumCover.loadGraphic(Paths.image('albums/blank'));
		else
		{
			#if MODS_ALLOWED
			if (FileSystem.exists('assets/shared/images/albums/' + songs[curSelected].album + '.png') || FileSystem.exists(Paths.modFolders('images/albums/' + songs[curSelected].album + '.png')))
				albumCover.loadGraphic(Paths.image('albums/' + songs[curSelected].album));
			else
				albumCover.loadGraphic(Paths.image('albums/blank'));
			#else
			if (OpenFlAssets.exists(Paths.image('albums/' + songs[curSelected].album)))
				albumCover.loadGraphic(Paths.image('albums/' + songs[curSelected].album));
			else
				albumCover.loadGraphic(Paths.image('albums/blank'));
			#end
		}
		albumCover.setGraphicSize(Std.int(albumCover.width * 0.5));
		albumCover.updateHitbox();
		add(albumCover);

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		// scoreText.cameras = [camText];

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		// scoreBG.cameras = [camText];
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		// diffText.cameras = [camText];
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		var swag:Alphabet = new Alphabet(1, 0, "swag");

		bottomTextBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomTextBG.alpha = 0.6;
		// bottomTextBG.cameras = [camText];
		add(bottomTextBG);

		#if PRELOAD_ALL
		var leText:String = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 16;
		#else
		var leText:String = "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 18;
		#end
		bottomString = leText;
		bottomText = new FlxText(bottomTextBG.x, bottomTextBG.y + 4, FlxG.width, bottomString, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		// bottomText.cameras = [camText];
		add(bottomText);

		player = new MusicPlayer(this);
		// player.cameras = [camText];
		add(player);
		
		changeSelection();
		reloadAlbumCover();
		super.create();
	}

	override function closeSubState() {
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, album:String)
	{
		songs.push(new SongMetadata(songName, weekNum, album));
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, FlxMath.bound(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}
		
		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		if (!player.playingMusic)
		{
			scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
			positionHighscore();

			var shiftMult:Int = 1;
			if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;
	
				player.playingMusic = false;
				player.switchPlayMusic();
	
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound, {volume: 1}, 2);
				discThing.angle = 0;
			}
			else
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				if (player.playingMusic) {
					discThing.angle += 0.2;
				}

				// updateTexts(elapsed);
				super.update(elapsed);
				
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, 'bf'));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		// updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length-1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + lastDifficultyName.toUpperCase() + ' >';
		else
			diffText.text = lastDifficultyName.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var lastList:Array<String> = Difficulty.list;
		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var bulltrash:Int = 0;

		for (item in grpSongs.members)
		{
			item.targetY = bulltrash - curSelected;
			bulltrash++;
	
			item.alpha = 0.5;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !lastList.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
		reloadAlbumCover();
		selectedItem = songs[curSelected].songName;
		curAlbum = songs[curSelected].album;
		selectedDifficulty = Difficulty.getString(curDifficulty);
	}

	inline private function _updateSongLastDifficulty()
	{
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty);
	}

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}


	function reloadAlbumCover() {
		if (songs[curSelected].album == '' || songs[curSelected].album == null)
			albumCover.loadGraphic(Paths.image('albums/blank'));
		else
		{
			#if MODS_ALLOWED
			if (FileSystem.exists('assets/shared/images/albums/' + songs[curSelected].album + '.png') || FileSystem.exists(Paths.modFolders('images/albums/' + songs[curSelected].album + '.png')))
				albumCover.loadGraphic(Paths.image('albums/' + songs[curSelected].album));
			else
				albumCover.loadGraphic(Paths.image('albums/blank'));
			#else
			if (OpenFlAssets.exists(Paths.image('albums/' + songs[curSelected].album)))
				albumCover.loadGraphic(Paths.image('albums/' + songs[curSelected].album));
			else
				albumCover.loadGraphic(Paths.image('albums/blank'));
			#end
		}
		albumCover.setGraphicSize(350);
		albumCover.updateHitbox();
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		return pressed;
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var album:String = "";
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, album:String)
	{
		this.songName = song;
		this.week = week;
		this.album = album;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}