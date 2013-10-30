module std.serialization;

enum optional;
enum serializable;
enum nonSerialized;
struct serializeAs { string Name; }

abstract class SerializationFormat
{
	import std.traitsExt : 
		Dequal,
		getDefaultMemberValue,
		getMemberAttribute,
		getMemberValue,
		hasAttribute,
		hasPublicDefaultConstructor,
		isClass,
		isMemberField,
		memberHasAttribute
	;

	protected static void ensureSerializable(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasAttribute!(T, serializable) || is(Dequal!T == Object), "Classes not marked as serializable cannot be serialized!");
		else
			static assert(0, "Not yet implemented!");
	}

	protected static void ensurePublicConstructor(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasPublicDefaultConstructor!T, `The class '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else
			static assert(0, "Not yet implemented!");
	}

	protected template shouldSerializeMember(T, string member)
	{
		enum shouldSerializeMember = member != "this" && isMemberField!(T, member) && !memberHasAttribute!(T, member, nonSerialized);
	}
	
	protected static bool shouldSerializeValue(T, string member)(T val) @safe pure nothrow
	{
		static if (memberHasAttribute!(T, member, optional))
		{
			if (getDefaultMemberValue!(T, member) == getMemberValue!member(val))
				return false;
		}
		return true;
	}

	protected template getFinalMemberName(T, string member)
	{
		enum getFinalMemberName = memberHasAttribute!(T, member, serializeAs) ? getMemberAttribute!(T, member, serializeAs).Name : member;
	}
	
	
	static ubyte[] serialize(T)(T val) @safe
		if (!is(Dequal!T == T))
	{
		return serialize(cast(Dequal!T)val); 
	}
	// The overload above is designed to reduce the number of times this
	// template is instantiated.
	abstract ubyte[] serialize(T)(T val) @safe
		if (is(Dequal!T == T));
	abstract T deserialize(T)(ubyte[] data);
}