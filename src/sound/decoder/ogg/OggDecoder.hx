package sound.decoder.ogg;

import haxe.io.Bytes;

import stb.format.vorbis.Reader;

// Chunk
private typedef Chunk = 
{
  var decoded:Bool;
  var start:Int;
  var end:Int;
  
  var next:Chunk;
  var previous:Chunk;
};

// Stolen from https://github.com/ncannasse/heaps/blob/master/hxd/snd/OggData.hx
private class BytesOutput extends haxe.io.Output 
{
	var bytes : haxe.io.Bytes;
	var position : Int;
	#if flash
	var m : hxd.impl.Memory.MemoryReader;
	#end

	public function new( bytes:Bytes ) 
  {
    this.bytes = bytes;
		#if flash
		m = hxd.impl.Memory.select(bytes);
		#end
	}

	public function done() {
		#if flash
		m.end();
		#end
	}

	public function setPosition( position:Int ) {
		this.position = position;
	}

	override function writeFloat(f) {
		#if flash
		m.wfloat(position, f);
		#else
		bytes.setFloat(position, f);
		#end
		position += 4;
	}

	override function writeInt16(i) {
		#if flash
		m.wb(position++, i >> 8);
		m.wb(position++, i);
		#else
		bytes.setUInt16(position, i);
		position += 2;
		#end
	}
}

/**
 * Simple interface to stb_ogg_sound
 * 
 * Progressively decode the OGG by requesting range
 * 
 * https://github.com/motion-twin/haxe_stb_ogg_sound (Motion Twin fork)
 */
class OggDecoder 
{
  // Performance
  public static inline var USE_FLOAT:Bool = false;
  
  // Stb OGG
  var reader:Reader;
  
  // Decoded Bytes in 16bit per sample
  public var decoded:Bytes;
  private var output:BytesOutput;
  
  // Keep track of decoded chunk
  var chunks:Chunk;
  
  // Properties
  public var length:Int = 0;
  public var channels:Int = 2;
  public var sampleRate:Int = 44100;
  
  // Bytes per sample (16 Bits)
  private var bps:Int = USE_FLOAT ? 4 : 2;
  
  // Constructor
  public function new( bytes:Bytes ) 
  {
    reader = Reader.openFromBytes(bytes);
    
    length = reader.totalSample;
    channels = reader.header.channel;
    sampleRate = reader.header.sampleRate;
    
    // Create Bytes big enough to hold the decoded bits
    decoded = Bytes.alloc(length * bps * channels);
    output = new BytesOutput(decoded);
    
    // We now have one big non-decoded chunk
    chunks  = {
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
    var first:Chunk = {
      decoded: false,
      start: 0,
      end: start,
      next: null,
      previous: null
    };
    
    var middle:Chunk = {
      decoded: true,
      start: start,
      end: end,
      next: null,
      previous: first
    };
    
    var last:Chunk = {
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
  
  // Get a sample
  public inline function getSample(pos:Int, channel:Int)
  {
    if ( USE_FLOAT )
    {
      return getSampleF(pos, channel);
    }
    else
    {
      return getSample16(pos, channel);
    }
  }
  
  // 16 Bit
  public inline function getSample16(pos:Int, channel:Int)
  {
    inline function sext16(v:Int) {
      return (v & 0x8000) == 0 ? v : v | 0xFFFF0000;
    }
    
    return sext16(decoded.getUInt16( ((pos * channels) << 1) + (channel << 1) )) / 0x8000;
  }
  
  // Float
  public inline function getSampleF(pos:Int, channel:Int)
  {
    return decoded.getFloat( ((pos * channels) << 2) + (channel << 2) );
  }
  
  // Read samples inside the OGG
  private function read(start:Int, end:Int)
  {
    // Start
    reader.currentSample = start;
    
    // 16 Bits
    output.setPosition( start * bps * channels );
    
    // Read into output
    var n = reader.read(output, end - start, channels, sampleRate, USE_FLOAT);
    output.done();
    
    // Debug
    trace("Read", start, end, n);
  }
  
  // Makes sure this range is decoded
  public function decode(start:Int, end:Int)
  {
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
      
      // Edit current chunk
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
          chunk.next = {
            decoded: true,
            start: ds,
            end: de,
            next: null,
            previous: chunk
          };
          
          chunk.next.next = {
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
            chunk.next = {
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
              chunk.next = {
                decoded: false,
                start: de,
                end: chunk.end,
                next: next,
                previous: chunk
              }
              
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