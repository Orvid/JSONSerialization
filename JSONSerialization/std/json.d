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

	private static void putString(R, S)(ref R output, S str) @trusted pure
		if (!is(Dequal!S == S) && isOutputRange!(R, string))
	{
		putString(output, cast(Dequal!S)str);
	}
	private static void putString(R, S)(ref R output, S str) @safe pure
		if (is(Dequal!S == S) && isOneOf!(ForeachType!S, char, wchar, dchar) && isOutputRange!(R, string))
	{
		// TODO: Decode each character individually so it properly supports the full UTF-32 range in UTF-8 strings.
		//       That would allow us to remove the isOneOf constraint in this template's declaration.
		foreach (dchar ch; str)
		{
			putCharacter(output, ch);
		}
	}

	private static void putCharacter(R)(ref R range, dchar ch) @safe pure
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

	static void toJSON(Range, T)(ref Range output, T val) @trusted
		if (!is(Dequal!T == T) && isOutputRange!(Range, string))
	{
		return toJSON(output, cast(Dequal!T)val);
	}
	// TODO: When to!string(float | double | real) becomes safe, remove this.
	static void toJSON(Range, T)(ref Range output, T val) @trusted
		if (is(Dequal!T == T) && isOneOf!(T, float, double, real) && isOutputRange!(Range, string))
	{
		import std.conv : to;

		output.put(to!string(val));
	}
	// The overload above is designed to reduce the number of times this
	// template is instantiated.
	static void toJSON(Range, T)(ref Range output, T val) @safe
		if (is(Dequal!T == T) && !isOneOf!(T, float, double, real) && isOutputRange!(Range, string))
	{
		import std.traits : isArray;
		import std.traitsExt : isClass;

		static if (isClass!T)
		{
			if (!val)
				output.put("null");
			else static if (is(T == Object))
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

	private static struct JSONLexer(Range)
		if (is(Range == string))
	{
		private enum State
		{
			None,
			String,
			Number,
			F_,
			Fa_,
			Fal_,
			Fals_,
			T_,
			Tr_,
			Tru_,
			N_,
			Nu_,
			Nul_,
		}
		static struct Token
		{
			TokenType type = TokenType.Unknown;
			string stringValue;

			string toString()
			{
				import std.conv : to;
				if (type == TokenType.String || type == TokenType.Number)
					return to!string(type) ~ ": " ~ stringValue;
				return to!string(type);
			}
		}
		enum TokenType
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
			EOF,
		}
		Range input;
		Token current;
		@property bool EOF() { return current.type == TokenType.EOF; }

		this(Range inRange)
		{
			input = inRange;
			consume();
		}

		void consume() @safe pure
		{
			size_t curI = 0;
			State curState = State.None;

			while (curI < input.length)
			{
				final switch (curState)
				{
					case State.None:
						switch (input[curI])
						{
							case '{':
								current = Token(TokenType.LCurl);
								goto Return;
							case '}':
								current = Token(TokenType.RCurl);
								goto Return;
							case '[':
								current = Token(TokenType.LSquare);
								goto Return;
							case ']':
								current = Token(TokenType.RSquare);
								goto Return;
							case ':':
								current = Token(TokenType.Colon);
								goto Return;
							case ',':
								current = Token(TokenType.Comma);
								goto Return;

							case 'F', 'f':
								curState = State.F_;
								curI++;
								break;
							case 'T', 't':
								curState = State.T_;
								curI++;
								break;
							case 'N', 'n':
								curState = State.N_;
								curI++;
								break;

							case '"':
								curState = State.String;
								curI++;
								break;

							case '0': .. case '9':
								curState = State.Number;
								curI++;
								break;

							default:
								// TODO: This shouldn't throw an exception.
								throw new Exception("Unknown input '" ~ input[curI] ~ "'!");
						}
						break;
					case State.String:
						if (input[curI] == '\\')
						{
							if (curI + 1 >= input.length)
								throw new Exception("Unexpected EOF");
							curI++;
							curI++;
						}
						else if (input[curI] == '"')
						{
							current = Token(TokenType.String, input[1..curI]);
							goto Return;
						}
						else
							curI++;
						break;
					// TODO TODO TODO TODO TODO: Implement.
					case State.Number:
						switch (input[curI])
						{
							case '0': .. case '9':
								curI++;
								break;

							default:
								current = Token(TokenType.Number, input[0..curI]);
								curI--; // Adjust for the +1 used when we return.
								goto Return;
						}
						break;

					case State.F_:
						if (input[curI] == 'A' || input[curI] == 'a')
						{
							curState = State.Fa_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Fa_:
						if (input[curI] == 'L' || input[curI] == 'l')
						{
							curState = State.Fal_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Fal_:
						if (input[curI] == 'S' || input[curI] == 's')
						{
							curState = State.Fals_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Fals_:
						if (input[curI] == 'E' || input[curI] == 'e')
						{
							current = Token(TokenType.False);
							goto Return;
						}
						else
							throw new Exception("");
						break;

					case State.T_:
						if (input[curI] == 'R' || input[curI] == 'r')
						{
							curState = State.Tr_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Tr_:
						if (input[curI] == 'U' || input[curI] == 'u')
						{
							curState = State.Tru_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Tru_:
						if (input[curI] == 'E' || input[curI] == 'e')
						{
							current = Token(TokenType.True);
							goto Return;
						}
						else
							throw new Exception("");
						break;

					case State.N_:
						if (input[curI] == 'U' || input[curI] == 'u')
						{
							curState = State.Nu_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Nu_:
						if (input[curI] == 'L' || input[curI] == 'l')
						{
							curState = State.Nul_;
							curI++;
						}
						else
							throw new Exception("");
						break;
					case State.Nul_:
						if (input[curI] == 'L' || input[curI] == 'l')
						{
							current = Token(TokenType.Null);
							goto Return;
						}
						else
							throw new Exception("");
						break;
				}
			}
			if (curState != State.None)
				throw new Exception("Unexpected EOF!");
			current = Token(TokenType.EOF);
			return;

		Return:
			input = input[curI + 1..$];
		}

	}

	private static T deserializeValue(T, PT)(ref PT parser) @safe pure
	{	
		alias TokenType = PT.TokenType;
		void expect(TokenTypes...)() @safe
		{
			switch (parser.current.type)
			{
				foreach (tp; TokenTypes)
				{
					case tp:
						return;
				}
				default:
					throw new Exception("Unexpected token!");// `" ~ to!string(parser.current.type) ~ "`!"); // TODO: Make more descriptive
			}
		}
		
		import std.traits : isArray;
		import std.traitsExt : isClass;
		
		static if (isClass!T)
		{
			if (parser.current.type == TokenType.Null)
			{
				parser.consume();
				return null;
			}
			ensureSerializable!T();
			ensurePublicConstructor!T();
			T parsedValue = new T();// TODO: constructDefault!T;
			expect!(TokenType.LCurl);
			parser.consume();
			// TODO: Deal with Optional fields, and ensure all required fields
			// have been deserialized.
			while (parser.current.type == TokenType.String)
			{
				switch (parser.current.stringValue)
				{
					foreach (member; __traits(allMembers, T))
					{
						static if (shouldSerializeMember!(T, member))
						{
							import std.traitsExt : MemberType, setMemberValue;

							case getFinalMemberName!(T, member):
								parser.consume();
								expect!(TokenType.Colon);
								parser.consume();
								setMemberValue!member(parsedValue, deserializeValue!(MemberType!(T, member))(parser));
								goto ExitSwitch;
						}
					}

					default:
						throw new Exception("Unknown member '" ~ parser.current.stringValue ~ "'!");
				}

				// TODO: Make this invalid if it's the last property.
			ExitSwitch:
				if (parser.current.type == TokenType.Comma)
					parser.consume();
			}
			expect!(TokenType.RCurl);
			parser.consume();
			return parsedValue;
		}
		else static if (isOneOf!(T, char, wchar, dchar))
		{
			static assert(0);
			// Characters
		}
		else static if (isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong/*, cent, ucent*/, float, double, real))
		{
			import std.conv : to;

			expect!(TokenType.Number);
			T val = to!T(parser.current.stringValue);
			parser.consume();
			return val;
		}
		else static if (is(T == bool))
		{
			expect!(TokenType.True, TokenType.False);
			bool ret = parser.current.type == TokenType.True;
			parser.consume();
			return ret;
		}
		else static if (isArray!T)
		{
			static assert(0);
			static if (isOneOf!(ForeachType!T, char, wchar, dchar))
			{
				// String
			}
			else
			{
				// Normal Array
			}
		}
		else
			static assert(0, "Serializing the type '" ~ T.stringof ~ "' to JSON is not yet supported!");
		return T.init;
	}

	static T fromJSON(T)(string val) @safe
	{
		auto parser = JSONLexer!string(val);

		return deserializeValue!T(parser);
	}
}

string toJSON(T)(T val) @safe 
{
	import std.range : Appender;

	auto ret = Appender!string();
	JSONSerializationFormat.toJSON(ret, val);
	return ret.data;
}
T fromJSON(T)(string val) @safe { return JSONSerializationFormat.fromJSON!T(val); }

@safe unittest
{
	import std.algorithm : equal;
	import std.conv : to;
	import std.serialization : nonSerialized, optional, serializeAs, serializable;

	@serializable static class PrivateConstructor { private this() { } @optional int A = 3; int B = 5; }
	static assert(!__traits(compiles, { assert(toJSON(new PrivateConstructor()) == `{"B":5}`); }), "A private constructor was allowed for a serializable class!");
	
	static class NonSerializable { @optional int A = 3; int B = 5; }
	static assert(!__traits(compiles, { assert(toJSON(new NonSerializable()) == `{"B":5}`); }), "A class not marked with @serializable was allowed!");

	@serializable static class OptionalField { @optional int A = 3; int B = 5; }
	static assert(toJSON(new OptionalField()) == `{"B":5}`, "An optional field set to its default value was not excluded!");

	@serializable static class NonSerializedField { int A = 3; @nonSerialized int B = 2; }
	static assert(toJSON(new NonSerializedField()) == `{"A":3}`, "A field marked with @nonSerialized was included!");

	@serializable static class SerializeAsField { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
	static assert(toJSON(new SerializeAsField()) == `{"A":3,"D":5}`, "A field marked with @serializeAs(`D`) failed to serialize as D!");

	@serializable static class ByteField { byte A = -3; }
	static assert(toJSON(new ByteField()) == `{"A":-3}`, "Failed to correctly serialize a byte field!");

	@serializable static class UByteField { ubyte A = 159; }
	static assert(toJSON(new UByteField()) == `{"A":159}`, "Failed to correctly serialize a ubyte field!");

	@serializable static class ShortField { short A = -26125; }
	static assert(toJSON(new ShortField()) == `{"A":-26125}`, "Failed to correctly serialize a short field!");

	@serializable static class UShortField { ushort A = 65313; }
	static assert(toJSON(new UShortField()) == `{"A":65313}`, "Failed to correctly serialize a ushort field!");

	@serializable static class IntField { int A = -2032534342; }
	static assert(toJSON(new IntField()) == `{"A":-2032534342}`, "Failed to correctly serialize an int field!");

	@serializable static class UIntField { uint A = 2520041234; }
	static assert(toJSON(new UIntField()) == `{"A":2520041234}`, "Failed to correctly serialize a uint field!");

	@serializable static class LongField { long A = -2305393212345134623; }
	static assert(toJSON(new LongField()) == `{"A":-2305393212345134623}`, "Failed to correctly serialize a long field!");

	@serializable static class ULongField { ulong A = 4021352154138321354; }
	static assert(toJSON(new ULongField()) == `{"A":4021352154138321354}`, "Failed to correctly serialize a ulong field!");

	//@serializable static class CentField { cent A = -23932104152349231532145324134; }
	//static assert(toJSON(new CentField()) == `{"A":-23932104152349231532145324134}`, "Failed to correctly serialize a cent field!");

	//@serializable static class UCentField { ucent A = 40532432168321451235829354323; }
	//static assert(toJSON(new UCentField()) == `{"A":40532432168321451235829354323}`, "Failed to correctly serialize a ucent field!");

	@serializable static class FloatField { float A = -433200; }
	static assert(toJSON(new FloatField()) == `{"A":-433200}`, "Failed to correctly serialize a float field!");

	@serializable static class DoubleField { double A = 3.25432e+53; }
	static assert(toJSON(new DoubleField()) == `{"A":3.25432e+53}`, "Failed to correctly serialize a double field!");

	@serializable static class RealField { real A = -2.13954e+104; }
	static assert(toJSON(new RealField()) == `{"A":-2.13954e+104}`, "Failed to correctly serialize a real field!");

	@serializable static class CharField { char A = '\x05'; }
	static assert(toJSON(new CharField()) == `{"A":"\u0005"}`, "Failed to correctly serialize a char field!");

	@serializable static class WCharField { wchar A = '\u04DA'; }
	static assert(toJSON(new WCharField()) == `{"A":"\u04DA"}`, "Failed to correctly serialize a wchar field!");

	@serializable static class DCharField { dchar A = '\U0010FFFF'; }
	static assert(toJSON(new DCharField()) == `{"A":"\x0010FFFF"}`, "Failed to correctly serialize a dchar field!");

	@serializable static class StringField { string A = "Hello!\b\"\u08A8\U0010FFFF"; }
	static assert(toJSON(new StringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a string field!");

	@serializable static class WStringField { wstring A = "Hello!\b\"\u08A8\U0010FFFF"; }
	static assert(toJSON(new WStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wstring field!");

	() @trusted {
		@serializable static class WCharArrayField { wchar[] A = cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w; }
		static assert(toJSON(new WCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wchar[] field!");
	}();

	@serializable static class ConstWCharArrayField { const(wchar)[] A = "Hello!\b\"\u08A8\U0010FFFF"w; }
	static assert(toJSON(new ConstWCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a const(wchar)[] field!");

	@serializable static class DStringField { dstring A = "Hello!\b\"\u08A8\U0010FFFF"d; }
	static assert(toJSON(new DStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a dstring field!");

	@serializable static class FalseBoolField { bool A; auto Init() { A = false; return this; } }
	static assert(toJSON((new FalseBoolField()).Init()) == `{"A":false}`, "Failed to correctly serialize a bool field set to false!");
	static assert(fromJSON!FalseBoolField(`{"A":false}`).A == false, "Failed to correctly deserialize a bool field set to false!");

	@serializable static class TrueBoolField { bool A; auto Init() { A = true; return this; } }
	static assert(toJSON((new TrueBoolField()).Init()) == `{"A":true}`, "Failed to correctly serialize a bool field set to true!");
	static assert(fromJSON!TrueBoolField(`{"A":true}`).A == true, "Failed to correctly deserialize a bool field set to true!");

	@serializable static class NullObjectField { Object A = null; }
	static assert(toJSON(new NullObjectField()) == `{"A":null}`, "Failed to correctly serialize an Object field set to null!");
	static assert(fromJSON!NullObjectField(`{"A":null}`).A is null, "Failed to correctly deserialize an Object field set to null!"); 

	@serializable static class ClassField { SerializeAsField A = new SerializeAsField(); }
	static assert(toJSON(new ClassField()) == `{"A":{"A":3,"D":5}}`, "Failed to correctly serialize a class field!");
	static assert(() {
		auto cfa = fromJSON!ClassField(`{"A":{"A":3,"D":5}}`);
		assert(cfa.A);
		assert(cfa.A.A == 3);
		assert(cfa.A.B == 5);
		return true;
	}(), "Failed to correctly deserialize a class field!");

	@serializable static class ClassArrayField { SerializeAsField[] A = [new SerializeAsField(), new SerializeAsField()]; }
	static assert(toJSON(new ClassArrayField()) == `{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`, "Failed to correctly serialize a class array field!");

	@serializable static class IntArrayField { int[] A = [-3, 6, 190]; }
	static assert(toJSON(new IntArrayField()) == `{"A":[-3,6,190]}`, "Failed to correctly serialize a int[] field!");


}

version (none)
{
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
}