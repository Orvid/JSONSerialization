module std.serialization.json;

import std.range : isOutputRange;
import std.serialization : BinaryOutputRange, SerializationFormat;

// TODO: Add support for associative arrays.
// TODO: Add support for unions.
// TODO: Add support for Tuple's.
// TODO: Add support for private members.
// TODO: Provide a nice error message when trying to deserialize a member marked as nonSerialized.
final class JSONSerializationFormat : SerializationFormat
{
	import std.range : isInputRange;
	import std.traits : ForeachType, isArray;
	import std.traitsExt : constructDefault, Dequal, isClass, isStruct, isOneOf;

//	// TODO: Unittest these 2 methods.
//	final override ubyte[] serialize(T)(T val) 
//	{
//		return cast(ubyte[])toJSON(val); 
//	}
	final override T deserialize(T)(ubyte[] data)
	{
		return fromJSON!T(cast(string)data); 
	}

	template isNativeSerializationSupported(T)
	{
		static if (is(Dequal!T == T))
		{
			static if (isDynamicType!T)
				enum isNativeSerializationSupported = true;
			else static if (isArray!T)
				enum isNativeSerializationSupported = isNativeSerializationSupported!(ForeachType!T);
			else static if (isSerializable!T)
			{
				enum isNativeSerializationSupported =
					   isClass!T
					|| isStruct!T
					|| isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong/*, cent, ucent*/)
					|| isOneOf!(T, float, double, real)
					|| is(T == bool)
					|| isOneOf!(T, char, wchar, dchar)
				;
			}
			else
				enum isNativeSerializationSupported = false;
		}
		else
		{
			enum isNativeSerializationSupported = false;
		}
	}

	static struct InnerFunStuff(OR)
		if (isOutputRange!(OR, ubyte[]))
	{
		// TODO: Why must D be a pain at times....
		mixin(BaseSerializationMembers!());

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe
			if (isNativeSerializationSupported!T && (isClass!T || isStruct!T) && !isDynamicType!T)
		{
			static if (isClass!T)
			{
				if (!val)
				{
					output.put("null");
					return;
				}
				else static if (is(T == Object))
				{
					output.put("{}");
					return;
				}
			}
			ensurePublicConstructor!T();
			output.put('{');
			size_t i = 0;
			foreach (member; membersToSerialize!T)
			{
				import std.traitsExt : getMemberValue;
				
				if (!shouldSerializeValue!(T, member)(val))
					continue;
				if (i != 0)
					output.put(',');
				output.put(`"` ~ getFinalMemberName!(T, member) ~ `":`);
				serialize(output, getMemberValue!member(val));
				i++;
			}
			output.put('}');
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @trusted
			if (isNativeSerializationSupported!T && isDynamicType!T)
		{
			if (val.isTypeBoolean)
				serialize(output, cast(bool)val);
			else if (val.isTypeString)
				serialize(output, cast(string)val);
			else if (val.isTypeArray)
			{
				output.put('[');
				for (size_t i = 0; i < cast(size_t)val.length; i++)
				{
					if (i != 0)
						output.put(',');
					serialize(output, val[i]);
				}
				output.put(']');
			}
			else if (val.isTypeObject)
			{
				if (!val)
					output.put("null");
				else
				{
					output.put('{');
					size_t i = 0;
					foreach (k, v; val)
					{
						if (i != 0)
							output.put(',');
						serialize(output, k);
						output.put(':');
						serialize(output, v);
						i++;
					}
					output.put('}');
				}
			}
			else if (val.isTypeNumeric)
			{
				if (val.isTypeIntegral)
					serialize(output, cast(long)val);
				else
					serialize(output, cast(real)val);
			}
			else
				output.put(`"<unknown>"`);
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe
			if (isNativeSerializationSupported!T && isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong/*, cent, ucent*/))
		{
			import std.performance.conv : to;
			
			val.to!string(output);
		}

		// TODO: When to!string(float | double | real) becomes safe, make this safe.
		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @trusted
			if (isNativeSerializationSupported!T && isOneOf!(T, float, double, real))
		{
			import std.string : format;

			if (cast(T)cast(long)val == val)
				serialize(output, cast(long)val);
			else
				output.put(format("%.17f", val));
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe pure nothrow
			if (isNativeSerializationSupported!T && is(T == bool))
		{
			output.put(val ? "true" : "false");
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR outputRange, T val, bool writeQuotes = true) @safe
			if (isNativeSerializationSupported!T && isOneOf!(T, char, wchar, dchar))
		{
			import std.format : formattedWrite;
			
			if (writeQuotes)
				outputRange.put('"');
			switch (val)
			{
				case '"':
					outputRange.put(`\"`);
					break;
				case '\\':
					outputRange.put("\\\\");
					break;
				case '/':
					outputRange.put("\\/");
					break;
				case '\b':
					outputRange.put("\\b");
					break;
				case '\f':
					outputRange.put("\\f");
					break;
				case '\n':
					outputRange.put("\\n");
					break;
				case '\r':
					outputRange.put("\\r");
					break;
				case '\t':
					outputRange.put("\\t");
					break;
				case 0x20, 0x21:
				case 0x23: .. case 0x2E:
				case 0x30: .. case 0x5B:
				case 0x5D: .. case 0x7E:
					outputRange.put(cast(char)val);
					break;
				default:
					if (val <= 0xFFFF)
						formattedWrite(outputRange, "\\u%04X", cast(ushort)val);
					else
						// NOTE: This is non-standard behaviour, but allows us to (de)serialize dchars.
						formattedWrite(outputRange, "\\x%08X", cast(uint)val);
					break;
			}
			if (writeQuotes)
				outputRange.put('"');
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe pure
			if (isNativeSerializationSupported!T && isArray!T && isOneOf!(ForeachType!T, char, wchar, dchar))
		{
			import std.performance.conv : to;

			static bool isAscii(S)(S str) @safe pure nothrow
			{
				foreach (ch; str)
				{
					switch (ch)
					{
						case 0x20, 0x21:
						case 0x23: .. case 0x2E:
						case 0x30: .. case 0x5B:
						case 0x5D: .. case 0x7E:
							break;
						default:
							return false;
					}
				}
				return true;
			}

			output.put('"');
			if (isAscii(val))
				output.put(to!string(val));
			else
			{
				foreach (dchar ch; val)
				{
					serialize(output, ch, false);
				}
			}
			output.put('"');
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe
			if (isNativeSerializationSupported!T && isArray!T && !isOneOf!(ForeachType!T, char, wchar, dchar))
		{
			output.put('[');
			foreach(i, v; val)
			{
				if (i != 0)
					output.put(',');
				serialize(output, v);
			}
			output.put(']');
		}
	}


	// TODO: Why must D be a pain at times....
	mixin(BaseDeserializationMembers!());

	// TODO: Implement the generic input range based version.
	@deserializationContext private static struct JSONLexer(Range)
		if (is(Range == string))
	{
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
			Unknown = 1 << 0,
			String = 1 << 1,
			Number = 1 << 2,
			LCurl = 1 << 3,
			RCurl = 1 << 4,
			LSquare = 1 << 5,
			RSquare = 1 << 6,
			Colon = 1 << 7,
			Comma = 1 << 8,
			False = 1 << 9,
			True = 1 << 10,
			Null = 1 << 11,
			EOF = 1 << 12,
		}
		Range input;
		Token current;
		@property bool EOF() { return current.type == TokenType.EOF; }
		
		this(Range inRange)
		{
			input = inRange;
			// Check for UTF-8 headers.
			if (input.length >= 3 && input[0..3] == x"EF BB BF")
				input = input[3..$];
			// TODO: Check for other UTF versions
			consume();
		}
		
		void expect(TokenTypes...)() @safe
		{
			debug import std.conv : to;
			import std.algorithm : reduce;

			// This right here is the reason the token types are flags;
			// it allows us to do a single direct branch, even for multiple
			// possible token types.
			enum expectedFlags = reduce!((a, b) => cast(ushort)a | cast(ushort)b)(0, [TokenTypes]);
			if ((current.type | expectedFlags) == expectedFlags)
				return;

			debug
				throw new Exception("Unexpected token! `" ~ to!string(current.type) ~ "`!");
			else
				throw new Exception("Unexpected token!"); // TODO: Make more descriptive
		}
		
		void consume() @safe pure
		{
		Restart:
			if (!input.length)
			{
				current = Token(TokenType.EOF);
				return;
			}

			size_t curI = 0;
			while (curI < input.length)
			{
				switch (input[curI])
				{
					case ' ', '\t', '\v', '\r', '\n':
						input = input[1..$];
						goto Restart;
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
						curI++;
						if (input[curI] != 'a' && input[curI] != 'A')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'l' && input[curI] != 'L')
							goto IdentifierError;
						curI++;
						if (input[curI] != 's' && input[curI] != 'S')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'e' && input[curI] != 'E')
							goto IdentifierError;
						current = Token(TokenType.False);
						goto Return;

					case 'T', 't':
						curI++;
						if (input[curI] != 'r' && input[curI] != 'R')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'u' && input[curI] != 'U')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'e' && input[curI] != 'E')
							goto IdentifierError;
						current = Token(TokenType.True);
						goto Return;

					case 'N', 'n':
						curI++;
						if (input[curI] != 'u' && input[curI] != 'U')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'l' && input[curI] != 'L')
							goto IdentifierError;
						curI++;
						if (input[curI] != 'l' && input[curI] != 'L')
							goto IdentifierError;
						current = Token(TokenType.Null);
						goto Return;
						
					case '"':
						curI++;
						while (curI < input.length)
						{
							// TODO: Make this a switch statement for readability once DMD auto-expands small
							//       switch statements to if-else chains.
							if (input[curI] == '\\')
							{
								// This loop will end if we just passed
								// the end of the file, and throw an EOF
								// exception for us.
								curI += 2;
							}
							else if (input[curI] == '"')
							{
								current = Token(TokenType.String, input[1..curI]);
								goto Return;
							}
							else
								curI++;
						}
						goto EOF;
						
					case '-', '+':
					case '0': .. case '9':
						curI++;
						while (curI < input.length)
						{
							switch (input[curI])
							{
								case 'E', 'e', '+', '-', '.':
								case '0': .. case '9':
									curI++;
									break;
									
								default:
									current = Token(TokenType.Number, input[0..curI]);
									curI--; // Adjust for the +1 used when we return.
									goto Return;
							}
						}
						goto EOF;
						
					default:
						throw new Exception("Unknown input '" ~ input[curI] ~ "'!");
					IdentifierError:
						throw new Exception("Unknown identifier!");
					EOF:
						throw new Exception("Unexpected EOF!");
				}
			}
			
		Return:
			input = input[curI + 1..$];
		}
	}
	
	private static C getCharacter(C)(ref string input) @safe pure
		if (isOneOf!(C, char, wchar, dchar))
	in
	{
		assert(input.length > 0);
	}
	body
	{
		import std.conv : to;
		
		size_t readLength = 0;
		dchar decoded = '\0';
		
		if (input[0] == '\\')
		{
			if (input.length < 2)
				throw new Exception("Unexpected EOF!");
			switch (input[1])
			{
				case '\\':
				case '/':
				case '"':
					decoded = input[1];
					readLength += 2;
					break;
				case 'B', 'b':
					decoded = '\b';
					readLength += 2;
					break;
				case 'F', 'f':
					decoded = '\f';
					readLength += 2;
					break;
				case 'N', 'n':
					decoded = '\n';
					readLength += 2;
					break;
				case 'R', 'r':
					decoded = '\r';
					readLength += 2;
					break;
				case 'T', 't':
					decoded = '\t';
					readLength += 2;
					break;
					
				case 'U', 'u':
					if (input.length < 6)
						throw new Exception("Unexpected EOF!");
					decoded = to!dchar(to!wchar(to!ushort(input[2..6], 16)));
					readLength += 6;
					break;
				case 'X', 'x':
					if (input.length < 10)
						throw new Exception("Unexpected EOF!");
					decoded = to!dchar(to!uint(input[2..10], 16));
					readLength += 10;
					break;
				default:
					// REVIEW: Should we go for spec complaince (invalid) or for the ability to handle invalid input?
					version(none)
					{
						// Spec Compliance
						throw new Exception("Unknown escape sequence!");
					}
					else
					{
						// Unknown escape sequence, so use the character
						// immediately following the backslash as a literal.
						decoded = input[1];
						readLength += 2;
						break;
					}
			}
		}
		else
		{
			readLength++;
			decoded = input[0];
		}
		
		
		input = input[readLength..$];
		return to!C(decoded);
	}

	private static T deserializeValue(T, PT)(ref PT parser) @safe
		if (isNativeSerializationSupported!T && isDynamicType!T)
	{
		return deserializeValue!T(parser, (name, val) => val);
	}

	private static T deserializeValue(T, PT)(ref PT parser, T delegate(string, T) callback) @trusted
		if (isNativeSerializationSupported!T && isDynamicType!T)
	{
		import std.performance.conv : to;
		import std.performance.string : contains;

		alias TokenType = PT.TokenType;
		T v;

		switch (parser.current.type)
		{
			case TokenType.LCurl:
				parser.consume();
				T[string] tmp;
				v = tmp;
				bool first = true;
				if (parser.current.type != TokenType.RCurl) do
				{
					if (!first) // The fact we've got here means the current token MUST be a comma.
						parser.consume();
					
					parser.expect!(TokenType.String);
					string fieldName = parser.current.stringValue;
					parser.consume();
					parser.expect!(TokenType.Colon);
					parser.consume();
					T tmpVal = deserializeValue!T(parser);
					v[fieldName] = callback(fieldName, tmpVal);

					first = false;
				} while (parser.current.type == TokenType.Comma);
				
				parser.expect!(TokenType.RCurl);
				parser.consume();
				break;
			case TokenType.LSquare:
				parser.consume();
				string[] tmp;
				v = tmp;
				size_t i = 0;
				if (parser.current.type != TokenType.RSquare) do
				{
					if (i != 0) // The fact we got here means that the current token MUST be a comma.
						parser.consume();

					v[i] = deserializeValue!T(parser);
					i++;
				} while (parser.current.type == TokenType.Comma);
				parser.expect!(TokenType.RSquare);
				parser.consume();
				break;
			case TokenType.Number:
				if (parser.current.stringValue.contains!('.'))
					v = to!real(parser.current.stringValue);
				else
					v = to!long(parser.current.stringValue);
				parser.consume();
				break;
			case TokenType.String:
				string strVal = parser.current.stringValue;
				if (strVal.contains!('\\'))
				{
					dchar[] dst = new dchar[strVal.length];
					size_t i;
					while (strVal.length > 0)
					{
						dst[i] = getCharacter!dchar(strVal);
						i++;
					}
					
					strVal = to!string(dst[0..i]);
				}
				v = strVal;
				parser.consume();
				break;
			case TokenType.True:
				parser.consume();
				v = true;
				break;
			case TokenType.False:
				parser.consume();
				v = false;
				break;
			case TokenType.Null:
				parser.consume();
				v = null;
				break;

			default:
				throw new Exception("Unknown token type!");
		}
		return callback("", v);
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @trusted
		if (isNativeSerializationSupported!T && (isClass!T || isStruct!T) && !isDynamicType!T)
	{
		alias TokenType = PT.TokenType;
		
		if (parser.current.type == TokenType.Null)
		{
			parser.consume();
			return T.init;
		}
		else if (parser.current.type == TokenType.String)
		{
			import std.performance.string : equal;

			// TODO: Support classes/structs with toString & parse methods.
			if (parser.current.stringValue.equal!("null", false))
			{
				parser.consume();
				return T.init;
			}
		}

		ensurePublicConstructor!T();
		T parsedValue = constructDefault!T();
		auto serializedFields = SerializedFieldSet!T();
		bool first = true;
		parser.expect!(TokenType.LCurl);
		parser.consume();
		if (parser.current.type != TokenType.RCurl) do
		{
			if (!first) // The fact we've got here means the current token MUST be a comma.
				parser.consume();
			
			parser.expect!(TokenType.String);
			switch (parser.current.stringValue)
			{
				foreach (member; membersToSerialize!T)
				{
					import std.traitsExt : MemberType, setMemberValue;
					
					case getFinalMemberName!(T, member):
					parser.consume();
					parser.expect!(TokenType.Colon);
					parser.consume();
					setMemberValue!member(parsedValue, deserializeValue!(MemberType!(T, member))(parser));
					serializedFields.markSerialized!(member);
					goto ExitSwitch;
				}
				
				default:
					throw new Exception("Unknown member '" ~ parser.current.stringValue ~ "'!");
			}
			
		ExitSwitch:
			first = false;
			continue;
		} while (parser.current.type == TokenType.Comma);

		parser.expect!(TokenType.RCurl);
		parser.consume();
		
		serializedFields.ensureFullySerialized();
		return parsedValue;
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @trusted
		if (isNativeSerializationSupported!T && isOneOf!(T, char, wchar, dchar))
	{
		alias TokenType = PT.TokenType;
		
		parser.expect!(TokenType.String);
		string strVal = parser.current.stringValue;
		T val = getCharacter!T(strVal);
		assert(strVal.length == 0, "Data still remaining after parsing a character!");
		parser.consume();
		return val;
	}

	private static T deserializeValue(T, PT)(ref PT parser) @safe pure
		if (isNativeSerializationSupported!T && isOneOf!(T, float, double, real))
	{
		alias TokenType = PT.TokenType;
		
		import std.conv : to;
		
		parser.expect!(TokenType.Number, TokenType.String);
		T val = to!T(parser.current.stringValue);
		parser.consume();
		return val;
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @safe pure
		if (isNativeSerializationSupported!T && isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong/*, cent, ucent*/))
	{
		alias TokenType = PT.TokenType;

		import std.performance.conv : parse;
		
		parser.expect!(TokenType.Number, TokenType.String);
		T val = parse!T(parser.current.stringValue);
		parser.consume();
		return val;
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @safe pure
		if (isNativeSerializationSupported!T && is(T == bool))
	{
		alias TokenType = PT.TokenType;

		bool ret;
		parser.expect!(TokenType.True, TokenType.False, TokenType.String);
		if (parser.current.type == TokenType.String)
		{
			import std.performance.string : equal;

			if (parser.current.stringValue.equal!("true", false))
				ret = true;
			else if (parser.current.stringValue.equal!("false", false))
				ret = false;
			else
				throw new Exception("Invalid string for a boolean!");
		}
		else
			ret = parser.current.type == TokenType.True;
		parser.consume();
		return ret;
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @trusted
		if (isNativeSerializationSupported!T && isArray!T && isOneOf!(ForeachType!T, char, wchar, dchar))
	{
		alias TokenType = PT.TokenType;

		import std.performance.string : contains;
		import std.conv : to;
		
		parser.expect!(TokenType.String);
		string strVal = parser.current.stringValue;
		T val;
		// TODO: Account for strings that are part of a larger string, as well as strings that
		//       can be unescaped in-place. Also look into using alloca to allocate the required
		//       space on the stack for the intermediate string representation.
		if (!strVal.contains!('\\'))
		{
			val = to!T(strVal);
		}
		else
		{
			dchar[] dst = new dchar[strVal.length];
			size_t i;
			while (strVal.length > 0)
			{
				dst[i] = getCharacter!dchar(strVal);
				i++;
			}
			
			val = to!T(dst[0..i]);
		}
		
		parser.consume();
		return val;
	}
	
	private static T deserializeValue(T, PT)(ref PT parser) @safe
		if (isNativeSerializationSupported!T && isArray!T && !isOneOf!(ForeachType!T, char, wchar, dchar))
	{
		alias TokenType = PT.TokenType;
		
		parser.expect!(TokenType.LSquare);
		parser.consume();

		// Due to the fact most arrays in JSON will
		// be fairly small arrays, not 4-8k elements,
		// just appending to an existing array is the
		// fastest way to do this.
		T arrVal;
		bool first = true;
		
		if (parser.current.type != TokenType.RSquare) do
		{
			if (!first) // The fact we got here means that the current token MUST be a comma.
				parser.consume();
			
			arrVal ~= deserializeValue!(ForeachType!T)(parser);
			first = false;
		} while (parser.current.type == TokenType.Comma);
		
		parser.expect!(TokenType.RSquare);
		parser.consume();
		
		return arrVal;
	}
	
	static T fromJSON(T)(string val) @safe
	{
		auto parser = JSONLexer!string(val);

		auto v = deserializeValue!T(parser);
		assert(parser.current.type == JSONLexer!string.TokenType.EOF);
		return v;
	}

	static T fromJSON(T)(string val, T delegate(string name, T val) callback) @safe
		if (isDynamicType!T)
	{
		auto parser = JSONLexer!string(val);
		
		auto v = deserializeValue!T(parser, callback);
		assert(parser.current.type == JSONLexer!string.TokenType.EOF);
		return v;
	}
}

void toJSON(T, OR)(T val, ref OR buf) @safe
	if (isOutputRange!(OR, ubyte[]))
{
	auto bor = BinaryOutputRange!OR(buf);
	JSONSerializationFormat.InnerFunStuff!(OR).serialize(bor, val);
	buf = bor.innerRange;
}

string toJSON(T)(T val) @trusted 
{
	import std.performance.array : Appender;

	auto ret = BinaryOutputRange!(Appender!(ubyte[]))();
	ret.put(""); // This ensures everything is initialized.
	JSONSerializationFormat.InnerFunStuff!(Appender!(ubyte[])).serialize(ret, val);
	return cast(string)ret.data;
}
T fromJSON(T)(string val) @safe 
{
	return JSONSerializationFormat.fromJSON!T(val); 
}
T fromJSON(T)(string val, T delegate(string name, T val) callback)
	if (SerializationFormat.isDynamicType!T)
{
	return JSONSerializationFormat.fromJSON!T(val, callback);
}

@safe unittest
{
	import std.serialization : runSerializationTests, Test;

	runSerializationTests!(string, toJSON, fromJSON, [
		Test.PrivateConstructor: [`{"B":5}`],
		Test.NonSerializable: [`{"B":5}`],
		Test.OptionalField: [`{"B":5}`],
		Test.NonSerializedField: [`{"A":3}`],
		Test.SerializeAsField: [`{"A":3,"D":5}`],
		Test.ByteField: [`{"A":-3}`, `{"A":"-3"}`],
		Test.UByteField: [`{"A":159}`, `{"A":"159"}`],
		Test.ShortField: [`{"A":-26125}`, `{"A":"-26125"}`],
		Test.UShortField: [`{"A":65313}`, `{"A":"65313"}`],
		Test.IntField: [`{"A":-2032534342}`, `{"A":"-2032534342"}`],
		Test.UIntField: [`{"A":2520041234}`, `{"A":"2520041234"}`],
		Test.LongField: [`{"A":-2305393212345134623}`, `{"A":"-2305393212345134623"}`],
		Test.ULongField: [`{"A":4021352154138321354}`, `{"A":"4021352154138321354"}`],
		Test.CentField: [`{"A":-23932104152349231532145324134}`, `{"A":"-23932104152349231532145324134"}`],
		Test.UCentField: [`{"A":40532432168321451235829354323}`, `{"A":"40532432168321451235829354323"}`],
		Test.FloatField: [`{"A":-433200}`, `{"A":"-433200"}`],
		Test.DoubleField: [`{"A":3.25432e+53}`, `{"A":"3.25432e+53"}`],
		Test.RealField: [`{"A":-2.13954e+104}`, `{"A":"-2.13954e+104"}`],
		Test.CharField: [`{"A":"\u0005"}`],
		Test.WCharField: [`{"A":"\u04DA"}`],
		Test.DCharField: [`{"A":"\x0010FFFF"}`],
		Test.StringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.WStringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.WCharArrayField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.ConstWCharArrayField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.DStringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.FalseBoolField: [`{"A":false}`, `{"A":"false"}`],
		Test.TrueBoolField: [`{"A":true}`, `{"A":"true"}`, `{"A":"True"}`, `{"A":"tRUe"}`],
		Test.NullObjectField: [`{"A":null}`, `{"A":"null"}`],
		Test.ClassField: [`{"A":{"A":3,"D":5}}`],
		Test.ClassArrayField: [`{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`],
		Test.IntArrayField: [`{"A":[-3,6,190]}`],
		Test.StructParent: [`{"A":3}`],
		Test.StructField: [`{"A":{"A":3}}`],
		Test.ParsableClassField: [`{"A":"3"}`],
		Test.EnumField: [`{"A":"valB"}`],
	])();
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
