package audio.decoder;

import haxe.io.Bytes;
import haxe.io.Output;
import haxe.io.BytesOutput;

// Chunk
private typedef Chunk =
{
  var decoded:Bool;
  var start:Int;
  var end:Int;

  var next:Chunk;
  var previous:Chunk;
};

// BytesOutput
private class BytesOutput extends Output
{
  var bytes:Bytes;
  var position:Int;

  public function new( bytes:Bytes )
  {
    this.bytes = bytes;
  }

  public function done()
  {

  }

  public function setPosition( position:Int )
  {
    this.position = position;
  }

  override function writeFloat(f)
  {
    bytes.setFloat(position, f);
    position += 4;
  }

  override function writeInt16(i)
  {
    bytes.setUInt16(position, i);
    position += 2;
  }
}

/**
 * Abstract for MP3 / OGG Decoder
 *
 * Basically, we want to decode chunk of the file at a time when needed,
 * eventually having the whole file decoded and not decoding a chunk
 * that has already been decoded.
 */
class Decoder
{
  // Performance
  #if decode_float
  public static inline var USE_FLOAT:Bool = true;
  public static inline var BPS:Int = 4;
  #else
  public static inline var USE_FLOAT:Bool = false;
  public static inline var BPS:Int = 2;
  #end

  // Decoded Bytes in 16bit per sample
  public var decoded:Bytes;
  private var output:BytesOutput;
  private var position:Int = 0;

  // Keep track of decoded chunk (DLL)
  var chunks:Chunk;

  // Properties
  public var length:Int = 0;
  public var channels:Int = 2;
  public var sampleRate:Int = 44100;

  // Bytes per sample (16 Bits or Float 32 Bits)
  private var bps:Int = BPS;

  // Constructor
  public function new( length:Int, channels:Int, sampleRate:Int )
  {
    this.length = length;
    this.channels = channels;
    this.sampleRate = sampleRate;

    // Create Bytes big enough to hold the decoded bits
    decoded = Bytes.alloc(length * BPS * channels);
    output = new BytesOutput(decoded);

    // We now have one big non-decoded chunk
    chunks =
    {
      decoded: false,
      start: 0,
      end: length,
      next: null,
      previous: null
    };
  }

  // Debug String
  public function chunkDebug(start:Int, end:Int)
  {
    var first:Chunk =
    {
      decoded: false,
      start: 0,
      end: start,
      next: null,
      previous: null
    };

    var middle:Chunk =
    {
      decoded: true,
      start: start,
      end: end,
      next: null,
      previous: first
    };

    var last:Chunk =
    {
      decoded: false,
      start: end,
      end: length,
      next: null,
      previous: middle
    };

    first.next = middle;
    middle.next = last;

    return chunkString("", first);
  }
  public function chunkString(str:String = "", chunk:Chunk = null, n:Int = 0, m:Int = 0)
  {
    if ( chunk == null ) chunk = chunks;

    var max = 40;

    var l = chunk.end - chunk.start;
    var c = Math.ceil((l / length) * max);

    n += l;
    m++;

    for ( i in 0...c )
    {
      str += chunk.decoded ? "X" : "O";
    }

    if ( chunk.next == null )
    {
      return str + " (" + n + " / " + m /*+ " / " + str.length*/ + ")";
    }

    return chunkString(str, chunk.next, n, m);
  }

  // Mostly usefull for debug, save decoded Bytes to WAV Bytes (16bits)
  public function getWAV()
  {
    var bitsPerSample = 16;
    var byteRate = Std.int(channels * sampleRate * bitsPerSample / 8);
    var blockAlign = Std.int(channels * bitsPerSample / 8);
    var dataLength = length * channels * 2;

    var output = new BytesOutput();
    output.bigEndian = false;
    output.writeString("RIFF");
    output.writeInt32(36 + dataLength);
    output.writeString("WAVEfmt ");
    output.writeInt32(16);
    output.writeUInt16(1);
    output.writeUInt16(channels);
    output.writeInt32(sampleRate);
    output.writeInt32(byteRate);
    output.writeUInt16(blockAlign);
    output.writeUInt16(bitsPerSample);
    output.writeString("data");
    output.writeInt32(dataLength);

    // Read Samples one after another (testing actual float conversion also)
    startSample(0);
    var n = length * channels, ival:Int;
    for ( i in 0...n )
    {
      /*ival = Std.int(nextSample() * 0x8000);
      if( ival > 0x7FFF ) ival = 0x7FFF;
      output.writeByte(ival & 0xFF);
      output.writeByte((ival >>> 8) & 0xFF);*/

      // This works too, seems as fast if not faster, but maybe not on all target...
      output.writeInt16( Std.int(nextSample() * 32767) );
      //output.writeInt16( Std.int((Math.random()*2-1) * 32767) );
    }

    return output.getBytes();
  }

  // Get a sample
  public inline function getSample(pos:Int, channel:Int = 0)
  {
    /*if ( USE_FLOAT )
    {
      return getSampleF(pos, channel);
    }
    else
    {
      return getSample16(pos, channel);
    }*/

    #if decode_float
    return getSampleF(pos, channel);
    #else
    return getSample16(pos, channel);
    #end
  }

  // 16 Bit
  private inline function sext16(v:Int)
  {
    return (v & 0x8000) == 0 ? v : v | 0xFFFF0000;
  }
  public inline function getSample16(pos:Int, channel:Int)
  {
    return sext16(decoded.getUInt16( (pos * channels + channel) << 1 )) / 0x8000;
  }

  // Float
  public inline function getSampleF(pos:Int, channel:Int)
  {
    return decoded.getFloat( (pos * channels + channel) << 2 );
  }

  // Start Sample
  public inline function startSample(pos:Int)
  {
    #if decode_float
    position = (pos * channels - 1) << 2;
    #else
    position = (pos * channels - 1) << 1;
    #end
  }

  // Nest Sample
  public inline function nextSample()
  {
    #if decode_float
    return decoded.getFloat( position += 4 );
    #else
    return sext16(decoded.getUInt16( position += 2 )) / 0x8000;
    #end
  }

  // Read samples inside the decoder
  private function read(start:Int, end:Int)
  {
    // Override me ;)
  }

  // Read all samples
  private function readAll( handler:Void->Void = null )
  {
    // Simply call read, but this could be override for specific target like JS with AudioContext
    read(0, length);

    // Call handler
    if ( handler != null ) handler();
  }

  // Decode all the samples, in one shot
  public function decodeAll( handler:Void->Void = null )
  {
    // We now have one big decoded chunk
    chunks =
    {
      decoded: true,
      start: 0,
      end: length,
      next: null,
      previous: null
    };

    // Read in one shot
    readAll( handler );
  }

  // Decode remaining
  public function decodeRemaining()
  {
    decode(0, length);
  }

  // Makes sure this range is decoded
  public function decode(start:Int, end:Int)
  {
    if ( start < 0 ) start = 0;
    if ( end > length ) end = length;

    _decode(start, end, chunks);
  }
  private function _decode(start:Int, end:Int, chunk:Chunk)
  {
    var previous = chunk.previous;
    var next = chunk.next;

    // If decoded, jump to next immediately
    if ( chunk.decoded )
    {
      if ( next != null ) _decode(start, end, next);
      return;
    }

    // Chunk is inside
    if ( ((chunk.start <= start) && (chunk.end >= start)) || ((chunk.start <= end) && (chunk.end >= end)) || ((chunk.start >= start) && (chunk.end <= end)) )
    {
      // Alright we need to decode
      var ds = start, de = end;
      if ( chunk.start > start ) ds = chunk.start;
      if ( chunk.end < end ) de = chunk.end;

      // This is the important part
      read(ds, de);

      // Edit current chunk (Ok, there's probably a better way to write this chunk of code,
      // but it kind of work really well and doesn't seem costly...)
      if ( (chunk.start == ds) && (chunk.end == de) )
      {
        // Chunk disappeared!
        if ( (previous == null) || !previous.decoded )
        {
          if ( (next == null) || !next.decoded )
          {
            // We are head and nothing else exists
            chunk.decoded = true;
          }
          else
          {
            // Merge into next chunk
            chunk.end = next.end;
            chunk.next = next.next;
            if ( chunk.next != null ) chunk.next.previous = chunk;
          }
        }
        else
        {
          if ( (next != null) && next.decoded )
          {
            previous.end = next.end;
            previous.next = next.next;
            if ( previous.next != null ) previous.next.previous = previous;
          }
          else
          {
            previous.end = chunk.end;
            previous.next = next;
            if ( next != null ) next.previous = previous;
          }
        }
      }
      else
      {
        // Chunk need to be cut into pieces (this is my last resort)
        if ( (ds > chunk.start) && (de < chunk.end) )
        {
          // Right in the middle so we got 3 chunk
          chunk.next =
          {
            decoded: true,
            start: ds,
            end: de,
            next: null,
            previous: chunk
          };

          chunk.next.next =
          {
            decoded: false,
            start: de,
            end: chunk.end,
            next: next,
            previous: chunk.next
          };

          chunk.end = ds;

          if ( next != null ) next.previous = chunk.next.next;
        }
        else if ( ds > chunk.start )
        {
          // Left chunk is empty, Right chunk is decoded
          chunk.end = ds;

          if ( (next != null) && next.decoded )
          {
            next.start = ds;
          }
          else
          {
            chunk.next =
            {
              decoded: true,
              start: ds,
              end: de,
              next: next,
              previous: chunk
            };

            if ( next != null ) next.previous = chunk.next;
          }
        }
        else if ( de < chunk.end )
        {
          // Left chunk is decoded, Right chunk is empty
          if ( (previous == null) || !previous.decoded )
          {
            chunk.decoded = true;

            if ( (next != null) && !next.decoded )
            {
              next.start = de;
            }
            else
            {
              chunk.next =
              {
                decoded: false,
                start: de,
                end: chunk.end,
                next: next,
                previous: chunk
              };

              if ( next != null ) next.previous = chunk.next;
            }

            chunk.end = de;
          }
          else
          {
            previous.end = de;

            chunk.start = de;
          }
        }
      }
    }

    // Check if we continue
    if ( (next != null) && (next.start < end) )
    {
      // Continue search
      _decode( start, end, next );
    }
  }
}