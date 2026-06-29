--created with Super_Hugo's Stage Editor v1.6.3

function onCreate()

	if songName == 'Doofus' then
		makeAnimatedLuaSprite('sprite', 'Sprite_Boxer_Background', 1085, 350) -- change the X and Y to a number
   		addAnimationByPrefix('sprite', 'beat', 'SPRITE_BOUNCE0', 24, false) -- change animation to a anim from XML
    	addLuaSprite('sprite', false)
		setProperty('sprite.flipX', true)
	end
end

function onStepHit()
    if curStep % 8 == 0 then
        objectPlayAnimation('sprite', 'beat', false)
    end
end