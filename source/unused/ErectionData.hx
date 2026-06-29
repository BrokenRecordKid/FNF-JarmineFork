package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;

typedef ErectionFile =
{
	// JSON variables
	var songsErect:Array<Dynamic>;
	var erectionCharacters:Array<String>;
	var erectionBackground:String;
	var erectionBefore:String;
	var storyNameErect:String;
	var erectionName:String;
	var startUnlockedErect:Bool;
	var hiddenUntilUnlockedErect:Bool;
	var hideStoryModeErect:Bool;
	var hideFreeplayErect:Bool;
	var difficultiesErect:String;
}

class ErectionData {
	public static var erectionsLoaded:Map<String, ErectionData> = new Map<String, ErectionData>();
	public static var erectionsList:Array<String> = [];
	public var erectionFolder:String = '';

	// JSON variables
	public var songsErect:Array<Dynamic>;
	public var erectionCharacters:Array<String>;
	public var erectionBackground:String;
	public var erectionBefore:String;
	public var storyNameErect:String;
	public var erectionName:String;
	public var startUnlockedErect:Bool;
	public var hiddenUntilUnlockedErect:Bool;
	public var hideStoryModeErect:Bool;
	public var hideFreeplayErect:Bool;
	public var difficultiesErect:String;

	public var erectionFileName:String;

	public static function createErectionFile():ErectionFile {
		var erectionFile:ErectionFile = {
			songsErect: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			erectionCharacters: ['dad', 'bf', 'gf'],
			#else
			erectionCharacters: ['bf', 'bf', 'gf'],
			#end
			erectionBackground: 'stage',
			erectionBefore: 'tutorial',
			storyNameErect: 'Your New Week',
			startUnlockedErect: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlockedErect: false,
			hideStoryModeErect: false,
			hideFreeplayErect: false,
			difficultiesErect: ''
		};
		return erectionFile;
	}

	public function new(erectionFile:ErectionFile, erectionFileName:String) {
		// here ya go - MiguelItsOut
		for (field in Reflect.fields(erectionFile))
			if(Reflect.fields(this).contains(field)) // Reflect.hasField() won't fucking work :/
				Reflect.setProperty(this, field, Reflect.getProperty(erectionFile, field));

		this.erectionFileName = erectionFileName;
	}

	public static function reloadErectionFiles(isStoryMode:Null<Bool> = false)
	{
		erectionsList = [];
		erectionsLoaded.clear();
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('erections/erectionsList.txt'));
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = directories[j] + 'erections/' + sexList[i] + '.json';
				if(!erectionsLoaded.exists(sexList[i])) {
					var erection:ErectionFile = getErectionFile(fileToCheck);
					if(erection != null) {
						var erectionFile:ErectionData = new ErectionData(erection, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							erectionFile.erectionFolder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(erectionFile != null && (isStoryMode == null || (isStoryMode && !erectionFile.hideStoryMode) || (!isStoryMode && !erectionFile.hideFreeplay))) {
							erectionsLoaded.set(sexList[i], erectionFile);
							erectionsList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i] + 'erections/';
			if(FileSystem.exists(directory)) {
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'erectionsList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}
		#end
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if(!erectionsLoaded.exists(weekToCheck))
		{
			var erection:ErectionFile = getErectionFile(path);
			if(erection != null)
			{
				var erectionFile:ErectionData = new ErectionData(erection, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					erectionFile.erectionFolder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if((PlayState.isStoryMode && !erectionFile.hideStoryMode) || (!PlayState.isStoryMode && !erectionFile.hideFreeplay))
				{
					erectionsLoaded.set(weekToCheck, erectionFile);
					erectionsList.push(weekToCheck);
				}
			}
		}
	}

	private static function getErectionFile(path:String):ErectionFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast tjson.TJSON.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function geterectionFileName():String {
		return erectionsList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():ErectionData {
		return erectionsLoaded.get(erectionsList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:ErectionData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.erectionFolder != null && data.erectionFolder.length > 0) {
			Mods.currentModDirectory = data.erectionFolder;
		}
	}
}
