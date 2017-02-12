package audio.decoder;

import haxe.io.Bytes;

#if lime_vorbis
import haxe.Int64;
import lime.utils.UInt8Array;
import lime.utils.Int16Array;
import lime.utils.Float32Array;
import lime.media.codecs.vorbis.VorbisFile;
#else
import stb.format.vorbis.Reader;
#end

/**
 * Simple interface to stb_ogg_sound
 *
 * Progressively decode the OGG by requesting range
 *
 * https://github.com/motion-twin/haxe_stb_ogg_sound (Motion Twin fork)
 */
class OggDecoder extends Decoder
{
  // Max samples read per call
  // Why, i'm not quite sure but this is how it was done in the official
  // library so there must be a good reason...
  private static inline var MAX_SAMPLE = 65536;
  private static inline var STREAM_BUFFER_SIZE = 48000;
  
  #if lime_vorbis
  var reader:VorbisFile;
  #else
  var reader:Reader;
  #end
  
  // Keep bytes
  var bytes:Bytes = null;
  
  // Constructor
  public function new( bytes:Bytes )
  {
    trace("");
    
    this.bytes = bytes;
    
    #if lime_vorbis
    //reader = VorbisFile.fromFile("assets/test1.ogg");
    reader = VorbisFile.fromBytes( bytes );
    //reader.streams();
    
    var info = reader.info();
    
    super( Int64.toInt(reader.pcmTotal()), info.channels, info.rate );
    
    #else
    reader = Reader.openFromBytes(bytes);
    super( reader.totalSample, reader.header.channel, reader.header.sampleRate );
    
    #end
    
    trace("OGG Reader finished");
  }
  
  #if lime_vorbis
  // Read bufer
  private function readVorbisFileBuffer( length:Int )
  {
		//var buffer = new UInt8Array( length );
    var buffer = new Int16Array( Std.int(length / 2) );
		//var buffer = new Float32Array( length );
    
    var read = 0, total = 0, readMax;
		
		while ( total < length ) 
    {
			readMax = 4096;
			
			if ( readMax > (length - total) ) 
      {
				readMax = length - total;
			}
			
			read = reader.read( buffer.buffer, total, readMax );
			//read = reader.readFloat( buffer.buffer, readMax );
			
			if (read > 0) 
      {
				total += read;
			}
      else 
      {
				break;
			}
		}
		
		return buffer;
	}
  #end
  
  // Read samples inside the OGG
  private override function read(start:Int, end:Int)
  {
    #if lime_vorbis
    var l = end - start, stop = false;
    var position = 0, buffer = null;
    
    var dataLength = Std.int( l * channels * 2 ); // 16 bits == 2 bytes
    
    reader.pcmSeek( Int64.ofInt(start) );
    output.setPosition( start * channels );
    
    while ( !stop )
    {
      if ( (dataLength - position) >= STREAM_BUFFER_SIZE )
      {
        buffer = readVorbisFileBuffer(STREAM_BUFFER_SIZE);
        position += STREAM_BUFFER_SIZE;
      } 
      else if ( position < dataLength ) 
      {
        buffer = readVorbisFileBuffer(dataLength - position);
        stop = true;
      }
      else
      {
        stop = true;
        break;
      }
      
      for ( i in 0...buffer.length )
      {
        output.writeFloat( buffer[i] / 32768 );
        //output.writeFloat( buffer[i] );
      }
    }
    
    output.done();
    
    #else
    //trace("");

    // Start
    reader.currentSample = start;
    //output.setPosition( start * Decoder.BPS * channels );
    output.setPosition( start * channels );
    
    // Read into output
    var l = end - start;
    while ( l > 0 )
    {
      var n = reader.read(output, l > MAX_SAMPLE ? MAX_SAMPLE : l, channels, sampleRate, Decoder.USE_FLOAT);
      if (n == 0) { break; }
      l -= MAX_SAMPLE;
    }

    //var n = reader.read(output, end - start, channels, sampleRate, USE_FLOAT);
    output.done();

    // Debug
    //trace("Read", start, end);
    
    #end
  }
}