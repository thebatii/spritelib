module spritelib.window;

private import std.datetime;
private import std.math;
private import std.string;
private import std.traits;

private import dchip.all;

private import derelict.sfml2.graphics;
private import derelict.sfml2.system;
private import derelict.sfml2.window;

private import spritelib.scene;
private import spritelib.util;

struct TimerEvent
{
	float duration;
	float delegate(float) handler;
}

private auto updateTimer(ref TimerEvent timerEvent, float elapsed)
{
	if(elapsed >= timerEvent.duration) {
		auto timerElapsed = (timerEvent.duration == 0.0 ? elapsed : elapsed - timerEvent.duration);
		timerEvent.duration = timerEvent.handler(timerElapsed);
		return timerEvent.duration >= 0.0;
	} else {
		timerEvent.duration -= elapsed;
		return true;
	}
}

class Window
{
	mixin SFML2Wrapper!"renderWindow";
	@property bool isOpen() { return sfRenderWindow_isOpen(_renderWindow) == 1; }
	private StopWatch _timer;
	private SceneGraph _scene;
	@property SceneGraph scene() pure @safe nothrow { return _scene; }
	@property void scene(SceneGraph s) @safe nothrow { _scene = s; }
	private Event _front;
	private Color _clearColor;
	@property Color clearColor() pure @safe nothrow { return _clearColor; }
	@property void clearColor(Color c) @safe nothrow { _clearColor = c; }
	private bool _isInitialized = false;
	private TimerEvent[] _timers;
	private TimerEvent[string] _namedTimers;
	
	this(int width, int height, string title)
	{
		_renderWindow = sfRenderWindow_create(sfVideoMode(width, height), toStringz(title), sfDefaultStyle, null);
		_clearColor = sfWhite;
		_scene = new SceneGraph();
		sfRenderWindow_setFramerateLimit(_renderWindow, 60);
	}
	@property Event front()
	{
		if(_isInitialized) {
			return _front;
		}
		this.popFront();
		_isInitialized = true;
		return _front;
	}
	@property bool empty() { return sfRenderWindow_isOpen(_renderWindow) != 1; }
	private bool getNextEvent()
	{
		cpFloat elapsed;
		if(!_timer.running()) {
			_timer.start();
			elapsed = 0;
		}
		if(sfRenderWindow_pollEvent(_renderWindow, &_front)) {
			return true;
		}
		if(elapsed != 0) {
			_timer.stop();
			elapsed = _timer.peek().to!("seconds", cpFloat)();
			_timer.reset();
			_timer.start();
			TimerEvent[] newTimerEvents;
			foreach(timerEvent; _timers) {
				if(elapsed >= timerEvent.duration) {
					auto timerElapsed = (timerEvent.duration == 0.0 ? elapsed : elapsed - timerEvent.duration);
					auto newDuration = timerEvent.handler(timerElapsed);
					if(newDuration >= 0.0) {
						newTimerEvents ~= TimerEvent(newDuration, timerEvent.handler);
					}
				} else {
					timerEvent.duration -= elapsed;
					newTimerEvents ~= timerEvent;
				}
			}
			_timers = newTimerEvents;
			foreach(key; _namedTimers.keys) {
				if(!updateTimer(_namedTimers[key], elapsed)) {
					_namedTimers.remove(key);
				}
			}
			cpSpaceStep(_scene.physics(), elapsed);
			_scene.update(elapsed);
		}
		this.render();
		return false;
	}
	private auto newTimer(T)(float duration, T handler) if(isCallable!T)
	{
		static if(is(T == float delegate(float))) {
			return TimerEvent(duration, handler);
		}
		static if(ParameterTypeTuple!(T).length == 1 && is(ParameterTypeTuple!(T)[0] == float)) {
			static if(is(ReturnType!T == void)) {
				return TimerEvent(duration, (float e) { handler(e); return -1.0; });
			}
			static if(is(ReturnType!T == bool)) {
				return TimerEvent(duration, (float e) { if(handler(e)) return duration; return -1.0; });
			}
			static if(is(ReturnType!T == float)) {
				return TimerEvent(duration, handler);
			} else {
				static assert(false, "Invalid handler type. Must return either a float, void, or bool value.");
			}
		}
		static if(ParameterTypeTuple!(T).length == 0) {
			static if(is(ReturnType!T == void)) {
				return TimerEvent(duration, (float e) { handler(); return -1.0f; });
			}
			static if(is(ReturnType!T == bool)) {
				return TimerEvent(duration, (float e) { if(handler()) return duration; return -1.0f; });
			}
			static if(is(ReturnType!T == float)) {
				return TimerEvent(duration, (float e) { return handler(); });
			} else {
				static assert(false, "Invalid handler type "~T.stringof~". Must return either a float, void, or bool value. Has return type "~(ReturnType!T).stringof);
			}
		} else {
			static assert(false, "Invalid handler type. Must have return type of void, float or bool and take no parameters or 1 float parameter!");
		}		
	}
	auto addTimer(T)(float duration, T handler) if(isCallable!T)
	{
		static if(is(T == float delegate(float))) {
			_timers ~= TimerEvent(duration, handler);
		} else static if(ParameterTypeTuple!(T).length == 1 && is(ParameterTypeTuple!(T)[0] == float)) {
			static if(is(ReturnType!T == void)) {
				_timers ~= TimerEvent(duration, (float e) { handler(e); return -1.0; });
			} static if(is(ReturnType!T == bool)) {
				_timers ~= TimerEvent(duration, (float e) { if(handler(e)) return duration; return -1.0; });
			} else static if(is(ReturnType!T == float)) {
				_timers ~= TimerEvent(duration, handler);
			} else {
				static assert(false, "Invalid handler type. Must return either a float, void, or bool value.");
			}
		} else static if(ParameterTypeTuple!(T).length == 0) {
			static if(is(ReturnType!T == void)) {
				_timers ~= TimerEvent(duration, (float e) { handler(); return -1.0f; });
			} else static if(is(ReturnType!T == bool)) {
				_timers ~= TimerEvent(duration, (float e) { if(handler()) return duration; return -1.0f; });
			} else static if(is(ReturnType!T == float)) {
				_timers ~= TimerEvent(duration, (float e) { return handler(); });
			} else {
				static assert(false, "Invalid handler type "~T.stringof~". Must return either a float, void, or bool value. Has return type "~(ReturnType!T).stringof);
			}
		} else {
			static assert(false, "Invalid handler type. Must have return type of void, float or bool and take no parameters or 1 float parameter!");
		}
		return _timers.length-1;
	}
	auto addTimer(T)(string name, float duration, T handler) if(isCallable!T)
	{
		_namedTimers[name] = newTimer(duration, handler);
	}
	void removeTimer(string name)
	{
		_namedTimers.remove(name);
	}
	void render()
	{
		sfRenderWindow_clear(_renderWindow, _clearColor);
		_scene.draw(this, null);
		sfRenderWindow_display(_renderWindow);
	}
	void popFront()
	{
		while(!getNextEvent()) {
			if(!isOpen) {
				return;
			}
		}
	}
	void close()
	{
		sfRenderWindow_close(_renderWindow);
	}
}