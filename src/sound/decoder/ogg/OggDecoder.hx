package sound.decoder.ogg;

import haxe.io.Bytes;
import haxe.io.BytesOutput;

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

/**
 * Simple interface to stb_ogg_sound
 * 
 * Progressively decode the OGG by requesting range
 * 
 * https://github.com/motion-twin/haxe_stb_ogg_sound (Motion Twin fork)
 */
class OggDecoder 
{
  // Stb OGG
  var reader:Reader;
  
  // Decoded Bytes in 16bit per sample
  public var decoded:Bytes;
  
  // Keep track of decoded chunk
  var chunks:Chunk;
  
  // Properties
  public var length:Int = 0;
  public var channels:Int = 2;
  public var sampleRate:Int = 44100;
  
  // Constructor
  public function new( bytes:Bytes ) 
  {
    reader = Reader.openFromBytes(bytes);
    
    length = reader.totalSample;
    channels = reader.header.channel;
    sampleRate = reader.header.sampleRate;
    
    // Create Bytes big enough to hold the decoded bits
    decoded = Bytes.alloc(length * 2 * channels);
    
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
  
  // Read samples inside the OGG
  public function read(start:Int, end:Int)
  {
    // TODO !
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
      
      //trace("-----------------------------");
      
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