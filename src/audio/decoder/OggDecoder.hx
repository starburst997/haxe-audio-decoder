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
import stb.format.vorbis.Reader;
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
  static var onlineAudio:AudioContext = new AudioContext();
  var offlineAudio:OfflineAudioContext;
  var decodedChannels:Array<js.html.Float32Array> = [];
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
    // Knowing some info about the OGG file is absolutely necessary (maybe find a smaller footprint library for this...)
    var reader = Reader.openFromBytes(bytes);
    trace("OGG Reader finished");
    
    super( reader.totalSample, reader.header.channel, reader.header.sampleRate );
    
    // Use Browser DecodeAudioData, at first it seems like CPU usage is down as well as Chrome's "violation"
    decodeWebAudio();
    
    #elseif lime_vorbis
    //reader = VorbisFile.fromFile("assets/test1.ogg");
    reader = VorbisFile.fromBytes( bytes );
    //reader.streams();
    
    var info = reader.info();
    trace("OGG Reader finished");
    
    super( Int64.toInt(reader.pcmTotal()), info.channels, info.rate );
    
    #else
    reader = Reader.openFromBytes(bytes);
    trace("OGG Reader finished");
    
    super( reader.totalSample, reader.header.channel, reader.header.sampleRate );
    #end
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
  private override function read(start:Int, end:Int):Bool
  {
    #if (js && webaudio)
    
    // Blit decoded output
    
    if ( decodedChannels.length > 0 )
    {
      var buffer:js.html.Float32Array;
      if ( channels == 2 )
      {
        for ( i in start...end )
        {
          decoded[(i << 1)] = decodedChannels[0][i];
          decoded[(i << 1) + 1] = decodedChannels[1][i];
        }
      }
      else if ( channels == 1 )
      {
        for ( i in start...end )
        {
          decoded[i] = decodedChannels[0][i];
        }
      }
      else
      {
        // Not supported
      }
      
      return true;
    }
    
    return false;
    
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
    return true;
    
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
    return true;

    // Debug
    //trace("Read", start, end);
    
    #end
  }
  
  #if (js && webaudio)
  // Interesting way to decode samples with WebAudio... Need to do some tests...
  function decodeWebAudio()
  {
    // Use Browser DecodeAudioData, sadly, doesn't seem very fast...
    offlineAudio = new OfflineAudioContext(channels, length, sampleRate );
    
    var source = offlineAudio.createBufferSource();
    
    var start = Date.now().getTime();
    
    onlineAudio.decodeAudioData( bytes.getData(), function(buffer) 
    {
      source.buffer = buffer;
      source.connect(offlineAudio.destination);
      source.start();
      
      offlineAudio.startRendering().then( function( renderedBuffer ) 
      {
        trace('Rendering completed successfully!!', Date.now().getTime() - start );
        
        for ( channel in 0...channels )
        {
          decodedChannels.push( renderedBuffer.getChannelData(channel) );
        }
      } );
    } );
  }
  #end
}