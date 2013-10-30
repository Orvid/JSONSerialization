module std.json;

import std.serialization : SerializationFormat;

final class JSONSerializationFormat : SerializationFormat
{
	import std.range : isInputRange, isOutputRange;
	import std.traits : ForeachType;
	import std.traitsExt : Dequal, isOneOf;

	// TODO: Unittest these 2 methods.
	final override ubyte[] serialize(T)(T val) 
	{
		return cast(ubyte[])toJSON(val); 
	}
	final override T deserialize(T)(ubyte[] data)
	{
		return fromJSON!T(cast(string)data); 
	}

	private static void putString(R, S)(R output, S str) @trusted pure
		if (!is(Dequal!S == S) && isOutputRange!(R, string))
	{
		putString(output, cast(Dequal!S)str);
	}
	private static void putString(R, S)(R output, S str) @safe pure
		if (is(Dequal!S == S) && isOneOf!(ForeachType!S, char, wchar, dchar) && isOutputRange!(R, string))
	{
		// TODO: Decode each character individually so it properly supports the full UTF-32 range in UTF-8 strings.
		//       That would allow us to remove the isOneOf constraint in this template's declaration.
		foreach (dchar ch; str)
		{
			putCharacter(output, ch);
		}
	}

	private static void putCharacter(R)(R range, dchar ch) @safe pure
	{
		import std.format : formattedWrite;

		switch (ch)
		{
			case '"':
				range.put(`\"`);
				break;
			case '\\':
				range.put("\\\\");
				break;
			case '/':
				range.put("\\/");
				break;
			case '\b':
				range.put("\\b");
				break;
			case '\f':
				range.put("\\f");
				break;
			case '\n':
				range.put("\\n");
				break;
			case '\r':
				range.put("\\r");
				break;
			case '\t':
				range.put("\\t");
				break;
			case 0x20, 0x21:
			case 0x23: .. case 0x2E:
			case 0x30: .. case 0x5B:
			case 0x5D: .. case 0x7E:
				range.put(ch);
				break;
			default:
				if (ch <= 0xFFFF)
					formattedWrite(range, "\\u%04X", cast(ushort)ch);
				else
					// This is non-standard behaviour, but allows us to (de)serialize dchars.
					formattedWrite(range, "\\x%08X", cast(uint)ch);
				break;
		}
	}

	static void toJSON(Range, T)(Range output, T val) @trusted
		if (!is(Dequal!T == T) && isOutputRange!(Range, string))
	{
		return toJSON(output, cast(Dequal!T)val);
	}
	// TODO: When to!string(float | double | real) becomes safe, remove this.
	static void toJSON(Range, T)(Range output, T val) @trusted
		if (is(Dequal!T == T) && isOneOf!(T, float, double, real) && isOutputRange!(Range, string))
	{
		import std.conv : to;

		output.put(to!string(val));
	}
	// The overload above is designed to reduce the number of times this
	// template is instantiated.
	static void toJSON(Range, T)(Range output, T val) @safe
		if (is(Dequal!T == T) && !isOneOf!(T, float, double, real) && isOutputRange!(Range, string))
	{
		import std.traits : isArray;
		import std.traitsExt : isClass;

		static if (isClass!T)
		{
			if (!val)
				output.put("null");
			static if (is(T == Object))
				output.put("{}");
			else
			{
				ensureSerializable!T();
				ensurePublicConstructor!T();
				output.put('{');
				size_t i = 0;
				foreach (member; __traits(allMembers, T))
				{
					static if (shouldSerializeMember!(T, member))
					{
						import std.traitsExt : getMemberValue;

						if (!shouldSerializeValue!(T, member)(val))
							continue;
						if (i != 0)
							output.put(',');
						output.put(`"` ~ getFinalMemberName!(T, member) ~ `":`);
						toJSON(output, getMemberValue!member(val));
						i++;
					}
				}
				output.put('}');
			}
		}
		else static if (isOneOf!(T, char, wchar, dchar))
		{
			// This may need to change as JSON doesn't support the full UTF8 range in strings by default.
			output.put(`"`);
			putCharacter(output, val);
			output.put(`"`);
		}
		else static if (isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong/*, cent, ucent*/))
		{
			import std.conv : to;

			output.put(to!string(val));
		}
		else static if (is(T == bool))
		{
			output.put(val ? "true" : "false");
		}
		else static if (isArray!T)
		{
			static if (isOneOf!(ForeachType!T, char, wchar, dchar))
			{
				output.put(`"`);
				putString(output, val);
				output.put(`"`);
			}
			else
			{
				output.put('[');
				foreach(i, v; val)
				{
					if (i != 0)
						output.put(',');
					toJSON(output, v);
				}
				output.put(']');
			}
		}
		else
			static assert(0, "Serializing the type '" ~ T.stringof ~ "' to JSON is not yet supported!");
	}

	private enum TokenType
	{
		Unknown,
		String,
		Number,
		LCurl,
		RCurl,
		LSquare,
		RSquare,
		Colon,
		Comma,
		False,
		True,
		Null,
	}

	private struct JSONParser(Range)
		if (isInputRange!(Range, char))
	{
		private struct Token
		{
			TokenType type = TokenType.Unknown;
			string stringValue;
		}
		Range input;
		Token current;

		this(Range inRange)
		{
			input = inRange;
			consume();
		}

		void consume() @safe pure nothrow
		{

		}

	}

	static T fromJSON(T)(string val) @safe pure nothrow
	{
		return T.init;
	}
}

string toJSON(T)(T val) @safe 
{
	import std.range : Appender;

	auto ret = Appender!string();
	JSONSerializationFormat.toJSON(ret, val);
	return ret.data;
}
T fromJSON(T)(string val) @safe pure nothrow { return JSONSerializationFormat.fromJSON!T(val); }

@safe unittest
{
	import std.serialization : nonSerialized, optional, serializeAs, serializable;

	@serializable static class PrivateConstructor { private this() { } @optional int A = 3; int B = 5; }
	assert(!__traits(compiles, { assert(toJSON(new PrivateConstructor()) == `{"B":5}`); }), "A private constructor was allowed for a serializable class!");
	
	static class NonSerializable { @optional int A = 3; int B = 5; }
	assert(!__traits(compiles, { assert(toJSON(new NonSerializable()) == `{"B":5}`); }), "A class not marked with @serializable was allowed!");

	@serializable static class OptionalField { @optional int A = 3; int B = 5; }
	assert(toJSON(new OptionalField()) == `{"B":5}`, "An optional field set to its default value was not excluded!");

	@serializable static class NonSerializedField { int A = 3; @nonSerialized int B = 2; }
	assert(toJSON(new NonSerializedField()) == `{"A":3}`, "A field marked with @nonSerialized was included!");

	@serializable static class SerializeAsField { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
	assert(toJSON(new SerializeAsField()) == `{"A":3,"D":5}`, "A field marked with @serializeAs(`D`) failed to serialize as D!");

	@serializable static class ByteField { byte A = -3; }
	assert(toJSON(new ByteField()) == `{"A":-3}`, "Failed to correctly serialize a byte field!");

	@serializable static class UByteField { ubyte A = 159; }
	assert(toJSON(new UByteField()) == `{"A":159}`, "Failed to correctly serialize a ubyte field!");

	@serializable static class ShortField { short A = -26125; }
	assert(toJSON(new ShortField()) == `{"A":-26125}`, "Failed to correctly serialize a short field!");

	@serializable static class UShortField { ushort A = 65313; }
	assert(toJSON(new UShortField()) == `{"A":65313}`, "Failed to correctly serialize a ushort field!");

	@serializable static class IntField { int A = -2032534342; }
	assert(toJSON(new IntField()) == `{"A":-2032534342}`, "Failed to correctly serialize an int field!");

	@serializable static class UIntField { uint A = 2520041234; }
	assert(toJSON(new UIntField()) == `{"A":2520041234}`, "Failed to correctly serialize a uint field!");

	@serializable static class LongField { long A = -2305393212345134623; }
	assert(toJSON(new LongField()) == `{"A":-2305393212345134623}`, "Failed to correctly serialize a long field!");

	@serializable static class ULongField { ulong A = 4021352154138321354; }
	assert(toJSON(new ULongField()) == `{"A":4021352154138321354}`, "Failed to correctly serialize a ulong field!");

	//@serializable static class CentField { cent A = -23932104152349231532145324134; }
	//assert(toJSON(new CentField()) == `{"A":-23932104152349231532145324134}`, "Failed to correctly serialize a cent field!");

	//@serializable static class UCentField { ucent A = 40532432168321451235829354323; }
	//assert(toJSON(new UCentField()) == `{"A":40532432168321451235829354323}`, "Failed to correctly serialize a ucent field!");

	@serializable static class FloatField { float A = -433200; }
	assert(toJSON(new FloatField()) == `{"A":-433200}`, "Failed to correctly serialize a float field!");

	@serializable static class DoubleField { double A = 3.25432e+53; }
	assert(toJSON(new DoubleField()) == `{"A":3.25432e+53}`, "Failed to correctly serialize a double field!");

	@serializable static class RealField { real A = -2.13954e+104; }
	assert(toJSON(new RealField()) == `{"A":-2.13954e+104}`, "Failed to correctly serialize a real field!");

	@serializable static class CharField { char A = '\x05'; }
	assert(toJSON(new CharField()) == `{"A":"\u0005"}`, "Failed to correctly serialize a char field!");

	@serializable static class WCharField { wchar A = '\u04DA'; }
	assert(toJSON(new WCharField()) == `{"A":"\u04DA"}`, "Failed to correctly serialize a wchar field!");

	@serializable static class DCharField { dchar A = '\U0010FFFF'; }
	assert(toJSON(new DCharField()) == `{"A":"\x0010FFFF"}`, "Failed to correctly serialize a dchar field!");

	@serializable static class StringField { string A = "Hello!\b\"\u08A8\U0010FFFF"; }
	assert(toJSON(new StringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a string field!");

	@serializable static class WStringField { wstring A = "Hello!\b\"\u08A8\U0010FFFF"; }
	assert(toJSON(new WStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wstring field!");

// TODO: Uncomment this once the bug in Mono-D is fixed.
/+
	() @trusted {
		@serializable static class WCharArrayField { wchar[] A = cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w; }
		assert(toJSON(new WCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wchar[] field!");
	}();
+/


	@serializable static class ConstWCharArrayField { const(wchar)[] A = "Hello!\b\"\u08A8\U0010FFFF"w; }
	assert(toJSON(new ConstWCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a const(wchar)[] field!");

	@serializable static class DStringField { dstring A = "Hello!\b\"\u08A8\U0010FFFF"d; }
	assert(toJSON(new DStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a dstring field!");

	@serializable static class FalseBoolField { bool A = false; }
	assert(toJSON(new FalseBoolField()) == `{"A":false}`, "Failed to correctly serialize a bool field set to false!");

	@serializable static class TrueBoolField { bool A = true; }
	assert(toJSON(new TrueBoolField()) == `{"A":true}`, "Failed to correctly serialize a bool field set to true!");

	@serializable static class NullObjectField { Object A = null; }
	assert(toJSON(new NullObjectField()) == `{"A":null}`, "Failed to correctly serialize an Object field set to null!");

	@serializable static class ClassField { SerializeAsField A = new SerializeAsField(); }
	assert(toJSON(new ClassField()) == `{"A":{"A":3,"D":5}}`, "Failed to correctly serialize a class field!");

	@serializable static class ClassArrayField { SerializeAsField[] A = [new SerializeAsField(), new SerializeAsField()]; }
	assert(toJSON(new ClassArrayField()) == `{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`, "Failed to correctly serialize a class array field!");

	@serializable static class IntArrayField { int[] A = [-3, 6, 190]; }
	assert(toJSON(new IntArrayField()) == `{"A":[-3,6,190]}`, "Failed to correctly serialize a int[] field!");
}

enum JSONElementType
{
	unknown,
	array,
	boolean,
	number,
	object,
	string,
}

final class JSONElement
{
private:
	JSONElementType type = JSONElementType.unknown;
	string innerValue;
	
	union
	{
		JSONElement[] arrayValueCache;
		JSONElement[string] objectValueCache;
	}
	
	template jsonElementTypeOf(T)
	{
		import std.traits : isArray, isNumeric, isSomeString;
		
		static if (isArray!T)
			enum jsonElementTypeOf = JSONElementType.array;
		else static if (isNumeric!T)
			enum jsonElementTypeOf = JSONElementType.number;
		else static if (isSomeString!T)
			enum jsonElementTypeOf = JSONElementType.string;
		else static if (is(T == bool))
			enum jsonElementTypeOf = JSONElementType.boolean;
		else
			enum jsonElementTypeOf = JSONElementType.object;
	}

	void ensureObject() @safe pure nothrow
	{
		if (type == JSONElementType.unknown)
			type = JSONElementType.object;
		assert(type == JSONElementType.object);
		if (!objectValueCache && innerValue)
			objectValueCache = fromJSON!(JSONElement[string])(innerValue);
	}

	void ensureArray() @safe pure nothrow
	{
		if (type == JSONElementType.unknown)
			type = JSONElementType.array;
		assert(type == JSONElementType.array);
		if (!arrayValueCache && innerValue)
			arrayValueCache = fromJSON!(JSONElement[])(innerValue);
	}
	
public:
	this(T val, T)()
	{
		innerValue = toJSON!(val);
		type = jsonElementTypeOf!(T);
	}
	this(T)(in T val)
	{
		innerValue = toJSON(val);
		type = jsonElementTypeOf!(T);
	}
	this()()
	{
	}
	
	JSONElement opIndex(size_t i) @safe pure nothrow
	{
		ensureArray();
		return arrayValueCache[i];
	}

	JSONElement opIndex(in string key) @safe pure nothrow
	{
		ensureObject();
		return objectValueCache[key];
	}
	
	JSONElement opIndexAssign(T)(in T val, in string key) @safe pure nothrow
	{
		ensureObject();
		return objectValueCache[key] = new JSONElement(val);
	}
	
	JSONElement opBinary(string op : "in")(in string key) @safe pure nothrow
	{
		ensureObject();
		return key in objectValueCache;
	}
	
	@property T value(T)() @safe pure nothrow
	{
		return fromJSON!T(innerValue);
	}
}


import std.range : isOutputRange;

final class JSONWriter(OutputRange)
	if (isOutputRange!(OutputRange, string))
{
	import std.collections : Stack;
	
private:
	enum WriteContext
	{
		array,
		field,
		object,
	}
	OutputRange output;
	Stack!WriteContext contextStack = new Stack!WriteContext();
	// Believe it or not, we only need a single
	// bool here regardless of how deep the json
	// is, due to the fact that if we've written
	// a value, it's no longer the first element.
	bool firstElement = true;
	
	void checkWriteComma() @safe pure nothrow
	{
		if (!firstElement)
			output.put(",");
	}
	
public:
	this(OutputRange outputRange) @safe pure nothrow
	{
		output = outputRange;
	}
	
	void startObject() @safe pure nothrow
	{
		import std.range : put;
		
		checkWriteComma();
		output.put("{");
		contextStack.push(WriteContext.object);
		firstElement = true;
	}
	
	void endObject() @safe pure nothrow
	{
		import std.range : put;
		
		assert(contextStack.pop() == WriteContext.object, "Tried to end an object while in a non-object context!");
		output.put("}");
		firstElement = false;
	}
	
	void startArray() @safe pure nothrow
	{
		import std.range : put;
		
		checkWriteComma();
		output.put("[");
		contextStack.push(WriteContext.array);
		firstElement = true;
	}
	
	void endArray() @safe pure nothrow
	{
		import std.range : put;
		
		assert(contextStack.pop() == WriteContext.array, "Tried to end an array while in a non-array context!");
		output.put("]");
		firstElement = false;
	}
	
	void startField(string name)() @safe pure nothrow
	{
		import std.range : put;
		
		checkWriteComma();
		output.put(`"` ~ JSONSerializationFormat.EscapeString(name) ~ `":`);
		contextStack.push(WriteContext.field);
		firstElement = true;
	}
	
	void startField(in string name) @safe pure
	{
		import std.range : put;
		
		checkWriteComma();
		output.put(`"`);
		JSONSerializationFormat.putString(output, name);
		output.put(`":`);
		contextStack.push(WriteContext.field);
		firstElement = true;
	}
	
	void endField() @safe pure nothrow
	{
		assert(contextStack.pop() == WriteContext.field, "Tried to end a field while in a non-field context!");
		firstElement = false;
	}
	
	void writeValue(T val, T)() @safe
	{
		checkWriteComma();
		toJSON!(val)(output);
		firstElement = false;
	}
	
	void writeValue(T)(in T val) @safe
	{
		checkWriteComma();
		toJSON(val, output);
		firstElement = false;
	}
	
	void writeField(string field, T val, T)() @safe
	{
		checkWriteComma();
		startField!(field);
		writeValue!(val);
		endField();
		firstElement = false;
	}
	
	void writeField(string field, T)(in T val) @safe
	{
		checkWriteComma();
		startField!(field);
		writeValue(val);
		endField();
		firstElement = false;
	}
	
	void writeField(T)(in string field, in T val) @safe
	{
		checkWriteComma();
		startField(field);
		writeValue(val);
		endField();
		firstElement = false;
	}
}
@safe unittest
{
	import std.range : Appender;

	auto dst = Appender!string();
	auto wtr = new JSONWriter!(Appender!string)(dst);
}