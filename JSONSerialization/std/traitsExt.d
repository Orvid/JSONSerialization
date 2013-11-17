module std.traitsExt;

enum isClass(T) = is(T == class);
@safe pure nothrow unittest
{
	class AClass { }
	interface AnInterface { }
	struct AStruct { }
	union AUnion { }
	enum AnEnum;
	void AFunction() { }

	static assert(isClass!AClass, "Failed to determine that AClass is a class!");
	static assert(!isClass!AnInterface, "Failed to determine that AnInterface is not a class!");
	static assert(!isClass!AStruct, "Failed to determine that AStruct is not a class!");
	static assert(!isClass!AUnion, "Failed to determine that AUnion is not a class!");
	static assert(!isClass!AnEnum, "Failed to determine that AnEnum is not a class!");
	static assert(!isClass!(typeof(AFunction)), "Failed to determine that AFunction is not a class!");
}

enum isStruct(T) = is(T == struct);
@safe pure nothrow unittest
{
	class AClass { }
	interface AnInterface { }
	struct AStruct { }
	union AUnion { }
	enum AnEnum;
	void AFunction() { }

	static assert(!isStruct!AClass, "Failed to determine that AClass is not a struct!");
	static assert(!isStruct!AnInterface, "Failed to determine that AnInterface is not a struct!");
	static assert(isStruct!AStruct, "Failed to determine that AStruct is a struct!");
	static assert(!isStruct!AUnion, "Failed to determine that AUnion is not a struct!");
	static assert(!isStruct!AnEnum, "Failed to determine that AnEnum is not a struct!");
	static assert(!isStruct!(typeof(AFunction)), "Failed to determine that AFunction is not a struct!");
}

enum isEnum(T) = is(T == enum);
@safe pure nothrow unittest
{
	class AClass { }
	interface AnInterface { }
	struct AStruct { }
	union AUnion { }
	enum AnEnum;
	void AFunction() { }
	
	static assert(!isEnum!AClass, "Failed to determine that AClass is not an enum!");
	static assert(!isEnum!AnInterface, "Failed to determine that AnInterface is not an enum!");
	static assert(!isEnum!AStruct, "Failed to determine that AStruct is an enum!");
	static assert(!isEnum!AUnion, "Failed to determine that AUnion is not an enum!");
	static assert(isEnum!AnEnum, "Failed to determine that AnEnum is an enum!");
	static assert(!isEnum!(typeof(AFunction)), "Failed to determine that AFunction is not an enum!");
}

enum isFunction(T) = is(T == function);
@safe pure nothrow unittest
{
	class AClass { }
	interface AnInterface { }
	struct AStruct { }
	union AUnion { }
	enum AnEnum;
	void AFunction() { }
	
	static assert(!isFunction!AClass, "Failed to determine that AClass is not a function!");
	static assert(!isFunction!AnInterface, "Failed to determine that AnInterface is not a function!");
	static assert(!isFunction!AStruct, "Failed to determine that AStruct is not a function!");
	static assert(!isFunction!AUnion, "Failed to determine that AUnion is not a function!");
	static assert(!isFunction!AnEnum, "Failed to determine that AnEnum is not a function!");
	static assert(isFunction!(typeof(AFunction)), "Failed to determine that AFunction is a function!");
}

enum isMemberClass(T, string member) = is(Dequal!(__traits(getMember, T.init, member)) == class);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(isMemberClass!(Outer, "AClass"), "Failed to determine that Outer.AClass is a class!");
	static assert(!isMemberClass!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not a class!");
	static assert(!isMemberClass!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not a class!");
	static assert(!isMemberClass!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not a class!");
	static assert(!isMemberClass!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not a class!");
	static assert(!isMemberClass!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not a class!");
	static assert(!isMemberClass!(Outer, "AField"), "Failed to determine that Outer.AField is not a class!");
}

enum isMemberInterface(T, string member) = is(Dequal!(__traits(getMember, T.init, member)) == interface);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberInterface!(Outer, "AClass"), "Failed to determine that Outer.AClass is not an interface!");
	static assert(isMemberInterface!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is an interface!");
	static assert(!isMemberInterface!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not an interface!");
	static assert(!isMemberInterface!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not an interface!");
	static assert(!isMemberInterface!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not an interface!");
	static assert(!isMemberInterface!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not an interface!");
	static assert(!isMemberInterface!(Outer, "AField"), "Failed to determine that Outer.AField is not an interface!");
}

enum isMemberStruct(T, string member) = is(Dequal!(__traits(getMember, T.init, member)) == struct);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberStruct!(Outer, "AClass"), "Failed to determine that Outer.AClass is not a struct!");
	static assert(!isMemberStruct!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not a struct!");
	static assert(isMemberStruct!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is a struct!");
	static assert(!isMemberStruct!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not a struct!");
	static assert(!isMemberStruct!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not a struct!");
	static assert(!isMemberStruct!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not a struct!");
	static assert(!isMemberStruct!(Outer, "AField"), "Failed to determine that Outer.AField is not a struct!");
}

enum isMemberUnion(T, string member) = is(Dequal!(__traits(getMember, T.init, member)) == union);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberUnion!(Outer, "AClass"), "Failed to determine that Outer.AClass is not a union!");
	static assert(!isMemberUnion!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not a union!");
	static assert(!isMemberUnion!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not a union!");
	static assert(isMemberUnion!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is a union!");
	static assert(!isMemberUnion!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not a union!");
	static assert(!isMemberUnion!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not a union!");
	static assert(!isMemberUnion!(Outer, "AField"), "Failed to determine that Outer.AField is not a union!");
}

enum isMemberEnum(T, string member) = is(Dequal!(__traits(getMember, T.init, member)) == enum);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberEnum!(Outer, "AClass"), "Failed to determine that Outer.AClass is not an enum!");
	static assert(!isMemberEnum!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not an enum!");
	static assert(!isMemberEnum!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not an enum!");
	static assert(!isMemberEnum!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not an enum!");
	static assert(isMemberEnum!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is an enum!");
	static assert(!isMemberEnum!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not an enum!");
	static assert(!isMemberEnum!(Outer, "AField"), "Failed to determine that Outer.AField is not an enum!");
}

enum isMemberFunction(T, string member) = is(typeof(__traits(getMember, T.init, member)) == function);
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberFunction!(Outer, "AClass"), "Failed to determine that Outer.AClass is not a function!");
	static assert(!isMemberFunction!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not a function!");
	static assert(!isMemberFunction!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not a function!");
	static assert(!isMemberFunction!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not a function!");
	static assert(!isMemberFunction!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not a function!");
	static assert(isMemberFunction!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is a function!");
	static assert(!isMemberFunction!(Outer, "AField"), "Failed to determine that Outer.AField is not a function!");
}

template isMemberField(T, string member)
{
	enum bool isMemberField = 
		   __traits(compiles, `typeof(T.` ~ member ~ `)`)
		&& !isMemberFunction!(T, member)
		&& !isMemberClass!(T, member)
		&& !isMemberInterface!(T, member)
		&& !isMemberStruct!(T, member)
		&& !isMemberUnion!(T, member)
		&& !isMemberEnum!(T, member)
	;
}
@safe pure nothrow unittest
{
	static class Outer
	{
		class AClass { }
		interface AnInterface { }
		struct AStruct { }
		union AUnion { }
		enum AnEnum;
		void AFunction() { }
		int AField;
	}
	
	static assert(!isMemberField!(Outer, "AClass"), "Failed to determine that Outer.AClass is not a field!");
	static assert(!isMemberField!(Outer, "AnInterface"), "Failed to determine that Outer.AnInterface is not a field!");
	static assert(!isMemberField!(Outer, "AStruct"), "Failed to determine that Outer.AStruct is not a field!");
	static assert(!isMemberField!(Outer, "AUnion"), "Failed to determine that Outer.AUnion is not a field!");
	static assert(!isMemberField!(Outer, "AnEnum"), "Failed to determine that Outer.AnEnum is not a field!");
	static assert(!isMemberField!(Outer, "AFunction"), "Failed to determine that Outer.AFunction is not a field!");
	static assert(isMemberField!(Outer, "AField"), "Failed to determine that Outer.AField is a field!");
}

@property auto hasPublicDefaultConstructor(T)() @safe pure nothrow
{
	import std.traits : arity;

	static if (!__traits(hasMember, T, "__ctor"))
		return true;
	else static if (__traits(getProtection, T.__ctor) != "public")
		return false;
	else static if (arity!(__traits(getMember, T, "__ctor")) == 0)
		return true;
	else
	{
		import std.traits : ParameterDefaultValueTuple;

		foreach (def; ParameterDefaultValueTuple!(__traits(getMember, T, "__ctor")))
		{
			static if (is(def == void) || is(typeof(def) == void))
				return false;
		}

		return true;
	}
}
@safe pure nothrow unittest
{
	static class NoConstructor { int A; }
	static assert(hasPublicDefaultConstructor!NoConstructor, "Failed to determine that a class with no constructor defined has a public default constructor!");

	static class PrivateConstructor { int A; private this() { } }
	static assert(!hasPublicDefaultConstructor!PrivateConstructor, "Failed to determine that a class with a private parameterless constructor defined does not have a public default constructor!");

	static class PublicConstructor { int A; public this() { } }
	static assert(hasPublicDefaultConstructor!PublicConstructor, "Failed to determine that a class with a public parameterless constructor defined has a public default constructor!");

	static class NonZeroParameterCount { int A; public this(int a) { A = a; } }
	static assert(!hasPublicDefaultConstructor!NonZeroParameterCount, "Failed to determine that a class with a public constructor with one parameter does not have a public default constructor!");

	static class NonZeroParameterCountWithDefault { int A; public this(int a = 3) { A = a; } }
	static assert(hasPublicDefaultConstructor!NonZeroParameterCountWithDefault, "Failed to determine that a class with a public constructor with one parameter with a default value has a public default constructor!");
}

// TODO: Unittest.
@property T constructDefault(T)()
	if (hasPublicDefaultConstructor!T)
{
	static if (isClass!T)
		return new T();
	else
		return T();
}

// TODO: Unittest.
@property auto getMemberValue(string member, T)(T val) @safe pure nothrow
{
	return __traits(getMember, val, member);
}

// TODO: Unittest.
@property auto setMemberValue(string member, T, V)(ref T parent, V val) @safe pure nothrow
{
	mixin(`parent.` ~ member ~ ` = val;`);
}

// TODO: Unittest.
alias MemberType(T, string member) = typeof(getDefaultMemberValue!(T, member));

// TODO: Unittest.
@property auto getDefaultMemberValue(T, string member)()
	if (hasPublicDefaultConstructor!T)
{
	return __traits(getMember, constructDefault!T, member);
}

// TODO: Unittest.
@property AttributeType getMemberAttribute(T, string member, AttributeType)() @safe nothrow
{
	foreach (at; __traits(getAttributes, __traits(getMember, T, member)))
	{
		static if (is(at == AttributeType) || is(typeof(at) == AttributeType))
			return at;
	}
	return AttributeType.init;
}

// TODO: Unittest.
@property bool memberHasAttribute(T, string member, AttributeType)() @safe nothrow
{
	foreach (at; __traits(getAttributes, __traits(getMember, T, member)))
	{
		static if (is(at == AttributeType) || is(typeof(at) == AttributeType))
			return true;
	}
	return false;
}

// TODO: Unittest.
@property bool hasAttribute(T, AttributeType)() @safe pure nothrow
{
	foreach (at; __traits(getAttributes, T))
	{
		static if (is(at == AttributeType) || is(typeof(at) == AttributeType))
			return true;
	}
	return false;
}

// TODO: Unittest.
template isOneOf(T, Possibilities...)
	if (Possibilities.length > 0)
{
	static if (is(T == Possibilities[0]))
		enum isOneOf = true;
	else static if (Possibilities.length == 1)
		enum isOneOf = false;
	else
		enum isOneOf = isOneOf!(T, Possibilities[1..$]);
}

template Dequal(T)
{
	import std.traits : ForeachType, isArray, isPointer, PointerTarget, Unqual;
	static if (isArray!T)
		alias Dequal = Dequal!(ForeachType!T)[];
	else static if (isPointer!T)
		alias Dequal = Dequal!(PointerTarget!T)*;
	else
		alias Dequal = Unqual!T;
}
@safe pure nothrow unittest
{
	static assert(is(Dequal!(int*) == int*));
	static assert(is(Dequal!(const(int)*) == int*));
	static assert(is(Dequal!(const(const(int)*)) == int*));
	
	static assert(is(Dequal!(int[]) == int[]));
	static assert(is(Dequal!(const(int)[]) == int[]));
	static assert(is(Dequal!(const(const(int)[])) == int[]));
	
	static assert(is(Dequal!Object == Object));
	static assert(is(Dequal!(const Object) == Object));
	
	static assert(is(Dequal!(immutable(int)[]) == int[]));
	static assert(is(Dequal!(shared(int)[]) == int[]));
	static assert(is(Dequal!(inout(int)[]) == int[]));
}