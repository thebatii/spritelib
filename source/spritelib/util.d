module spritelib.util;

private import std.range;
private import std.traits;

private import derelict.sfml2.graphics;
private import derelict.sfml2.system;
private import derelict.sfml2.window;

alias sfRenderStates* RenderStates;
alias sfEvent Event;

struct Color
{
	mixin SFML2StructWrapper!(Color, sfColor);
	
	this(ubyte r, ubyte g, ubyte b, ubyte a=255)
	{
		data = sfColor(r, g, b, a);
	}
	this(sfColor c) { data = c; }
}
struct ClipRect
{
	mixin SFML2StructWrapper!(ClipRect, sfIntRect);
	
	this(int l, int t, int w, int h)
	{
		data = sfIntRect(l, t, w, h);
	}
	this(sfIntRect r)
	{
		data = r;
	}
}
template SFML2StructWrapper(Wrapper, S)
{
	S data;
	alias data this;
	
	const int opCmp(Wrapper d) const
	{
		auto d1 = [data.tupleof];
		auto d2 = [d.data.tupleof];
		for(size_t i=0; i<d1.length; ++i) {
			if(d1[i] != d2[i]) {
				return d1[i] > d2[i] ? 1 : -1;
			}
		}
		return 0;
	}
}
struct Rectangle
{
	mixin SFML2StructWrapper!(Rectangle, sfFloatRect);
	
	this(float l, float b, float w, float h)
	{
		data = sfFloatRect(l, b, w, h);
	}
	this(sfFloatRect r)
	{
		data = r;
	}
	cpBB opCast(cpBB)()
	{
		return cpBB(data.left, data.top, data.left+data.width, data.top+data.height);
	}
}
struct Vector
{
	mixin SFML2StructWrapper!(Vector, sfVector2f);
	
	this(sfVector2f v) { data = v; }
	this(float x, float y) { data = sfVector2f(x, y); }
	cpVect opCast(cpVect)()
	{
		return cpVect(data.x, data.y);
	}
}
S upperFirst(S)(S s) @trusted pure if(isSomeString!S)
{
    Unqual!(typeof(s[0]))[] retval;
    bool changed = false;

    ElementType!S c2;

    c2 = std.uni.toUpper(s[0]);
    if(s[0] != c2) {
	retval ~= c2;
	retval ~= s[1..$];
	return retval;
    }
    return s;
} 

mixin template SFML2Wrapper(string type)
{
	private bool _isDebug;
	@property bool isDebug() pure @safe nothrow const { return _isDebug; }
	@property void isDebug(bool b) @safe nothrow { _isDebug = b; }
	mixin("protected sf"~upperFirst(type)~"* _"~type~";");
	mixin("@property sf"~upperFirst(type)~"* "~type~"() pure @safe nothrow { return _"~type~"; }");
	mixin("alias "~type~" this;");
	mixin("~this() { sf"~upperFirst(type)~"_destroy(_"~type~"); }");
}

template SFML2PropertyGetType(string type, string name)
{
	mixin("alias ReturnType!(sf"~upperFirst(type)~"_get"~upperFirst(name)~") SFML2PropertyGetType;");
}
template SFML2PropertySetType(string type, string name)
{
	mixin("alias ParameterTypeTuple!(sf"~upperFirst(type)~"_set"~upperFirst(name)~")[1] SFML2PropertySetType;");
}
mixin template SFML2GetProperty(string type, string name)
{
	mixin("@property "~SFML2PropertyGetType!(type, name).stringof~" "~name~"() @trusted const { return sf"~upperFirst(type)~"_get"~upperFirst(name)~"(this._"~type~"); }");
}
mixin template SFML2SetProperty(string type, string name)
{
	mixin("@property void "~name~"("~SFML2PropertySetType!(type, name).stringof~" value) { sf"~upperFirst(type)~"_set"~upperFirst(name)~"(this._"~type~", value); }");
}
mixin template SFML2Getter(string type, string name)
{
	mixin(SFML2PropertyGetType!(type, name).stringof~" "~name~"() { return sf"~upperFirst(type)~"_get"~upperFirst(name)~"(this._"~type~"); }");
}
mixin template SFML2Setter(string type, string name)
{
	mixin("void "~name~"("~SFML2PropertySetType!(type, name).stringof~" value) { sf"~upperFirst(type)~"_set"~upperFirst(name)~"(this, value); }");
}

mixin template SFML2GetProperties(string type, T...)
{
	static if(T.length == 1) {
		mixin SFML2GetProperty!(type, T[0]);
	} else {
		mixin SFML2GetProperty!(type, T[0]);
		mixin SFML2GetProperties!(type, T[1..$]);
	}
}
mixin template SFML2SetProperties(string type, T...)
{
	static if(T.length == 1) {
		mixin SFML2SetProperty!(type, T[0]);
	} else {
		mixin SFML2SetProperty!(type, T[0]);
		mixin SFML2SetProperties!(type, T[1..$]);
	}

}