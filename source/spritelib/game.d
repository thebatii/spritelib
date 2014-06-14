module spritelib.game;

private import std.string;

public import dchip.all;

private import derelict.sfml2.audio;
public import derelict.sfml2.graphics;
public import derelict.sfml2.system;
public import derelict.sfml2.window;

public import spritelib.file;
public import spritelib.physics;
public import spritelib.scene;
private import spritelib.sound;
public import spritelib.sprite;
public import spritelib.spritenode;
public import spritelib.util;
private import spritelib.window;

static this()
{
	DerelictSFML2System.load();
	DerelictSFML2Window.load();
	DerelictSFML2Graphics.load();
	DerelictSFML2Audio.load();
}

class GameEngine
{
	private static GameEngine _instance;
	private Window _window;
	@property Window window() pure @safe nothrow { return _window; }
	private SoundManager _sound;
	@property ref SoundManager sound() pure @safe nothrow { return _sound; }
	
	public static GameEngine instance()
	{
		if(_instance is null) {
			_instance = new GameEngine();
		}
		return _instance;
	}
	
	protected this()
	{
		_sound.output = sfSound_create();
	}
	void initializeWindow(int width, int height, string title)
	{
		_window = new Window(width, height, title);
	}
	mixin Resource!(Texture, "texture");
	mixin Resource!(Animation, "animation");
	void loop(void delegate(Event) eventHandler)
	{
		foreach(event; window) {
			eventHandler(event);
		}
	}
}

auto addSpriteAnimation(SceneGraph scene, SpriteNode node, string animation)
{
	auto anim = spriteNodeAnimation(node, GameEngine.instance.animation(animation));
	scene.addAnimation(anim);
	return anim;
}
auto loadTexture(string file, string name)
{
	auto texture = new Texture(file);
	GameEngine.instance.texture(texture, name);
	return texture;
}
mixin template Resource(T, string name)
{
	mixin(format(q{
				T[string] _%s;
				T %s(string name)
				{
					return _%s[name];
				}
				void %s(T resource, string name)
				{
					_%s[name] = resource;
				}
	}, name, name, name, name, name));
}