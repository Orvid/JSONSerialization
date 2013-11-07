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
		isStruct,
		isMemberField,
		memberHasAttribute
	;

protected:
	enum deserializationContext;

	enum isDeserializationContext(T) = hasAttribute!(T, deserializationContext);

	template isSerializable(T)
	{
		import std.traits : isBuiltinType;

		static if (isBuiltinType!T)
			enum isSerializable = true;
		else static if (hasAttribute!(T, serializable) || is(Dequal!T == Object))
			enum isSerializable = true;
		else
			enum isSerializable = false;
	}

	static void ensurePublicConstructor(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasPublicDefaultConstructor!T, `The class '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else static if (isStruct!T)
			static assert(hasPublicDefaultConstructor!T, `The struct '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else
			static assert(0, "Not yet implemented!");
	}

	enum shouldSerializeMember(T, string member) = member != "this" && isMemberField!(T, member) && !memberHasAttribute!(T, member, nonSerialized);
	
	static bool shouldSerializeValue(T, string member)(T val) @safe pure nothrow
	{
		static if (memberHasAttribute!(T, member, optional))
		{
			if (getDefaultMemberValue!(T, member) == getMemberValue!member(val))
				return false;
		}
		return true;
	}
	enum getFinalMemberName(T, string member) = memberHasAttribute!(T, member, serializeAs) ? getMemberAttribute!(T, member, serializeAs).Name : member;

	template BaseMembers()
	{
		enum BaseMembers = q{
			// This overload is designed to reduce the number of times the serialization
			// templates are instantiated. (and make the type checks within them much simpler)
			static void serialize(Range, T)(ref Range output, T val) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T) && isOutputRange!(Range, string))
			{
				return serialize(output, cast(Dequal!T)val);
			}

			static void serialize(Range, T)(ref Range output, T val) @trusted
				if (!isNativeSerializationSupported!T && is(Dequal!T == T) && isOutputRange!(Range, string))
			{
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					// TODO: Support using an output range here as well.
					output.put('"');
					output.put(val.toString());
					output.put('"');
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support serializing " ~ T.stringof ~ "s!");
			}


			
			static T deserializeValue(T, PT)(ref PT ctx) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T) && isDeserializationContext!PT)
			{
				return cast(T)deserializeValue!(Dequal!T)(ctx);
			}

			static T deserializeValue(T, PT)(ref PT ctx) @safe
				if (!isNativeSerializationSupported!T && is(Dequal!T == T) && isDeserializationContext!PT)
			{
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					T v = T.parse(ctx.current.stringValue);
					ctx.consume();
					return v;
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support deserializing " ~ T.stringof ~ "s!");
			}
		};
	}

public:
	abstract ubyte[] serialize(T)(T val);
	abstract T deserialize(T)(ubyte[] data);
}