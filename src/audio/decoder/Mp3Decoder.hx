package audio.decoder;

import haxe.io.Bytes;
import haxe.io.BytesInput;

import format.mp3.Data;
import format.mp3.Tools;

#if js
  import js.html.Audio;
  import js.html.audio.AudioContext;
  import js.html.audio.OfflineAudioContext;
#else
  // TODO: Haxe MP3 Decoder
#end

/**
 * Simple interface to MP3 Decoder
 *
 * Progressively decode the MP3 by requesting range
 * 
 * JS works but sample point are wayyyy off compared to Flash extract()
 *
 * Will need some major cleanup, mostly experimenting right now...
 */
class Mp3Decoder extends Decoder
{
  #if js
  static var onlineAudio:AudioContext = new AudioContext();
  var offlineAudio:OfflineAudioContext;
  var decodedChannels:Array<js.html.Float32Array> = [];
  #else

  #end

  // Keep bytes
  var bytes:Bytes = null;

  // Constructor
  public function new( bytes:Bytes, delay:Bool = false )
  {
    this.bytes = bytes;
    
    super(delay);
  }
  
  override function create()
  {
    trace("");
    
    #if js
    // Knowing some info about the MP3 file is absolutely necessary (maybe find a smaller footprint library for this...)
    var info = Mp3Utils.getInfo(bytes);
    trace("MP3 Reader finished");
    
    _process( info.length, info.channels, info.sampleRate );

    // Use Browser DecodeAudioData, at first it seems like CPU usage is down as well as Chrome's "violation"
    if ( hasDecodeAudioData() )
    {
      decodeWebAudio();
    }
    #elseif flash
    // Use Sound.extract()
    trace("MP3 not implemented yet!!!");

    _process( 2, 2, 44100 );
    #else
    trace("MP3 not implemented yet!!!");

    _process( 2, 2, 44100 );
    #end
  }

  // Read samples inside the MP3
  private override function read(start:Int, end:Int):Bool
  {
    #if js

    if ( hasDecodeAudioData() )
    {
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
    }
    else
    {
      // TODO: !!!

      return true;
    }

    #else
    // TODO: !!!
    return true;
    #end
  }

  #if js
  // Interesting way to decode samples with WebAudio... Need to do some tests...
  function decodeWebAudio()
  {
    // Use Browser DecodeAudioData
    offlineAudio = new OfflineAudioContext(channels, length, sampleRate );

    var source = offlineAudio.createBufferSource();

    var start = Date.now().getTime();

    // For some weird reason, Promise Based seems faster...
    if ( hasPromise() )
    {
      onlineAudio.decodeAudioData( bytes.getData() ).then( function(buffer)
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
    else
    {
      // No promise :(
      onlineAudio.decodeAudioData( bytes.getData(), function(buffer)
      {
        source.buffer = buffer;
        source.connect(offlineAudio.destination);
        source.start();

        offlineAudio.oncomplete = function(e)
        {
          var renderedBuffer = e.renderedBuffer;
          trace('Rendering completed successfully!!', Date.now().getTime() - start );

          for ( channel in 0...channels )
          {
            decodedChannels.push( renderedBuffer.getChannelData(channel) );
          }
        };

        offlineAudio.startRendering();
      } );
    }
  }

  // Check if we can use decodeAudioData
  static var _hasDecodeAudioData = 0;
  function hasDecodeAudioData()
  {
    if ( _hasDecodeAudioData > 0 ) return _hasDecodeAudioData == 1;

    if ( untyped __typeof__(onlineAudio.decodeAudioData) == "function" )
    {
      trace("WE HAVE DECODE AUDIO!!!!!!!");

      // Check OGG Vorbis support
      var support = new Audio().canPlayType('audio/mpeg; codecs="mp3"');
      trace("MP3 Support", support);
      if ( support == 'probably' )
      {
        _hasDecodeAudioData = 1;
        return true;
      }
    }

    _hasDecodeAudioData = 2;
    return false;
  }

  // Check if we have a promise based browser
  static var _hasPromise = 0;
  function hasPromise()
  {
    if ( _hasPromise > 0 ) return _hasPromise == 1;

    if ( untyped __js__('typeof Promise !== "undefined" && Promise.toString().indexOf("[native code]") !== -1') )
    {
      trace("WE HAVE PROMISE!!!!!!!");
      _hasPromise = 1;
      return true;
    }

    _hasPromise = 2;
    return false;
  }
  #end
}

// Modify the MP3 Class a bit so we can get the information a bit more efficiently
typedef Mp3Info =
{
  var sampleRate:Int;
  var channels:Int;
  var length:Int;
};

private class Mp3Utils extends format.mp3.Reader
{
  var bi:BytesInput;
  var channels:Int = 1;
  var sampleRate:Int = 44100;
  
  public function new( i:BytesInput ) 
  {
    bi = i;
    
    super(i);
  }
  
  public override function readFrame():MP3Frame
  {
    var header = readFrameHeader();
    
    if (header == null || Tools.isInvalidFrameHeader(header))
      return null;
    
    channels = header.channelMode == Mono ? 1 : 2;
    
    sampleRate = switch ( header.samplingRate )
    {
      case SR_48000: 48000;
      case SR_44100: 44100;
      case SR_32000: 32000;
      case SR_24000: 24000;
      case SR_22050: 22050;
      case SR_12000: 12000;
      case SR_11025: 11025;
      case SR_8000: 8000;
      default: 441000;
    };
    
    try {
      var length = Tools.getSampleDataSizeHdr(header);
      samples += Tools.getSampleCountHdr(header);
      sampleSize += length;
      
      bi.position += length;
      
      return 
      {
        header: header,
        data: null
      };
    }
    catch ( e:haxe.io.Eof )
    {
      return null;
    }
  }

  public static function getInfo( bytes:Bytes ):Mp3Info
  {
    var reader = new Mp3Utils(new BytesInput(bytes));
    
    reader.readFrames();
    
    return
    {
      sampleRate: reader.sampleRate,
      channels: reader.channels,
      length: reader.samples
    };
  }
}