module spritelib.sprite;

private import std.exception;
private import std.string;
private import std.traits;

private import derelict.sfml2.graphics;
private import derelict.sfml2.system;
private import derelict.sfml2.window;

private import spritelib.util;
private import spritelib.window;

interface Sprite
{
	@property Vector position() const;
	@property void position(in Vector) nothrow;
	void draw(Window, RenderStates);
	Rectangle globalBounds();
	@property void color(Color);
	@property bool isDebug() @safe pure nothrow const;
	@property void isDebug(bool) @safe nothrow;
	@property Vector origin() const;
	@property void texture(Texture);
	@property void textureRect(ClipRect);
	@property ClipRect textureRect() @trusted const;
	void rotation(float);
}

auto spriteRadius(Sprite s)
{
	auto bounds = s.globalBounds();
	if(bounds.width > bounds.height)
		return bounds.width / 2.0;
	return bounds.height / 2.0;
}
void drawBoundingBox(Sprite s, Window window, RenderStates states, sfColor color=sfBlack, float thickness=1.0f)
{
	auto bounds = s.globalBounds();
	auto box = new RectangleShape(bounds);
	sfRectangleShape_setOrigin(box._rectangleShape, sfVector2f(0, 0)); // Make up for the offset of the original shape.
	box.color = Color(0, 0, 0, 0);
	box.outlineColor = color;
	box.outlineThickness = thickness;
	box.draw(window, states);
}

class Shape(string type) : Sprite
{
	mixin SFML2Wrapper!(type);
	mixin("@property void color(Color c) { sf"~upperFirst(type)~"_setFillColor(_"~type~", c); }");
	mixin SFML2SetProperties!(type, "outlineColor", "outlineThickness", "rotation");
	this()
	{
		isDebug = false;
		mixin("_"~type~" = sf"~upperFirst(type)~"_create();");
		mixin("enforce(_"~type~" !is null, \"Failed to allocate "~upperFirst(type)~"\");");
	}
	void draw(Window window, RenderStates states)
	{
		mixin("sfRenderWindow_draw"~upperFirst(type)~"(window, _"~type~", states);");
		if(this.isDebug)
			drawBoundingBox(this, window, states);
	}
	@property Vector origin() const { mixin("return Vector(sf"~upperFirst(type)~"_getOrigin(_"~type~"));"); }
	@property Vector position() const { mixin("return Vector(sf"~upperFirst(type)~"_getPosition(_"~type~"));"); }
	@property void position(in Vector v) { mixin("sf"~upperFirst(type)~"_setPosition(_"~type~", v);"); }
	Rectangle globalBounds()
	{
		mixin("return Rectangle(sf"~upperFirst(type)~"_getGlobalBounds(_"~type~"));");
	}
	@property void texture(Texture t) { mixin("sf"~upperFirst(type)~"_setTexture(_"~type~", t, false);"); }
	@property void textureRect(ClipRect r) { mixin("sf"~upperFirst(type)~"_setTextureRect(_"~type~", r);"); }
	@property ClipRect textureRect() @trusted const { mixin("return ClipRect(sf"~upperFirst(type)~"_getTextureRect(_"~type~"));"); }
}

class CircleShape : Shape!"circleShape"
{
	mixin SFML2GetProperties!("circleShape", "radius");
	mixin SFML2SetProperties!("circleShape", "radius");
	
	this(Vector pos, float radius)
	{
		super();
		this.radius = radius;
		this.position = pos;
		sfCircleShape_setOrigin(_circleShape, sfVector2f(radius, radius));
	}
}
class RectangleShape : Shape!"rectangleShape"
{
	this(Rectangle bounds)
	{
		super();
		this.position = Vector(bounds.left, bounds.top);
		sfRectangleShape_setSize(_rectangleShape, sfVector2f(bounds.width, bounds.height));
		sfRectangleShape_setOrigin(_rectangleShape, sfVector2f(bounds.width/2.0, bounds.height/2.0));
	}
	alias Object.opCmp opCmp;
	int opCmp(RectangleShape shape)
	{
		if(shape == this) {
			return 0;
		}
		return cast(int)this._rectangleShape - cast(int)shape._rectangleShape;
	}
}
class ConvexShape : Shape!"convexShape"
{
	mixin SFML2GetProperties!("convexShape", "pointCount");
	this(Vector[] points...)
	in
	{
		assert(points.length > 0);
	}
	body
	{
		super();
		sfConvexShape_setPointCount(_convexShape, points.length);
		for(size_t i=0; i<points.length; ++i) {
			sfConvexShape_setPoint(_convexShape, i, points[i]);
		}
	}
	
	Vector[] points()
	{
		Vector[] p;
		auto count = sfConvexShape_getPointCount(_convexShape);
		p.length = count;
		for(size_t i=0; i<count; ++i) {
			p[i] = sfConvexShape_getPoint(_convexShape, i);
		}
		return p;
	}
}

class Texture
{
	mixin SFML2Wrapper!"texture";

	this(string file)
	{
		_texture = sfTexture_createFromFile(toStringz(file), null);
		enforce(_texture !is null, "Failed to create texture from "~file);
		sfTexture_setSmooth(_texture, true);
	}
	auto opDispatch(string s, T...)(T args) { mixin("return sfTexture_"~s~"(_texture, args);"); }
	int opCmp(Texture)(Texture t) const
	{
		if(_texture != t._texture) {
			return _texture > t._texture ? 1 : -1;
		}
		return 0;
	}
}

class ImageSprite : Sprite
{
	mixin SFML2Wrapper!"sprite";
	mixin SFML2GetProperties!("sprite", "position");
	mixin SFML2SetProperties!("sprite", "position", "rotation");
	private bool _isDebug;
	@property bool isDebug() @safe pure nothrow const { return _isDebug; }
	@property void isDebug(bool b) @safe nothrow { _isDebug = b; }

	this(Texture texture)
	{
		_sprite = sfSprite_create();
		enforce(_sprite !is null, "Failed to allocate sprite");
		this.texture(texture);
		auto rect = this.textureRect();
		this.origin(Vector(rect.width/2.0, rect.height/2.0));
	}
	this(Texture texture, ClipRect rect)
	{
		_sprite = sfSprite_create();
		enforce(_sprite !is null, "Failed to allocate sprite");
		this.texture(texture);
		textureRect(rect);
		this.origin(Vector(rect.width/2.0, rect.height/2.0));
	}

	@property void texture(Texture texture)
	{
		sfSprite_setTexture(_sprite, texture, false);
	}
	@property ClipRect textureRect() const @trusted { return ClipRect(sfSprite_getTextureRect(_sprite)); }
	@property void textureRect(ClipRect r) { sfSprite_setTextureRect(_sprite, r); }
	@property void color(Color c) { sfSprite_setColor(_sprite, c); }
	@property void origin(in Vector v) { sfSprite_setOrigin(_sprite, v); }
	@property Vector origin() const { return Vector(sfSprite_getOrigin(_sprite)); }
	@property Vector position() const { return Vector(sfSprite_getPosition(_sprite)); }
	@property void position(in Vector v) { sfSprite_setPosition(_sprite, v); }
	Rectangle globalBounds()
	{
		auto bounds = sfSprite_getGlobalBounds(_sprite);
		return Rectangle(bounds);
	}
	void draw(Window window, RenderStates states)
	{
		sfRenderWindow_drawSprite(window, _sprite, states);
		if(_isDebug)
			drawBoundingBox(this, window, states);
	}
	void setScale(Vector s)
	{
		sfSprite_setScale(_sprite, s);
	}
}

class ScalingSprite : ImageSprite
{
	private ClipRect _center;
	private ImageSprite[8] _edges;
	private ImageSprite _centerSprite;

	this(Texture texture, ClipRect clip, ClipRect center)
	{
		super(texture, clip);
		_center = center;
		int[2] x = [ clip.left+center.left, clip.left+center.left+center.width ];
		int[2] y = [ clip.top+center.top, clip.top+center.top+center.height ];
		int[2] widths = [ center.left, clip.width-center.left-center.width ];
		int[2] heights = [ center.top, clip.height-center.top-center.height ];

		_edges[0] = new ImageSprite(texture, ClipRect(clip.left, clip.top, widths[0], heights[0])); // Top Left
		_edges[1] = new ImageSprite(texture, ClipRect(clip.left, y[0], widths[0], center.height)); // Left
		_edges[2] = new ImageSprite(texture, ClipRect(clip.left, y[1], widths[0], heights[1])); // Bottom Left
		_edges[3] = new ImageSprite(texture, ClipRect(x[0], clip.top, center.width, heights[0])); // Top
		_edges[4] = new ImageSprite(texture, ClipRect(x[0], y[1], center.width, heights[1])); // Bottom
		_edges[5] = new ImageSprite(texture, ClipRect(x[1], clip.top, widths[1], heights[0])); // Top Right
		_edges[6] = new ImageSprite(texture, ClipRect(x[1], y[0], widths[1], center.height)); // Right
		_edges[7] = new ImageSprite(texture, ClipRect(x[1], y[1], widths[1], heights[1])); // Bottom Right
		_centerSprite = new ImageSprite(texture, ClipRect(x[0], y[0], center.width, center.height));
	}
	override void draw(Window window, RenderStates state)
	{
		auto bounds = this.globalBounds();
		auto clip = this.textureRect();
		//float[2] x = [ bounds.left+_edges[0].getTextureRect().width, bounds.left+bounds.width-_edges[5].getTextureRect().width ];
		float[2] x = [ bounds.left+bounds.width/2.0, bounds.left+bounds.width-_edges[5].textureRect().width/2.0 ];
		//float[2] y = [ bounds.top+_edges[0].getTextureRect().height, bounds.top+bounds.height-_edges[2].getTextureRect().width ];
		float[2] y = [ bounds.top+bounds.height/2.0, bounds.top+bounds.height-_edges[2].textureRect().width/2.0 ];
		float scaleX = (bounds.width-_edges[0].textureRect().width-_edges[5].textureRect().width) /
			(clip.width-_edges[0].textureRect().width-_edges[5].textureRect().width);
		float scaleY = (bounds.height-_edges[0].textureRect().height-_edges[7].textureRect().height) /
			(clip.height-_edges[0].textureRect().height-_edges[7].textureRect().height);
		// Draw Top Left
		_edges[0].position = Vector(bounds.left+_edges[0].textureRect().width/2.0, bounds.top+_edges[0].textureRect().height/2.0);
		_edges[0].draw(window, state);
		// Draw Bottom Left
		_edges[2].position = Vector(bounds.left+_edges[2].textureRect().width/2.0, y[1]);
		_edges[2].draw(window, state);
		// Draw Top Right
		_edges[5].position = Vector(x[1], bounds.top+_edges[5].textureRect().height/2.0);
		_edges[5].draw(window, state);
		// Draw Bottom Right
		_edges[7].position = Vector(x[1], y[1]);
		_edges[7].draw(window, state);
		// Draw Left
		_edges[1].position = Vector(bounds.left+_edges[0].textureRect().width/2.0, y[0]);
		_edges[1].setScale(Vector(1.0, scaleY));
		_edges[1].draw(window, state);
		// Draw Right
		_edges[6].position = Vector(x[1], y[0]);
		_edges[6].setScale(Vector(1.0, scaleY));
		_edges[6].draw(window, state);
		// Draw Top
		_edges[3].position = Vector(x[0], bounds.top+_edges[0].textureRect().height/2.0);
		_edges[3].setScale(Vector(scaleX, 1.0));
		_edges[3].draw(window, state);
		// Draw Bottom
		_edges[4].position = Vector(x[0], y[1]);
		_edges[4].setScale(Vector(scaleX, 1.0));
		_edges[4].draw(window, state);
		// Draw Center
		_centerSprite.position = Vector(x[0], y[0]);
		_centerSprite.setScale(Vector(scaleX, scaleY));
		_centerSprite.draw(window, state);
		if(isDebug)
			drawBoundingBox(this, window, state);
	}
	override void color(Color theColor)
	{
		foreach(s; _edges) {
			s.color(theColor);
		}
		_centerSprite.color(theColor);
	}
}