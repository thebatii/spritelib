module spritelib.spritenode;

private import std.range;

private import dchip.all;

private import derelict.sfml2.graphics;

private import spritelib.physics;
private import spritelib.scene;
private import spritelib.sprite;
private import spritelib.util;
private import spritelib.window;


interface SpriteNode : Sprite
{
	cpBody* physics() pure @safe nothrow;
	void physics(cpBody*) @safe nothrow;
	PhysicsShape* newShape(cpSpace*);
	void addShape(PhysicsShape*);
	Sprite drawable();
	void scene(SceneGraph);
	SceneGraph scene();
}

struct Animation
{
	struct Sequence
	{
		Texture texture;
		ClipRect clip;
		float duration;
		
		const int opCmp(Sequence seq)
		{
			auto cmp = texture.opCmp(seq.texture);
			if(cmp != 0) {
				return cmp;
			}
			cmp = clip.opCmp(seq.clip);
			if(cmp != 0) {
				return cmp;
			}
			if(duration != seq.duration) {
				return duration > seq.duration ? 1 : -1;
			}
			return 0;
		}
	}
	Sequence[] sequence;
	bool doesRepeat;
	
	const int opCmp(Animation animation) const
	{
		if(sequence.length != animation.sequence.length) {
			return sequence.length > animation.sequence.length ? 1 : -1;
		}
		for(size_t i=0; i<sequence.length; ++i) {
			auto cmp = sequence[i].opCmp(animation.sequence[i]);
			if(cmp != 0) {
				return cmp;
			}
		}
		if(doesRepeat != animation.doesRepeat) {
			return doesRepeat ? 1 : -1;
		}
		return 0;
	}
}
alias float delegate(float) SpriteNodeAnimation;

auto spriteNodeAnimation(SpriteNode node, Animation animation)
{
	if(animation.doesRepeat) {
		return newAnimation(node, cycle(animation.sequence.save));
	}
	return newAnimation(node, animation.sequence.save);
}
private auto newAnimation(T)(SpriteNode node, T range) if(isInputRange!T)
{
	assert(!range.empty);
	auto current = range.front;
	return (float elapsed) {
		while(elapsed >= current.duration) {
			elapsed -= current.duration;
			range.popFront();
			if(range.empty) {
				node.texture(current.texture);
				if(current.clip.width > 0 && current.clip.height > 0) {
					node.textureRect(current.clip);
				}
				return -1.0f;
			}
			current = range.front;
			node.texture(current.texture);
			node.textureRect(current.clip);
		}
		current.duration -= elapsed;
		return current.duration;
	};
}

struct SpriteNodeRef
{
	SpriteNode node;
}
void removeSpriteNode(SpriteNodeRef* node)
in
{
	assert(node !is null);
	assert(node.node !is null);
	assert(node.node.scene() !is null);
}
body
{
	node.node.scene().remove(node.node);
}
void removeSpriteNode(cpBody* body_)
{
	removeSpriteNode(cast(SpriteNodeRef*)(body_.data));
}

void update(SpriteNode node)
{
	if(node.physics() !is null) {
		auto p = node.physics().p;
		node.position = Vector(p.x, p.y);
	}
}
void update(SpriteNode node, float time)
{
	if(node.physics() !is null) {
		auto v = node.physics().v;
		auto space = cpBodyGetSpace(node.physics());
		if(v.x == v.x && v.y == v.y && space is null) {
			auto p = node.physics().p;
			node.position(Vector(p.x+(v.x*time), p.y+(v.y*time)));
		} else {
			update(node);
		}
		node.drawable().rotation(radiansToDegrees(cpBodyGetAngle(node.physics())));
	}
}
auto moveSprite(Window window, SpriteNode sprite, Vector distance, float duration)
{
	sprite.physics().v = cpVect(distance.x/duration, distance.y/duration);
	float durationLeft = duration;
	return window.addTimer(duration, (float elapsed) {
			sprite.physics().v = cpVect(0, 0);
			return -1.0f;
	});
}
void addVelocity(SpriteNode sprite, Vector v, float factor=1.0)
{
	if(sprite.physics() !is null) {
		sprite.physics().v = cpvadd(sprite.physics().v, cpVect(v.x/factor, v.y/factor));
	}
}
class ShapeNode(string type) : SpriteNode
{
	mixin("private "~upperFirst(type)~" _sprite;");
	mixin SpriteNodeSprite!();
	mixin SpriteNodeNewShape!();
	
	this()
	{
		_node.node = this;
		_isDebug = false;
	}
	protected PhysicsShape* initializeShape(cpSpace* space, cpBody* body_)
	{
		assert(false, "Must override initializeShape() method");
	}
}

class CircleNode : ShapeNode!"circleShape"
{
	this(Vector pos, float radius)
	{
		_sprite = new CircleShape(pos, radius);
	}
	this(Vector pos, float radius, cpFloat mass)
	{
		_sprite = new CircleShape(pos, radius);
		_physics = cpBodyNew(mass, cpMomentForCircle(mass, 0, radius, cpVect(0, 0)));
		_physics.p = cpVect(pos.x, pos.y);
		_physics.data = &_node;
	}
	override protected PhysicsShape* initializeShape(cpSpace* space, cpBody* body_)
	{
		return circleShape(this, null, body_, _sprite.radius);
	}
}

class RectangleNode : ShapeNode!"rectangleShape"
{
	this(Rectangle bounds)
	{
		_sprite = new RectangleShape(bounds);
	}
	this(Rectangle bounds, cpFloat mass)
	{
		_sprite = new RectangleShape(bounds);
		_physics = cpBodyNew(mass, cpMomentForBox(mass, bounds.width, bounds.height));
		_physics.p = cpVect(_sprite.position().x, _sprite.position().y);
		_physics.data = &_node;
	}
	override protected PhysicsShape* initializeShape(cpSpace* space, cpBody* body_)
	{
		cpShape* shape;
		auto bounds = _sprite.globalBounds;
		if(space !is null && body_ == space.staticBody) {
			shape = cpBoxShapeNew2(space.staticBody, cpBB(bounds.left, bounds.top, bounds.left+bounds.width, bounds.top+bounds.height));
		}
		shape = cpBoxShapeNew(body_, bounds.width, bounds.height);
		auto s = new PhysicsShape(ShapeType.Polygon, shape, this);
		shape.data = s;
		return s;
	}
}

class ImageSpriteNode : SpriteNode
{
	ImageSprite _sprite;
	mixin SpriteNodeSprite!();
	mixin SpriteNodeNewShape!();
	
	this(ImageSprite s)
	{
		_sprite = s;
		_node.node = this;
	}
	protected PhysicsShape* initializeShape(cpSpace* space, cpBody* body_)
	{
		assert(false, "Must override initializeShape!");
	}
	void setScale(Vector s) { _sprite.setScale(s); }
}
class RectangleImageNode : ImageSpriteNode
{
	this(Texture texture, ClipRect clip, ClipRect center)
	{
		super(new ScalingSprite(texture, clip, center));
	}
	this(Texture texture, ClipRect clip, ClipRect center, cpFloat mass)
	{
		super(new ScalingSprite(texture, clip, center));
		_physics = cpBodyNew(mass, cpMomentForBox(mass, clip.width, clip.height));
		_physics.p = cpVect(_sprite.position().x, _sprite.position().y);
	}
	override protected PhysicsShape* initializeShape(cpSpace* space, cpBody* body_)
	{
		cpShape* shape;
		auto bounds = _sprite.globalBounds;
		if(space is null || body_ != space.staticBody) {
			shape = cpBoxShapeNew(body_, bounds.width, bounds.height);
		} else {
			auto bb = cpBB(bounds.left, bounds.top, bounds.left+bounds.width, bounds.top+bounds.height);
			shape = cpBoxShapeNew2(body_, bb);
		}
		auto s = new PhysicsShape(ShapeType.Polygon, shape, this);
		shape.data = s;
		return s;
	}
}

mixin template SpriteNodeSprite()
{
	private cpBody* _physics;
	protected SpriteNodeRef _node;
	private bool _isDebug;
	cpBody* physics() pure @safe nothrow { return _physics; }
	void physics(cpBody* p) @safe nothrow
	{
		_physics = p;
		_physics.data = &_node;
	}
	private PhysicsShape*[] _shapes;
	private SceneGraph _scene;
	SceneGraph scene() { return _scene; }
	void scene(SceneGraph s) { _scene = s; }

	Sprite drawable() { return _sprite; }
	Rectangle globalBounds() @trusted { return _sprite.globalBounds(); }
	@property Vector position() const { return _sprite.position; }
	@property void position(in Vector p)
	{
		_sprite.position = p;
		if(_physics !is null) {
			_physics.p = cpVect(p.x, p.y);
		}
	}
	void draw(Window window, RenderStates states)
	{
		_sprite.draw(window, states);
		if(_isDebug) {
			foreach(shape; _shapes) {
				drawPhysicsShape(window, shape, states);
			}
		}
	}
	@property void color(Color c)
	{
		_sprite.color = c;
	}
	@property bool isDebug() const pure nothrow @safe
	{
		return _isDebug;
	}
	@property void isDebug(bool d) @safe nothrow
	{
		_isDebug = d;
	}
	@property Vector origin() const { return _sprite.origin; }
	@property void texture(Texture t)
	{
		_sprite.texture(t);
	}
	@property void textureRect(ClipRect r)
	{
		_sprite.textureRect(r);
	}
	@property ClipRect textureRect() @trusted const { return _sprite.textureRect(); }
	void rotation(float r)
	{
		_sprite.rotation(r);
		if(_physics !is null) {
			auto space = cpBodyGetSpace(_physics);
			if(space !is null && _physics != space.staticBody) { // Fully dynamic body.
				cpBodySetAngle(_physics, degreesToRadians(r));
				cpSpaceReindexShapesForBody(space, _physics);
			} else if(space is null) { // Rogue bodies
				cpBodySetAngle(_physics, degreesToRadians(r));
			}
		}
	}
	void addShape(PhysicsShape* s)
	{
		_shapes ~= s;
	}
}

mixin template SpriteNodeNewShape()
{
	PhysicsShape* newShape(cpSpace* space)
	in
	{
		assert(_physics !is null || space !is null);
	}
	body
	{
		auto shape = this.initializeShape(space, (_physics is null ? space.staticBody : _physics));
		if(space !is null) {
			cpSpaceAddShape(space, shape.shape);
		}
		_shapes ~= shape;
		return shape;
	}
}

void drawPhysicsShape(Window window, PhysicsShape* shape, RenderStates states)
{
	auto bb = cpShapeGetBB(shape.shape);
	auto angle = shape.shape.body_.a;
	switch(shape.type) {
		case ShapeType.Circle:
			auto radius = (bb.r-bb.l)/2.0;
			auto circle = new CircleShape(Vector(bb.l+radius, bb.b+radius), radius);
			circle.color = Color(0, 0, 0, 0);
			circle.outlineColor = Color(0, 0, 0);
			circle.outlineThickness = 1.0;
			circle.draw(window, states);
			break;
		case ShapeType.Polygon:
			auto offset = Vector((bb.r-bb.l)/2.0, (bb.t-bb.b)/2.0);
			offset.x += bb.l;
			offset.y += bb.b;
			Vector[] points;
			for(int i=0; i<cpPolyShapeGetNumVerts(shape.shape); ++i) {
				auto v = cpPolyShapeGetVert(shape.shape, i);
				points ~= Vector(v.x, v.y);
			}
			auto polygon = new ConvexShape(points);
			polygon.position = offset;
			polygon.color = Color(0, 0, 0, 0);
			polygon.outlineColor = Color(0, 0, 0);
			polygon.outlineThickness = 1.0;
			polygon.rotation(radiansToDegrees(angle));
			polygon.draw(window, states);
			break;
		case ShapeType.Segment:
			auto seg = cast(cpSegmentShape*)(shape.shape);
			auto line = [sfVertex(Vector(seg.a.x, seg.a.y), sfBlack), sfVertex(Vector(seg.b.x, seg.b.y), sfBlack)];
			sfRenderWindow_drawPrimitives(window, line.ptr, 2, sfLines, states);
			break;
		default:
			assert(false, "Type not handled");
	}
}