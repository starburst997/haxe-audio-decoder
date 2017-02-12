package audio.decoder;

import haxe.io.Bytes;

#if lime_vorbis
import haxe.Int64;
import lime.utils.UInt8Array;
import lime.utils.Int16Array;
import lime.utils.Float32Array;
import lime.media.codecs.vorbis.VorbisFile;
#elseif (js && webaudio)
import js.html.audio.AudioContext;
import js.html.audio.OfflineAudioContext;
#else
import stb.format.vorbis.Reader;
#end

/**
 * Simple interface to stb_ogg_sound
 *
 * Progressively decode the OGG by requesting range
 *
 * https://github.com/motion-twin/haxe_stb_ogg_sound (Motion Twin fork)
 * 
 * Compile flag "oggFloat" doesn't seems to works
 */
class OggDecoder extends Decoder
{
  // Max samples read per call
  // Why, i'm not quite sure but this is how it was done in the official
  // library so there must be a good reason...
  private static inline var MAX_SAMPLE = 65536;
  private static inline var STREAM_BUFFER_SIZE = 48000;
  
  #if (js && webaudio)
  
  #elseif lime_vorbis
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
    
    #if (js && webaudio)
    
    super(1, 2, 44100);
    
    #elseif lime_vorbis
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
    
    #if !oggFloat
    var buffer = new Int16Array( Std.int(length / 2) );
    #else
		var buffer = new Float32Array( Std.int(length / 4) );
    #end
    
    var read = 0, total = 0, readMax;
		
		while ( total < length ) 
    {
			readMax = 4096;
			
			if ( readMax > (length - total) ) 
      {
				readMax = length - total;
			}
			
      #if !oggFloat
			read = reader.read( buffer.buffer, total, readMax );
      #else
			read = reader.readFloat( buffer.buffer, readMax );
			#end
      
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
    #if (js && webaudio)
    
    // Nothing to do here since we can only decode whole file at once
    
    #elseif lime_vorbis
    var l = end - start, stop = false;
    var position = 0, buffer = null;
    
    #if !oggFloat
    var dataLength = Std.int( l * channels * 2 ); // 16 bits == 2 bytes
    #else
    var dataLength = Std.int( l * channels * 4 );
    #end
    
    reader.pcmSeek( Int64.ofInt(start) );
    output.setPosition( start * channels );
    
    #if !oggFloat
    var p = Std.int( start * channels * 2 );
    #else
    var p = Std.int( start * channels * 4 );
    #end
    
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
      
      #if audio16
      
      #if !oggFloat
      output.array.buffer.blit(p, buffer.buffer, 0, buffer.length << 1);
      p += buffer.length << 1;
      #else
      for ( i in 0...buffer.length )
      {
        output.writeInt16( Std.int(buffer[i] * 32767.0) );
      }
      #end
      
      #else
      
      #if !oggFloat
      for ( i in 0...buffer.length )
      {
        output.writeFloat( buffer[i] / 32768.0 );
        //output.writeFloat( buffer[i] );
      }
      #else
      output.array.buffer.blit(p, buffer.buffer, 0, buffer.length << 2);
      p += buffer.length << 2;
      #end
      
      #end
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
  
  // WebAudio Decoder
  #if (js && webaudio)
  
  // TODO: But I feel like this will go nowhere, seems kind of slow for very small file?
  // And no way to extract a small part of it :(
  
  #end
}