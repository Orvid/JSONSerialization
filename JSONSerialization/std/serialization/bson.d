module std.serialization.bson;

import std.range : isOutputRange;
import std.serialization : SerializationFormat;

final class BSONSerializationFormat : SerializationFormat
{

}

void toBSON(T, OR)(T val, ref OR buf)
	if (isOutputRange!(OR, ubyte[]))
{

}

ubyte[] toBSON(T)(T val)
{
	return [];
}

T fromBSON(T)(ubyte[] data)
{
	return T.init;
}