module main;

import std.stdio;
import std.datetime : StopWatch;
import std.datetime : benchmark;
import std.serialization : serializable;
import std.json : toJSON, fromJSON;
import std.conv : to;
import std.range : Appender, isOutputRange;

enum ObjectCount = 100000;

@trusted pure struct CustomStringRange
{
@trusted:
	private char[] mBuffer = ['\0'];
	private size_t nextI = 0;

	private void ensureSpace(size_t len)
	{
		while (nextI + len >= mBuffer.length)
			mBuffer.length = (mBuffer.length ? mBuffer.length : 1) << 1;
	}

	@property string data()
	{
		return cast(string)mBuffer[0..nextI].dup;
	}

	void clear()
	{
		nextI = 0;
		mBuffer[] = 0;
	}

	void put(string str)
	{
		ensureSpace(str.length);
		mBuffer[nextI..str.length + nextI] = str[0..$];
		nextI += str.length;
	}
	
	void put(char[] str)
	{
		ensureSpace(str.length);
		mBuffer[nextI..str.length + nextI] = str[0..$];
		nextI += str.length;
	}
	
	void put(const(char)[] str)
	{
		ensureSpace(str.length);
		mBuffer[nextI..str.length + nextI] = str[0..$];
		nextI += str.length;
	}

	void put(char c)
	{
		ensureSpace(1);
		mBuffer[nextI] = c;
		nextI++;
	}
}
static assert(isOutputRange!(CustomStringRange, string));

void main(string[] args)
{
	@serializable static final class SimpleObject
	{
		int id;
		string name;
		string address;
		int[] scores;

		public static SimpleObject Create(int id)
		{
			import std.random : uniform;

			auto so = new SimpleObject();
			so.id = uniform(0, ObjectCount);
			so.name = "Simple-" ~ to!string(id);
			so.address = "Planet Earth";
			auto scoreCount = uniform(0, 10);
			for (auto i = 0; i < scoreCount; i++)
			{
				// This is a uniform random with a bias torward 0, to produce more realistic
				// data as input.
				so.scores ~= uniform(uniform(int.min, 0), uniform(0, int.max));
			}
			return so;
		}
	}
	string[ObjectCount] stringArray;
	SimpleObject[ObjectCount] sourceArray;
	SimpleObject[ObjectCount] destinationArray;
	for (auto i = 0; i < ObjectCount; i++)
		sourceArray[i] = SimpleObject.Create(i);

	size_t totalPayload = 0;
	StopWatch swSerialize;
	auto ret = CustomStringRange();
	foreach (i, so; sourceArray)
	{
		swSerialize.start();
		toJSON(so, ret);
		swSerialize.stop();
		totalPayload += ret.data.length;
		stringArray[i] = ret.data;
		ret.clear();
	}

	StopWatch swDeserialize;
	foreach (i, str; stringArray)
	{
		swDeserialize.start();
		destinationArray[i] = fromJSON!SimpleObject(str);
		swDeserialize.stop();
	}

	writefln("Took %s ms (%s ms / %s/sec) to serialize 100k SimpleObjects with an average payload of %s bytes (%s).", swSerialize.peek().msecs, cast(real)swSerialize.peek().msecs / ObjectCount, 354, cast(real)totalPayload / ObjectCount, totalPayload);
	writefln("Took %s ms (%s ms / %s/sec) to deserialize 100k SimpleObjects", swDeserialize.peek().msecs, cast(real)swDeserialize.peek().msecs / ObjectCount, cast(real)ObjectCount * (1000.0 / swDeserialize.peek().msecs));
}

